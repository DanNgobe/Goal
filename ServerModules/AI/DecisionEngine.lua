--[[
  DecisionEngine.lua
  
  Base decision-making logic for all NPCs (outfield players and goalkeepers).
  Evaluates game state and selects optimal actions based on role, position, and tactical state.
  
  Responsibilities:
  - Evaluate current game state for a single NPC
  - Maintain decision state machine (Idle, Positioning, Pursuing, Attacking, Defending)
  - Score potential actions (pass, shoot, dribble, defend)
  - Select highest-scoring action
  
  Can be inherited by specialized decision engines (e.g., GoalkeeperDecisionEngine)
]]

local DecisionEngine = {}
DecisionEngine.__index = DecisionEngine

local AIConfig = require(script.Parent.AIConfig)
local BallPredictor = require(script.Parent.BallPredictor)
local SafeMath = require(script.Parent.SafeMath)

function DecisionEngine.new()
  local self = setmetatable({}, DecisionEngine)
  return self
end

function DecisionEngine:Decide(npc, gameState, decisionState)
  if not npc or not gameState then
    warn("[DecisionEngine] Invalid parameters passed to Decide")
    return {action = "Position", target = npc.Position, priority = 0}
  end
  
  local hasPossession = gameState.ball.possessor == npc
  
  if hasPossession then
    return self:DecideWithPossession(npc, gameState, decisionState)
  else
    return self:DecideWithoutPossession(npc, gameState, decisionState)
  end
end

function DecisionEngine:DecideWithPossession(npc, gameState, decisionState)
  local actions = {}
  
  local shootScore = self:ScoreShot(npc, gameState)
  if shootScore > 0 then
    table.insert(actions, {
      action = "Shoot",
      target = gameState.opponentTeam.goalPosition,
      score = shootScore,
      reasoning = "Shot opportunity available"
    })
  end
  
  local passOptions = self:GetPassingOptions(npc, gameState)
  for _, option in ipairs(passOptions) do
    local passScore = self:ScorePass(npc, option.teammate, gameState)
    if passScore > 0 then
      table.insert(actions, {
        action = "Pass",
        target = option.teammate,
        score = passScore,
        reasoning = "Pass to " .. option.teammate.Role
      })
    end
  end
  
  local dribbleScore = self:ScoreDribble(npc, gameState)
  if dribbleScore > 0 then
    local dribbleDirection = (gameState.opponentTeam.goalPosition - npc.Position).Unit
    table.insert(actions, {
      action = "Dribble",
      target = npc.Position + (dribbleDirection * 10),
      score = dribbleScore,
      reasoning = "Dribble toward goal"
    })
  end
  
  if #actions == 0 then
    return {
      action = "Dribble",
      target = npc.Position + Vector3.new(0, 0, 5),
      priority = 30,
      reasoning = "Default dribble"
    }
  end
  
  table.sort(actions, function(a, b) return a.score > b.score end)
  local bestAction = actions[1]
  
  return {
    action = bestAction.action,
    target = bestAction.target,
    priority = bestAction.score,
    reasoning = bestAction.reasoning
  }
end

function DecisionEngine:DecideWithoutPossession(npc, gameState, decisionState)
  local actions = {}
  
  if gameState.ball.isLoose then
    local shouldPursue = self:ShouldPursue(npc, gameState, nil)
    if shouldPursue then
      local canIntercept, interceptionPoint = BallPredictor:CanIntercept(
        npc,
        gameState.ball.part,
        AIConfig.PREDICTION_TIME_AHEAD
      )
      
      local pursuitScore = self:ScorePursuit(npc, gameState)
      table.insert(actions, {
        action = "Pursue",
        target = interceptionPoint,
        score = pursuitScore,
        reasoning = "Pursue loose ball"
      })
    end
  end
  
  if gameState.ball.possessor and self:IsOpponent(npc, gameState.ball.possessor, gameState) then
    local defensiveTarget = self:SelectDefensiveTarget(npc, gameState)
    if defensiveTarget then
      local defendScore = self:ScoreDefend(npc, gameState)
      table.insert(actions, {
        action = "Defend",
        target = defensiveTarget,
        score = defendScore,
        reasoning = "Apply defensive pressure"
      })
    end
  end
  
  if #actions == 0 then
    return {
      action = "Position",
      target = npc.TargetPosition or npc.Position,
      priority = 40,
      reasoning = "Return to formation position"
    }
  end
  
  table.sort(actions, function(a, b) return a.score > b.score end)
  local bestAction = actions[1]
  
  return {
    action = bestAction.action,
    target = bestAction.target,
    priority = bestAction.score,
    reasoning = bestAction.reasoning
  }
