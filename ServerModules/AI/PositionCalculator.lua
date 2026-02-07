--[[
  PositionCalculator.lua
  
  Calculates target positions for NPCs based on formation and game state.
  Provides dynamic position adjustments based on ball location and tactical state.
  
  Responsibilities:
  - Retrieve base formation positions from FormationData
  - Adjust positions dynamically based on ball location
  - Calculate goalkeeper-specific positioning
  - Provide main entry point for target position calculation
]]

local PositionCalculator = {}

local AIConfig = require(script.Parent.AIConfig)
local SafeMath = require(script.Parent.SafeMath)

local FormationData = nil
local FieldCenter = nil
local FieldSize = nil

function PositionCalculator.Initialize(formationData, fieldCenter, fieldSize)
  FormationData = formationData
  FieldCenter = fieldCenter
  FieldSize = fieldSize
  
  if not FormationData then
    warn("[PositionCalculator] FormationData not provided!")
    return false
  end
  
  if not FieldCenter or not FieldSize then
    warn("[PositionCalculator] Field dimensions not provided!")
    return false
  end
  
  return true
end

function PositionCalculator.GetFormationPosition(role, formation, teamSide)
  if not FormationData then
    warn("[PositionCalculator] Not initialized!")
    return Vector3.new(0, 3, 0)
  end
  
  local formationType = formation or "Neutral"
  local positionData = FormationData.GetPositionByRole(role, formationType)
  
  if not positionData then
    warn("[PositionCalculator] No position data for role:", role)
    return Vector3.new(0, 3, 0)
  end
  
  local formationPosition = positionData.Position
  local sideMultiplier = (teamSide == "Blue") and -1 or 1
  
  local scaledX = formationPosition.X * FieldSize.X
  local scaledZ = formationPosition.Z * FieldSize.Z
  
  local worldX = FieldCenter.X + scaledX
  local worldY = FieldCenter.Y + 3
  local worldZ = FieldCenter.Z + (scaledZ * sideMultiplier)
  
  return Vector3.new(worldX, worldY, worldZ)
end

function PositionCalculator.AdjustForBall(basePosition, ballPosition, role, tacticalState, teamSide)
  if not ballPosition or not basePosition then
    return basePosition
  end
  
  local adjustedPosition = basePosition
  local sideMultiplier = (teamSide == "Blue") and -1 or 1
  
  local defensiveThirdZ = FieldCenter.Z + (FieldSize.Z * 0.33 * sideMultiplier)
  local attackingThirdZ = FieldCenter.Z - (FieldSize.Z * 0.33 * sideMultiplier)
  
  local ballInDefensiveThird = (teamSide == "Blue" and ballPosition.Z < defensiveThirdZ) or
                                (teamSide == "Red" and ballPosition.Z > defensiveThirdZ)
  
  local ballInAttackingThird = (teamSide == "Blue" and ballPosition.Z > attackingThirdZ) or
                                (teamSide == "Red" and ballPosition.Z < attackingThirdZ)
  
  local ballOnLeftSide = ballPosition.X < FieldCenter.X
  local ballOnRightSide = ballPosition.X > FieldCenter.X
  
  if ballInDefensiveThird and tacticalState ~= "Attacking" then
    if role ~= "GK" then
      local pullBackAmount = 5
      adjustedPosition = Vector3.new(
        adjustedPosition.X,
        adjustedPosition.Y,
        adjustedPosition.Z + (pullBackAmount * sideMultiplier)
      )
    end
  end
  
  if ballInAttackingThird and (role == "LW" or role == "RW" or role == "ST") then
    local pushForwardAmount = 5
    adjustedPosition = Vector3.new(
      adjustedPosition.X,
      adjustedPosition.Y,
      adjustedPosition.Z - (pushForwardAmount * sideMultiplier)
    )
  end
  
  if role == "LW" and ballOnLeftSide then
    local pushUpAmount = 3
    adjustedPosition = Vector3.new(
      adjustedPosition.X,
      adjustedPosition.Y,
      adjustedPosition.Z - (pushUpAmount * sideMultiplier)
    )
  elseif role == "RW" and ballOnRightSide then
    local pushUpAmount = 3
    adjustedPosition = Vector3.new(
      adjustedPosition.X,
      adjustedPosition.Y,
      adjustedPosition.Z - (pushUpAmount * sideMultiplier)
    )
  end
  
  if role == "DF" then
    local lateralShift = (ballPosition.X - FieldCenter.X) * 0.3
    adjustedPosition = Vector3.new(
      basePosition.X + lateralShift,
      adjustedPosition.Y,
      adjustedPosition.Z
    )
  end
  
  return adjustedPosition
end

function PositionCalculator.GetGoalkeeperPosition(goalCenter, ballPosition)
  if not goalCenter or not ballPosition then
    return goalCenter or Vector3.new(0, 3, 0)
  end
  
  -- Wrap in pcall for error handling
  local success, gkPos = pcall(function()
    local directionToBall = SafeMath.SafeNormalize(ballPosition - goalCenter, Vector3.new(0, 0, 1))
    local distance = SafeMath.SafeDistance(goalCenter, ballPosition)
    local offsetDistance = math.min(distance * 0.25, AIConfig.GK_MAX_RANGE)
    
    local gkPosition = goalCenter + (directionToBall * offsetDistance)
    gkPosition = Vector3.new(gkPosition.X, goalCenter.Y + 3, gkPosition.Z)
    
    return gkPosition
  end)
  
  if not success then
    warn("[PositionCalculator] GetGoalkeeperPosition failed:", gkPos)
    return goalCenter
  end
  
  return gkPos
end

function PositionCalculator.GetTargetPosition(npc, formation, tacticalState, ballPosition, goalCenter)
  if not npc or not npc.Role then
    warn("[PositionCalculator] Invalid NPC provided!")
    return Vector3.new(0, 3, 0)
  end
  
  local role = npc.Role
  local teamSide = npc.Team or "Blue"
  
  if role == "GK" and goalCenter then
    local ballInDefensiveHalf = false
    local sideMultiplier = (teamSide == "Blue") and -1 or 1
    local defensiveHalfZ = FieldCenter.Z + (FieldSize.Z * 0.0 * sideMultiplier)
    
    if ballPosition then
      ballInDefensiveHalf = (teamSide == "Blue" and ballPosition.Z < defensiveHalfZ) or
                            (teamSide == "Red" and ballPosition.Z > defensiveHalfZ)
    end
    
    if ballInDefensiveHalf and ballPosition then
      return PositionCalculator.GetGoalkeeperPosition(goalCenter, ballPosition)
    else
      return PositionCalculator.GetFormationPosition(role, formation, teamSide)
    end
  end
  
  local basePosition = PositionCalculator.GetFormationPosition(role, formation, teamSide)
  
  if ballPosition then
    return PositionCalculator.AdjustForBall(basePosition, ballPosition, role, tacticalState, teamSide)
  end
  
  return basePosition
end

return PositionCalculator
