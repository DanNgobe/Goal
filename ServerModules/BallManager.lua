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
	Ground_Kick_Max = 55,
	Air_Kick_Max = 65,
	Ground_Kick_Height = 15,
	Air_Kick_Height = 65,
	Possession_Timeout = 0.5,
	Touch_Cooldown = 0.5,
	Max_Possession_Speed = 50,
	Damping = 0.98,
	Reset_Height = -10
}

-- Private variables
local Ball = nil
local KickSound = nil
local CurrentOwnerCharacter = nil  -- Now stores Character, not Player
local LastKickerCharacter = nil  -- Track who last kicked the ball (for goal celebrations)
local LastOwnerCharacter = nil  -- Track who passed the ball (for assists)
local OwnershipStart = 0
local BallAttachment = nil
local BallSpinner = nil
local BallAxle = nil
local TouchCooldown = {}  -- Key is now Character
local HeartbeatConnection = nil
local TouchConnection = nil
local GoalkeeperAlignPos = nil  -- For goalkeeper AlignPosition
local GoalkeeperAlignOri = nil  -- For goalkeeper AlignOrientation
local GoalkeeperBallAttach = nil  -- Attachment on ball
local GoalkeeperBoneAttach = nil  -- Attachment on body bone

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

-- Check if character is a goalkeeper
local function IsGoalkeeper(character)
	return TeamManager and TeamManager.IsGoalkeeper(character)
end

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

	-- Set collision group for Ball
	pcall(function()
		Ball.CollisionGroup = "Ball"
	end)

	if not BlueGoal or not RedGoal then
		warn("[BallManager] Goals not found!")
		return false
	end

	KickSound = Ball:FindFirstChild("Kick")
	if not KickSound then
		warn("[BallManager] Kick sound not found in Ball!")
	end


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

	return true
end

-- Private: Setup goal zone detection
function BallManager._SetupGoalDetection()
	-- HomeTeam Goal detection
	local blueConnection = BlueGoal.Touched:Connect(function(hit)
		if hit == Ball and TeamManager then
			-- Notify TeamManager with scorer and assister info
			TeamManager.OnGoalScored("AwayTeam", LastKickerCharacter, LastOwnerCharacter)  -- AwayTeam scores in HomeTeam's goal
			-- Reset ball immediately
			BallManager.ResetBallToCenter()
		end
	end)
	table.insert(GoalTouchConnections, blueConnection)

	-- AwayTeam Goal detection
	local redConnection = RedGoal.Touched:Connect(function(hit)
		if hit == Ball and TeamManager then
			-- Notify TeamManager with scorer and assister info
			TeamManager.OnGoalScored("HomeTeam", LastKickerCharacter, LastOwnerCharacter)  -- HomeTeam scores in AwayTeam's goal
			-- Reset ball immediately
			BallManager.ResetBallToCenter()
		end
	end)
	table.insert(GoalTouchConnections, redConnection)
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

	-- Reset trackers
	LastKickerCharacter = nil
	LastOwnerCharacter = nil

	-- Reset ball position to center
	Ball.CFrame = CFrame.new(FieldCenter + Vector3.new(0, 10, 0))
	Ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	Ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

end


