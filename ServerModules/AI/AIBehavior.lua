--[[
	AIBehavior.lua
	Field player actions and movement
	- Ball possession (Shoot, Pass, Dribble)
	- Movement with collision avoidance
	- Smooth rotation using Body Gyro
	- Role-based behavior (Chaser, Support, Formation)
]]

local AIBehavior = {}

-- Dependencies
local AIUtils = require(script.Parent.AIUtils)
local AnimationData = require(game:GetService("ReplicatedStorage"):WaitForChild("AnimationData"))

-- Injected dependencies
local TeamManager = nil
local BallManager = nil

-- State
local State = {
	LastPassTime = {},      -- Track pass cooldowns per NPC
	LastBallReceived = {}, -- Track when NPC received the ball
	ActiveNPCs = {},        -- Track active NPCs for rotation updates
	KickingNPCs = {},       -- Track NPCs currently performing kick animations
	HeartbeatConnection = nil
}

-- Configuration
local Config = {
	Speed = {
		Normal = 16,
		Dribble = 12,
		Chase = 20,
		Support = 18,
		Intercept = 18
	},

	Distance = {
		StopDistance = 3,      -- Stop within this distance
		ShootRange = 80,
		PassRange = 70,
		MinimumPass = 8        -- Don't pass to very close teammates
	},

	Awareness = {
		CollisionAvoid = 5,    -- Distance to start avoiding collisions
		PersonalSpace = 3      -- Minimum distance from other players
	},

	FormationWeight = {
		Support = 0.5,
		Formation = 0.6
	},

	PassCooldown = 1.5,
	DribbleDelay = 2.0      -- Time to dribble after receiving ball before passing
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIBehavior.Initialize(teamManager, ballManager)
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
-- HELPER: PLAY KICK ANIMATION
--------------------------------------------------------------------------------

local function PlayKickAnimation(npc, direction, power, kickType)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animId = AnimationData.ChooseKickAnimation(npc:FindFirstChild("HumanoidRootPart"), direction, power, kickType)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	local kickAnim = Instance.new("Animation")
	kickAnim.AnimationId = animId
	local track = animator:LoadAnimation(kickAnim)
	track.Looped = false
	track:Play()
	return track
end

--------------------------------------------------------------------------------
-- MAIN NPC UPDATE
--------------------------------------------------------------------------------

function AIBehavior.UpdateNPC(slot, teamName, role)
	local npc = slot.NPC
	if not npc or not npc.Parent then return end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return end

	-- Skip update if NPC is currently performing a kick animation
	local npcId = tostring(npc)
	-- if State.KickingNPCs[npcId] then return end

	-- Setup BodyGyro for rotation control
	local bodyGyro = root:FindFirstChild("AIBodyGyro")
	if not bodyGyro then
		bodyGyro = Instance.new("BodyGyro")
		bodyGyro.Name = "AIBodyGyro"
		bodyGyro.MaxTorque = Vector3.new(0, 400000, 0)
		bodyGyro.P = 10000
		bodyGyro.D = 500
		bodyGyro.Parent = root
	end

	-- Track this NPC for rotation updates
	local npcId = tostring(npc)
	State.ActiveNPCs[npcId] = {
		npc = npc,
		root = root,
		bodyGyro = bodyGyro,
		teamName = teamName,
		hasBall = BallManager and BallManager.IsCharacterOwner(npc) or false
	}

	local hasBall = State.ActiveNPCs[npcId].hasBall

	if hasBall then
		HandleBallPossession(slot, npc, humanoid, root, teamName)
	else
		HandleRoleBasedBehavior(slot, npc, humanoid, root, teamName, role)
	end
end

--------------------------------------------------------------------------------
-- ROLE-BASED BEHAVIOR
--------------------------------------------------------------------------------

function HandleRoleBasedBehavior(slot, npc, humanoid, root, teamName, role)
	local ball = workspace:FindFirstChild("Ball")
	local ballOwner = BallManager and BallManager.GetCurrentOwner() or nil

	-- Defensive behavior against opponent with ball
	if ballOwner and not AIUtils.IsTeammate(ballOwner, teamName) then
		local ballOwnerRoot = ballOwner:FindFirstChild("HumanoidRootPart")
		if ballOwnerRoot then
			if role == "Chaser" then
				humanoid.WalkSpeed = Config.Speed.Intercept
				MoveWithAvoidance(humanoid, root, ballOwnerRoot.Position, teamName, npc)
				return
			elseif role == "Support" then
				local target = AIUtils.CalculateInterceptPosition(root.Position, slot.HomePosition, ballOwner)
				humanoid.WalkSpeed = Config.Speed.Support
				MoveWithAvoidance(humanoid, root, target, teamName, npc)
				return
			end
		end
	end

	-- Role-based positioning
	if role == "Chaser" and ball then
		humanoid.WalkSpeed = Config.Speed.Chase
		MoveWithAvoidance(humanoid, root, ball.Position, teamName, npc)
	elseif role == "Support" and ball then
		local target = AIUtils.CalculateBlendedPosition(
			root.Position,
			slot.HomePosition,
			ball.Position,
			Config.FormationWeight.Support
		)
		humanoid.WalkSpeed = Config.Speed.Support
		MoveWithAvoidance(humanoid, root, target, teamName, npc)
	else
		local target = slot.HomePosition
		if ball then
			target = AIUtils.CalculateBlendedPosition(
				root.Position,
				slot.HomePosition,
				ball.Position,
				Config.FormationWeight.Formation
			)
		end
		humanoid.WalkSpeed = Config.Speed.Normal
		MoveWithAvoidance(humanoid, root, target, teamName, npc)
	end
end

--------------------------------------------------------------------------------
-- BALL POSSESSION (Shoot, Pass, Dribble)
--------------------------------------------------------------------------------

function HandleBallPossession(slot, npc, humanoid, root, teamName)
	humanoid.WalkSpeed = Config.Speed.Dribble

	local npcId = tostring(npc)
	local now = tick()

	-- Track when ball was received
	if not State.LastBallReceived[npcId] then
		State.LastBallReceived[npcId] = now
	end

	local timeSinceBallReceived = now - State.LastBallReceived[npcId]
	local lastPass = State.LastPassTime[npcId] or 0
	local canPass = (now - lastPass) > Config.PassCooldown

	-- Priority: Shoot → Pass (if dribbled enough) → Dribble
	if TryShoot(slot, npc, root, teamName) then
		State.LastBallReceived[npcId] = nil  -- Reset for next possession
		return
	end

	-- Only allow passing after dribbling for a bit
	if canPass and timeSinceBallReceived > Config.DribbleDelay and TryPass(slot, npc, root, teamName) then
		State.LastPassTime[npcId] = now
		State.LastBallReceived[npcId] = nil  -- Reset for next possession
		return
	end

	DribbleTowardGoal(npc, humanoid, root, teamName)
end

function TryShoot(slot, npc, root, teamName)
	local goalPos = AIUtils.GetOpponentGoalPosition(teamName)
	if not goalPos then return false end

	local dist = (goalPos - root.Position).Magnitude
	if dist > Config.Distance.ShootRange then return false end

	-- Check if shot is blocked by opponents
	if AIUtils.IsPathBlocked(root.Position, goalPos, teamName) then
		return false
	end

	-- Face the goal direction (instantly)
	local dirToGoal = (goalPos - root.Position).Unit

	local power = math.clamp(dist / Config.Distance.ShootRange, 0.5, 1)
	local kickType = dist > 40 and "Air" or "Ground"

	-- Mark NPC as kicking to prevent AI updates during animation
	local npcId = tostring(npc)
	-- State.KickingNPCs[npcId] = true

	local animTrack = PlayKickAnimation(npc, dirToGoal, power, kickType)
	BallManager.KickBall(npc, kickType, power, dirToGoal)
	return true
end

function TryPass(slot, npc, root, teamName)
	local bestTarget = FindBestPassTarget(npc, root, teamName)
	if not bestTarget then return false end

	-- Face the pass target direction (instantly)
	local dir = (bestTarget.Position - root.Position).Unit
	
	local power = math.clamp(bestTarget.Distance / Config.Distance.PassRange, 0.3, 0.8)

	-- Mark NPC as kicking to prevent AI updates during animation
	local npcId = tostring(npc)
	-- State.KickingNPCs[npcId] = true

	local animTrack = PlayKickAnimation(npc, dir, power, "Ground")

	-- Spawn kick in separate thread so it doesn't block
	task.spawn(function()
		if BallManager then
			BallManager.KickBall(npc, "Ground", power, dir)
		end
		-- Wait for animation to finish before clearing kicking state
		if animTrack then
			animTrack.Ended:Wait()
		else
			task.wait(0.8)
		end
		-- State.KickingNPCs[npcId] = nil
	end)

	return true
end

function FindBestPassTarget(npc, root, teamName)
	if not TeamManager then return nil end

	local slots = TeamManager.GetTeamSlots(teamName)
	local myPos = root.Position
	local goalPos = AIUtils.GetOpponentGoalPosition(teamName)
	if not goalPos then return nil end

	local myDistToGoal = (goalPos - myPos).Magnitude
	local bestTarget = nil
	local bestScore = -math.huge

	for _, slot in ipairs(slots) do
		if slot.NPC ~= npc and slot.NPC and slot.NPC.Parent then
			local teammateRoot = slot.NPC:FindFirstChild("HumanoidRootPart")
			local teammateHumanoid = slot.NPC:FindFirstChildOfClass("Humanoid")

			if teammateRoot and teammateHumanoid and teammateHumanoid.Health > 0 then
				local teammatePos = teammateRoot.Position
				local dist = (teammatePos - myPos).Magnitude

				-- Must be in pass range and not too close
				if dist > Config.Distance.MinimumPass and dist < Config.Distance.PassRange then
					-- Check if pass is blocked by opponents
					if AIUtils.IsPathBlocked(myPos, teammatePos, teamName) then
						continue
					end

					local teammateDistToGoal = (goalPos - teammatePos).Magnitude
					local progressAmount = myDistToGoal - teammateDistToGoal

					-- Score based on progression
					local score = progressAmount * 2 - (dist * 0.15)

					if teammateDistToGoal < 40 then
						score = score + 20
					elseif teammateDistToGoal < 60 then
						score = score + 10
					end

					if progressAmount > 15 then
						score = score + 8
					end

					if score > bestScore then
						bestScore = score
						bestTarget = {Position = teammatePos, Distance = dist}
					end
				end
			end
		end
	end

	return bestTarget
end

function DribbleTowardGoal(npc, humanoid, root, teamName)
	local goalPos = AIUtils.GetOpponentGoalPosition(teamName)
	if not goalPos then
		humanoid:MoveTo(root.Position)
		return
	end

	local dir = (goalPos - root.Position).Unit
	local target = root.Position + (dir * 20)
	MoveWithAvoidance(humanoid, root, target, teamName, npc)
end

--------------------------------------------------------------------------------
-- MOVEMENT WITH COLLISION AVOIDANCE
--------------------------------------------------------------------------------

function MoveWithAvoidance(humanoid, root, targetPos, teamName, npc)
	local currentPos = root.Position
	local dist = (targetPos - currentPos).Magnitude

	-- Stop if close enough
	if dist <= Config.Distance.StopDistance then
		humanoid:MoveTo(currentPos)
		return
	end

	-- Check for nearby players to avoid
	local nearbyTeammates = AIUtils.GetNearbyPlayers(currentPos, teamName, Config.Awareness.CollisionAvoid)
	local nearbyOpponents = AIUtils.GetNearbyPlayers(currentPos, AIUtils.GetOppositeTeam(teamName), Config.Awareness.CollisionAvoid)

	local avoidanceVector = Vector3.new()

	-- Add avoidance from teammates
	for _, teammate in ipairs(nearbyTeammates) do
		if teammate.Character ~= npc and teammate.Distance < Config.Awareness.PersonalSpace and teammate.Distance > 0.1 then
			local away = (currentPos - teammate.Position).Unit
			local strength = (Config.Awareness.PersonalSpace - teammate.Distance) / Config.Awareness.PersonalSpace
			avoidanceVector = avoidanceVector + (away * strength * 5)
		end
	end

	-- Add avoidance from opponents
	for _, opponent in ipairs(nearbyOpponents) do
		if opponent.Distance < Config.Awareness.PersonalSpace and opponent.Distance > 0.1 then
			local away = (currentPos - opponent.Position).Unit
			local strength = (Config.Awareness.PersonalSpace - opponent.Distance) / Config.Awareness.PersonalSpace
			avoidanceVector = avoidanceVector + (away * strength * 3)
		end
	end

	-- Blend target direction with avoidance
	local targetDir = (targetPos - currentPos).Unit
	local finalDir = (targetDir + avoidanceVector).Unit

	-- Always-ahead target: extend target by 15 studs to keep NPCs moving smoothly
	-- They never actually "reach" the target, preventing stop-and-go jitter
	local extendDistance = 15
	local finalTarget = currentPos + (finalDir * math.min(dist + extendDistance, 35))

	humanoid:MoveTo(finalTarget)
end

--------------------------------------------------------------------------------
-- SMOOTH ROTATION (HEARTBEAT UPDATE)
--------------------------------------------------------------------------------

function UpdateRotations()
	local ball = workspace:FindFirstChild("Ball")
	if not ball then return end

	for npcId, data in pairs(State.ActiveNPCs) do
		if data.npc and data.npc.Parent and data.root and data.root.Parent and data.bodyGyro and data.bodyGyro.Parent then
			local targetDir

			if data.hasBall then
				-- Face toward opponent's goal when dribbling
				local goalPos = AIUtils.GetOpponentGoalPosition(data.teamName)
				if goalPos then
					targetDir = (goalPos - data.root.Position).Unit
				end
			else
				-- Face the ball
				targetDir = (ball.Position - data.root.Position).Unit
			end

			if targetDir then
				-- Set BodyGyro target CFrame
				local flatTarget = Vector3.new(targetDir.X, 0, targetDir.Z)
				if flatTarget.Magnitude > 0 then
					flatTarget = flatTarget.Unit
					data.bodyGyro.CFrame = CFrame.lookAt(data.root.Position, data.root.Position + flatTarget)
				end
			end
		else
			-- Clean up invalid NPCs
			State.ActiveNPCs[npcId] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function AIBehavior.Cleanup()
	-- Disconnect rotation updates
	if State.HeartbeatConnection then
		State.HeartbeatConnection:Disconnect()
		State.HeartbeatConnection = nil
	end

	-- Clear state
	State.LastPassTime = {}
	State.LastBallReceived = {}
	State.ActiveNPCs = {}
	-- State.KickingNPCs = {}
end

return AIBehavior
