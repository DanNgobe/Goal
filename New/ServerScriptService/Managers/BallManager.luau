--[[
	BallManager.lua
	Server-side authority for ball physics, possession, and kicking.

	Responsibilities:
	- Receive the existing workspace Ball part (not create one)
	- Possession via Ball.Touched — foot/shoe detection + goalkeeper catch
	- HingeConstraint spin axle for dribble (mirrors Goal project pattern)
	- KickBall remote: BodyVelocity impulse, freeze kicker briefly
	- PossessionChanged remote: notifies the owning client (true/false)
	- Ball damping, out-of-bounds reset, player cleanup
	- Exposes Reset(), DetachBall(), GetCurrentOwner(), GetBall()

	Architecture:
	- Ball is a pre-existing Part in Workspace (name: "Ball")
	- GameManager finds it and passes it into Initialize()
	- Server is authority; client never moves the ball directly
]]

local BallManager = {}

-- Services
local Players       = game:GetService("Players")
local Debris        = game:GetService("Debris")
local RunService    = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared
local Utils   = ReplicatedStorage:WaitForChild("Utils")
local Logger  = require(Utils:WaitForChild("Logger")).new("BallManager")
local Config  = require(ReplicatedStorage:WaitForChild("BallConfig"))
local SlotManager = require(script.Parent.SlotManager)

-- ── Private State ─────────────────────────────────────────────────────────────
local Ball                  = nil   -- The workspace Ball Part
local FieldCenter           = nil   -- Vector3 center of pitch
local CurrentOwnerCharacter = nil   -- Character (player or NPC) with possession
local LastKickerCharacter   = nil   -- For goal celebration tracking
local OwnershipStart        = 0
local TouchCooldown         = {}    -- [character] = tick()

-- Constraints for dribble attachment
local BallAxle              = nil   -- Invisible part welded to character
local BallAttachment        = nil   -- WeldConstraint holding axle to character
local BallSpinner           = nil   -- HingeConstraint for ball spin
local BallSpinnerAttachment = nil   -- Attachment on the ball for HingeConstraint

-- Heartbeat / touch connections
local HeartbeatConnection   = nil
local TouchConnection       = nil

-- Remotes
local PossessionChanged     = nil   -- RemoteEvent: server -> owning client

-- Goalkeeper constraints
local GoalkeeperAlignPos   = nil
local GoalkeeperAlignOri   = nil
local GoalkeeperBallAttach = nil
local GoalkeeperBoneAttach = nil

-- External callback (for AI/NPCs)
local PossessionChangedCallback = nil

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Roblox doesn't have a TeamManager in Football_Game yet for GK, so we stub
local function IsGoalkeeper(character)
	return SlotManager and SlotManager.IsGoalkeeper(character)
end

-- ── Attachment ────────────────────────────────────────────────────────────────

local function _CleanBallConstraints()
	if BallAttachment        then BallAttachment:Destroy();        BallAttachment        = nil end
	if BallSpinner           then BallSpinner:Destroy();           BallSpinner           = nil end
	if BallAxle              then BallAxle:Destroy();              BallAxle              = nil end
	if BallSpinnerAttachment then BallSpinnerAttachment:Destroy(); BallSpinnerAttachment = nil end

	if GoalkeeperAlignPos   then GoalkeeperAlignPos:Destroy();   GoalkeeperAlignPos   = nil end
	if GoalkeeperAlignOri   then GoalkeeperAlignOri:Destroy();   GoalkeeperAlignOri   = nil end
	if GoalkeeperBallAttach then GoalkeeperBallAttach:Destroy(); GoalkeeperBallAttach = nil end
	if GoalkeeperBoneAttach then GoalkeeperBoneAttach:Destroy(); GoalkeeperBoneAttach = nil end

	-- Bulletproof: destroy any residual/orphaned attachments or constraints on the ball to prevent memory/physics leaks
	if Ball then
		for _, child in ipairs(Ball:GetChildren()) do
			if child.Name == "GK_BallAttach" or child.Name == "GK_BoneAttach" or child:IsA("AlignPosition") or child:IsA("AlignOrientation") or child.Name == "BallAttachment" then
				pcall(function() child:Destroy() end)
			end
		end
	end
end

