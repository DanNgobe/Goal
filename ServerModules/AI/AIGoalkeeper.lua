--[[
	AIGoalkeeper.lua
	Goalkeeper - positioning, rush out, intercept prediction, and save animations.
	
	Features:
	- Positioning along goal line based on ball location
	- Diving to save shots
	- Catching close balls
	- Distribution (throw/kick)
	- Rush out for through balls
	- Smooth rotation to face ball
	- Intercept prediction with anticipation
]]

local AIGoalkeeper = {}

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local AIUtils = require(script.Parent.AIUtils)
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))

-- Local helper for kick animations
local function PlayKickAnimation(npc, direction, power, kickType)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animId = AnimationData.ChooseKickAnimation(npc:FindFirstChild("HumanoidRootPart"), direction, power, kickType)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	local kickAnim = Instance.new("Animation")
	kickAnim.AnimationId = animId
	local track = animator:LoadAnimation(kickAnim)
	track:Play()
	
	-- Play running animation when kick finishes
	track.Ended:Connect(function()
		if humanoid and npc.Parent then
			local runAnim = Instance.new("Animation")
			runAnim.AnimationId = AnimationData.Movement.Running
			local runTrack = animator:LoadAnimation(runAnim)
			runTrack.Looped = false
			runTrack:Play()
		end
	end)
	
	return track
end

-- Injected dependencies
local TeamManager = nil
local BallManager = nil

-- State
local State = {
	LastSaveAttempt = {},
	HasBall = {},
	DistributionDelay = {},
	ActiveGKs = {},
	HeartbeatConnection = nil,
	InterceptMarkers = {},
	RegisteredSlots = {}  -- Track which slots have registered goalkeepers
}

