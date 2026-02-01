--[[
	AIGoalkeeper.lua
	Simplified goalkeeper AI for testing and development.
	
	Features:
	- Ball tracking and positioning
	- Dive animations when ball approaches
	- Smart positioning within goal area
	- Catch mechanics
]]

local AIGoalkeeper = {}

-- Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Settings
local Settings = {
	-- Positioning
	MaxDistanceFromGoal = 8,  -- How far keeper can move from goal line
	ReactionDistance = 25,  -- Distance at which keeper starts reacting
	DiveDistance = 12,  -- Distance at which keeper attempts dive
	
	-- Movement
	WalkSpeed = 16,
	SprintSpeed = 24,
	
	-- Dive mechanics
	DiveSpeed = 50,
	DiveDuration = 0.6,
	DiveCooldown = 1.5,
	
	-- Catch mechanics
	CatchRadius = 4,  -- How close ball needs to be to catch
	
	-- Update rates
	UpdateRate = 0.1,  -- How often to recalculate (seconds)
}

-- Private variables
local Character = nil
local Humanoid = nil
local RootPart = nil
local Animator = nil

local Ball = nil
local Goal = nil
local GoalCenter = nil
local GoalWidth = 0
local GoalHeight = 0

local LastDiveTime = 0
local IsDiving = false
local IsHoldingBall = false

local UpdateConnection = nil
local HeartbeatConnection = nil

-- Animation tracks
local AnimTracks = {
	DiveLeft = nil,
	DiveRight = nil,
	JumpCatch = nil,
	StandingCatch = nil,
	Scoop = nil,
	Throw = nil,
	IdleWithBall = nil,
}

-- Animation IDs
local AnimationIDs = {
	DiveLeft = "rbxassetid://134119711911427",  -- Goalkeeper Left Diving Save
	DiveRight = "rbxassetid://118774312513760",  -- Goalkeeper Right Diving Save
	JumpCatch = "rbxassetid://119888679150732",  -- Goalkeeper Jump Catch
	StandingCatch = "rbxassetid://110067978291476",  -- Goalkeeper Standing Catch
	Scoop = "rbxassetid://90457004291903",  -- Goalkeeper Scoop
	Throw = "rbxassetid://135849061306619",  -- Goalkeeper Throw
	IdleWithBall = "rbxassetid://92162025465133",  -- Goalkeeper Idle (With ball)
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIGoalkeeper.Initialize(character, ball, goal)
	Character = character
	Ball = ball
	Goal = goal
	
	if not Character or not Ball or not Goal then
		warn("[AIGoalkeeper] Missing required objects!")
		return false
	end
	
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	RootPart = Character:FindFirstChild("HumanoidRootPart")
	
	if not Humanoid or not RootPart then
		warn("[AIGoalkeeper] Character missing Humanoid or HumanoidRootPart!")
		return false
	end
	
	-- Calculate goal dimensions
	CalculateGoalDimensions()
	
	-- Setup animator
	SetupAnimator()
	
	-- Start update loop
	StartUpdateLoop()
	
	print("[AIGoalkeeper] Initialized successfully")
	return true
end

function CalculateGoalDimensions()
	-- Get goal center and dimensions
	GoalCenter = Goal.Position
	GoalWidth = Goal.Size.X
	GoalHeight = Goal.Size.Y
	
	print(string.format("[AIGoalkeeper] Goal - Center: %s, Width: %.1f, Height: %.1f", 
		tostring(GoalCenter), GoalWidth, GoalHeight))
end

function SetupAnimator()
	Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end
	
	-- Load animations
	for animName, animId in pairs(AnimationIDs) do
		local anim = Instance.new("Animation")
		anim.AnimationId = animId
		AnimTracks[animName] = Animator:LoadAnimation(anim)
	end
end

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function StartUpdateLoop()
	local lastUpdate = 0
	
	UpdateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		
		-- Update at fixed rate
		if now - lastUpdate >= Settings.UpdateRate then
			lastUpdate = now
			UpdateBehavior()
		end
	end)
	
	-- Separate heartbeat for continuous checks
	HeartbeatConnection = RunService.Heartbeat:Connect(function()
		CheckBallCatch()
	end)
