--[[
  BehaviorController.lua
  
  Executes actions determined by DecisionEngine.
  Handles movement, passing, shooting, dribbling, and defensive behaviors.
  
  Responsibilities:
  - Execute movement commands using NPCManager
  - Execute ball actions (pass, shoot, kick) using BallManager
  - Handle pathfinding and obstacle avoidance
  - Implement position-holding behavior
]]

local BehaviorController = {}

-- Services
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- Dependencies (injected via Initialize)
local NPCManager = nil
local BallManager = nil
local AIConfig = nil
local SafeMath = nil

-- Private variables
local PathfindingCache = {}  -- Cache recent pathfinding results


-- Initialize the BehaviorController
function BehaviorController.Initialize(npcManager, ballManager, aiConfig)
  NPCManager = npcManager
  BallManager = ballManager
  AIConfig = aiConfig
  
  -- Load SafeMath module
  local success, safeMathModule = pcall(function()
    return require(script.Parent.SafeMath)
  end)
  
  if success then
    SafeMath = safeMathModule
  else
    warn("[BehaviorController] Failed to load SafeMath module, using fallback")
    -- Create minimal fallback SafeMath
    SafeMath = {
      SafeNormalize = function(vec, default)
        if not vec or vec.Magnitude < 0.0001 then
          return default or Vector3.new(0, 0, 1)
        end
        return vec.Unit
      end,
      SafeDistance = function(pos1, pos2)
        if not pos1 or not pos2 then
          return math.huge
        end
        return (pos2 - pos1).Magnitude
      end,
      ClampToBounds = function(pos, bounds)
        return pos
      end,
      IsWithinBounds = function(pos, bounds)
        return true
      end
    }
  end
  
  if not NPCManager or not BallManager or not AIConfig then
    warn("[BehaviorController] Missing required dependencies!")
    return false
  end
  
  return true
end


-- Move NPC to target position
-- urgency: "sprint", "jog", or "walk"
function BehaviorController:MoveTo(npc, targetPosition, urgency)
  if not npc or not targetPosition then
    warn("[BehaviorController] Invalid parameters for MoveTo")
    return false
  end
  
  -- Validate target position
  if typeof(targetPosition) ~= "Vector3" then
    warn("[BehaviorController] Invalid target position type")
    return false
  end
  
  local humanoid = npc:FindFirstChildOfClass("Humanoid")
  local rootPart = npc:FindFirstChild("HumanoidRootPart")
  
  if not humanoid or not rootPart then
    warn("[BehaviorController] NPC missing Humanoid or HumanoidRootPart")
    return false
  end
  
  -- Wrap in pcall for error handling
  local success, err = pcall(function()
    -- Set movement speed based on urgency
    local speed = AIConfig.JOG_SPEED
    if urgency == "sprint" then
      speed = AIConfig.SPRINT_SPEED
    elseif urgency == "walk" then
      speed = AIConfig.WALK_SPEED
    end
    
    humanoid.WalkSpeed = speed
    
    -- Check if pathfinding is needed
    local directPath = targetPosition - rootPart.Position
    local distance = directPath.Magnitude
    
    -- If very close, use HoldPosition instead
    if distance < AIConfig.POSITION_ARRIVAL_THRESHOLD then
      return self:HoldPosition(npc, targetPosition)
    end
    
    -- Check for obstacles in direct path
    local hasObstacle = self:_CheckForObstacles(rootPart.Position, targetPosition)
    
    if hasObstacle then
      -- Use pathfinding with fallback
      local waypoints = self:_GeneratePath(rootPart.Position, targetPosition)
      if waypoints and #waypoints > 0 then
        -- Move to first waypoint
        humanoid:MoveTo(waypoints[1])
      else
        -- Fallback to direct movement
        humanoid:MoveTo(targetPosition)
      end
    else
      -- Direct movement
      humanoid:MoveTo(targetPosition)
    end
  end)
  
  if not success then
    warn("[BehaviorController] MoveTo failed:", err)
    -- Fallback: try simple move without pathfinding
    local fallbackSuccess = pcall(function()
      humanoid:MoveTo(targetPosition)
    end)
    return fallbackSuccess
  end
  
  return success
end


