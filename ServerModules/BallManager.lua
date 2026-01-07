--[[
	BallManager.lua
	Handles ball physics, possession, and kicking for both players and NPCs.
	
	Responsibilities:
	- Ball possession system (works with ANY character)
	- Attachment/detachment logic
	- Kick handling
	- Touch detection
	- Ball damping and physics
]]

local BallManager = {}

-- Services
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

-- Settings
local Settings = {
	Ground_Kick_Max = 50,
	Air_Kick_Max = 80,
	Ground_Kick_Height = 15,
	Air_Kick_Height = 60,
	Possession_Timeout = 0.5,
	Touch_Cooldown = 0.5,
	Damping = 0.99
}

-- Private variables
local Ball = nil
local KickSound = nil
local CurrentOwnerCharacter = nil  -- Now stores Character, not Player
local OwnershipStart = 0
local BallAttachment = nil
local BallSpinner = nil
local BallAxle = nil
local TouchCooldown = {}  -- Key is now Character
local HeartbeatConnection = nil
local TouchConnection = nil

-- Goal references
local BlueGoal = nil
local RedGoal = nil
local GoalTouchConnections = {}

-- Remote Events
local RemoteFolder = nil
local KickBall = nil
local PossessionChanged = nil

-- Callbacks for external systems
local PossessionChangedCallback = nil
local TeamManager = nil
local FieldCenter = nil

-- Initialize the Ball Manager
function BallManager.Initialize(ballPart, blueGoal, redGoal, fieldCenter, teamManager)
	Ball = ballPart
	BlueGoal = blueGoal
	RedGoal = redGoal
	FieldCenter = fieldCenter
	TeamManager = teamManager

	if not Ball then
		warn("[BallManager] Ball part not found!")
		return false
	end

	if not BlueGoal or not RedGoal then
		warn("[BallManager] Goals not found!")
		return false
	end

	KickSound = Ball:FindFirstChild("Kick")
	if not KickSound then
		warn("[BallManager] Kick sound not found in Ball!")
	end

	-- Setup collision groups
	BallManager._SetupCollisionGroups()

	-- Create RemoteEvents
	RemoteFolder = Instance.new("Folder")
	RemoteFolder.Name = "BallRemotes"
	RemoteFolder.Parent = ReplicatedStorage

	KickBall = Instance.new("RemoteEvent")
	KickBall.Name = "KickBall"
	KickBall.Parent = RemoteFolder

	PossessionChanged = Instance.new("RemoteEvent")
	PossessionChanged.Name = "PossessionChanged"
	PossessionChanged.Parent = RemoteFolder

	-- Connect events
	BallManager._SetupTouchDetection()
	BallManager._SetupKickHandler()
	BallManager._SetupHeartbeat()
	BallManager._SetupPlayerCleanup()
	BallManager._SetupGoalDetection()

	print("[BallManager] Initialized with goal detection")
	return true
end

-- Private: Setup goal zone detection
function BallManager._SetupGoalDetection()
	-- Blue Goal detection
	local blueConnection = BlueGoal.Touched:Connect(function(hit)
		if hit == Ball and TeamManager then
			-- Reset ball immediately
			BallManager.ResetBallToCenter()
			-- Notify TeamManager
			TeamManager.OnGoalScored("Red")  -- Red scores in Blue's goal
		end
	end)
	table.insert(GoalTouchConnections, blueConnection)

	-- Red Goal detection
	local redConnection = RedGoal.Touched:Connect(function(hit)
		if hit == Ball and TeamManager then
			-- Reset ball immediately
			BallManager.ResetBallToCenter()
			-- Notify TeamManager
			TeamManager.OnGoalScored("Blue")  -- Blue scores in Red's goal
		end
	end)
	table.insert(GoalTouchConnections, redConnection)
	print("[BallManager] Goal detection active")
end

-- Set a callback for when possession changes (for AI to listen)
function BallManager.OnPossessionChanged(callback)
	PossessionChangedCallback = callback
end

-- Reset ball to center (called by TeamManager after goals)
function BallManager.ResetBallToCenter()
	if not Ball or not FieldCenter then
		warn("[BallManager] Cannot reset ball - missing Ball or FieldCenter")
		return
	end

	-- Detach ball if possessed
	BallManager.DetachBall()

	-- Reset ball position to center
	Ball.CFrame = CFrame.new(FieldCenter + Vector3.new(0, 10, 0))
	Ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	Ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	print("[BallManager] Ball reset to center")
end

-- Private: Setup collision groups for the ball
function BallManager._SetupCollisionGroups()
	if Ball then
		Ball.CollisionGroup = "Ball"
	end
end