-- Settings
local Settings = {
	-- Positioning
	LateralScale = 0.5,
	LateralClamp = 14,
	WalkSpeed = 22,
	RushSpeed = 28,
	UpdateRate = 0.1,

	-- Rush out
	RushMaxDistHeld = 18,
	RushMaxDistFree = 35,
	InterceptRadius = 3,

	-- Intercept translate
	MaxTranslateDist = 10,
	TranslateSmoothness = 10,

	-- Save animations
	AnimationTriggerDistance = 30,
	AnimationCooldown = 3,
	DiveLateralDistance = 8,
	DiveSpeedThreshold = 60,
	ScoopHeight = 2,
	StandingHeight = 5,
	JumpHeight = 10,

	-- Distribution
	DistributionDelay = 3,
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIGoalkeeper.Initialize(teamManager, ballManager)
	TeamManager = teamManager
	BallManager = ballManager

	-- Start smooth rotation updates
	if State.HeartbeatConnection then
		State.HeartbeatConnection:Disconnect()
	end
	State.HeartbeatConnection = RunService.Heartbeat:Connect(UpdateRotations)

	return TeamManager ~= nil and BallManager ~= nil
end

--------------------------------------------------------------------------------
-- REGISTER GOALKEEPER
--------------------------------------------------------------------------------

function AIGoalkeeper.RegisterGoalkeeper(slot, teamName)
	local npc = slot.NPC
	if not npc or not npc.Parent then return end

	local npcId = tostring(npc)
	
	-- Store slot and team info for heartbeat updates
	State.ActiveGKs[npcId] = {
		npc = npc,
		slot = slot,
		teamName = teamName,
		root = npc:FindFirstChild("HumanoidRootPart"),
		humanoid = npc:FindFirstChildOfClass("Humanoid")
	}
end

--------------------------------------------------------------------------------
-- ANIMATIONS
--------------------------------------------------------------------------------

function LoadAnimations(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local animations = {}
	
	if not humanoid then return animations end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	for name, id in pairs(AnimationData.Goalkeeper) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		track.Looped = false
		animations[name] = track
	end
	
	return animations
end

function StopAllAnimations(animations)
	for _, track in pairs(animations) do
		if track and track.IsPlaying then
			track:Stop()
		end
	end
end

function PlayAnimation(npc, animations, name)
	if not animations or not animations[name] then return false end
	
	local track = animations[name]
	StopAllAnimations(animations)
	
	track:Play()
	
	task.spawn(function()
		local maxTime = math.min(track.Length, 6)
		task.wait(maxTime)
		if track and track.IsPlaying then
			track:Stop()
		end
	end)
	
	return true
end

--------------------------------------------------------------------------------
-- INTERCEPT PREDICTION
--------------------------------------------------------------------------------

function PredictIntercept(ballPos, ballVel, goalPlaneZ)
	if math.abs(ballVel.Z) < 0.1 then
		return nil
	end

	local t = (goalPlaneZ - ballPos.Z) / ballVel.Z
	if t <= 0 then
		return nil
	end

	return ballPos + ballVel * t
end

--------------------------------------------------------------------------------
-- 1. POSITIONING
--------------------------------------------------------------------------------

function CalculateGoalkeeperPosition(homePos, ballPos)
	local lateralOffset = (ballPos.X - homePos.X) * Settings.LateralScale
	lateralOffset = math.clamp(lateralOffset, -Settings.LateralClamp, Settings.LateralClamp)

	return Vector3.new(homePos.X + lateralOffset, homePos.Y, homePos.Z)
end

function MoveToPosition(humanoid, root, targetPos)
	local dist = (targetPos - root.Position).Magnitude
	if dist <= 1 then
		humanoid:MoveTo(root.Position)
	else
		humanoid:MoveTo(targetPos)
	end
end

--------------------------------------------------------------------------------
-- 2. SAVE ANIMATIONS
--------------------------------------------------------------------------------

function TrySave(npc, humanoid, root, animations, interceptPoint, ballVel, homePos, npcId)
	local now = tick()
	local lastSave = State.LastSaveAttempt[npcId] or 0

	-- Cooldown check
	if now - lastSave < Settings.AnimationCooldown then
		return false
	end

	local relative = root.CFrame:PointToObjectSpace(interceptPoint)
	local dx = relative.X
	local dy = interceptPoint.Y - root.Position.Y
	local speed = ballVel.Magnitude

	local saveType = nil

	-- Check for dive based on lateral distance and speed
	if math.abs(dx) > Settings.DiveLateralDistance and speed > Settings.DiveSpeedThreshold then
		if dx < 0 then
			saveType = "Right_Diving_Save"
		else
			saveType = "Left_Diving_Save"
		end
	elseif dy < Settings.ScoopHeight then
		-- Low ball - scoop
		saveType = "Scoop"
	elseif dy < Settings.StandingHeight then
		-- Mid height - standing catch
		saveType = "Standing_Catch"
	elseif dy > Settings.JumpHeight then
		-- High ball - jump catch
		saveType = "Jump_Catch"
	end

	if saveType then
		State.LastSaveAttempt[npcId] = now
		PlayAnimation(npc, animations, saveType)
		return true
	end

	return false
end

--------------------------------------------------------------------------------
-- 3. CATCHING CLOSE BALLS (integrated in TrySave)
--------------------------------------------------------------------------------

-- Catching is handled in TrySave function above

--------------------------------------------------------------------------------
-- 4. DISTRIBUTION (THROW/KICK)
--------------------------------------------------------------------------------

function HandleDistribution(npc, humanoid, root, bodyGyro, teamName, npcId)
	local now = tick()
	local delayStart = State.DistributionDelay[npcId]

	if not delayStart then
		State.DistributionDelay[npcId] = now
		return
	end

	-- Find best teammate to distribute to
	local bestTarget = FindDistributionTarget(npc, root, teamName)
	
	-- MUST look at them first! Start rotating during the delay
	if bestTarget and bodyGyro then
		local dir = (bestTarget.Position - root.Position).Unit
		local flatTarget = Vector3.new(dir.X, 0, dir.Z)
		if flatTarget.Magnitude > 0 then
			bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + flatTarget.Unit)
		end
	end

	if now - delayStart < Settings.DistributionDelay then 
		humanoid:MoveTo(root.Position)
		return
	end

	if bestTarget then
		State.DistributionDelay[npcId] = nil

		-- Final rotation adjustment
		local dir = (bestTarget.Position - root.Position).Unit
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)

		-- Choose distribution method based on distance
		if bestTarget.Distance > 40 then
			-- Long kick
			PlayKickAnimation(npc, dir, 0.9, "Air")
			task.delay(0.4, function()
				if BallManager then
					BallManager.KickBall(npc, "Air", 0.9, dir)
				end
			end)
		else
			-- Throw
			PlayKickAnimation(npc, dir, 0.5, "Ground")
			task.delay(0.4, function()
				if BallManager then
					BallManager.KickBall(npc, "Ground", 0.5, dir)
				end
			end)
		end
	end