-- Execute a pass to teammate
function BehaviorController:Pass(npc, targetNPC, gameState)
  if not npc or not targetNPC then
    warn("[BehaviorController] Invalid parameters for Pass")
    return false
  end
  
  local rootPart = npc:FindFirstChild("HumanoidRootPart")
  local targetRootPart = targetNPC:FindFirstChild("HumanoidRootPart")
  
  if not rootPart or not targetRootPart then
    warn("[BehaviorController] Missing HumanoidRootPart for Pass")
    return false
  end
  
  -- Wrap in pcall for error handling
  local success, err = pcall(function()
    -- Check if NPC has possession
    if not BallManager.IsCharacterOwner(npc) then
      if AIConfig.DEBUG_MODE then
        warn("[BehaviorController] NPC does not have ball possession for Pass")
      end
      return false
    end
    
    -- Calculate pass direction and power
    local passDirection = SafeMath.SafeNormalize(
      targetRootPart.Position - rootPart.Position,
      Vector3.new(0, 0, 1)
    )
    
    -- Aim slightly ahead if target is moving
    if targetRootPart.AssemblyLinearVelocity.Magnitude > 1 then
      local targetVelocity = targetRootPart.AssemblyLinearVelocity
      local leadTime = 0.5
      local leadOffset = targetVelocity * leadTime
      passDirection = SafeMath.SafeNormalize(
        (targetRootPart.Position + leadOffset) - rootPart.Position,
        passDirection
      )
    end
    
    -- Calculate pass power based on distance
    local distance = SafeMath.SafeDistance(rootPart.Position, targetRootPart.Position)
    local power = math.clamp(SafeMath.SafeDivide(distance, AIConfig.MAX_PASS_DISTANCE, 0.5), 0.3, 1.0)
    
    -- Determine kick type
    local kickType = distance < 20 and "Ground" or "Air"
    
    -- Execute kick using BallManager
    local kickSuccess = BallManager.KickBall(npc, kickType, power, passDirection)
    
    if kickSuccess and AIConfig.LOG_DECISIONS then
      print(string.format("[BehaviorController] %s passed to %s", npc.Name, targetNPC.Name))
    end
    
    return kickSuccess
  end)
  
  if not success then
    warn("[BehaviorController] Pass execution failed:", err)
    return false
  end
  
  return success
end


-- Execute a shot on goal
function BehaviorController:Shoot(npc, gameState)
  if not npc or not gameState then
    warn("[BehaviorController] Invalid parameters for Shoot")
    return false
  end
  
  local rootPart = npc:FindFirstChild("HumanoidRootPart")
  if not rootPart then
    warn("[BehaviorController] NPC missing HumanoidRootPart for Shoot")
    return false
  end
  
  -- Wrap in pcall for error handling
  local success, err = pcall(function()
    -- Check if NPC has possession
    if not BallManager.IsCharacterOwner(npc) then
      if AIConfig.DEBUG_MODE then
        warn("[BehaviorController] NPC does not have ball possession for Shoot")
      end
      return false
    end
    
    -- Determine opponent goal
    local opponentGoal = gameState.opponentTeam and gameState.opponentTeam.goalPosition
    if not opponentGoal then
      warn("[BehaviorController] Opponent goal position not found")
      return false
    end
    
    -- Calculate shot direction with goalkeeper consideration
    local shotDirection = SafeMath.SafeNormalize(
      opponentGoal - rootPart.Position,
      Vector3.new(0, 0, 1)
    )
    
    -- Try to aim away from goalkeeper if present
    local goalkeeper = self:_FindGoalkeeper(gameState.opponentTeam.npcs)
    if goalkeeper then
      local gkRootPart = goalkeeper:FindFirstChild("HumanoidRootPart")
      if gkRootPart then
        local toGK = SafeMath.SafeNormalize(gkRootPart.Position - rootPart.Position, shotDirection)
        local toGoal = shotDirection
        
        local crossProduct = toGoal:Cross(toGK)
        local aimOffset = SafeMath.SafeNormalize(Vector3.new(crossProduct.X, 0, crossProduct.Z), Vector3.new(3, 0, 0)) * 3
        shotDirection = SafeMath.SafeNormalize((opponentGoal + aimOffset) - rootPart.Position, shotDirection)
      end
    end
    
    -- Calculate shot power based on distance
    local distance = SafeMath.SafeDistance(rootPart.Position, opponentGoal)
    local power = math.clamp(SafeMath.SafeDivide(distance, AIConfig.MAX_SHOT_DISTANCE, 0.8), 0.6, 1.0)
    
    -- Always use Air kick for shots
    local kickType = "Air"
    
    -- Execute kick using BallManager
    local kickSuccess = BallManager.KickBall(npc, kickType, power, shotDirection)
    
    if kickSuccess and AIConfig.LOG_DECISIONS then
      print(string.format("[BehaviorController] %s shot on goal", npc.Name))
    end
    
    return kickSuccess
  end)
  
  if not success then
    warn("[BehaviorController] Shoot execution failed:", err)
    return false
  end
  
  return success
end