end

function DecisionEngine:ScorePass(npc, teammate, gameState)
  if not npc or not teammate or not gameState then
    return 0
  end
  
  -- Wrap in pcall for error handling
  local success, score = pcall(function()
    local npcPosition = npc.Position
    local teammatePosition = teammate.Position
    local distance = SafeMath.SafeDistance(npcPosition, teammatePosition)
    
    if distance > AIConfig.MAX_PASS_DISTANCE then
      return 0
    end
    
    local distanceScore = 100 - math.abs(distance - AIConfig.OPTIMAL_PASS_DISTANCE) * 2
    distanceScore = SafeMath.Clamp(distanceScore, 0, 100)
    
    local forwardProgress = self:CalculateForwardProgress(
      npcPosition,
      teammatePosition,
      gameState.opponentTeam.goalPosition
    )
    local forwardScore = math.max(0, forwardProgress * 50)
    
    local passingLaneClear = self:IsPassingLaneClear(npcPosition, teammatePosition, gameState)
    local laneScore = passingLaneClear and 100 or 20
    
    local opponentProximity = self:GetNearestOpponentDistance(teammate, gameState)
    local proximityScore = math.min(100, opponentProximity * 5)
    
    local totalScore = (distanceScore * 0.3) + (forwardScore * 0.3) + (laneScore * 0.3) + (proximityScore * 0.1)
    
    return totalScore
  end)
  
  if not success then
    warn("[DecisionEngine] ScorePass failed:", score)
    return 0
  end
  
  return score or 0
end

function DecisionEngine:ScoreShot(npc, gameState)
  if not npc or not gameState then
    return 0
  end
  
  local npcPosition = npc.Position
  local goalPosition = gameState.opponentTeam.goalPosition
  local distance = (goalPosition - npcPosition).Magnitude
  
  if distance > AIConfig.MAX_SHOT_DISTANCE then
    return 0
  end
  
  local distanceScore = 100 - math.abs(distance - AIConfig.OPTIMAL_SHOT_DISTANCE) * 3
  distanceScore = math.max(0, math.min(100, distanceScore))
  
  local shootingAngle = self:CalculateShootingAngle(npcPosition, goalPosition, gameState)
  if shootingAngle < AIConfig.MIN_SHOT_ANGLE then
    return 0
  end
  
  local angleScore = math.min(100, shootingAngle * 2)
  
  local clearLine = self:HasClearLineToGoal(npcPosition, goalPosition, gameState)
  local lineScore = clearLine and 100 or 30
  
  local gkPosition = self:FindGoalkeeper(gameState.opponentTeam)
  local gkScore = 50
  if gkPosition then
    local gkDistance = (gkPosition - goalPosition).Magnitude
    gkScore = math.min(100, gkDistance * 10)
  end
  
  local totalScore = (distanceScore * 0.35) + (angleScore * 0.25) + (lineScore * 0.25) + (gkScore * 0.15)
  
  return totalScore
end

function DecisionEngine:ScoreDribble(npc, gameState)
  if not npc or not gameState then
    return 0
  end
  
  local baseScore = 50
  
  local opponentsNearby = self:CountOpponentsInRange(npc, gameState, AIConfig.PRESSURE_RANGE)
  if opponentsNearby > 0 then
    baseScore = baseScore - (opponentsNearby * 20)
  end
  
  if npc.Role == "DF" then
    local inDefensiveThird = self:IsInDefensiveThird(npc, gameState)
    if inDefensiveThird then
      baseScore = baseScore * 0.5
    end
  end
  
  local nearBoundary = self:IsNearFieldBoundary(npc, gameState)
  if nearBoundary then
    baseScore = baseScore * 0.3
  end
  
  return math.max(0, baseScore)
end

function DecisionEngine:ScorePursuit(npc, gameState)
  if not npc or not gameState then
    return 0
  end
  
  local ballPosition = gameState.ball.position
  local distance = (ballPosition - npc.Position).Magnitude
  
  if distance > AIConfig.BALL_PURSUIT_RANGE then
    return 0
  end
  
  local distanceScore = 100 - (distance / AIConfig.BALL_PURSUIT_RANGE) * 100
  
  local roleBonus = 0
  if npc.Role == "ST" or npc.Role == "LW" or npc.Role == "RW" then
    roleBonus = 20
  elseif npc.Role == "DF" then
    roleBonus = 10
  end
  
  return math.max(0, distanceScore + roleBonus)