-- Private: Attach ball to character
local function AttachBallToCharacter(character, rootPart)
	-- Clean up existing attachments
	if BallAttachment then BallAttachment:Destroy() end
	if BallSpinner then BallSpinner:Destroy() end
	if BallAxle then BallAxle:Destroy() end

	-- Check if this is a goalkeeper
	local isGoalkeeper = IsGoalkeeper(character)

	if isGoalkeeper then
		-- GOALKEEPER: Use AlignPosition and AlignOrientation constraints for smooth animation following
		-- Find the Hips bone (direct child of RootPart, like "mixamorig5:Hips")
		local hipsBone = nil

		-- First, find the RootPart (different from HumanoidRootPart)
		local animRootPart = character:FindFirstChild("RootPart")

		if animRootPart then
			-- Search for Hips bone directly under RootPart
			for _, child in pairs(animRootPart:GetChildren()) do
				if child.Name:match("Hips") then
					hipsBone = child
					break
				end
			end
		end

		if not hipsBone then
			warn("[BallManager] Hips bone not found for goalkeeper, using rootPart as fallback")
			hipsBone = rootPart
		end

		-- Clean up any existing goalkeeper constraints
		if GoalkeeperAlignPos then GoalkeeperAlignPos:Destroy() end
		if GoalkeeperAlignOri then GoalkeeperAlignOri:Destroy() end
		if GoalkeeperBallAttach then GoalkeeperBallAttach:Destroy() end
		if GoalkeeperBoneAttach then GoalkeeperBoneAttach:Destroy() end

		Ball.CanCollide = false
		Ball.Massless = true

		-- Create attachment on the ball
		GoalkeeperBallAttach = Instance.new("Attachment")
		GoalkeeperBallAttach.Parent = Ball

		-- Create attachment on the hips bone with offset
		GoalkeeperBoneAttach = Instance.new("Attachment")
		GoalkeeperBoneAttach.Parent = hipsBone
		GoalkeeperBoneAttach.CFrame = CFrame.new(0, 0, -1.5)  -- Offset: 1.5 studs below hips, 0)  -- Offset: similar to sample script

		-- AlignPosition constraint
		GoalkeeperAlignPos = Instance.new("AlignPosition")
		GoalkeeperAlignPos.Attachment0 = GoalkeeperBallAttach
		GoalkeeperAlignPos.Attachment1 = GoalkeeperBoneAttach
		GoalkeeperAlignPos.RigidityEnabled = true
		GoalkeeperAlignPos.MaxForce = math.huge
		GoalkeeperAlignPos.Responsiveness = 200
		GoalkeeperAlignPos.Parent = Ball

		-- AlignOrientation constraint
		GoalkeeperAlignOri = Instance.new("AlignOrientation")
		GoalkeeperAlignOri.Attachment0 = GoalkeeperBallAttach
		GoalkeeperAlignOri.Attachment1 = GoalkeeperBoneAttach
		GoalkeeperAlignOri.RigidityEnabled = true
		GoalkeeperAlignOri.MaxTorque = math.huge
		GoalkeeperAlignOri.Responsiveness = 200
		GoalkeeperAlignOri.Parent = Ball

		BallAttachment = GoalkeeperAlignPos  -- Store reference for cleanup
		BallSpinner = nil
		BallAxle = nil
	else
		-- OUTFIELD PLAYER: Original complex system with spin
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

		BallAttachment = axleWeld
		BallSpinner = hinge

		Ball.CanCollide = false
		Ball.Massless = true
	end
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

	-- Clean up goalkeeper constraints
	if GoalkeeperAlignPos then
		GoalkeeperAlignPos:Destroy()
		GoalkeeperAlignPos = nil
	end
	if GoalkeeperAlignOri then
		GoalkeeperAlignOri:Destroy()
		GoalkeeperAlignOri = nil
	end
	if GoalkeeperBallAttach then
		GoalkeeperBallAttach:Destroy()
		GoalkeeperBallAttach = nil
	end
	if GoalkeeperBoneAttach then
		GoalkeeperBoneAttach:Destroy()
		GoalkeeperBoneAttach = nil
	end

	Ball.CanCollide = true
	Ball.Massless = false

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
	-- Ball is flying or moving too fast
	if Ball:FindFirstChildOfClass("BodyVelocity") or Ball.AssemblyLinearVelocity.Magnitude > Settings.Max_Possession_Speed then
		return false
	end

	-- Check cooldown
	if TouchCooldown[character] and tick() - TouchCooldown[character] < Settings.Touch_Cooldown then
		return false
	end

	-- Check if someone else has recent possession
	if CurrentOwnerCharacter and CurrentOwnerCharacter ~= character then
		-- PROTECT GOALKEEPER POSSESSION: If current owner is GK, nobody else can take it
		if IsGoalkeeper(CurrentOwnerCharacter) then
			return false
		end

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