local function _DetachBall()
	_CleanBallConstraints()

	if Ball then
		Ball.CanCollide = true
		Ball.Massless   = false
		
		-- Force network ownership back to the server so server-applied kick velocities/spins replicate flawlessly
		pcall(function()
			if Ball:IsDescendantOf(workspace) then
				Ball:SetNetworkOwner(nil)
			end
		end)
	end

	local oldOwner = CurrentOwnerCharacter
	CurrentOwnerCharacter = nil

	if oldOwner then
		local player = Players:GetPlayerFromCharacter(oldOwner)
		if player then
			PossessionChanged:FireClient(player, false)
		end
		if PossessionChangedCallback then
			PossessionChangedCallback(oldOwner, false)
		end
	end
end

local function AttachBallToCharacter(character, rootPart)
	-- Clean up any existing attachment first
	_CleanBallConstraints()

	local isGK = IsGoalkeeper(character)

	if isGK then
		-- GOALKEEPER: Advanced constraint attachment to body bone (Hips)
		-- This allows the ball to move perfectly with dive/catch animations
		local hips = character:FindFirstChild("Hips", true) or character:FindFirstChild("LowerTorso", true) or rootPart
		
		Ball.CanCollide = false
		Ball.Massless = true
		
		GoalkeeperBallAttach = Instance.new("Attachment")
		GoalkeeperBallAttach.Name = "GK_BallAttach"
		GoalkeeperBallAttach.Parent = Ball
		
		GoalkeeperBoneAttach = Instance.new("Attachment")
		GoalkeeperBoneAttach.Name = "GK_BoneAttach"
		GoalkeeperBoneAttach.Parent = hips
		-- Offset so it looks like it's being held in front of the gut/hands
		GoalkeeperBoneAttach.CFrame = CFrame.new(0, 0, -1.2)
		
		GoalkeeperAlignPos = Instance.new("AlignPosition")
		GoalkeeperAlignPos.Attachment0 = GoalkeeperBallAttach
		GoalkeeperAlignPos.Attachment1 = GoalkeeperBoneAttach
		GoalkeeperAlignPos.RigidityEnabled = true
		GoalkeeperAlignPos.MaxForce = math.huge
		GoalkeeperAlignPos.Responsiveness = 200
		GoalkeeperAlignPos.Parent = Ball
		
		GoalkeeperAlignOri = Instance.new("AlignOrientation")
		GoalkeeperAlignOri.Attachment0 = GoalkeeperBallAttach
		GoalkeeperAlignOri.Attachment1 = GoalkeeperBoneAttach
		GoalkeeperAlignOri.RigidityEnabled = true
		GoalkeeperAlignOri.MaxTorque = math.huge
		GoalkeeperAlignOri.Responsiveness = 200
		GoalkeeperAlignOri.Parent = Ball
		
		BallAttachment = GoalkeeperAlignPos -- Store for general cleanup
	else
		-- OUTFIELD: Standard foot-level dribble axle with spin
		-- Calculate vertical offset dynamically using the Humanoid's HipHeight (ground to rootPart center)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local verticalOffset = Config.Dribble_VerticalOffset
		if humanoid and humanoid.HipHeight > 0 then
			-- Add 1 stud to raise the ball slightly above ground level
			verticalOffset = -(humanoid.HipHeight + (rootPart.Size.Y / 2)) + 1
		end

		-- Position ball in front of character at foot level
		local offset = rootPart.CFrame.LookVector * Config.Dribble_ForwardOffset
		Ball.CFrame = CFrame.new(
			Vector3.new(rootPart.Position.X, rootPart.Position.Y + verticalOffset, rootPart.Position.Z)
			+ Vector3.new(offset.X, 0, offset.Z)
		)

		-- Invisible axle at ball center, welded to the character's root
		local axle = Instance.new("Part")
		axle.Name         = "BallAxle"
		axle.Size         = Vector3.new(0.5, 0.5, 0.5)
		axle.Transparency = 1
		axle.CanCollide   = false
		axle.Massless     = true
		axle.CFrame       = Ball.CFrame
		axle.Parent       = workspace
		BallAxle = axle

		local axleWeld = Instance.new("WeldConstraint")
		axleWeld.Part0  = axle
		axleWeld.Part1  = rootPart
		axleWeld.Parent = axle
		BallAttachment = axleWeld

		-- Attachments for the HingeConstraint spin effect
		local axleAttachment = Instance.new("Attachment")
		axleAttachment.CFrame  = CFrame.Angles(math.rad(90), 0, 0)
		axleAttachment.Parent  = axle

		local ballAttachment = Instance.new("Attachment")
		ballAttachment.Parent  = Ball
		BallSpinnerAttachment = ballAttachment

		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment0       = axleAttachment
		hinge.Attachment1       = ballAttachment
		hinge.ActuatorType      = Enum.ActuatorType.Motor
		hinge.MotorMaxTorque    = 10000
		hinge.AngularVelocity   = 10
		hinge.Parent            = axle
		BallSpinner = hinge

		Ball.CanCollide = false
		Ball.Massless   = true
	end