-- Private: Attach ball to character
local function AttachBallToCharacter(character, rootPart)
	-- Clean up existing attachments
	if BallAttachment then BallAttachment:Destroy() end
	if BallSpinner then BallSpinner:Destroy() end
	if BallAxle then BallAxle:Destroy() end

	-- Position ball in front of character at foot level
	local offset = rootPart.CFrame.LookVector * 3.25
	Ball.CFrame = CFrame.new(
		Vector3.new(rootPart.Position.X, rootPart.Position.Y - 5, rootPart.Position.Z) + 
			Vector3.new(offset.X, 0, offset.Z)
	)

	-- Create invisible "axle" part at ball center
	local axle = Instance.new("Part")
	axle.Name = "BallAxle"
	axle.Size = Vector3.new(0.5, 0.5, 0.5)
	axle.Transparency = 1
	axle.CanCollide = false
	axle.Massless = true
	axle.CFrame = Ball.CFrame
	axle.Parent = workspace
	BallAxle = axle

	-- Weld axle to character
	local axleWeld = Instance.new("WeldConstraint")
	axleWeld.Part0 = axle
	axleWeld.Part1 = rootPart
	axleWeld.Parent = axle

	-- Create attachments for HingeConstraint
	local axleAttachment = Instance.new("Attachment")
	axleAttachment.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	axleAttachment.Parent = axle

	local ballAttachment = Instance.new("Attachment")
	ballAttachment.Parent = Ball

	-- Create HingeConstraint for ball spin
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = axleAttachment
	hinge.Attachment1 = ballAttachment
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.MotorMaxTorque = 10000
	hinge.AngularVelocity = 10
	hinge.Parent = axle

	Ball.CanCollide = false
	BallAttachment = axleWeld
	BallSpinner = hinge
end

-- Private: Detach ball from character
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

	local oldOwner = CurrentOwnerCharacter
	CurrentOwnerCharacter = nil

	-- Notify player clients if the owner was a player
	if oldOwner then
		local player = Players:GetPlayerFromCharacter(oldOwner)
		if player then
			PossessionChanged:FireClient(player, false)
		end

		-- Call external callback (for AI system)
		if PossessionChangedCallback then
			PossessionChangedCallback(oldOwner, false)
		end
	end
end

-- Set possession for a character (Player OR NPC)
function BallManager.SetPossession(character, rootPart)
	if not character or not rootPart then
		warn("[BallManager] Invalid character or rootPart for SetPossession")
		return false
	end

	-- Detach from previous owner
	if CurrentOwnerCharacter and CurrentOwnerCharacter ~= character then
		local oldPlayer = Players:GetPlayerFromCharacter(CurrentOwnerCharacter)
		if oldPlayer then
			PossessionChanged:FireClient(oldPlayer, false)
		end

		-- Notify AI system
		if PossessionChangedCallback then
			PossessionChangedCallback(CurrentOwnerCharacter, false)
		end
	end

	CurrentOwnerCharacter = character
	OwnershipStart = tick()
	AttachBallToCharacter(character, rootPart)

	-- Notify player if owner is a player
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		PossessionChanged:FireClient(player, true)
	end

	-- Notify AI system
	if PossessionChangedCallback then
		PossessionChangedCallback(character, true)
	end

	return true
end

-- Get current owner character
function BallManager.GetCurrentOwner()
	return CurrentOwnerCharacter
end

-- Check if a specific character owns the ball
function BallManager.IsCharacterOwner(character)
	return CurrentOwnerCharacter == character
end

-- Check if a character can take possession
function BallManager.CanTakePossession(character)
	-- Ball is flying
	if Ball:FindFirstChildOfClass("BodyVelocity") then
		return false
	end

	-- Check cooldown
	if TouchCooldown[character] and tick() - TouchCooldown[character] < Settings.Touch_Cooldown then
		return false
	end

	-- Check if someone else has recent possession
	if CurrentOwnerCharacter and CurrentOwnerCharacter ~= character then
		if tick() - OwnershipStart < Settings.Possession_Timeout then
			return false
		end
	end

	return true
end

-- Detach the ball (public method)
function BallManager.DetachBall()
	DetachBall()
end

-- Private: Choose kick animation based on direction and power
local function ChooseKickAnimation(rootPart, direction, power, kickType)
	-- Determine if ball is going left or right relative to character
	local characterRight = rootPart.CFrame.RightVector
	local dotRight = characterRight:Dot(direction)

	-- Determine if it's a pass (low power) or strike (high power)
	local isStrike = power > 0.85 or kickType == "Air"

	if isStrike then
		-- Strike animations (powerful shots)
		if dotRight > 0 then
			return "rbxassetid://76069154190283"  -- Strike Right Kick
		else
			return "rbxassetid://108579500601701" -- Strike Left Kick
		end
	else
		-- Pass animations (lower power passes)
		if dotRight > 0 then
			return "rbxassetid://133927349049921" -- Pass Right Kick
		else
			return "rbxassetid://99205226261734"  -- Pass Left Kick
		end
	end
