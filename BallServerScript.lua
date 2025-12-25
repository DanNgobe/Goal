-- ServerScriptService/BallServer
local Services = {
	Players = game:GetService("Players"),
	Debris = game:GetService("Debris"),
	ReplicatedStorage = game:GetService("ReplicatedStorage")
}

local Settings = {
	Ground_Kick_Max = 50,
	Air_Kick_Max = 80,
	Ground_Kick_Height = 15,
	Air_Kick_Height = 60,
	Possession_Timeout = 0.5,
	Touch_Cooldown = 0.5
}

local Ball = workspace:WaitForChild("Ball")
local KickSound = Ball:WaitForChild("Kick")

-- Create RemoteEvents
local RemoteFolder = Instance.new("Folder")
RemoteFolder.Name = "BallRemotes"
RemoteFolder.Parent = Services.ReplicatedStorage

local KickBall = Instance.new("RemoteEvent")
KickBall.Name = "KickBall"
KickBall.Parent = RemoteFolder

local PossessionChanged = Instance.new("RemoteEvent")
PossessionChanged.Name = "PossessionChanged"
PossessionChanged.Parent = RemoteFolder

-- State management
local CurrentOwner = nil
local OwnershipStart = 0
local BallAttachment = nil
local BallSpinner = nil
local BallAxle = nil
local TouchCooldown = {}

-- Create attachment weld
local function AttachBallToPlayer(Character, RootPart)
	if BallAttachment then
		BallAttachment:Destroy()
	end
	if BallSpinner then
		BallSpinner:Destroy()
	end
	if BallAxle then
		BallAxle:Destroy()
	end

	-- Position ball in front of player at foot level
	local Offset = RootPart.CFrame.LookVector * 2.2
	Ball.CFrame = CFrame.new(
		Vector3.new(RootPart.Position.X, RootPart.Position.Y - 2, RootPart.Position.Z) + 
			Vector3.new(Offset.X, 0, Offset.Z)
	)

	-- Create invisible "axle" part at ball center
	local Axle = Instance.new("Part")
	Axle.Name = "BallAxle"
	Axle.Size = Vector3.new(0.5, 0.5, 0.5)
	Axle.Transparency = 1
	Axle.CanCollide = false
	Axle.Massless = true
	Axle.CFrame = Ball.CFrame
	Axle.Parent = workspace
	BallAxle = Axle

	-- Weld axle to player (this stays fixed)
	local AxleWeld = Instance.new("WeldConstraint")
	AxleWeld.Part0 = Axle
	AxleWeld.Part1 = RootPart
	AxleWeld.Parent = Axle

	-- Create attachments for HingeConstraint
	local AxleAttachment = Instance.new("Attachment")
	AxleAttachment.CFrame = CFrame.Angles(math.rad(90), 0, 0) -- Rotate for pitch (forward/backward spin)
	AxleAttachment.Parent = Axle

	local BallAttachment0 = Instance.new("Attachment")
	BallAttachment0.Parent = Ball

	-- Create HingeConstraint to allow ball to spin on Y axis only
	local Hinge = Instance.new("HingeConstraint")
	Hinge.Attachment0 = AxleAttachment
	Hinge.Attachment1 = BallAttachment0
	Hinge.ActuatorType = Enum.ActuatorType.Motor
	Hinge.MotorMaxTorque = 10000
	Hinge.AngularVelocity = 10 -- Spin speed
	Hinge.Parent = Axle

	Ball.CanCollide = false
	BallAttachment = AxleWeld
	BallSpinner = Hinge

	return AxleWeld
end

local function DetachBall()
	if BallAttachment then
		BallAttachment:Destroy()
		BallAttachment = nil
	end
	if BallSpinner then
		BallSpinner:Destroy()
		BallSpinner = nil
	end
	if BallAxle then
		BallAxle:Destroy()
		BallAxle = nil
	end
	Ball.CanCollide = true
	local OldOwner = CurrentOwner
	CurrentOwner = nil

	-- Notify clients that possession ended
	if OldOwner then
		PossessionChanged:FireClient(OldOwner, false)
	end
end

local function SetPossession(Player, RootPart)
	-- Detach from previous owner
	if CurrentOwner and CurrentOwner ~= Player then
		PossessionChanged:FireClient(CurrentOwner, false)
	end

	CurrentOwner = Player
	OwnershipStart = tick()
	AttachBallToPlayer(Player.Character, RootPart)

	-- Notify the new owner
	PossessionChanged:FireClient(Player, true)
end