-- Dribble ball forward
function BehaviorController:Dribble(npc, direction, gameState)
  if not npc or not direction then
    warn("[BehaviorController] Invalid parameters for Dribble")
    return false
  end
  
  local humanoid = npc:FindFirstChildOfClass("Humanoid")
  local rootPart = npc:FindFirstChild("HumanoidRootPart")
  
  if not humanoid or not rootPart then
    warn("[BehaviorController] NPC missing Humanoid or HumanoidRootPart for Dribble")
    return false
  end
  
  -- Wrap in pcall for error handling
  local success, err = pcall(function()
    -- Check if NPC has possession
    if not BallManager.IsCharacterOwner(npc) then
      if AIConfig.DEBUG_MODE then
        warn("[BehaviorController] NPC does not have ball possession for Dribble")
      end
      return false
    end
    
    -- Normalize direction safely
    direction = SafeMath.SafeNormalize(direction, Vector3.new(0, 0, 1))
    
    -- Check for boundary awareness
    if gameState and gameState.fieldBounds then
      local futurePosition = rootPart.Position + (direction * 5)
      
      -- Clamp to bounds if needed
      if not SafeMath.IsWithinBounds(futurePosition, gameState.fieldBounds) then
        -- Near boundary, change direction toward field center
        local fieldCenter = Vector3.new(0, 0, 0)
        if NPCManager and NPCManager.GetFieldCenter then
          local center = NPCManager.GetFieldCenter()
          if center then
            fieldCenter = center
          end
        end
        direction = SafeMath.SafeNormalize(fieldCenter - rootPart.Position, direction)
      end
    end
    
    -- Set dribbling speed
    humanoid.WalkSpeed = AIConfig.JOG_SPEED
    
    -- Move in dribble direction
    local targetPosition = rootPart.Position + (direction * 10)
    humanoid:MoveTo(targetPosition)
    
    return true
  end)
  
  if not success then
    warn("[BehaviorController] Dribble execution failed:", err)
    return false
  end
  
  return success
end


-- Apply defensive pressure to opponent
function BehaviorController:Pressure(npc, targetNPC)
  if not npc or not targetNPC then
    warn("[BehaviorController] Invalid parameters for Pressure")
    return false
  end
  
  local humanoid = npc:FindFirstChildOfClass("Humanoid")
  local rootPart = npc:FindFirstChild("HumanoidRootPart")
  local targetRootPart = targetNPC:FindFirstChild("HumanoidRootPart")
  
  if not humanoid or not rootPart or not targetRootPart then
    warn("[BehaviorController] Missing required parts for Pressure")
    return false
  end
  
  -- Calculate position between target and goal
  local ownGoal = self:_GetOwnGoalPosition(npc)
  if not ownGoal then
    -- Fallback: just move toward target
    humanoid.WalkSpeed = AIConfig.SPRINT_SPEED
    humanoid:MoveTo(targetRootPart.Position)
    return true
  end
  
  -- Position between opponent and goal, but close to opponent
  local toGoal = (ownGoal - targetRootPart.Position).Unit
  local pressurePosition = targetRootPart.Position + (toGoal * AIConfig.PRESSURE_RANGE * 0.5)
  
  -- Sprint to pressure position
  humanoid.WalkSpeed = AIConfig.SPRINT_SPEED
  humanoid:MoveTo(pressurePosition)
  
  return true
end


-- Maintain position (small adjustments)
function BehaviorController:HoldPosition(npc, targetPosition)
  if not npc or not targetPosition then
    warn("[BehaviorController] Invalid parameters for HoldPosition")
    return false
  end
  
  local humanoid = npc:FindFirstChildOfClass("Humanoid")
  local rootPart = npc:FindFirstChild("HumanoidRootPart")
  
  if not humanoid or not rootPart then
    warn("[BehaviorController] NPC missing Humanoid or HumanoidRootPart for HoldPosition")
    return false
  end
  
  local distance = (targetPosition - rootPart.Position).Magnitude
  
  -- If very close, reduce speed significantly
  if distance < AIConfig.POSITION_ARRIVAL_THRESHOLD then
    humanoid.WalkSpeed = AIConfig.WALK_SPEED
    
    -- Only move if distance is meaningful
    if distance > 0.5 then
      humanoid:MoveTo(targetPosition)
    end
  else
    -- Still need to move, use normal speed
    humanoid.WalkSpeed = AIConfig.JOG_SPEED
    humanoid:MoveTo(targetPosition)
  end
  
  return true
end