end


-- Kick the ball (called by players via remote or by AI directly)
function BallManager.KickBall(character, kickType, power, direction)
	if CurrentOwnerCharacter ~= character then
		return false
	end

	if not character then
		DetachBall()
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then
		DetachBall()
		return false
	end

	-- Validate power (0-1)
	power = math.clamp(power or 1, 0, 1)
	local powerCurve = math.sqrt(power)

	-- Validate direction
	if not direction or direction.Magnitude < 0.1 then
		direction = rootPart.CFrame.LookVector
	else
		direction = direction.Unit
	end

	-- Stop the character and play animation
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	rootPart.Anchored = true

	-- Choose kick animation based on direction and power
	local kickAnimationId = ChooseKickAnimation(rootPart, direction, power, kickType)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local kickAnimation = Instance.new("Animation")
	kickAnimation.AnimationId = kickAnimationId
	local animTrack : AnimationTrack = animator:LoadAnimation(kickAnimation)
	animTrack:Play()

	-- Detach ball
	DetachBall()

	-- Calculate kick force
	local maxPower = kickType == "Ground" and Settings.Ground_Kick_Max or Settings.Air_Kick_Max
	local maxHeight = kickType == "Ground" and Settings.Ground_Kick_Height or Settings.Air_Kick_Height
	local force = maxPower * powerCurve * 1.5
	local height = maxHeight * powerCurve

	-- Restore character movement after animation
	task.spawn(function()
		task.wait(animTrack.Length)
		if rootPart and humanoid then
			rootPart.Anchored = false
			humanoid.WalkSpeed = originalWalkSpeed
			animTrack:Stop()
		end
	end)

	task.wait(0.3)

	-- Apply velocity
	local velocity = Instance.new("BodyVelocity")
	velocity.Parent = Ball
	velocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	velocity.Velocity = (direction * force) + Vector3.new(0, height, 0)

	Debris:AddItem(velocity, 0.2)

	if KickSound then
		KickSound:Play()
	end

	return true
end

-- Private: Setup touch detection
function BallManager._SetupTouchDetection()
	TouchConnection = Ball.Touched:Connect(function(part)
		-- Don't allow attachment if ball is flying
		if Ball:FindFirstChildOfClass("BodyVelocity") then
			return
		end

		local character = part.Parent
		if not character then
			return
		end

		-- Check if touched by foot or leg 
		if not (part.Name == "Shoes" or part.Name == "Socks") then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		-- Check if can take possession
		if not BallManager.CanTakePossession(character) then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			TouchCooldown[character] = tick()
			BallManager.SetPossession(character, rootPart)

			-- Notify TeamManager about ball touch (for kickoff)
			if TeamManager and TeamManager.OnBallTouched then
				TeamManager.OnBallTouched()
			end
		end
	end)
end

-- Private: Setup kick handler for players
function BallManager._SetupKickHandler()
	KickBall.OnServerEvent:Connect(function(player, kickType, power, direction)
		local character = player.Character
		if not character then
			return
		end

		BallManager.KickBall(character, kickType, power, direction)
	end)
end

-- Private: Setup heartbeat for damping and maintenance
function BallManager._SetupHeartbeat()
	HeartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		-- Apply damping when ball is loose
		if not CurrentOwnerCharacter and Ball.AssemblyLinearVelocity.Magnitude > 0.1 then
			Ball.AssemblyLinearVelocity *= Settings.Damping
		end

		-- Auto-detach if owner dies
		if CurrentOwnerCharacter then
			local humanoid = CurrentOwnerCharacter:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				DetachBall()
				return
			end

			-- Update ball spin based on character speed
			if BallSpinner then
				local rootPart = CurrentOwnerCharacter:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local speed = rootPart.AssemblyLinearVelocity.Magnitude
					BallSpinner.AngularVelocity = speed * 2
				end
			end
		end
	end)
end

-- Private: Setup player cleanup
function BallManager._SetupPlayerCleanup()
	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			if CurrentOwnerCharacter == character then
				DetachBall()
			end
			TouchCooldown[character] = nil
		end
	end)
end

-- Cleanup (for testing/resetting)
function BallManager.Cleanup()
	if TouchConnection then
		TouchConnection:Disconnect()
	end
	if HeartbeatConnection then
		HeartbeatConnection:Disconnect()
	end

	DetachBall()

	if RemoteFolder then
		RemoteFolder:Destroy()
	end

	print("[BallManager] Cleaned up")
end

return BallManager