end

-- ── Possession ────────────────────────────────────────────────────────────────

function BallManager.SetPossession(character, rootPart)
	if not character or not rootPart then return false end
	if CurrentOwnerCharacter == character then return true end -- Already possess the ball!

	-- Notify old owner they lost the ball
	if CurrentOwnerCharacter and CurrentOwnerCharacter ~= character then
		local oldPlayer = Players:GetPlayerFromCharacter(CurrentOwnerCharacter)
		if oldPlayer then
			PossessionChanged:FireClient(oldPlayer, false)
		end
		if PossessionChangedCallback then
			PossessionChangedCallback(CurrentOwnerCharacter, false)
		end
	end

	CurrentOwnerCharacter = character
	OwnershipStart        = tick()
	
	-- Clear ball momentum immediately so it doesn't drag the NPC
	Ball.AssemblyLinearVelocity  = Vector3.zero
	Ball.AssemblyAngularVelocity = Vector3.zero
	
	AttachBallToCharacter(character, rootPart)

	-- Notify the new owning player
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		PossessionChanged:FireClient(player, true)
	end
	if PossessionChangedCallback then
		PossessionChangedCallback(character, true)
	end

	return true
end

function BallManager.CanTakePossession(character)
	-- Ball moving too fast (freshly kicked)
	if Ball:FindFirstChildOfClass("BodyVelocity")
	or Ball.AssemblyLinearVelocity.Magnitude > Config.Max_Possession_Speed then
		return false
	end

	-- Per-character cooldown
	if TouchCooldown[character] and (tick() - TouchCooldown[character]) < Config.Touch_Cooldown then
		return false
	end

	-- Possession timeout protection
	if CurrentOwnerCharacter and CurrentOwnerCharacter ~= character then
		if IsGoalkeeper(CurrentOwnerCharacter) then return false end
		if (tick() - OwnershipStart) < Config.Possession_Timeout then
			return false
		end
	end

	return true
end

-- ── Kick ──────────────────────────────────────────────────────────────────────

function BallManager.KickBall(character, kickType, power, direction)
	if CurrentOwnerCharacter ~= character then return false end
	if not character then _DetachBall(); return false end

	LastKickerCharacter = character

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart then _DetachBall(); return false end

	power       = math.clamp(power or 1, 0, 1)
	local curve = math.sqrt(power)  -- Square root curve: more responsive at low power

	if not direction or direction.Magnitude < 0.1 then
		direction = rootPart.CFrame.LookVector
	else
		direction = direction.Unit
	end

	local maxPower  = kickType == "Ground" and Config.Ground_Kick_Max or Config.Air_Kick_Max
	local maxHeight = kickType == "Ground" and Config.Ground_Kick_Height or Config.Air_Kick_Height
	local force     = maxPower  * curve * 1.45
	local height    = maxHeight * curve

	-- Detach, then position ball slightly forward to avoid immediate re-touch
	_DetachBall()
	Ball.CFrame = CFrame.new(rootPart.Position + (direction * 3) + Vector3.new(0, -1, 0))
	Ball.AssemblyLinearVelocity  = Vector3.zero
	-- Apply random spin for visual variety
	Ball.AssemblyAngularVelocity = Vector3.new(math.random(-15,15), math.random(-15,15), math.random(-15,15))

	-- Briefly block touch and disable collisions so the ball exits the kicker's body cleanly without friction killing the spin
	Ball.CanTouch = false
	Ball.CanCollide = false
	
	task.delay(0.15, function()
		if Ball and not CurrentOwnerCharacter then
			Ball.CanCollide = true
		end
	end)

	task.delay(Config.Kick_Touch_Block, function()
		if Ball then Ball.CanTouch = true end
	end)

	-- Freeze the kicker's position momentarily (punch-through feel)
	if humanoid then
		local origSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		rootPart.Anchored  = true
		task.delay(Config.Kick_Freeze_Duration, function()
			if humanoid and humanoid.Parent then
				humanoid.WalkSpeed = origSpeed
				rootPart.Anchored  = false
			end
		end)
	end

	-- Apply velocity via BodyVelocity (Debris removes it)
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.one * math.huge
	bv.Velocity = (direction * force) + Vector3.new(0, height, 0)
	bv.Parent   = Ball
	Debris:AddItem(bv, Config.Kick_Velocity_Duration)

	-- Play kick sound if it exists on the ball
	local kickSound = Ball:FindFirstChild("Kick")
	if kickSound then kickSound:Play() end

	Logger:info(character.Name or "NPC",
		string.format("kicked [%s] power=%.2f force=%.0f height=%.0f", kickType, power, force, height))

	return true
