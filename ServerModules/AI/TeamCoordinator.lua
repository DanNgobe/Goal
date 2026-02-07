--[[
  TeamCoordinator.lua
  
  Manages multi-NPC coordination to prevent conflicts and ensure team cohesion.
  
  Functions:
  - AssignBallPursuer: Designate which NPC should pursue loose ball
  - CheckClustering: Detect if too many NPCs are clustered together
  - GetPassingOptions: Find available teammates for passing
  - AssignDefensiveRoles: Ensure proper defensive coverage
  - PositionSupportPlayers: Position teammates to support attacker
]]

local AIConfig = require(script.Parent.AIConfig)
local SafeMath = require(script.Parent.SafeMath)

local TeamCoordinator = {}

-- Constants
local CLUSTERING_RADIUS = AIConfig.CLUSTERING_RADIUS
local MAX_CLUSTER_SIZE = 3
local BALL_PURSUIT_RANGE = AIConfig.BALL_PURSUIT_RANGE
local MAX_PASS_DISTANCE = AIConfig.MAX_PASS_DISTANCE
local PASS_LANE_WIDTH = AIConfig.PASS_LANE_WIDTH

--[[
  Designate which NPC should pursue a loose ball.
  Only one NPC per team should pursue at a time.
  
  Parameters:
    teamNPCs - Array of NPC models on the same team
    ballPosition - Vector3 position of the ball
    
  Returns:
    NPC - The NPC that should pursue, or nil if none should
]]
function TeamCoordinator:AssignBallPursuer(teamNPCs, ballPosition)
  if not teamNPCs or #teamNPCs == 0 then
    return nil
  end
  
  if not ballPosition then
    warn("[TeamCoordinator] Invalid ball position passed to AssignBallPursuer")
    return nil
  end
  
  -- Wrap in pcall for error handling
  local success, pursuer = pcall(function()
    local closestNPC = nil
    local closestDistance = math.huge
    local secondClosestNPC = nil
    local secondClosestDistance = math.huge
    
    -- Find closest and second closest NPCs to ball
    for _, npc in ipairs(teamNPCs) do
      if npc and npc.Parent and npc:FindFirstChild("HumanoidRootPart") then
        local npcPosition = npc.HumanoidRootPart.Position
        local distance = SafeMath.SafeDistance(npcPosition, ballPosition)
        
        -- Only consider NPCs within pursuit range
        if distance <= BALL_PURSUIT_RANGE then
          if distance < closestDistance then
            -- Shift current closest to second closest
            secondClosestNPC = closestNPC
            secondClosestDistance = closestDistance
            
            closestNPC = npc
            closestDistance = distance
          elseif distance < secondClosestDistance then
            secondClosestNPC = npc
            secondClosestDistance = distance
          end
        end
      end
    end
    
    -- If closest is GK, also allow second closest field player to pursue
    if closestNPC then
      local role = closestNPC:GetAttribute("Role")
      if role == "GK" and secondClosestNPC then
        -- Return second closest as primary pursuer if GK is closest
        return secondClosestNPC
      end
    end
    
    return closestNPC
  end)
  
  if not success then
    warn("[TeamCoordinator] AssignBallPursuer failed:", pursuer)
    return nil
  end
  
  return pursuer
end

--[[
  Check if too many NPCs are clustered within a radius of a position.
  
  Parameters:
    teamNPCs - Array of NPC models on the same team
    position - Vector3 center position to check
    radius - Optional radius to check (defaults to CLUSTERING_RADIUS)
    
  Returns:
    number - Count of NPCs within the radius
]]
function TeamCoordinator:CheckClustering(teamNPCs, position, radius)
  if not teamNPCs or #teamNPCs == 0 then
    return 0
  end
  
  if not position then
    warn("[TeamCoordinator] Invalid position passed to CheckClustering")
    return 0
  end
  
  radius = radius or CLUSTERING_RADIUS
  local count = 0
  
  for _, npc in ipairs(teamNPCs) do
    if npc and npc.Parent and npc:FindFirstChild("HumanoidRootPart") then
      local npcPosition = npc.HumanoidRootPart.Position
      local distance = SafeMath.SafeDistance(npcPosition, position)
      
      if distance <= radius then
        count = count + 1
      end
    end
  end
  
  return count