end

function FindDistributionTarget(npc, root, teamName)
	if not TeamManager then return nil end

	local slots = TeamManager.GetTeamSlots(teamName)
	local myPos = root.Position
	local bestTarget = nil
	local bestScore = -math.huge

	for _, slot in ipairs(slots) do
		if slot.NPC ~= npc and slot.NPC and slot.NPC.Parent then
			local teammateRoot = slot.NPC:FindFirstChild("HumanoidRootPart")
			if teammateRoot then
				local teammatePos = teammateRoot.Position
				local dist = (teammatePos - myPos).Magnitude

				-- Prefer teammates that are forward and open
				local score = dist * 0.5

				-- Check if relatively clear path
				if not AIUtils.IsPathBlocked(myPos, teammatePos, teamName) then
					score = score + 30
				end

				if score > bestScore then
					bestScore = score
					bestTarget = {Position = teammatePos, Distance = dist}
				end
			end
		end
	end

	return bestTarget
end

--------------------------------------------------------------------------------
-- 5. RUSH OUT FOR THROUGH BALLS
--------------------------------------------------------------------------------

function GetRushDecision(root, homePos, ballPos, ballVel, ballIsHeld, distToBall)
	local distBallToHome = (ballPos - homePos).Magnitude
	local maxDist = ballIsHeld and Settings.RushMaxDistHeld or Settings.RushMaxDistFree

	if distBallToHome > maxDist then
		return "none"
	end

	local keeperTime = distToBall / Settings.RushSpeed

	local toKeeper = root.Position - ballPos
	local awaySpeed = 0
	if toKeeper.Magnitude > 0 then
		awaySpeed = math.max(0, ballVel:Dot(toKeeper.Unit) * -1)
	end

	local ballTime = Settings.InterceptRadius / math.max(awaySpeed, 0.1)

	if keeperTime <= ballTime then
		return "rush"
	else
		return "predict"
	end
end

--------------------------------------------------------------------------------
-- 6. TRANSLATE TO INTERCEPT
--------------------------------------------------------------------------------

function TranslateToIntercept(root, homePos, targetPos)
	if not targetPos then return end

	local currentPos = root.Position

	-- Lock to goal line
	local target = Vector3.new(
		targetPos.X,
		currentPos.Y,
		homePos.Z
	)

	-- Clamp max step
	local delta = target - currentPos
	if delta.Magnitude > Settings.MaxTranslateDist then
		target = currentPos + delta.Unit * Settings.MaxTranslateDist
	end

	-- Smooth move
	local dt = Settings.UpdateRate
	local alpha = 1 - math.exp(-Settings.TranslateSmoothness * dt)
	local newPos = currentPos:Lerp(target, alpha)

	root.CFrame = CFrame.new(newPos, newPos + root.CFrame.LookVector)
end

--------------------------------------------------------------------------------
-- HEARTBEAT UPDATE
--------------------------------------------------------------------------------

function UpdateRotations()
	local ball = workspace:FindFirstChild("Ball")
	if not ball then return end

	-- Check for goalkeeper slot changes and re-register as needed
	if TeamManager then
		for _, teamName in ipairs({"Blue", "Red"}) do
			local slots = TeamManager.GetAISlots(teamName)
			for _, slot in ipairs(slots) do
				if slot.Role == "GK" then
					local slotId = tostring(slot)
					local currentNPC = slot.NPC
					local registeredNPC = State.RegisteredSlots[slotId]
					
					-- If the NPC in the slot has changed, re-register
					if currentNPC and currentNPC.Parent and currentNPC ~= registeredNPC then
						-- Clean up old goalkeeper if it exists
						if registeredNPC then
							local oldNpcId = tostring(registeredNPC)
							State.ActiveGKs[oldNpcId] = nil
						end
						
						-- Register new goalkeeper
						AIGoalkeeper.RegisterGoalkeeper(slot, teamName)
						State.RegisteredSlots[slotId] = currentNPC
					elseif not currentNPC or not currentNPC.Parent then
						-- Slot is empty, clean up
						State.RegisteredSlots[slotId] = nil
						if registeredNPC then
							local oldNpcId = tostring(registeredNPC)
							State.ActiveGKs[oldNpcId] = nil
						end
					end
				end
			end
		end
	end

	for npcId, data in pairs(State.ActiveGKs) do
		-- Skip if NPC is invalid
		if not data.npc or not data.npc.Parent then
			State.ActiveGKs[npcId] = nil
			continue
		end

		local npc = data.npc
		local humanoid = data.humanoid or npc:FindFirstChildOfClass("Humanoid")
		local root = data.root or npc:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root then
			State.ActiveGKs[npcId] = nil
			continue
		end

		-- Setup BodyGyro if not present
		local bodyGyro = root:FindFirstChild("GKBodyGyro")
		if not bodyGyro then
			bodyGyro = Instance.new("BodyGyro")
			bodyGyro.Name = "GKBodyGyro"
			bodyGyro.MaxTorque = Vector3.new(0, 400000, 0)
			bodyGyro.P = 10000
			bodyGyro.D = 500
			bodyGyro.Parent = root
		end

		-- Update goalkeeper with its slot and team data
		if data.slot and data.teamName then
			UpdateGoalkeeperState(npc, humanoid, root, bodyGyro, data.slot, data.teamName, npcId, ball)
		end

		-- Face the ball (unless we have it)
		local hasBall = BallManager and BallManager.IsCharacterOwner(npc) or false
		if not hasBall then
			local targetDir = (ball.Position - root.Position).Unit
			local flatTarget = Vector3.new(targetDir.X, 0, targetDir.Z)
			if flatTarget.Magnitude > 0 then
				flatTarget = flatTarget.Unit
				bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + flatTarget)
			end
		end
	end