end

-- ── Touch Detection ───────────────────────────────────────────────────────────

function BallManager._SetupTouchDetection()
	TouchConnection = Ball.Touched:Connect(function(part)
		local character = part.Parent
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		-- DEBOUNCE: If this character already has possession, ignore touches
		if CurrentOwnerCharacter == character then return end

		-- GOALKEEPER: any body part, immediate catch
		if IsGoalkeeper(character) then
			local bv = Ball:FindFirstChildOfClass("BodyVelocity")
			if bv then bv:Destroy() end
			Ball.AssemblyLinearVelocity  = Vector3.zero
			Ball.AssemblyAngularVelocity = Vector3.zero
			TouchCooldown[character] = tick()
			BallManager.SetPossession(character, rootPart)
			return
		end

		-- IMPACT DAMPING: Reduce speed when loose ball hits a body
		if not CurrentOwnerCharacter then
			local vel = Ball.AssemblyLinearVelocity
			if vel.Magnitude > 2 then
				Ball.AssemblyLinearVelocity  = vel * 0.7
				Ball.AssemblyAngularVelocity = Ball.AssemblyAngularVelocity * 0.7
			end
		end

		-- OUTFIELD: must touch standard R15 foot/leg parts (foot contact only)
		if not (part.Name == "LeftFoot" or part.Name == "RightFoot" or part.Name == "LeftLowerLeg" or part.Name == "RightLowerLeg" or part.Name == "Left Leg" or part.Name == "Right Leg") then
			return
		end

		-- Ball still on BodyVelocity = freshly kicked, skip
		if Ball:FindFirstChildOfClass("BodyVelocity")
		or Ball.AssemblyLinearVelocity.Magnitude > Config.Max_Possession_Speed then
			return
		end

		if not BallManager.CanTakePossession(character) then return end

		TouchCooldown[character] = tick()
		BallManager.SetPossession(character, rootPart)
	end)
end

-- ── Kick Handler ──────────────────────────────────────────────────────────────

function BallManager._SetupKickHandler()
	KickBall.OnServerEvent:Connect(function(player, kickType, power, direction)
		local character = player.Character
		if not character then return end

		-- Requirement 13.1 / 13.2: Verify the requesting player currently owns the ball
		local currentOwner = BallManager.GetCurrentOwner()
		if character ~= currentOwner then
			local ownerName = currentOwner and currentOwner.Name or "none"
			Logger:warn(string.format(
				"KickBall rejected: '%s' does not own the ball (current owner: '%s')",
				player.Name, ownerName
			))
			return
		end

		-- Requirement 13.3: Clamp power to valid range [0, 1]
		power = math.clamp(typeof(power) == "number" and power or 0, 0, 1)

		-- Requirement 13.3: Reject if direction is not a finite, non-zero Vector3.
		-- NaN self-inequality check (n ~= n is true only for NaN) covers corrupted components.
		local dirValid = typeof(direction) == "Vector3"
			and direction.Magnitude > 0
			and direction.X == direction.X
			and direction.Y == direction.Y
			and direction.Z == direction.Z
			and math.abs(direction.X) ~= math.huge
			and math.abs(direction.Y) ~= math.huge
			and math.abs(direction.Z) ~= math.huge

		if not dirValid then
			Logger:warn(string.format(
				"KickBall rejected: invalid direction from '%s'",
				player.Name
			))
			return
		end

		BallManager.KickBall(character, kickType, power, direction)
	end)