end

--[[
  Get available passing options for an NPC with possession.
  Returns teammates sorted by pass score.
  
  Parameters:
    npc - The NPC with possession
    teamNPCs - Array of NPC models on the same team
    opponentNPCs - Array of opponent NPC models
    goalPosition - Vector3 position of opponent's goal
    
  Returns:
    Array of {npc = NPC, score = number} sorted by score (highest first)
]]
function TeamCoordinator:GetPassingOptions(npc, teamNPCs, opponentNPCs, goalPosition)
  if not npc or not npc:FindFirstChild("HumanoidRootPart") then
    warn("[TeamCoordinator] Invalid NPC passed to GetPassingOptions")
    return {}
  end
  
  if not teamNPCs or #teamNPCs == 0 then
    return {}
  end
  
  local npcPosition = npc.HumanoidRootPart.Position
  local passingOptions = {}
  
  for _, teammate in ipairs(teamNPCs) do
    -- Skip self
    if teammate ~= npc and teammate and teammate.Parent and teammate:FindFirstChild("HumanoidRootPart") then
      local teammatePosition = teammate.HumanoidRootPart.Position
      local distance = (teammatePosition - npcPosition).Magnitude
      
      -- Only consider teammates within passing range
      if distance <= MAX_PASS_DISTANCE and distance > 3 then
        local score = self:ScorePassOption(npcPosition, teammatePosition, opponentNPCs, goalPosition, distance)
        
        table.insert(passingOptions, {
          npc = teammate,
          score = score
        })
      end
    end
  end
  
  -- Sort by score (highest first)
  table.sort(passingOptions, function(a, b)
    return a.score > b.score
  end)
  
  return passingOptions
end

--[[
  Score a potential pass option (internal helper).
  
  Parameters:
    fromPosition - Vector3 position of passer
    toPosition - Vector3 position of receiver
    opponentNPCs - Array of opponent NPC models
    goalPosition - Vector3 position of opponent's goal
    distance - Distance between passer and receiver
    
  Returns:
    number - Score (0-100)
]]
function TeamCoordinator:ScorePassOption(fromPosition, toPosition, opponentNPCs, goalPosition, distance)
  local score = 50  -- Base score
  
  -- Distance scoring: optimal around 20 studs
  local optimalDistance = AIConfig.OPTIMAL_PASS_DISTANCE
  local distanceFactor = 1 - math.abs(distance - optimalDistance) / optimalDistance
  distanceFactor = SafeMath.Clamp(distanceFactor, 0, 1)
  score = score + (distanceFactor * 20)
  
  -- Forward progress: passing toward goal is better
  if goalPosition then
    local currentDistanceToGoal = SafeMath.SafeDistance(fromPosition, goalPosition)
    local newDistanceToGoal = SafeMath.SafeDistance(toPosition, goalPosition)
    local progressToGoal = currentDistanceToGoal - newDistanceToGoal
    
    if progressToGoal > 0 then
      score = score + math.min(progressToGoal * 2, 20)
    else
      score = score + math.max(progressToGoal * 1, -10)
    end
  end
  
  -- Check for blocking opponents in passing lane
  if opponentNPCs then
    local passDirection = SafeMath.SafeNormalize(toPosition - fromPosition, Vector3.new(0, 0, 1))
    local blockedPenalty = 0
    
    for _, opponent in ipairs(opponentNPCs) do
      if opponent and opponent.Parent and opponent:FindFirstChild("HumanoidRootPart") then
        local opponentPosition = opponent.HumanoidRootPart.Position
        
        -- Check if opponent is in the passing lane
        local toOpponent = opponentPosition - fromPosition
        local projectionLength = SafeMath.SafeDot(toOpponent, passDirection)
        
        -- Only check opponents between passer and receiver
        if projectionLength > 0 and projectionLength < distance then
          local projectionPoint = fromPosition + (passDirection * projectionLength)
          local distanceToLane = SafeMath.SafeDistance(opponentPosition, projectionPoint)
          
          if distanceToLane < PASS_LANE_WIDTH then
            blockedPenalty = blockedPenalty + 15
          end
        end
      end
    end
    
    score = score - blockedPenalty
  end
  
  -- Clamp score to 0-100
  return SafeMath.Clamp(score, 0, 100)