-- Kick the ball (called by players via remote or by AI directly)
-- Note: Animation should be played BEFORE calling this function
-- - For players: animation played on client
-- - For NPCs: animation played by AIController
function BallManager.KickBall(character, kickType, power, direction)
	if CurrentOwnerCharacter ~= character then
		return false
	end

	if not character then
		DetachBall()
		return false
	end

	-- Track who kicked the ball (for goal celebrations and assists)
	if character ~= LastKickerCharacter then
		LastOwnerCharacter = LastKickerCharacter
	end
	LastKickerCharacter = character

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart then
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

	-- Calculate kick force first
	local maxPower = kickType == "Ground" and Settings.Ground_Kick_Max or Settings.Air_Kick_Max
	local maxHeight = kickType == "Ground" and Settings.Ground_Kick_Height or Settings.Air_Kick_Height
	local force = maxPower * powerCurve * 1.3
	local height = maxHeight * powerCurve

	-- Detach ball and position it away from character
	DetachBall()

	-- Position ball slightly in front of character to prevent drag
	Ball.CFrame = CFrame.new(rootPart.Position + (direction * 3) + Vector3.new(0, -2, 0))
	Ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	Ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	-- Disable ball touch temporarily to prevent immediate re-possession
	Ball.CanTouch = false

	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	rootPart.Anchored = true
	task.delay(0.2, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalWalkSpeed
			rootPart.Anchored = false
		end
	end)

	-- Apply velocity
	local velocity = Instance.new("BodyVelocity")
	velocity.Parent = Ball
	velocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	velocity.Velocity = (direction * force) + Vector3.new(0, height, 0)

	Debris:AddItem(velocity, 0.2)

	if KickSound then
		KickSound:Play()
	end

	-- Re-enable ball touch after delay
	task.delay(0.3, function()
		if Ball then
			Ball.CanTouch = true
		end
	end)

	return true
end

-- Private: Setup touch detection
function BallManager._SetupTouchDetection()
	TouchConnection = Ball.Touched:Connect(function(part)
		local character = part.Parent
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		-- GOALKEEPER CATCH: Any body part, immediate stop and possession
		if IsGoalkeeper(character) then
			-- Remove any BodyVelocity if present
			local bodyVel = Ball:FindFirstChildOfClass("BodyVelocity")
			if bodyVel then
				bodyVel:Destroy()
			end

			-- Stop ball completely
			Ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			Ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

			-- Give immediate possession
			TouchCooldown[character] = tick()
			BallManager.SetPossession(character, rootPart)

			-- Notify TeamManager about ball touch (for kickoff)
			if TeamManager and TeamManager.OnBallTouched then
				TeamManager.OnBallTouched()
			end
			return
		end

		-- IMPACT DAMPING: If ball is loose and hits a player, reduce its speed
		if not CurrentOwnerCharacter then
			-- Reduce velocity on impact with ANY part of the character
			-- This simulates the ball "losing energy" when hitting a player's body
			local velocity = Ball.AssemblyLinearVelocity
			if velocity.Magnitude > 2 then
				Ball.AssemblyLinearVelocity = velocity * 0.7
				Ball.AssemblyAngularVelocity *= 0.7
			end
		end

		-- NORMAL PLAYERS: Feet only, with speed/cooldown checks
		-- Don't allow attachment if ball is flying or moving fast
		if Ball:FindFirstChildOfClass("BodyVelocity") or Ball.AssemblyLinearVelocity.Magnitude > 20 then
			return
		end

		-- Check if touched by foot or leg 
		if not (part.Name == "Shoes" or part.Name == "Socks") then
			return
		end

		-- Check if can take possession
		if not BallManager.CanTakePossession(character) then
			return
		end

		TouchCooldown[character] = tick()
		BallManager.SetPossession(character, rootPart)

		-- Notify TeamManager about ball touch (for kickoff)
		if TeamManager and TeamManager.OnBallTouched then
			TeamManager.OnBallTouched()
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
		-- Check if ball fell out of world
		if Ball.Position.Y < Settings.Reset_Height then
			BallManager.ResetBallToCenter()
			return
		end

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
