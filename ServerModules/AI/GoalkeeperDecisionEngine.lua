--[[
  GoalkeeperDecisionEngine.lua
  
  Specialized decision-making for goalkeepers, inherits from DecisionEngine.
  Overrides specific behaviors for goalkeeper positioning, shot reactions, and distribution.
  
  Responsibilities:
  - Override positioning logic to stay near goal
  - Override pursuit logic to be more conservative
  - Add shot reaction and ball collection behaviors
  - Prioritize distribution (passing to defenders) over dribbling
  
  Inherits from DecisionEngine for common logic (movement, ball awareness, basic decision-making)
]]

local DecisionEngine = require(script.Parent.DecisionEngine)
local AIConfig = require(script.Parent.AIConfig)
local BallPredictor = require(script.Parent.BallPredictor)
local SafeMath = require(script.Parent.SafeMath)

local GoalkeeperDecisionEngine = {}
setmetatable(GoalkeeperDecisionEngine, {__index = DecisionEngine})
GoalkeeperDecisionEngine.__index = GoalkeeperDecisionEngine

function GoalkeeperDecisionEngine.new()
  local self = DecisionEngine.new()
  setmetatable(self, GoalkeeperDecisionEngine)
  return self
end

function GoalkeeperDecisionEngine:Decide(npc, gameState, decisionState)
  if not npc or not gameState then
    warn("[GoalkeeperDecisionEngine] Invalid parameters passed to Decide")
    return {action = "Position", target = npc.Position, priority = 0}
  end
  
  local hasPossession = gameState.ball.possessor == npc
  
  if hasPossession then
    return self:DecideWithPossession(npc, gameState, decisionState)
  end
  
  if self:IsShotIncoming(gameState) then
    return self:ReactToShot(npc, gameState)
  end
  
  if self:CanCollectBall(npc, gameState) then
    return {
      action = "Pursue",
      target = gameState.ball.position,
      priority = 90,
      reasoning = "Collect ball in goal area"
    }
  end
  
  local gkPosition = self:GetGoalkeeperPosition(npc, gameState)
  return {
    action = "Position",
    target = gkPosition,
    priority = 50,
    reasoning = "Position between ball and goal"
  }
end

function GoalkeeperDecisionEngine:ShouldPursue(npc, gameState, teamCoordinator)
  if not npc or not gameState then
    return false
  end
  
  if not gameState.ball.isLoose then
    return false
  end
  
  local ballPosition = gameState.ball.position
  local distance = (ballPosition - npc.Position).Magnitude
  
  if distance > 10 then
    return false
  end
  
  if self:AreOpponentsNearby(npc, gameState, 15) then
    return false
  end
  
  return true
end

function GoalkeeperDecisionEngine:ScorePass(npc, teammate, gameState)
  local baseScore = DecisionEngine.ScorePass(self, npc, teammate, gameState)
  
  if teammate.Role == "DF" then
    baseScore = baseScore * 1.5
  end
  
  return math.min(baseScore, 100)
end

function GoalkeeperDecisionEngine:IsShotIncoming(gameState)
  if not gameState or not gameState.ball or not gameState.ownTeam then
    return false
  end
  
  local ball = gameState.ball.part
  if not ball then
    return false
  end
  
  local ballVelocity = ball.AssemblyLinearVelocity
  if ballVelocity.Magnitude < 10 then
    return false
  end
  
  local goalPosition = gameState.ownTeam.goalPosition
  local ballPosition = gameState.ball.position
  
  local ballToGoal = (goalPosition - ballPosition)
  local distanceToGoal = ballToGoal.Magnitude
  
  if distanceToGoal > AIConfig.GK_REACTION_DISTANCE then
    return false
  end
  
  local velocityDirection = ballVelocity.Unit
  local toGoalDirection = ballToGoal.Unit
  
  local dotProduct = velocityDirection:Dot(toGoalDirection)
  
  return dotProduct > 0.7
end

function GoalkeeperDecisionEngine:ReactToShot(npc, gameState)
  if not npc or not gameState then
    return {action = "Position", target = npc.Position, priority = 0}
  end
  
  local ball = gameState.ball.part
  if not ball then
    return {action = "Position", target = npc.Position, priority = 0}
  end
  
  local canIntercept, interceptionPoint = BallPredictor:CanIntercept(
    npc,
    ball,
    AIConfig.PREDICTION_TIME_AHEAD
  )
  
  local goalPosition = gameState.ownTeam.goalPosition
  local ballPosition = gameState.ball.position
  local ballToGoal = (goalPosition - ballPosition).Unit
  
  local interceptPosition = interceptionPoint
  if not canIntercept then
    local distanceFromGoal = math.min(5, (ballPosition - goalPosition).Magnitude * 0.3)
    interceptPosition = goalPosition - (ballToGoal * distanceFromGoal)
  end
  
  return {
    action = "Pursue",
    target = interceptPosition,
    priority = 95,
    reasoning = "React to incoming shot"
  }
end

function GoalkeeperDecisionEngine:GetGoalkeeperPosition(npc, gameState)
  if not npc or not gameState or not gameState.ownTeam then
    return npc and npc.Position or Vector3.new(0, 3, 0)
  end
  
  -- Wrap in pcall for error handling
  local success, gkPos = pcall(function()
    local goalPosition = gameState.ownTeam.goalPosition
    local ballPosition = gameState.ball.position
    
    local ballToGoal = (goalPosition - ballPosition)
    local distanceToGoal = ballToGoal.Magnitude
    
    if distanceToGoal < 0.1 then
      return goalPosition
    end
    
    local directionToGoal = SafeMath.SafeNormalize(ballToGoal, Vector3.new(0, 0, 1))
    
    local offsetDistance = math.min(AIConfig.GK_MAX_RANGE, distanceToGoal * 0.3)
    offsetDistance = math.max(3, offsetDistance)
    
    local gkPosition = goalPosition - (directionToGoal * offsetDistance)
    
    gkPosition = Vector3.new(gkPosition.X, goalPosition.Y, gkPosition.Z)
    
    return gkPosition
  end)
  
  if not success then
    warn("[GoalkeeperDecisionEngine] GetGoalkeeperPosition failed:", gkPos)
    return gameState.ownTeam.goalPosition or npc.Position
  end
  
  return gkPos
end

function GoalkeeperDecisionEngine:CanCollectBall(npc, gameState)
  if not npc or not gameState or not gameState.ball then
    return false
  end
  
  if not gameState.ball.isLoose then
    return false
  end
  
  local goalPosition = gameState.ownTeam.goalPosition
  local ballPosition = gameState.ball.position
  
  local ballToGoalDistance = (goalPosition - ballPosition).Magnitude
  if ballToGoalDistance > 15 then
    return false
  end
  
  local npcToBallDistance = (ballPosition - npc.Position).Magnitude
  if npcToBallDistance > 10 then
    return false
  end
  
  if self:AreOpponentsNearby(npc, gameState, 10) then
    return false
  end
  
  return true
end

function GoalkeeperDecisionEngine:AreOpponentsNearby(npc, gameState, range)
  if not gameState.opponentTeam or not gameState.opponentTeam.npcs then
    return false
  end
  
  for _, opponent in ipairs(gameState.opponentTeam.npcs) do
    local distance = (opponent.Position - npc.Position).Magnitude
    if distance < range then
      return true
    end
  end
  
  return false
end

return GoalkeeperDecisionEngine