end

--[[
  Assign defensive roles to ensure proper coverage.
  Returns a map of NPC to defensive assignment.
  
  Parameters:
    teamNPCs - Array of NPC models on the same team
    opponentNPCs - Array of opponent NPC models
    ballPosition - Vector3 position of the ball
    ownGoalPosition - Vector3 position of own goal
    
  Returns:
    Map of {[NPC] = {type = "pressure"|"mark"|"cover", target = NPC or Vector3}}
]]
function TeamCoordinator:AssignDefensiveRoles(teamNPCs, opponentNPCs, ballPosition, ownGoalPosition)
  if not teamNPCs or #teamNPCs == 0 then
    return {}
  end
  
  if not ballPosition or not ownGoalPosition then
    warn("[TeamCoordinator] Invalid positions passed to AssignDefensiveRoles")
    return {}
  end
  
  local assignments = {}
  
  -- Find opponent with ball (if any)
  local ballCarrier = nil
  if opponentNPCs then
    for _, opponent in ipairs(opponentNPCs) do
      if opponent and opponent:GetAttribute("HasBall") then
        ballCarrier = opponent
        break
      end
    end
  end
  
  -- Assign closest defender to pressure ball carrier
  if ballCarrier and ballCarrier:FindFirstChild("HumanoidRootPart") then
    local closestDefender = nil
    local closestDistance = math.huge
    
    for _, npc in ipairs(teamNPCs) do
      if npc and npc.Parent and npc:FindFirstChild("HumanoidRootPart") then
        local role = npc:GetAttribute("Role")
        -- Prioritize defenders for pressure
        if role == "DF" or role == "LW" or role == "RW" then
          local distance = (npc.HumanoidRootPart.Position - ballCarrier.HumanoidRootPart.Position).Magnitude
          if distance < closestDistance then
            closestDistance = distance
            closestDefender = npc
          end
        end
      end
    end
    
    if closestDefender then
      assignments[closestDefender] = {
        type = "pressure",
        target = ballCarrier
      }
    end
  end
  
  -- Ensure at least one defender between ball and goal
  local defendersBetweenBallAndGoal = 0
  local defenders = {}
  
  for _, npc in ipairs(teamNPCs) do
    if npc and npc.Parent and npc:FindFirstChild("HumanoidRootPart") then
      local role = npc:GetAttribute("Role")
      if role == "DF" then
        table.insert(defenders, npc)
        
        -- Check if defender is between ball and goal
        local npcPosition = npc.HumanoidRootPart.Position
        local ballToGoal = (ownGoalPosition - ballPosition).Unit
        local ballToNPC = (npcPosition - ballPosition).Unit
        
        -- If defender is in the direction of goal from ball
        if ballToGoal:Dot(ballToNPC) > 0.5 then
          defendersBetweenBallAndGoal = defendersBetweenBallAndGoal + 1
        end
      end
    end
  end
  
  -- If no defender between ball and goal, assign one to cover
  if defendersBetweenBallAndGoal == 0 and #defenders > 0 then
    -- Find defender closest to the line between ball and goal
    local closestDefender = nil
    local closestDistance = math.huge
    
    for _, defender in ipairs(defenders) do
      if not assignments[defender] then  -- Don't reassign if already pressuring
        local defenderPosition = defender.HumanoidRootPart.Position
        local ballToGoal = (ownGoalPosition - ballPosition)
        local midpoint = ballPosition + (ballToGoal * 0.5)
        local distance = (defenderPosition - midpoint).Magnitude
        
        if distance < closestDistance then
          closestDistance = distance
          closestDefender = defender
        end
      end
    end
    
    if closestDefender then
      -- Position between ball and goal
      local coverPosition = ballPosition + ((ownGoalPosition - ballPosition).Unit * 10)
      assignments[closestDefender] = {
        type = "cover",
        target = coverPosition
      }
    end
  end
  
  -- Assign remaining defenders to mark dangerous opponents
  if opponentNPCs then
    for _, npc in ipairs(teamNPCs) do
      if npc and npc.Parent and not assignments[npc] then
        local role = npc:GetAttribute("Role")
        if role == "DF" or role == "LW" or role == "RW" then
          -- Find closest unmarked opponent
          local closestOpponent = nil
          local closestDistance = math.huge
          
          for _, opponent in ipairs(opponentNPCs) do
            if opponent and opponent.Parent and opponent:FindFirstChild("HumanoidRootPart") then
              -- Check if opponent is already being marked
              local alreadyMarked = false
              for _, assignment in pairs(assignments) do
                if assignment.type == "mark" and assignment.target == opponent then
                  alreadyMarked = true
                  break
                end
              end
              
              if not alreadyMarked then
                local distance = (npc.HumanoidRootPart.Position - opponent.HumanoidRootPart.Position).Magnitude
                if distance < closestDistance then
                  closestDistance = distance
                  closestOpponent = opponent
                end
              end
            end
          end
          
          if closestOpponent then
            assignments[npc] = {
              type = "mark",
              target = closestOpponent
            }
          end
        end
      end
    end
  end
  
  return assignments