end

function DecisionEngine:ScoreDefend(npc, gameState)
  if not npc or not gameState then
    return 0
  end
  
  local baseScore = 60
  
  local ballCarrier = gameState.ball.possessor
  if ballCarrier then
    local distance = (ballCarrier.Position - npc.Position).Magnitude
    if distance < AIConfig.PRESSURE_RANGE then
      baseScore = baseScore + 30
    end
  end
  
  local inDefensiveThird = self:IsInDefensiveThird(npc, gameState)
  if inDefensiveThird then
    baseScore = baseScore + 20
  end
  
  return baseScore
end

function DecisionEngine:ShouldPursue(npc, gameState, teamCoordinator)
  if not npc or not gameState then
    return false
  end
  
  if not gameState.ball.isLoose then
    return false
  end
  
  local ballPosition = gameState.ball.position
  local distance = (ballPosition - npc.Position).Magnitude
  
  if distance > AIConfig.BALL_PURSUIT_RANGE then
    return false
  end
  
  if npc.Role == "GK" then
    return distance < 10
  end
  
  return true
end

function DecisionEngine:SelectDefensiveTarget(npc, gameState)
  if not npc or not gameState then
    return nil
  end
  
  local ballCarrier = gameState.ball.possessor
  if ballCarrier and self:IsOpponent(npc, ballCarrier, gameState) then
    local distance = (ballCarrier.Position - npc.Position).Magnitude
    if distance < AIConfig.PRESSURE_RANGE * 2 then
      return ballCarrier.Position
    end
  end
  
  local nearestOpponent = self:FindNearestOpponent(npc, gameState)
  if nearestOpponent then
    local goalPosition = gameState.ownTeam.goalPosition
    local opponentPosition = nearestOpponent.Position
    local markingPosition = opponentPosition + ((goalPosition - opponentPosition).Unit * 3)
    return markingPosition
  end
  
  return nil
end

function DecisionEngine:GetPassingOptions(npc, gameState)
  local options = {}
  
  if not gameState.ownTeam or not gameState.ownTeam.npcs then
    return options
  end
  
  for _, teammate in ipairs(gameState.ownTeam.npcs) do
    if teammate ~= npc then
      local distance = (teammate.Position - npc.Position).Magnitude
      if distance <= AIConfig.MAX_PASS_DISTANCE then
        table.insert(options, {teammate = teammate})
      end
    end
  end
  
  return options
end

function DecisionEngine:CalculateForwardProgress(fromPosition, toPosition, goalPosition)
  if not fromPosition or not toPosition or not goalPosition then
    return 0
  end
  
  local currentDistanceToGoal = SafeMath.SafeDistance(fromPosition, goalPosition)
  local newDistanceToGoal = SafeMath.SafeDistance(toPosition, goalPosition)
  
  if currentDistanceToGoal < 0.1 then
    return 0
  end
  
  local progress = SafeMath.SafeDivide(currentDistanceToGoal - newDistanceToGoal, currentDistanceToGoal, 0)
  return progress
end

function DecisionEngine:IsPassingLaneClear(fromPosition, toPosition, gameState)
  if not gameState.opponentTeam or not gameState.opponentTeam.npcs then
    return true
  end
  
  local passDirection = SafeMath.SafeNormalize(toPosition - fromPosition, Vector3.new(0, 0, 1))
  local passDistance = SafeMath.SafeDistance(fromPosition, toPosition)
  
  for _, opponent in ipairs(gameState.opponentTeam.npcs) do
    if opponent and opponent.Parent and opponent:FindFirstChild("HumanoidRootPart") then
      local toOpponent = opponent.Position - fromPosition
      local projectionLength = SafeMath.SafeDot(toOpponent, passDirection)
      
      if projectionLength > 0 and projectionLength < passDistance then
        local projectionPoint = fromPosition + (passDirection * projectionLength)
        local distanceToLane = SafeMath.SafeDistance(opponent.Position, projectionPoint)
        
        if distanceToLane < AIConfig.PASS_LANE_WIDTH then
          return false
        end
      end
    end
  end
  
  return true
end

