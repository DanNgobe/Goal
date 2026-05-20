--[[
	AIGoalkeeper.lua
	Goalkeeper logic for Football_Game
	- Adapted for SlotManager and modern Logger
]]

local AIGoalkeeper = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("AIGoalkeeper")

-- Modules
local AIUtils = require(script.Parent.Parent:WaitForChild("Utils"):WaitForChild("AIUtils"))
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))

-- Injected dependencies
local SlotManager = nil
local BallManager = nil

-- State
local State = {
	LastSaveAttempt = {},
	DistributionDelay = {},
	ActiveGKs = {},
	RegisteredSlots = {},
	WasHoldingBall = {}
}

-- Settings
local Settings = {
	LateralScale = 0.8,
	LateralClamp = 15,
	WalkSpeed = 22,
	RushSpeed = 26,
	RushMaxDistFree = 45,
	AnimationTriggerDistance = 35,
	AnimationCooldown = 2.5,
	DistributionDelay = 1.0, 
	DiveLateralDistance = 8,
	DiveSpeedThreshold = 25,
	ScoopHeight = 2.5,
	StandingHeight = 5.5,
	JumpHeight = 10,
	TranslateSmoothness = 4,
}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function LoadAnimations(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local tracks = {}
	if not humanoid then return tracks end
	
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	
	for name, id in pairs(AnimationData.Goalkeeper) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		tracks[name] = animator:LoadAnimation(anim)
	end
	return tracks
end

local function PlayKickAnimation(npc, direction, power, kickType)
	local npcId = tostring(npc)
	local tracks = State.ActiveGKs[npcId] and State.ActiveGKs[npcId].animations
	
	if tracks and tracks.Throw then
		tracks.Throw:Play()
		return tracks.Throw
	end

	-- Fallback to standard choose kick logic if specific GK throw isn't used
	local success, animId = pcall(function() 
		return AnimationData.ChooseKickAnimation(npc:FindFirstChild("HumanoidRootPart"), direction, power, kickType) 
	end)
	
	if not success then return nil end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	track:Play()
	return track
end

local function StopAllGoalkeeperAnimations(npcId)
	local data = State.ActiveGKs[npcId]
	if data and data.animations then
		for _, track in pairs(data.animations) do
			if track.IsPlaying then track:Stop(0.1) end
		end
	end
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIGoalkeeper.Initialize(slotManager, ballManager)
	SlotManager = slotManager
	BallManager = ballManager

	return SlotManager ~= nil and BallManager ~= nil
end

--------------------------------------------------------------------------------
-- REGISTER
--------------------------------------------------------------------------------

function AIGoalkeeper.RegisterGoalkeeper(slot, teamName)
	local npc = slot.Model
	if not npc or not npc.Parent then return end

	local npcId = tostring(npc)
	State.ActiveGKs[npcId] = {
		npc = npc,
		slot = slot,
		teamName = teamName,
		root = npc:FindFirstChild("HumanoidRootPart"),
		humanoid = npc:FindFirstChildOfClass("Humanoid"),
		animations = LoadAnimations(npc)
	}
	Logger:info(string.format("Registered Goalkeeper: %s (%s)", npc.Name, teamName))
end

--------------------------------------------------------------------------------
-- POSITIONING & MOVEMENT
--------------------------------------------------------------------------------

function PredictIntercept(ballPos, ballVel, goalZ)
	if math.abs(ballVel.Z) < 0.1 then return nil end
	local t = (goalZ - ballPos.Z) / ballVel.Z
	if t <= 0 then return nil end
	return ballPos + ballVel * t
end

function TrySave(npc, root, animations, interceptPoint, ballVel, npcId)
	local now = tick()
	local lastSave = State.LastSaveAttempt[npcId] or 0
	if now - lastSave < Settings.AnimationCooldown then return false end

	local rel = root.CFrame:PointToObjectSpace(interceptPoint)
	local dy = interceptPoint.Y - root.Position.Y
	local speed = ballVel.Magnitude
	
	local saveType = nil
	if math.abs(rel.X) > Settings.DiveLateralDistance and speed > Settings.DiveSpeedThreshold then
		saveType = rel.X < 0 and "Right_Diving_Save" or "Left_Diving_Save"
	elseif dy < Settings.ScoopHeight then
		saveType = "Scoop"
	elseif dy < Settings.StandingHeight then
		saveType = "Standing_Catch"
	elseif dy > Settings.JumpHeight then
		saveType = "Jump_Catch"
	end

	if saveType and animations[saveType] then
		State.LastSaveAttempt[npcId] = now
		animations[saveType]:Play()
		Logger:info(string.format("%s attempted save: %s", npc.Name, saveType))
		return true
	end
	return false
end

function TranslateToIntercept(root, homePos, targetPos)
	local target = Vector3.new(targetPos.X, root.Position.Y, homePos.Z)
	local alpha = 1 - math.exp(-Settings.TranslateSmoothness * 0.1)
	root.CFrame = root.CFrame:Lerp(CFrame.new(target, target + root.CFrame.LookVector), alpha)
end

function CalculateGKPosition(homePos, ballPos)
	local lateralOffset = (ballPos.X - homePos.X) * Settings.LateralScale
	lateralOffset = math.clamp(lateralOffset, -Settings.LateralClamp, Settings.LateralClamp)
	return Vector3.new(homePos.X + lateralOffset, homePos.Y, homePos.Z)
end

function MoveToPosition(humanoid, root, targetPos)
	local dist = (targetPos - root.Position).Magnitude
	if dist <= 0.8 then
		humanoid:MoveTo(root.Position)
	else
		humanoid:MoveTo(targetPos)
	end
end

--------------------------------------------------------------------------------
-- HEARTBEAT UPDATE
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- MAIN UPDATE (Called by AIController)
--------------------------------------------------------------------------------

function AIGoalkeeper.Update()
	local ball = workspace:FindFirstChild("Ball")
	if not (ball and SlotManager) then return end

	-- Cleanup & Re-register check
	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		local slots = SlotManager.GetTeamSlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.Role == "GK" and slot.IsAI then
				local slotId = tostring(slot)
				local currentModel = slot.Model
				if currentModel and currentModel.Parent and currentModel ~= State.RegisteredSlots[slotId] then
					AIGoalkeeper.RegisterGoalkeeper(slot, teamName)
					State.RegisteredSlots[slotId] = currentModel
				end
			end
		end
	end

	for npcId, data in pairs(State.ActiveGKs) do
		if not (data.npc and data.npc.Parent) then
			State.ActiveGKs[npcId] = nil
			continue
		end

		local npc = data.npc
		local humanoid = data.humanoid or npc:FindFirstChildOfClass("Humanoid")
		local root = data.root or npc:FindFirstChild("HumanoidRootPart")

		if not (humanoid and root) then
			State.ActiveGKs[npcId] = nil
			continue
		end

		-- Use AlignOrientation for smooth ball tracking
		humanoid.AutoRotate = false
		local rootAttachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
		if not rootAttachment then
			rootAttachment = Instance.new("Attachment")
			rootAttachment.Name = "RootAttachment"
			rootAttachment.Parent = root
		end

		local alignOrient = root:FindFirstChild("GKAlignOrient")
		if not alignOrient then
			alignOrient = Instance.new("AlignOrientation")
			alignOrient.Name = "GKAlignOrient"
			alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
			alignOrient.Attachment0 = rootAttachment
			alignOrient.MaxTorque = 400000
			alignOrient.Responsiveness = 30
			alignOrient.Parent = root
		end

		UpdateGoalkeeperState(npc, humanoid, root, alignOrient, data.slot, data.teamName, npcId, ball)
	end
end

function UpdateGoalkeeperState(npc, humanoid, root, alignOrient, slot, teamName, npcId, ball)
	if humanoid.Health <= 0 then return end

	local hasBall = BallManager and (BallManager.GetCurrentOwner() == npc) or false

	if hasBall then
		-- Ensure we aren't still playing a diving save animation while holding the ball
		if not State.WasHoldingBall[npcId] then
			StopAllGoalkeeperAnimations(npcId)
		end
		State.WasHoldingBall[npcId] = true
		HandleDistribution(npc, humanoid, root, alignOrient, teamName, npcId)
		return
	end

	-- Cleanup when ball is released
	if State.WasHoldingBall[npcId] then
		State.WasHoldingBall[npcId] = false
		State.DistributionDelay[npcId] = nil
		StopAllGoalkeeperAnimations(npcId)
	end

	if not ball then
		humanoid.WalkSpeed = Settings.WalkSpeed
		local target = slot.HomePosition or root.Position
		MoveToPosition(humanoid, root, target)
		return
	end

	local ballPos = ball.Position
	local ballVel = ball.AssemblyLinearVelocity
	local distToBall = (ballPos - root.Position).Magnitude
	
	local homePos = slot.HomePosition or root.Position
	local interceptPoint = PredictIntercept(ballPos, ballVel, homePos.Z)
	local animations = State.ActiveGKs[npcId].animations

	-- 1. Try Save Animations
	if interceptPoint and distToBall <= Settings.AnimationTriggerDistance then
		if TrySave(npc, root, animations, interceptPoint, ballVel, npcId) then
			return
		end
	end

	-- 2. Decide: Rush out, Predict Translate, or position
	local distBallToHome = (ballPos - homePos).Magnitude
	
	if distBallToHome < Settings.RushMaxDistFree then
		-- Rush out
		humanoid.WalkSpeed = Settings.RushSpeed
		MoveToPosition(humanoid, root, ballPos)
	elseif interceptPoint and math.abs(interceptPoint.X - homePos.X) < Settings.LateralClamp * 1.5 then
		-- Translate to intercept
		TranslateToIntercept(root, homePos, interceptPoint)
		humanoid.WalkSpeed = Settings.WalkSpeed
	else
		humanoid.WalkSpeed = Settings.WalkSpeed
		local adjustedPos = CalculateGKPosition(homePos, ballPos)
		MoveToPosition(humanoid, root, adjustedPos)
	end

	-- Update Orientation
	if alignOrient then
		local targetDir = (ballPos - root.Position).Unit
		local flat = Vector3.new(targetDir.X, 0, targetDir.Z)
		if flat.Magnitude > 0 then
			alignOrient.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
		end
	end
end

function HandleDistribution(npc, humanoid, root, alignOrient, teamName, npcId)
	local now = tick()
	local delayStart = State.DistributionDelay[npcId]

	if not delayStart then
		State.DistributionDelay[npcId] = now
		return
	end

	if now - delayStart < Settings.DistributionDelay then
		humanoid:MoveTo(root.Position)
		return
	end

	-- Simple distribution: kick forward
	State.DistributionDelay[npcId] = nil
	local goalPos = AIUtils.GetOpponentGoalPosition(teamName)
	if goalPos then
		local dir = (goalPos - root.Position).Unit
		PlayKickAnimation(npc, dir, 0.8, "Air")
		task.delay(0.4, function()
			if BallManager then BallManager.KickBall(npc, "Air", 0.8, dir) end
		end)
	end
end

function AIGoalkeeper.Cleanup()
	State.ActiveGKs = {}
	State.RegisteredSlots = {}
	State.DistributionDelay = {}
end

return AIGoalkeeper