end

function UpdateBehavior()
	if not Character or not Ball or not RootPart then return end
	if IsDiving then return end
	if IsHoldingBall then return end
	
	local ballPosition = Ball.Position
	local ballVelocity = Ball.AssemblyLinearVelocity
	local distanceToBall = (ballPosition - RootPart.Position).Magnitude
	
	-- Check if ball is moving toward goal
	local ballToGoal = (GoalCenter - ballPosition).Unit
	local velocityDirection = ballVelocity.Unit
	local isMovingTowardGoal = ballVelocity.Magnitude > 5 and velocityDirection:Dot(ballToGoal) > 0.5
	
	-- Decision making
	if isMovingTowardGoal and distanceToBall <= Settings.DiveDistance then
		-- DIVE!
		AttemptDive(ballPosition, ballVelocity)
	elseif distanceToBall <= Settings.ReactionDistance then
		-- Position to intercept
		PositionToIntercept(ballPosition, ballVelocity)
	else
		-- Return to goal center
		ReturnToGoalCenter()
	end
end

--------------------------------------------------------------------------------
-- POSITIONING
--------------------------------------------------------------------------------

function ReturnToGoalCenter()
	if not RootPart then return end
	
	-- Move to center of goal, slightly in front
	local targetPosition = GoalCenter + (RootPart.CFrame.LookVector * 2)
	
	-- Clamp to goal area
	targetPosition = ClampToGoalArea(targetPosition)
	
	-- Move toward target
	Humanoid.WalkSpeed = Settings.WalkSpeed
	Humanoid:MoveTo(targetPosition)
end

function PositionToIntercept(ballPosition, ballVelocity)
	if not RootPart then return end
	
	-- Predict where ball will be
	local timeToReach = 0.5  -- Predict 0.5 seconds ahead
	local predictedPosition = ballPosition + (ballVelocity * timeToReach)
	
	-- Project onto goal line
	local goalLine = GoalCenter
	local targetX = math.clamp(predictedPosition.X, GoalCenter.X - GoalWidth/2, GoalCenter.X + GoalWidth/2)
	local targetZ = GoalCenter.Z
	local targetY = RootPart.Position.Y
	
	local targetPosition = Vector3.new(targetX, targetY, targetZ)
	
	-- Move toward intercept point
	Humanoid.WalkSpeed = Settings.SprintSpeed
	Humanoid:MoveTo(targetPosition)
	
	-- Face the ball
	local lookDirection = (ballPosition - RootPart.Position) * Vector3.new(1, 0, 1)
	if lookDirection.Magnitude > 0.1 then
		RootPart.CFrame = CFrame.new(RootPart.Position, RootPart.Position + lookDirection)
	end
end

function ClampToGoalArea(position)
	-- Keep keeper within goal area
	local maxDistance = Settings.MaxDistanceFromGoal
	local distanceFromGoal = (position - GoalCenter).Magnitude
	
	if distanceFromGoal > maxDistance then
		local direction = (position - GoalCenter).Unit
		position = GoalCenter + (direction * maxDistance)
	end
	
	return position
end

--------------------------------------------------------------------------------
-- DIVE MECHANICS
--------------------------------------------------------------------------------

function AttemptDive(ballPosition, ballVelocity)
	local now = tick()
	
	-- Check cooldown
	if now - LastDiveTime < Settings.DiveCooldown then
		return
	end
	
	-- Determine dive direction (left or right)
	local ballRelativeX = ballPosition.X - RootPart.Position.X
	local diveDirection = ballRelativeX > 0 and "Right" or "Left"
	
	-- Execute dive
	ExecuteDive(diveDirection, ballPosition)
	
	LastDiveTime = now
end