end

--[[
  Position support players to assist an attacker with possession.
  Returns a map of NPC to support position.
  
  Parameters:
    attackerNPC - The NPC with possession
    teamNPCs - Array of NPC models on the same team
    opponentGoalPosition - Vector3 position of opponent's goal
    
  Returns:
    Map of {[NPC] = Vector3 support position}
]]
function TeamCoordinator:PositionSupportPlayers(attackerNPC, teamNPCs, opponentGoalPosition)
  if not attackerNPC or not attackerNPC:FindFirstChild("HumanoidRootPart") then
    warn("[TeamCoordinator] Invalid attacker NPC passed to PositionSupportPlayers")
    return {}
  end
  
  if not teamNPCs or #teamNPCs == 0 then
    return {}
  end
  
  local attackerPosition = attackerNPC.HumanoidRootPart.Position
  local attackerRole = attackerNPC:GetAttribute("Role")
  local supportPositions = {}
  
  -- Direction toward goal
  local toGoalDirection = Vector3.new(0, 0, 1)  -- Default forward
  if opponentGoalPosition then
    toGoalDirection = (opponentGoalPosition - attackerPosition).Unit
  end
  
  -- Assign support positions based on role
  for _, npc in ipairs(teamNPCs) do
    if npc ~= attackerNPC and npc and npc.Parent and npc:FindFirstChild("HumanoidRootPart") then
      local role = npc:GetAttribute("Role")
      local supportPosition = nil
      
      if role == "ST" then
        -- Striker: Position ahead of attacker toward goal
        supportPosition = attackerPosition + (toGoalDirection * 15)
        
      elseif role == "LW" then
        -- Left wing: Position to the left and slightly forward
        local leftDirection = Vector3.new(-toGoalDirection.Z, 0, toGoalDirection.X).Unit
        supportPosition = attackerPosition + (leftDirection * 12) + (toGoalDirection * 8)
        
      elseif role == "RW" then
        -- Right wing: Position to the right and slightly forward
        local rightDirection = Vector3.new(toGoalDirection.Z, 0, -toGoalDirection.X).Unit
        supportPosition = attackerPosition + (rightDirection * 12) + (toGoalDirection * 8)
        
      elseif role == "DF" then
        -- Defender: Position behind attacker for safety pass
        supportPosition = attackerPosition - (toGoalDirection * 10)
      end
      
      if supportPosition then
        supportPositions[npc] = supportPosition
      end
    end
  end
  
  -- Ensure at least two support players are in viable passing lanes
  -- This is handled by the positioning logic above, which spreads players
  -- in different directions to create passing options
  
  return supportPositions
end

return TeamCoordinator