-- Handle ball touches
Ball.Touched:Connect(function(Part)
	-- Don't allow attachment if ball has BodyVelocity (still flying from a kick)
	if Ball:FindFirstChildOfClass("BodyVelocity") then
		return
	end

	local Character = Part.Parent
	if not Character then
		return
	end

	local Player = Services.Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	-- Check cooldown
	if TouchCooldown[Player] and tick() - TouchCooldown[Player] < Settings.Touch_Cooldown then
		return
	end

	-- Check if someone else has recent possession
	if CurrentOwner and CurrentOwner ~= Player then
		if tick() - OwnershipStart < Settings.Possession_Timeout then
			return
		end
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	-- Check if touched by foot
	if not (Part.Name == "LeftFoot" or Part.Name == "RightFoot") then
		return
	end

	local RootPart = Character:FindFirstChild("HumanoidRootPart")
	if RootPart then
		TouchCooldown[Player] = tick()
		SetPossession(Player, RootPart)
	end
end)

-- Handle kicks
KickBall.OnServerEvent:Connect(function(Player, KickType, Power, Direction)
	if CurrentOwner ~= Player then
		return
	end

	if not Player.Character then
		DetachBall()
		return
	end

	local Root = Player.Character:FindFirstChild("HumanoidRootPart")
	local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
	if not Root or not Humanoid then
		DetachBall()
		return
	end

	-- Validate power (0-1)
	Power = math.clamp(Power or 1, 0, 1)

	-- Apply logarithmic power curve for diminishing returns
	-- Light taps have good power, holding gives more but with exponential decay
	local PowerCurve = math.sqrt(Power)

	-- Validate direction
	if not Direction or Direction.Magnitude < 0.1 then
		Direction = Root.CFrame.LookVector
	else
		Direction = Direction.Unit
	end

	-- Stop the player and play animation
	local OriginalWalkSpeed = Humanoid.WalkSpeed
	Humanoid.WalkSpeed = 0
	Root.Anchored = true

	-- Load and play kick animation
	local KickAnimationId = "rbxassetid://13755924377"
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end

	local KickAnimation = Instance.new("Animation")
	KickAnimation.AnimationId = KickAnimationId
	local AnimTrack = Animator:LoadAnimation(KickAnimation)
	AnimTrack:Play()

	-- Wait for animation kick moment (adjust timing as needed)
	--task.wait(0.5)

	DetachBall()

	local MaxPower = KickType == "Ground" and Settings.Ground_Kick_Max or Settings.Air_Kick_Max
	local MaxHeight = KickType == "Ground" and Settings.Ground_Kick_Height or Settings.Air_Kick_Height
	local Force = MaxPower * PowerCurve * 2
	local Height = MaxHeight * PowerCurve

	-- Apply velocity
	local Velocity = Instance.new("BodyVelocity")
	Velocity.Parent = Ball
	Velocity.MaxForce = Vector3.new(1, 1, 1) * math.huge

	if KickType == "Ground" then
		Velocity.Velocity = (Direction * Force) + Vector3.new(0, Height, 0)
	else -- Air kick
		Velocity.Velocity = (Direction * Force) + Vector3.new(0, Height, 0)
	end

	Services.Debris:AddItem(Velocity, 0.2)

	KickSound:Play()

	-- Restore player movement after animation
	task.wait(0.5)
	Root.Anchored = false
	Humanoid.WalkSpeed = OriginalWalkSpeed
	AnimTrack:Stop()
end)

-- Damping
local RunService = game:GetService("RunService")
local DAMPING = 0.99

RunService.Heartbeat:Connect(function(dt)
	if not CurrentOwner and Ball.AssemblyLinearVelocity.Magnitude > 0.1 then
		Ball.AssemblyLinearVelocity *= DAMPING
	end

	-- Auto-detach if owner dies or leaves
	if CurrentOwner then
		local Character = CurrentOwner.Character
		if not Character then
			DetachBall()
			return
		end

		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid or Humanoid.Health <= 0 then
			DetachBall()
			return
		end

		-- Update ball spin based on player speed
		if BallSpinner then
			local RootPart = Character:FindFirstChild("HumanoidRootPart")
			if RootPart then
				local Speed = RootPart.AssemblyLinearVelocity.Magnitude
				-- Scale spin with speed (0 when standing, faster when running)
				BallSpinner.AngularVelocity = Speed * 2
			end
		end
	end
end)

-- Cleanup on player leaving
Services.Players.PlayerRemoving:Connect(function(Player)
	if CurrentOwner == Player then
		DetachBall()
	end
	TouchCooldown[Player] = nil
end)