function ExecuteDive(direction, targetPosition)
	if IsDiving then return end
	
	IsDiving = true
	
	-- Stop movement
	Humanoid.WalkSpeed = 0
	Humanoid:MoveTo(RootPart.Position)
	
	-- Play dive animation
	local animTrack = direction == "Left" and AnimTracks.DiveLeft or AnimTracks.DiveRight
	if animTrack then
		animTrack:Play()
	end
	
	-- Calculate dive target
	local diveOffset = direction == "Left" and Vector3.new(-3, 0, 0) or Vector3.new(3, 0, 0)
	local diveTarget = RootPart.Position + diveOffset
	
	-- Create dive motion using BodyVelocity
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(50000, 0, 50000)
	bodyVelocity.Velocity = diveOffset.Unit * Settings.DiveSpeed
	bodyVelocity.Parent = RootPart
	
	-- Remove after dive duration
	task.delay(Settings.DiveDuration, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
		
		-- Recovery
		task.wait(0.3)
		IsDiving = false
		Humanoid.WalkSpeed = Settings.WalkSpeed
	end)
	
	print(string.format("[AIGoalkeeper] Diving %s!", direction))
end

--------------------------------------------------------------------------------
-- CATCH MECHANICS
--------------------------------------------------------------------------------

function CheckBallCatch()
	if not Ball or not RootPart then return end
	if IsHoldingBall then return end
	
	local distanceToBall = (Ball.Position - RootPart.Position).Magnitude
	
	-- Check if ball is within catch radius
	if distanceToBall <= Settings.CatchRadius then
		-- Check if ball is moving (not already caught)
		if Ball.AssemblyLinearVelocity.Magnitude > 1 then
			CatchBall()
		end
	end
end

function CatchBall()
	if IsHoldingBall then return end
	
	IsHoldingBall = true
	
	-- Stop ball
	Ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	Ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	Ball.CanCollide = false
	
	-- Play catch animation (choose based on ball height)
	local ballHeight = Ball.Position.Y - RootPart.Position.Y
	local catchAnim = nil
	
	if ballHeight > 3 then
		catchAnim = AnimTracks.JumpCatch
	elseif ballHeight < -1 then
		catchAnim = AnimTracks.Scoop
	else
		catchAnim = AnimTracks.StandingCatch
	end
	
	if catchAnim then
		catchAnim:Play()
	end
	
	-- Attach ball to keeper (simple weld)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = RootPart
	weld.Part1 = Ball
	weld.Parent = Ball
	
	print("[AIGoalkeeper] Ball caught!")
	
	-- Hold for a moment with idle animation
	if AnimTracks.IdleWithBall then
		AnimTracks.IdleWithBall:Play()
	end
	
	task.wait(1.5)
	
	-- Play throw animation
	if AnimTracks.Throw then
		AnimTracks.Throw:Play()
	end
	
	task.wait(0.3)  -- Wait for throw animation windup
	
	-- Release ball
	if weld and weld.Parent then
		weld:Destroy()
	end
	
	Ball.CanCollide = true
	
	-- Throw ball forward
	local throwDirection = RootPart.CFrame.LookVector
	Ball.AssemblyLinearVelocity = throwDirection * 30 + Vector3.new(0, 20, 0)
	
	IsHoldingBall = false
	
	print("[AIGoalkeeper] Ball released!")
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function AIGoalkeeper.Cleanup()
	if UpdateConnection then
		UpdateConnection:Disconnect()
	end
	if HeartbeatConnection then
		HeartbeatConnection:Disconnect()
	end
	
	-- Stop all animations
	for _, track in pairs(AnimTracks) do
		if track then
			track:Stop()
		end
	end
	
	print("[AIGoalkeeper] Cleaned up")
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function AIGoalkeeper.SetDiveDistance(distance)
	Settings.DiveDistance = distance
end

function AIGoalkeeper.SetReactionDistance(distance)
	Settings.ReactionDistance = distance
end

function AIGoalkeeper.SetWalkSpeed(speed)
	Settings.WalkSpeed = speed
	if Humanoid and not IsDiving then
		Humanoid.WalkSpeed = speed
	end
end

return AIGoalkeeper
