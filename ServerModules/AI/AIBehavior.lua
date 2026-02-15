--[[
	AIBehavior.lua
	Field player actions and movement
	- Ball possession (Shoot, Pass, Dribble)
	- Movement with collision avoidance and overtaking
	- Smooth rotation using Body Gyro
	- Role-based behavior (Chaser, Support, Formation)
	- Stamina system for sprinting
	- Improved passing with air passes
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
	Stamina = {},           -- Track stamina per NPC
	HeartbeatConnection = nil
}

-- Configuration
local Config = {
	Speed = {
		Normal = 16,
		Dribble = 18,
		Chase = 20,
		Sprint = 24,        -- NEW: Sprint speed
		Support = 18,
		Intercept = 18
	},

	Distance = {
		StopDistance = 3,      -- Stop within this distance
		ShootRange = 80,
		PassRange = 70,
		MinimumPass = 8,       -- Don't pass to very close teammates
		AirPassMinimum = 20,   -- NEW: Minimum distance for air passes
		OvertakeDistance = 8   -- NEW: Distance at which to attempt overtaking
	},

	Awareness = {
		CollisionAvoid = 5,    -- Distance to start avoiding collisions
		PersonalSpace = 3,     -- Minimum distance from other players
		OvertakeRadius = 6     -- NEW: Radius to check for overtaking opportunities
	},

	FormationWeight = {
		Support = 0.5,
		Formation = 0.6
	},

	Stamina = {
		Max = 100,
		SprintDrain = 15,      -- Stamina per second while sprinting
		RecoveryRate = 25,     -- Stamina per second while not sprinting
		MinimumToSprint = 20,  -- Minimum stamina required to start sprinting
		SprintThreshold = 30   -- Stop sprinting when stamina drops below this
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
-- STAMINA SYSTEM
--------------------------------------------------------------------------------

local function InitializeStamina(npcId)
	if not State.Stamina[npcId] then
		State.Stamina[npcId] = {
			Current = Config.Stamina.Max,
			LastUpdate = tick(),
			IsSprinting = false
		}
	end
end

local function UpdateStamina(npcId, dt, isSprinting)
	local stamina = State.Stamina[npcId]
	if not stamina then return end

	if isSprinting and stamina.Current >= Config.Stamina.MinimumToSprint then
		-- Drain stamina while sprinting
		stamina.Current = math.max(0, stamina.Current - (Config.Stamina.SprintDrain * dt))
		stamina.IsSprinting = true
	else
		-- Recover stamina when not sprinting
		stamina.Current = math.min(Config.Stamina.Max, stamina.Current + (Config.Stamina.RecoveryRate * dt))
		stamina.IsSprinting = false
	end
end

local function CanSprint(npcId)
	local stamina = State.Stamina[npcId]
	if not stamina then return false end

	-- Can sprint if have minimum stamina, or already sprinting with threshold stamina
	if stamina.IsSprinting then
		return stamina.Current > Config.Stamina.SprintThreshold
	else
		return stamina.Current >= Config.Stamina.MinimumToSprint
	end
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

	-- Initialize stamina for this NPC
	local npcId = tostring(npc)
	InitializeStamina(npcId)

	-- Update stamina (will be updated based on sprint decision later)
	local now = tick()
	local lastUpdate = State.Stamina[npcId].LastUpdate
	local dt = now - lastUpdate
	State.Stamina[npcId].LastUpdate = now

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
	State.ActiveNPCs[npcId] = {
		npc = npc,
		root = root,
		bodyGyro = bodyGyro,
		teamName = teamName,
		hasBall = BallManager and BallManager.IsCharacterOwner(npc) or false
	}

	local hasBall = State.ActiveNPCs[npcId].hasBall

	if hasBall then
		HandleBallPossession(slot, npc, humanoid, root, teamName, dt, npcId)
	else
		HandleRoleBasedBehavior(slot, npc, humanoid, root, teamName, role, dt, npcId)
	end
end

--------------------------------------------------------------------------------
-- ROLE-BASED BEHAVIOR
--------------------------------------------------------------------------------

function HandleRoleBasedBehavior(slot, npc, humanoid, root, teamName, role, dt, npcId)
	local ball = workspace:FindFirstChild("Ball")
	local ballOwner = BallManager and BallManager.GetCurrentOwner() or nil
	local shouldSprint = false

	-- DEFENSIVE ROLES: When opponent has ball
	if ballOwner and not AIUtils.IsTeammate(ballOwner, teamName) then
		local ballOwnerRoot = ballOwner:FindFirstChild("HumanoidRootPart")
		if ballOwnerRoot then
			-- Primary presser - chase ball carrier aggressively
			if role == "Chaser" then
				shouldSprint = CanSprint(npcId)
				humanoid.WalkSpeed = shouldSprint and Config.Speed.Sprint or Config.Speed.Intercept
				MoveToTarget(humanoid, root, ballOwnerRoot.Position, teamName, npc, ballOwner)
				UpdateStamina(npcId, dt, shouldSprint)
				return
			
			-- Second presser - apply pressure from different angle
			elseif role == "SecondPress" then
				shouldSprint = CanSprint(npcId)
				humanoid.WalkSpeed = shouldSprint and Config.Speed.Sprint or Config.Speed.Intercept
				
				-- Approach from a cutting angle (try to cut off forward movement)
				local ownGoal = AIUtils.GetOwnGoalPosition(teamName)
				if ownGoal then
					local ballToGoalDir = (ownGoal - ball.Position).Unit
					local cutoffPoint = ball.Position + (ballToGoalDir * 8)
					MoveToTarget(humanoid, root, cutoffPoint, teamName, npc)
				else
					MoveToTarget(humanoid, root, ball.Position, teamName, npc)
				end
				UpdateStamina(npcId, dt, shouldSprint)
				return
			
			-- Goal cover - drop back and protect goal area
			elseif role == "GoalCover" then
				humanoid.WalkSpeed = Config.Speed.Support
				local ownGoal = AIUtils.GetOwnGoalPosition(teamName)
				if ownGoal then
					-- Position between ball and goal
					local ballToGoalDir = (ownGoal - ball.Position).Unit
					local coverPosition = ball.Position + (ballToGoalDir * 15)
					MoveToTarget(humanoid, root, coverPosition, teamName, npc)
				else
					MoveToTarget(humanoid, root, slot.HomePosition, teamName, npc)
				end
				UpdateStamina(npcId, dt, false)
				return
			
			-- Supporters - mark space and cut passing lanes
			elseif role == "Support" then
				local target = AIUtils.CalculateInterceptPosition(root.Position, slot.HomePosition, ballOwner)
				humanoid.WalkSpeed = Config.Speed.Support
				MoveToTarget(humanoid, root, target, teamName, npc)
				UpdateStamina(npcId, dt, false)
				return
			end
		end
	end

	-- ATTACKING/NEUTRAL ROLES: When we have ball or it's loose
	if role == "Chaser" and ball then
		-- Sprint towards loose ball
		shouldSprint = CanSprint(npcId)
		humanoid.WalkSpeed = shouldSprint and Config.Speed.Sprint or Config.Speed.Chase
		MoveToTarget(humanoid, root, ball.Position, teamName, npc)
		UpdateStamina(npcId, dt, shouldSprint)
	
	elseif role == "Support" and ball then
		-- Supporters find SPACE to receive passes
		-- Blend between home position and moving into open space
		local target = FindOpenSpace(root.Position, slot.HomePosition, ball.Position, teamName)
		humanoid.WalkSpeed = Config.Speed.Support
		MoveToTarget(humanoid, root, target, teamName, npc)
		UpdateStamina(npcId, dt, false)
	
	else
		-- Formation players - maintain shape but stay aware of ball
		local target = slot.HomePosition
		if ball then
			target = AIUtils.CalculateBlendedPosition(
				root.Position,
				slot.HomePosition,
				ball.Position,
				0.7  -- Stick closer to formation position
			)
		end
		humanoid.WalkSpeed = Config.Speed.Normal
		MoveToTarget(humanoid, root, target, teamName, npc)
		UpdateStamina(npcId, dt, false)
	end
end

-- NEW: Find open space to receive passes
function FindOpenSpace(currentPos, homePos, ballPos, teamName)
	-- Direction from ball toward home position
	local ballToHome = (homePos - ballPos).Unit
	
	-- Check positions at different distances from ball
	local bestPos = homePos
	local bestScore = -math.huge
	
	-- Test positions: slightly left, center, slightly right of home position
	local rightVec = ballToHome:Cross(Vector3.new(0, 1, 0)) * 10
	
	local testPositions = {
		homePos,  -- Center
		homePos + rightVec,  -- Right
		homePos - rightVec,  -- Left
	}
	
	for _, testPos in ipairs(testPositions) do
		-- Count nearby players (crowdedness)
		local teammates = AIUtils.GetNearbyPlayers(testPos, teamName, 15)
		local opponents = AIUtils.GetNearbyPlayers(testPos, AIUtils.GetOppositeTeam(teamName), 15)
		local crowdedness = #teammates + (#opponents * 1.5)  -- Opponents count more
		
		-- Distance from current position (prefer closer moves)
		local moveDist = (testPos - currentPos).Magnitude
		
		-- Score: lower crowdedness is better, prefer positions we can reach
		local score = -crowdedness * 10 - (moveDist * 0.2)
		
		if score > bestScore then
			bestScore = score
			bestPos = testPos
		end
	end
	
	return bestPos
end

--------------------------------------------------------------------------------
-- BALL POSSESSION (Shoot, Pass, Dribble)
--------------------------------------------------------------------------------

function HandleBallPossession(slot, npc, humanoid, root, teamName, dt, npcId)
	local now = tick()

	-- Track when ball was received
	if not State.LastBallReceived[npcId] then
		State.LastBallReceived[npcId] = now
	end

	local timeSinceBallReceived = now - State.LastBallReceived[npcId]
	local lastPass = State.LastPassTime[npcId] or 0
	local canPass = (now - lastPass) > Config.PassCooldown

	-- Update stamina - sprint while dribbling to evade defenders
	local goalPos = AIUtils.GetOpponentGoalPosition(teamName)
	local distToGoal = goalPos and (goalPos - root.Position).Magnitude or 999
	
	-- Sprint when close to goal or under pressure
	local nearbyOpponents = AIUtils.GetNearbyPlayers(root.Position, AIUtils.GetOppositeTeam(teamName), 10)
	local underPressure = #nearbyOpponents > 0
	local shouldSprint = (distToGoal < 50 or underPressure) and CanSprint(npcId)
	
	humanoid.WalkSpeed = shouldSprint and Config.Speed.Sprint or Config.Speed.Dribble
	UpdateStamina(npcId, dt, shouldSprint)

	-- Priority: Shoot → Pass (if dribbled enough AND it's a GOOD pass) → Dribble
	if TryShoot(slot, npc, root, teamName) then
		State.LastBallReceived[npcId] = nil  -- Reset for next possession
		return
	end

	-- Only pass if: (1) dribbled enough, (2) not too close to goal, (3) pass improves position
	if canPass and timeSinceBallReceived > Config.DribbleDelay then
		if TrySmartPass(slot, npc, root, teamName, distToGoal) then
			State.LastPassTime[npcId] = now
			State.LastBallReceived[npcId] = nil  -- Reset for next possession
			return
		end
	end

	DribbleTowardGoal(npc, humanoid, root, teamName)
end

-- NEW: Smart passing that avoids backward passes when close to goal
function TrySmartPass(slot, npc, root, teamName, distToGoal)
	local bestTarget = FindBestPassTarget(npc, root, teamName)
	if not bestTarget then return false end
	
	-- DON'T pass backward when close to goal - shoot instead!
	if distToGoal < 50 and bestTarget.ProgressAmount < -5 then
		return false  -- Reject backward pass, keep dribbling/shooting
	end
	
	-- DON'T pass if target is much further from goal (backward pass)
	if bestTarget.ProgressAmount < -10 then
		return false  -- Too much backward movement
	end

	-- Face the pass target direction
	local dir = (bestTarget.Position - root.Position).Unit

	-- Determine pass type based on distance and obstacles
	local kickType = "Ground"
	local power = math.clamp(bestTarget.Distance / Config.Distance.PassRange, 0.3, 0.8)

	-- Use air pass for longer distances or if ground path is blocked
	if bestTarget.Distance > Config.Distance.AirPassMinimum then
		local groundBlocked = AIUtils.IsPathBlocked(root.Position, bestTarget.Position, teamName)
		if groundBlocked or bestTarget.Distance > 60 then
			kickType = "Air"
			power = math.clamp(bestTarget.Distance / Config.Distance.PassRange, 0.5, 0.9)
		end
	end

	local npcId = tostring(npc)
	local animTrack = PlayKickAnimation(npc, dir, power, kickType)

	-- Spawn kick in separate thread
	task.spawn(function()
		if BallManager then
			BallManager.KickBall(npc, kickType, power, dir)
		end
		if animTrack then
			animTrack.Ended:Wait()
		else
			task.wait(0.8)
		end
	end)

	return true
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

	local npcId = tostring(npc)

	local animTrack = PlayKickAnimation(npc, dirToGoal, power, kickType)
	BallManager.KickBall(npc, kickType, power, dirToGoal)
	return true
end

function TryPass(slot, npc, root, teamName)
	local bestTarget = FindBestPassTarget(npc, root, teamName)
	if not bestTarget then return false end

	-- Face the pass target direction (instantly)
	local dir = (bestTarget.Position - root.Position).Unit
	
	-- Determine pass type based on distance and obstacles
	local kickType = "Ground"
	local power = math.clamp(bestTarget.Distance / Config.Distance.PassRange, 0.3, 0.8)

	-- Use air pass for longer distances or if ground path is blocked
	if bestTarget.Distance > Config.Distance.AirPassMinimum then
		local groundBlocked = AIUtils.IsPathBlocked(root.Position, bestTarget.Position, teamName)
		if groundBlocked or bestTarget.Distance > 35 then
			kickType = "Air"
			power = math.clamp(bestTarget.Distance / Config.Distance.PassRange, 0.5, 0.9)
		end
	end

	local npcId = tostring(npc)

	local animTrack = PlayKickAnimation(npc, dir, power, kickType)

	-- Spawn kick in separate thread so it doesn't block
	task.spawn(function()
		if BallManager then
			BallManager.KickBall(npc, kickType, power, dir)
		end
		-- Wait for animation to finish before clearing kicking state
		if animTrack then
			animTrack.Ended:Wait()
		else
			task.wait(0.8)
		end
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
					-- For air passes, don't check ground blocking
					local passBlocked = false
					if dist < Config.Distance.AirPassMinimum then
						passBlocked = AIUtils.IsPathBlocked(myPos, teammatePos, teamName)
					end

					if passBlocked then
						continue
					end

					local teammateDistToGoal = (goalPos - teammatePos).Magnitude
					local progressAmount = myDistToGoal - teammateDistToGoal

					-- Score based on progression
					local score = progressAmount * 2 - (dist * 0.15)

					-- Bonus for teammates in scoring positions
					if teammateDistToGoal < 40 then
						score = score + 20
					elseif teammateDistToGoal < 60 then
						score = score + 10
					end

					-- Bonus for significant forward progress
					if progressAmount > 15 then
						score = score + 8
					end

					if score > bestScore then
						bestScore = score
						bestTarget = {
							Position = teammatePos, 
							Distance = dist,
							ProgressAmount = progressAmount  -- NEW: track progress for smart passing
						}
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

	local currentPos = root.Position
	local dirToGoal = (goalPos - currentPos).Unit
	
	-- Check for opponents in the way
	local nearbyOpponents = AIUtils.GetNearbyPlayers(currentPos, AIUtils.GetOppositeTeam(teamName), 12)
	
	local avoidanceVector = Vector3.new()
	
	-- Avoid opponents aggressively when dribbling
	for _, opponent in ipairs(nearbyOpponents) do
		if opponent.Distance < 8 then
			local awayFromOpponent = (currentPos - opponent.Position).Unit
			local strength = (8 - opponent.Distance) / 8
			avoidanceVector = avoidanceVector + (awayFromOpponent * strength * 10)  -- Strong avoidance
		end
	end
	
	-- Blend goal direction with opponent avoidance
	local finalDir = (dirToGoal + avoidanceVector).Unit
	local target = currentPos + (finalDir * 20)
	
	MoveToTarget(humanoid, root, target, teamName, npc)
end

--------------------------------------------------------------------------------
-- UNIFIED MOVEMENT SYSTEM
--------------------------------------------------------------------------------

function MoveToTarget(humanoid, root, targetPos, teamName, npc, targetCharacter)
	local currentPos = root.Position
	local ball = workspace:FindFirstChild("Ball")
	
	-- Determine if target is the ball or an opponent with ball
	local isChasingBallCarrier = targetCharacter and BallManager and BallManager.IsCharacterOwner(targetCharacter)
	local isChasingBall = ball and (targetPos - ball.Position).Magnitude < 2
	
	local finalTarget = targetPos
	
	-- OVERTAKING LOGIC: Only when chasing opponent with ball
	if isChasingBallCarrier then
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local distToTarget = (targetPos - currentPos).Magnitude
			
			-- When close enough, move to intercept the ball itself, not the player
			if distToTarget < Config.Distance.OvertakeDistance and ball then
				finalTarget = ball.Position
			end
		end
	end
	
	local dist = (finalTarget - currentPos).Magnitude
	
	-- Stop if close enough
	if dist <= Config.Distance.StopDistance then
		humanoid:MoveTo(currentPos)
		return
	end
	
	-- COLLISION AVOIDANCE
	local nearbyTeammates = AIUtils.GetNearbyPlayers(currentPos, teamName, Config.Awareness.CollisionAvoid)
	local nearbyOpponents = AIUtils.GetNearbyPlayers(currentPos, AIUtils.GetOppositeTeam(teamName), Config.Awareness.CollisionAvoid)
	
	local avoidanceVector = Vector3.new()
	
	-- Avoid teammates
	for _, teammate in ipairs(nearbyTeammates) do
		if teammate.Character ~= npc and teammate.Distance < Config.Awareness.PersonalSpace and teammate.Distance > 0.1 then
			local away = (currentPos - teammate.Position).Unit
			local strength = (Config.Awareness.PersonalSpace - teammate.Distance) / Config.Awareness.PersonalSpace
			avoidanceVector = avoidanceVector + (away * strength * 5)
		end
	end
	
	-- Light avoidance from opponents (unless we're actively chasing ball/ball carrier)
	if not isChasingBall and not isChasingBallCarrier then
		for _, opponent in ipairs(nearbyOpponents) do
			if opponent.Distance < Config.Awareness.PersonalSpace and opponent.Distance > 0.1 then
				local away = (currentPos - opponent.Position).Unit
				local strength = (Config.Awareness.PersonalSpace - opponent.Distance) / Config.Awareness.PersonalSpace
				avoidanceVector = avoidanceVector + (away * strength * 2)
			end
		end
	end
	
	-- Blend target direction with avoidance
	local targetDir = (finalTarget - currentPos).Unit
	local finalDir = (targetDir + avoidanceVector).Unit
	
	-- Extend target ahead to keep smooth movement
	local extendDistance = 15
	local moveTarget = currentPos + (finalDir * math.min(dist + extendDistance, 35))
	
	humanoid:MoveTo(moveTarget)
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
-- PUBLIC API (for debugging/UI)
--------------------------------------------------------------------------------

function AIBehavior.GetStamina(npc)
	local npcId = tostring(npc)
	return State.Stamina[npcId]
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
	State.Stamina = {}
end

return AIBehavior