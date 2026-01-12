--[[
	AIGoalkeeper.lua
	Goalkeeper-specific behavior
	- Positioning along goal line based on ball location
	- Diving to save shots
	- Catching close balls
	- Distribution (throw/kick)
	- Rush out for through balls
	- Decision making (stay/rush/distribute)
]]

local AIGoalkeeper = {}

-- Dependencies
local AIUtils = require(script.Parent.AIUtils)
local AnimationData = require(game.ReplicatedStorage.AnimationData)

-- Injected dependencies
local TeamManager = nil
local BallManager = nil

-- State
local State = {
	LastSaveAttempt = {},
	HasBall = {},
	LastDistribution = {},
	ActiveGKs = {},
	HeartbeatConnection = nil
}

-- Configuration
local Config = {
	Positioning = {
		-- Positioning now uses defensive formation HomePosition
	},

	Actions = {
		DiveRange = 20,          -- Max distance to attempt dive (react early)
		CatchRange = 12,         -- Max distance to catch
		ScoopRange = 8,          -- Max distance to scoop
		RushOutDistance = 25,    -- Distance to consider rushing out
		RushOutSpeed = 22
	},

	Timing = {
		SaveCooldown = 0.3,      -- Time between save attempts (faster reaction)
		DistributionDelay = 1.5  -- Time to hold ball before distributing
	},

	Speed = {
		Normal = 22,
		Positioning = 22
	}
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
	State.HeartbeatConnection = game:GetService("RunService").Heartbeat:Connect(UpdateRotations)

	return TeamManager ~= nil and BallManager ~= nil
end

--------------------------------------------------------------------------------
-- MAIN GOALKEEPER UPDATE
--------------------------------------------------------------------------------

function AIGoalkeeper.UpdateGoalkeeper(slot, teamName)
	local npc = slot.NPC
	if not npc or not npc.Parent then return end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return end

	-- Setup BodyGyro for rotation control
	local bodyGyro = root:FindFirstChild("GKBodyGyro")
	if not bodyGyro then
		bodyGyro = Instance.new("BodyGyro")
		bodyGyro.Name = "GKBodyGyro"
		bodyGyro.MaxTorque = Vector3.new(0, 400000, 0)
		bodyGyro.P = 10000
		bodyGyro.D = 500
		bodyGyro.Parent = root
	end

	local npcId = tostring(npc)
	local ball = workspace:FindFirstChild("Ball")
	local hasBall = BallManager and BallManager.IsCharacterOwner(npc) or false
	State.HasBall[npcId] = hasBall

	-- Track this GK for rotation updates
	State.ActiveGKs[npcId] = {
		npc = npc,
		root = root,
		bodyGyro = bodyGyro,
		hasBall = hasBall
	}

	-- If goalkeeper has ball, distribute it
	if hasBall then
		HandleDistribution(npc, humanoid, root, teamName, npcId)
		return
	end

	-- If no ball, stay at home position
	if not ball then
		humanoid.WalkSpeed = Config.Speed.Normal
		MoveToPosition(humanoid, root, slot.HomePosition)
		return
	end

	-- Decision making: Rush out or position normally
	local myGoalPos = AIUtils.GetOwnGoalPosition(teamName)
	if not myGoalPos then
		MoveToPosition(humanoid, root, slot.HomePosition)
		return
	end

	local ballPos = ball.Position
	local distToBall = (ballPos - root.Position).Magnitude

	-- Try to save/catch if ball is close
	if distToBall <= Config.Actions.DiveRange then
		if TrySave(npc, humanoid, root, ball, npcId) then
			return
		end
	end

	-- Decide: Rush out or position at home with lateral adjustment
	if ShouldRushOut(root, slot.HomePosition, ballPos, teamName) then
		humanoid.WalkSpeed = Config.Actions.RushOutSpeed
		MoveToPosition(humanoid, root, ballPos)
	else
		humanoid.WalkSpeed = Config.Speed.Positioning
		-- Adjust position laterally based on ball position
		local adjustedPos = CalculateGoalkeeperPosition(slot.HomePosition, ballPos)
		MoveToPosition(humanoid, root, adjustedPos)
	end
end

--------------------------------------------------------------------------------
-- 1. POSITIONING
--------------------------------------------------------------------------------

-- Calculate goalkeeper position with lateral adjustment based on ball
function CalculateGoalkeeperPosition(homePos, ballPos)
	-- Get lateral offset (X-axis movement left/right)
	local lateralOffset = (ballPos.X - homePos.X) * 0.5 -- 50% of ball's lateral position

	-- Clamp to prevent going too far (goal is ~33 wide, so ±16 from center)
	lateralOffset = math.clamp(lateralOffset, -14, 14)

	-- Return home position with lateral adjustment
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
-- 2. DIVING TO SAVE SHOTS
--------------------------------------------------------------------------------

function TrySave(npc, humanoid, root, ball, npcId)
	local now = tick()
	local lastSave = State.LastSaveAttempt[npcId] or 0

	-- Cooldown check
	if now - lastSave < Config.Timing.SaveCooldown then
		return false
	end

	local ballPos = ball.Position
	local distToBall = (ballPos - root.Position).Magnitude

	-- Check if ball is moving towards goalkeeper (velocity check)
	local ballVelocity = ball.AssemblyLinearVelocity
	if ballVelocity.Magnitude < 15 then
		-- Ball is too slow, don't attempt dramatic saves
		return false
	end

	-- Check if ball is moving towards us (more lenient angle)
	local ballToGK = (root.Position - ballPos).Unit
	local velocityDot = ballToGK:Dot(ballVelocity.Unit)
	if velocityDot < 0.1 then
		-- Ball not moving towards us
		return false
	end

	-- Determine save type based on distance and height
	-- Character height ~11, goal height ~15
	local heightDiff = ballPos.Y - root.Position.Y
	local saveType = nil
	local animId = nil

	if distToBall <= Config.Actions.ScoopRange and heightDiff < 2 then
		-- Scoop low balls (at feet or ground)
		saveType = "Scoop"
		animId = AnimationData.Goalkeeper.Scoop
	elseif distToBall <= Config.Actions.CatchRange then
		if heightDiff > 5 then
			-- Jump to catch high balls (above head height)
			saveType = "JumpCatch"
			animId = AnimationData.Goalkeeper.Jump_Catch
		else
			-- Standing catch for chest/waist height
			saveType = "StandingCatch"
			animId = AnimationData.Goalkeeper.Standing_Catch
		end
	elseif distToBall <= Config.Actions.DiveRange then
		-- Dive left or right
		local dirToBall = (ballPos - root.Position).Unit
		local characterRight = root.CFrame.RightVector
		local dotRight = characterRight:Dot(dirToBall)

		if dotRight > 0 then
			saveType = "DiveRight"
			animId = AnimationData.Goalkeeper.Right_Diving_Save
		else
			saveType = "DiveLeft"
			animId = AnimationData.Goalkeeper.Left_Diving_Save
		end
	end

	if saveType and animId then
		State.LastSaveAttempt[npcId] = now
		PlayGoalkeeperAnimation(npc, humanoid, root, animId)

		-- Attempt to catch the ball
		task.delay(0.2, function()
			if ball and ball.Parent and BallManager then
				local currentDist = (ball.Position - root.Position).Magnitude
				if currentDist <= Config.Actions.CatchRange then
					BallManager.SetOwner(npc)
				end
			end
		end)

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

function HandleDistribution(npc, humanoid, root, teamName, npcId)
	local now = tick()
	local lastDist = State.LastDistribution[npcId] or now

	-- Wait a bit before distributing
	if now - lastDist < Config.Timing.DistributionDelay then
		humanoid:MoveTo(root.Position)
		return
	end

	-- Find best teammate to distribute to
	local bestTarget = FindDistributionTarget(npc, root, teamName)

	if bestTarget then
		State.LastDistribution[npcId] = now

		-- Face the target
		local dir = (bestTarget.Position - root.Position).Unit
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)

		-- Choose distribution method based on distance
		if bestTarget.Distance > 40 then
			-- Long kick
			PlayGoalkeeperAnimation(npc, humanoid, root, AnimationData.Goalkeeper.Place_And_Kick)
			task.delay(0.5, function()
				if BallManager then
					BallManager.KickBall(npc, "Air", 0.9, dir)
				end
			end)
		else
			-- Throw
			PlayGoalkeeperAnimation(npc, humanoid, root, AnimationData.Goalkeeper.Throw)
			task.delay(0.3, function()
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

function ShouldRushOut(root, homePos, ballPos, teamName)
	local distToHome = (ballPos - homePos).Magnitude
	local distToGK = (ballPos - root.Position).Magnitude

	-- Only rush if ball is:
	-- 1. Within rush distance from home position
	-- 2. Closer to goalkeeper than to home
	-- 3. Ball owner is opponent or no owner
	local ballOwner = BallManager and BallManager.GetCurrentOwner() or nil
	local isOpponentBall = ballOwner and not AIUtils.IsTeammate(ballOwner, teamName)

	if distToHome < Config.Actions.RushOutDistance and
		distToGK < distToHome * 0.8 and
		(not ballOwner or isOpponentBall) then
		return true
	end

	return false
end

--------------------------------------------------------------------------------
-- 6. DECISION MAKING (integrated in UpdateGoalkeeper)
--------------------------------------------------------------------------------

-- Decision making is handled in the main UpdateGoalkeeper function

--------------------------------------------------------------------------------
-- SMOOTH ROTATION (HEARTBEAT UPDATE)
--------------------------------------------------------------------------------

function UpdateRotations()
	local ball = workspace:FindFirstChild("Ball")
	if not ball then return end

	for npcId, data in pairs(State.ActiveGKs) do
		if data.npc and data.npc.Parent and data.root and data.root.Parent and data.bodyGyro and data.bodyGyro.Parent then
			-- Always face the ball (unless we have it)
			if not data.hasBall then
				local targetDir = (ball.Position - data.root.Position).Unit
				local flatTarget = Vector3.new(targetDir.X, 0, targetDir.Z)
				if flatTarget.Magnitude > 0 then
					flatTarget = flatTarget.Unit
					data.bodyGyro.CFrame = CFrame.lookAt(data.root.Position, data.root.Position + flatTarget)
				end
			end
		else
			-- Clean up invalid GKs
			State.ActiveGKs[npcId] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- ANIMATION HELPER
--------------------------------------------------------------------------------

function PlayGoalkeeperAnimation(npc, humanoid, root, animId)
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	root.Anchored = true

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animId
	local animTrack = animator:LoadAnimation(animation)

	-- Ensure animation doesn't loop
	animTrack.Looped = false
	animTrack:Play()

	task.spawn(function()
		task.wait(animTrack.Length)
		if animTrack and animTrack.IsPlaying then
			animTrack:Stop()
		end
		if root and humanoid then
			root.Anchored = false
			humanoid.WalkSpeed = originalWalkSpeed
		end
		animation:Destroy()
	end)
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
	State.LastDistribution = {}
	State.ActiveGKs = {}
end

return AIGoalkeeper