end

-- ── Heartbeat ─────────────────────────────────────────────────────────────────

-- Returns true if the ball was reset, signalling the caller to skip further
-- processing for this frame.
local function HandleOutOfBounds()
	if Ball.Position.Y < Config.Reset_Height then
		BallManager.Reset()
		return true
	end
	return false
end

-- Applies velocity damping when the ball is loose (no current owner).
local function HandleLooseBallDamping()
	if not CurrentOwnerCharacter and Ball.AssemblyLinearVelocity.Magnitude > 0.1 then
		Ball.AssemblyLinearVelocity = Ball.AssemblyLinearVelocity * Config.Damping
	end
end

-- Detaches the ball from a dead owner; updates the dribble spin rate for a
-- living owner.
local function HandleOwnerCheck()
	if not CurrentOwnerCharacter then return end

	local hum = CurrentOwnerCharacter:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		_DetachBall()
		return
	end

	if BallSpinner then
		local root = CurrentOwnerCharacter:FindFirstChild("HumanoidRootPart")
		if root then
			BallSpinner.AngularVelocity = root.AssemblyLinearVelocity.Magnitude * Config.Axle_SpinRate
		end
	end
end

function BallManager._SetupHeartbeat()
	HeartbeatConnection = RunService.Heartbeat:Connect(function()
		if not Ball or not Ball.Parent then return end

		if HandleOutOfBounds() then return end
		HandleLooseBallDamping()
		HandleOwnerCheck()
	end)
end

-- ── Player Cleanup ────────────────────────────────────────────────────────────

function BallManager._SetupPlayerCleanup()
	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			if CurrentOwnerCharacter == character then _DetachBall() end
			TouchCooldown[character] = nil
		end
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Called by GameManager passing the workspace Ball part + field center
function BallManager.Initialize(ballPart, fieldCenter)
	if not ballPart then
		Logger:warn("Ball part not provided to BallManager.Initialize!")
		return false
	end

	Ball        = ballPart
	FieldCenter = fieldCenter

	-- Ensure collision group tag exists (Studio must have "Ball" group)
	pcall(function() Ball.CollisionGroup = "Ball" end)

	-- Create Remotes inside existing Events folder
	local events = ReplicatedStorage:WaitForChild("Events")
	local ballEvents = events:FindFirstChild("BallEvents") or Instance.new("Folder")
	ballEvents.Name   = "BallEvents"
	ballEvents.Parent = events

	KickBall = Instance.new("RemoteEvent")
	KickBall.Name   = "KickBall"
	KickBall.Parent = ballEvents

	PossessionChanged = Instance.new("RemoteEvent")
	PossessionChanged.Name   = "PossessionChanged"
	PossessionChanged.Parent = ballEvents

	-- Wire everything up
	BallManager._SetupTouchDetection()
	BallManager._SetupKickHandler()
	BallManager._SetupHeartbeat()
	BallManager._SetupPlayerCleanup()

	Logger:info("BallManager initialized with ball:", Ball.Name)
	return true
end

-- Reset ball to field center (called on goal and match restart)
function BallManager.Reset(spawnCFrame)
	_DetachBall()

	if not Ball then return end
	local center = spawnCFrame or (FieldCenter and CFrame.new(FieldCenter + Vector3.new(0, 5, 0))) or CFrame.new(0, 5, 0)
	Ball.CFrame                  = center
	Ball.AssemblyLinearVelocity  = Vector3.zero
	Ball.AssemblyAngularVelocity = Vector3.zero

	Logger:info("Ball reset to center.")
end

-- Explicit public detach (for MatchManager / round resets)
function BallManager.DetachBall()
	_DetachBall()
end

function BallManager.GetBall()
	return Ball
end

function BallManager.GetCurrentOwner()
	return CurrentOwnerCharacter
end

function BallManager.GetLastKicker()
	return LastKickerCharacter
end

function BallManager.OnPossessionChanged(callback)
	PossessionChangedCallback = callback
end

function BallManager.Cleanup()
	if TouchConnection    then TouchConnection:Disconnect()    end
	if HeartbeatConnection then HeartbeatConnection:Disconnect() end
	_DetachBall()
	Logger:info("BallManager cleaned up.")
end

return BallManager