end

function UpdateGoalkeeperState(npc, humanoid, root, bodyGyro, slot, teamName, npcId, ball)
	if humanoid.Health <= 0 then return end

	local hasBall = BallManager and BallManager.IsCharacterOwner(npc) or false
	State.HasBall[npcId] = hasBall

	-- If goalkeeper has ball, distribute it
	if hasBall then
		-- Reset distribution delay timer when first acquiring ball
		if not State.DistributionDelay[npcId] then
			State.DistributionDelay[npcId] = tick()
		end
		HandleDistribution(npc, humanoid, root, bodyGyro, teamName, npcId)
		return
	else
		-- Clear distribution delay when ball is lost
		State.DistributionDelay[npcId] = nil
	end

	-- If no ball, stay at home position
	if not ball then
		humanoid.WalkSpeed = Settings.WalkSpeed
		MoveToPosition(humanoid, root, slot.HomePosition)
		return
	end

	-- Load animations for this NPC if not already loaded
	if not State.ActiveGKs[npcId].animations then
		State.ActiveGKs[npcId].animations = LoadAnimations(npc)
	end
	local animations = State.ActiveGKs[npcId].animations

	local ballPos = ball.Position
	local ballVel = ball.AssemblyLinearVelocity
	local ballIsHeld = not ball.CanCollide
	local distToBall = (ballPos - root.Position).Magnitude

	-- Intercept prediction
	local interceptPoint = PredictIntercept(ballPos, ballVel, slot.HomePosition.Z)

	-- Try save animations before anything else
	if interceptPoint and distToBall <= Settings.AnimationTriggerDistance then
		if TrySave(npc, humanoid, root, animations, interceptPoint, ballVel, slot.HomePosition, npcId) then
			return
		end
	end

	-- Decide: Rush out or position normally
	local rushResult = GetRushDecision(root, slot.HomePosition, ballPos, ballVel, ballIsHeld, distToBall)

	if rushResult == "rush" then
		humanoid.WalkSpeed = Settings.RushSpeed
		MoveToPosition(humanoid, root, ballPos)
	elseif rushResult == "predict" and interceptPoint then
		TranslateToIntercept(root, slot.HomePosition, interceptPoint)
		humanoid.WalkSpeed = Settings.WalkSpeed
	else
		humanoid.WalkSpeed = Settings.WalkSpeed
		-- Adjust position laterally based on ball position
		local adjustedPos = CalculateGoalkeeperPosition(slot.HomePosition, ballPos)
		MoveToPosition(humanoid, root, adjustedPos)
	end
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function AIGoalkeeper.Cleanup()
	-- Disconnect rotation updates
	if State.HeartbeatConnection then
		State.HeartbeatConnection:Disconnect()
		State.HeartbeatConnection = nil
	end

	State.LastSaveAttempt = {}
	State.HasBall = {}
	State.DistributionDelay = {}
	State.ActiveGKs = {}
	State.RegisteredSlots = {}
end

return AIGoalkeeper
