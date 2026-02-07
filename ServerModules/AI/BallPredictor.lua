--[[
  BallPredictor.lua
  
  Utility module for predicting ball movement and trajectory.
  Used by AI system for interception, positioning, and pass reception.
  
  Functions:
  - PredictPosition: Predict ball position after time interval with drag
  - PredictLanding: Calculate where airborne ball will land
  - CanIntercept: Check if NPC can intercept ball trajectory
  - PredictPassArrival: Estimate when/where pass will arrive
]]

local AIConfig = require(script.Parent.AIConfig)
local SafeMath = require(script.Parent.SafeMath)

local BallPredictor = {}

-- Constants
local DRAG_FACTOR = 0.95  -- Per-second drag coefficient for ball movement
local NPC_SPEED = 16      -- Default NPC movement speed (studs/second)
local GRAVITY = workspace.Gravity  -- Roblox gravity constant

--[[
  Predict ball position after a time interval, accounting for drag.
  
  Parameters:
    ball - The ball Part object
    timeAhead - Time in seconds to predict ahead
    
  Returns:
    Vector3 - Predicted position
]]
function BallPredictor:PredictPosition(ball, timeAhead)
  if not ball or not ball:IsA("BasePart") then
    warn("[BallPredictor] Invalid ball object passed to PredictPosition")
    return ball and ball.Position or Vector3.new(0, 0, 0)
  end
  
  -- Wrap in pcall for error handling
  local success, predictedPos = pcall(function()
    local currentPosition = ball.Position
    local velocity = ball.AssemblyLinearVelocity
    
    -- Validate time ahead
    if not timeAhead or timeAhead < 0 then
      timeAhead = 0
    end
    
    -- If ball is stationary or nearly stationary, return current position
    if velocity.Magnitude < 0.1 then
      return currentPosition
    end
    
    -- Apply drag factor: dragFactor^timeAhead
    local dragMultiplier = math.pow(DRAG_FACTOR, timeAhead)
    
    -- Predicted position with drag
    local predictedPosition = currentPosition + (velocity * timeAhead * dragMultiplier)
    
    return predictedPosition
  end)
  
  if not success then
    warn("[BallPredictor] PredictPosition failed:", predictedPos)
    return ball.Position
  end
  
  return predictedPos
end

--[[
  Calculate where an airborne ball will land, accounting for gravity.
  
  Parameters:
    ball - The ball Part object
    
  Returns:
    Vector3 - Landing position
    number - Time to land (seconds)
]]
function BallPredictor:PredictLanding(ball)
  if not ball or not ball:IsA("BasePart") then
    warn("[BallPredictor] Invalid ball object passed to PredictLanding")
    return ball and ball.Position or Vector3.new(0, 0, 0), 0
  end
  
  -- Wrap in pcall for error handling
  local success, landingPos, landingTime = pcall(function()
    local currentPosition = ball.Position
    local velocity = ball.AssemblyLinearVelocity
    
    -- Check if ball is airborne
    local height = currentPosition.Y
    local verticalVelocity = velocity.Y
    
    -- If ball is on ground or moving upward slowly, return current position
    if height < 2 or (verticalVelocity > -1 and height < 5) then
      return currentPosition, 0
    end
    
    -- Use kinematic equation to calculate time to land
    local discriminant = verticalVelocity * verticalVelocity + 2 * GRAVITY * height
    
    if discriminant < 0 then
      return currentPosition, 0
    end
    
    local timeToLand = SafeMath.SafeDivide(
      verticalVelocity + SafeMath.SafeSqrt(discriminant, 0),
      GRAVITY,
      0
    )
    
    -- Ensure positive time
    if timeToLand < 0 then
      timeToLand = 0
    end
    
    -- Calculate horizontal landing position
    local landingX = currentPosition.X + velocity.X * timeToLand
    local landingZ = currentPosition.Z + velocity.Z * timeToLand
    
    -- Landing position
    local landingPosition = Vector3.new(landingX, 0, landingZ)
    
    return landingPosition, timeToLand
  end)
  
  if not success then
    warn("[BallPredictor] PredictLanding failed:", landingPos)
    return ball.Position, 0
  end
  
  return landingPos, landingTime
end

--[[
  Check if an NPC can intercept the ball trajectory within a time window.
  
  Parameters:
    npc - The NPC Model object
    ball - The ball Part object
    timeWindow - Maximum time window to consider (seconds)
    
  Returns:
    boolean - Can intercept
    Vector3 - Interception point (or ball position if cannot intercept)
]]
function BallPredictor:CanIntercept(npc, ball, timeWindow)
  if not npc or not npc:FindFirstChild("HumanoidRootPart") then
    warn("[BallPredictor] Invalid NPC passed to CanIntercept")
    return false, ball and ball.Position or Vector3.new(0, 0, 0)
  end
  
  if not ball or not ball:IsA("BasePart") then
    warn("[BallPredictor] Invalid ball object passed to CanIntercept")
    return false, Vector3.new(0, 0, 0)
  end
  
  local npcPosition = npc.HumanoidRootPart.Position
  local npcSpeed = NPC_SPEED
  
  -- Get NPC's actual walk speed if available
  local humanoid = npc:FindFirstChildOfClass("Humanoid")
  if humanoid then
    npcSpeed = humanoid.WalkSpeed
  end
  
  -- Sample multiple time points within the window to find best interception
  local bestInterceptionPoint = nil
  local bestTimeDifference = math.huge
  local canIntercept = false
  
  local sampleCount = 5
  for i = 1, sampleCount do
    local sampleTime = (timeWindow / sampleCount) * i
    
    -- Predict ball position at this time
    local predictedBallPosition = self:PredictPosition(ball, sampleTime)
    
    -- Calculate if NPC can reach this position in time
    local distanceToIntercept = (npcPosition - predictedBallPosition).Magnitude
    local timeToReach = distanceToIntercept / npcSpeed
    
    -- Check if NPC arrives before or shortly after ball
    local timeDifference = math.abs(timeToReach - sampleTime)
    
    if timeToReach <= sampleTime + 0.5 and timeDifference < bestTimeDifference then
      bestTimeDifference = timeDifference
      bestInterceptionPoint = predictedBallPosition
      canIntercept = true
    end
  end
  
  -- If no interception found, return current ball position
  if not bestInterceptionPoint then
    bestInterceptionPoint = ball.Position
  end
  
  return canIntercept, bestInterceptionPoint
end

--[[
  Estimate when and where a pass will arrive at target position.
  
  Parameters:
    fromPosition - Vector3 starting position of pass
    toPosition - Vector3 target position of pass
    passSpeed - Speed of the pass (studs/second)
    
  Returns:
    Vector3 - Arrival position (accounting for any adjustments)
    number - Arrival time (seconds)
]]
function BallPredictor:PredictPassArrival(fromPosition, toPosition, passSpeed)
  if not fromPosition or not toPosition then
    warn("[BallPredictor] Invalid positions passed to PredictPassArrival")
    return toPosition or Vector3.new(0, 0, 0), 0
  end
  
  if not passSpeed or passSpeed <= 0 then
    passSpeed = 50  -- Default pass speed
  end
  
  -- Calculate distance and time
  local distance = (toPosition - fromPosition).Magnitude
  local arrivalTime = distance / passSpeed
  
  -- For now, arrival position is the target position
  -- In future, could account for moving targets or drag
  local arrivalPosition = toPosition
  
  return arrivalPosition, arrivalTime
end

return BallPredictor