function DecisionEngine:GetNearestOpponentDistance(npc, gameState)
  if not gameState.opponentTeam or not gameState.opponentTeam.npcs then
    return 100
  end
  
  local minDistance = math.huge
  
  for _, opponent in ipairs(gameState.opponentTeam.npcs) do
    if opponent and opponent.Parent and opponent:FindFirstChild("HumanoidRootPart") then
      local distance = SafeMath.SafeDistance(npc.Position, opponent.Position)
      if distance < minDistance then
        minDistance = distance
      end
    end
  end
  
  return minDistance
end

function DecisionEngine:CalculateShootingAngle(npcPosition, goalPosition, gameState)
  local goalWidth = 10
  
  local toGoal = (goalPosition - npcPosition)
  local distance = toGoal.Magnitude
  
  if distance < 0.1 then
    return 90
  end
  
  local angle = math.deg(math.atan(goalWidth / distance))
  return angle * 2
end

function DecisionEngine:HasClearLineToGoal(npcPosition, goalPosition, gameState)
  if not gameState.opponentTeam or not gameState.opponentTeam.npcs then
    return true
  end
  
  local toGoal = (goalPosition - npcPosition).Unit
  local distanceToGoal = (goalPosition - npcPosition).Magnitude
  
  for _, opponent in ipairs(gameState.opponentTeam.npcs) do
    if opponent.Role ~= "GK" then
      local toOpponent = opponent.Position - npcPosition
      local projectionLength = toOpponent:Dot(toGoal)
      
      if projectionLength > 0 and projectionLength < distanceToGoal then
        local projectionPoint = npcPosition + (toGoal * projectionLength)
        local distanceToLine = (opponent.Position - projectionPoint).Magnitude
        
        if distanceToLine < 3 then
          return false
        end
      end
    end
  end
  
  return true
end

function DecisionEngine:FindGoalkeeper(team)
  if not team or not team.npcs then
    return nil
  end
  
  for _, npc in ipairs(team.npcs) do
    if npc.Role == "GK" then
      return npc.Position
    end
  end
  
  return nil
end

function DecisionEngine:CountOpponentsInRange(npc, gameState, range)
  if not gameState.opponentTeam or not gameState.opponentTeam.npcs then
    return 0
  end
  
  local count = 0
  
  for _, opponent in ipairs(gameState.opponentTeam.npcs) do
    local distance = (opponent.Position - npc.Position).Magnitude
    if distance < range then
      count = count + 1
    end
  end
  
  return count
end

function DecisionEngine:IsInDefensiveThird(npc, gameState)
  if not gameState.ownTeam or not gameState.fieldBounds then
    return false
  end
  
  local teamSide = gameState.ownTeam.name
  local npcZ = npc.Position.Z
  local fieldCenterZ = (gameState.fieldBounds.minZ + gameState.fieldBounds.maxZ) / 2
  local fieldDepth = gameState.fieldBounds.maxZ - gameState.fieldBounds.minZ
  
  local defensiveThirdZ = fieldCenterZ + (fieldDepth * 0.33 * ((teamSide == "Blue") and -1 or 1))
  
  if teamSide == "Blue" then
    return npcZ < defensiveThirdZ
  else
    return npcZ > defensiveThirdZ
  end
end

function DecisionEngine:IsNearFieldBoundary(npc, gameState)
  if not gameState.fieldBounds then
    return false
  end
  
  local position = npc.Position
  local bounds = gameState.fieldBounds
  local margin = 5
  
  return position.X < (bounds.minX + margin) or
         position.X > (bounds.maxX - margin) or
         position.Z < (bounds.minZ + margin) or
         position.Z > (bounds.maxZ - margin)
end

function DecisionEngine:FindNearestOpponent(npc, gameState)
  if not gameState.opponentTeam or not gameState.opponentTeam.npcs then
    return nil
  end
  
  local nearestOpponent = nil
  local minDistance = math.huge
  
  for _, opponent in ipairs(gameState.opponentTeam.npcs) do
    local distance = (opponent.Position - npc.Position).Magnitude
    if distance < minDistance then
      minDistance = distance
      nearestOpponent = opponent
    end
  end
  
  return nearestOpponent
end

function DecisionEngine:IsOpponent(npc, otherNpc, gameState)
  if not npc or not otherNpc or not gameState then
    return false
  end
  
  local npcTeam = gameState.ownTeam.name
  local otherTeam = nil
  
  if gameState.ownTeam.npcs then
    for _, teammate in ipairs(gameState.ownTeam.npcs) do
      if teammate == otherNpc then
        return false
      end
    end
  end
  
  return true
end

return DecisionEngine