-- Private: Check for obstacles in direct path
function BehaviorController:_CheckForObstacles(startPos, endPos)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    -- Simple raycast to check for obstacles
    local direction = (endPos - startPos)
    local distance = direction.Magnitude
    
    if distance < 0.1 then
      return false
    end
    
    direction = SafeMath.SafeNormalize(direction, Vector3.new(0, 0, 1))
    
    -- Raycast parameters
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    -- Try to filter NPCs folder
    local npcsFolder = workspace:FindFirstChild("NPCs")
    if npcsFolder then
      raycastParams.FilterDescendantsInstances = {npcsFolder}
    else
      raycastParams.FilterDescendantsInstances = {}
    end
    
    -- Cast ray
    local rayResult = workspace:Raycast(startPos, direction * distance, raycastParams)
    
    -- If hit something that's not the ground, there's an obstacle
    if rayResult and rayResult.Instance and rayResult.Instance.Name ~= "Ground" then
      return true
    end
    
    return false
  end)
  
  if not success then
    -- If raycast fails, assume no obstacles (fallback)
    return false
  end
  
  return result
end


-- Private: Generate path with waypoints (max 5)
function BehaviorController:_GeneratePath(startPos, endPos)
  -- Wrap in pcall for error handling
  local success, waypoints = pcall(function()
    -- Check cache first
    local cacheKey = string.format("%.1f_%.1f_%.1f_%.1f", startPos.X, startPos.Z, endPos.X, endPos.Z)
    if PathfindingCache[cacheKey] then
      return PathfindingCache[cacheKey]
    end
    
    local pathWaypoints = {}
    
    -- Try direct path first
    if not self:_CheckForObstacles(startPos, endPos) then
      table.insert(pathWaypoints, endPos)
      PathfindingCache[cacheKey] = pathWaypoints
      return pathWaypoints
    end
    
    -- Try routing around obstacle (left and right)
    local direction = SafeMath.SafeNormalize(endPos - startPos, Vector3.new(0, 0, 1))
    local perpendicular = Vector3.new(-direction.Z, 0, direction.X)
    
    -- Try left route
    local leftWaypoint = startPos + (direction * 10) + (perpendicular * 5)
    if not self:_CheckForObstacles(startPos, leftWaypoint) and 
       not self:_CheckForObstacles(leftWaypoint, endPos) then
      table.insert(pathWaypoints, leftWaypoint)
      table.insert(pathWaypoints, endPos)
      PathfindingCache[cacheKey] = pathWaypoints
      return pathWaypoints
    end
    
    -- Try right route
    local rightWaypoint = startPos + (direction * 10) - (perpendicular * 5)
    if not self:_CheckForObstacles(startPos, rightWaypoint) and 
       not self:_CheckForObstacles(rightWaypoint, endPos) then
      table.insert(pathWaypoints, rightWaypoint)
      table.insert(pathWaypoints, endPos)
      PathfindingCache[cacheKey] = pathWaypoints
      return pathWaypoints
    end
    
    -- Fallback: direct path even with obstacle
    table.insert(pathWaypoints, endPos)
    PathfindingCache[cacheKey] = pathWaypoints
    return pathWaypoints
  end)
  
  if not success then
    warn("[BehaviorController] Pathfinding failed, using direct path")
    -- Fallback: return direct path
    return {endPos}
  end
  
  return waypoints or {endPos}
end


-- Private: Check if position is near field boundary
function BehaviorController:_IsNearBoundary(position, fieldBounds)
  if not fieldBounds then return false end
  
  local fieldCenter = NPCManager.GetFieldCenter()
  local halfWidth = fieldBounds.Width / 2
  local halfLength = fieldBounds.Length / 2
  
  -- Check if within 5 studs of boundary
  local boundaryMargin = 5
  
  if math.abs(position.X - fieldCenter.X) > (halfWidth - boundaryMargin) then
    return true
  end
  
  if math.abs(position.Z - fieldCenter.Z) > (halfLength - boundaryMargin) then
    return true
  end
  
  return false
end


-- Private: Find goalkeeper in team
function BehaviorController:_FindGoalkeeper(teamNPCs)
  for _, npc in ipairs(teamNPCs) do
    if npc.Name:match("GK") then
      return npc
    end
  end
  return nil
end


-- Private: Get own goal position for defensive positioning
function BehaviorController:_GetOwnGoalPosition(npc)
  -- Determine team from NPC name
  local teamName = npc.Name:match("^(%w+)_")
  if not teamName then return nil end
  
  -- Get field center and calculate goal position
  local fieldCenter = NPCManager.GetFieldCenter()
  local fieldBounds = NPCManager.GetFieldBounds()
  
  if not fieldCenter or not fieldBounds then return nil end
  
  -- Blue goal is at negative Z, Red goal is at positive Z
  local goalZ = teamName == "Blue" and -fieldBounds.Length / 2 or fieldBounds.Length / 2
  
  return Vector3.new(fieldCenter.X, fieldCenter.Y, fieldCenter.Z + goalZ)
end


return BehaviorController
