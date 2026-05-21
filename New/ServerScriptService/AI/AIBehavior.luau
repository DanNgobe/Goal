--[[
	AIBehavior.lua
	Field player actions and movement for Football_Game
	- Adapted for SlotManager (slot.Model) and modern Logger
]]

local AIBehavior = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("AIBehavior")

-- Modules
local AIUtils = require(script.Parent.Parent:WaitForChild("Utils"):WaitForChild("AIUtils"))
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))

-- Injected dependencies
local SlotManager = nil
local BallManager = nil

local State = {
	LastPassTime     = {}, -- Track pass cooldowns per NPC
	LastBallReceived = {}, -- Track when NPC received the ball
	Stamina          = {}, -- Track stamina per NPC
	LastTackleTime   = {}, -- Track tackle cooldowns per NPC
	IsTackling       = {}, -- Guard: true while slide animation is playing
}

-- Configuration
local Config = {
	Speed = {
		Normal    = 16,
		Dribble   = 19,
		Chase     = 20,
		Sprint    = 24,
		Support   = 18,
		Intercept = 18,
		Overtake  = 26
	},

	Distance = {
		StopDistance   = 1.0, -- Reduced for responsiveness
		ShootRange     = 80,
		PassRange      = 100,
		MinimumPass    = 8,
		AirPassMinimum = 50,
	},

	Stamina = {
		Max             = 100,
		SprintDrain     = 15,
		RecoveryRate    = 25,
		MinimumToSprint = 20,
		SprintThreshold = 30
	},

	Tackle = {
		Range       = 6,    -- Distance at which tackle triggers
		Cooldown    = 3.0,  -- Seconds between tackles per NPC
		Duration    = 0.9,  -- Seconds for the slide boost
		FrontArcDeg = 130,  -- Facing requirement
	},

	PassCooldown     = 1.5,
	DribbleDelay     = 1.2,
	PressureDistance = 15,

	Behavior = {
		ChaseDistance                 = 18,   -- Distance at which Chaser switches to active pursuit
		SecondPressCutoffDist         = 20,   -- Lead distance ahead of ball for SecondPress cutoff
		GoalCoverDist                 = 22,   -- Lead distance ahead of ball for GoalCover position
		SupportForwardRunLead         = 15,   -- Min studs ahead of ball for attacking Support runs
		AttackRunClampFraction        = 0.9,  -- Max fraction of pitch length for forward run target
		PossessionDribbleKickThreshold = 0.3, -- Seconds held before emergency dribble-kick triggers
	},
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIBehavior.Initialize(slotManager, ballManager)
	SlotManager = slotManager
	BallManager = ballManager

	return SlotManager ~= nil and BallManager ~= nil
end

--------------------------------------------------------------------------------
-- STAMINA SYSTEM
--------------------------------------------------------------------------------

local function InitializeStamina(npcId)
	if not State.Stamina[npcId] then
		State.Stamina[npcId] = {
			Current     = Config.Stamina.Max,
			LastUpdate  = tick(),
			IsSprinting = false
		}
	end
end

local function UpdateStamina(npcId, dt, isSprinting)
	local stamina = State.Stamina[npcId]
	if not stamina then return end

	if isSprinting and stamina.Current >= Config.Stamina.MinimumToSprint then
		stamina.Current     = math.max(0, stamina.Current - (Config.Stamina.SprintDrain * dt))
		stamina.IsSprinting = true
	else
		stamina.Current     = math.min(Config.Stamina.Max, stamina.Current + (Config.Stamina.RecoveryRate * dt))
		stamina.IsSprinting = false
	end
end

local function CanSprint(npcId)
	local stamina = State.Stamina[npcId]
	if not stamina then return false end

	if stamina.IsSprinting then
		return stamina.Current > Config.Stamina.SprintThreshold
	else
		return stamina.Current >= Config.Stamina.MinimumToSprint
	end
end

--------------------------------------------------------------------------------
-- ANIMATIONS
--------------------------------------------------------------------------------

local function PlayKickAnimation(npc, direction, power, kickType)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local success, animId = pcall(function() 
		return AnimationData.ChooseKickAnimation(npc:FindFirstChild("HumanoidRootPart"), direction, power, kickType) 
	end)

	if not success then
		Logger:warn("Failed to find kick animation in AnimationData, using fallback.")
		return nil
	end

	local animator       = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent      = humanoid

	local kickAnim       = Instance.new("Animation")
	kickAnim.AnimationId = animId
	local track          = animator:LoadAnimation(kickAnim)
	track.Looped         = false
	track:Play()
	return track
end

local function PlayTackleAnimation(npc, npcId)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator         = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent        = humanoid

	local tackleAnim       = Instance.new("Animation")
	tackleAnim.AnimationId = AnimationData.Defense.Tackle
	local track            = animator:LoadAnimation(tackleAnim)
	track.Looped           = false
	track:Play()

	-- "GO DOWN AND BOOST": Adjust HipHeight and WalkSpeed for the slide duration
	local originalHipHeight = humanoid.HipHeight
	local originalWalkSpeed = humanoid.WalkSpeed

	humanoid.HipHeight = 1   -- Slide low to the ground
	humanoid.WalkSpeed = 32  -- Significant boost for the tackle burst
	State.IsTackling[npcId] = true

	task.delay(Config.Tackle.Duration, function()
		if humanoid and humanoid.Parent then
			humanoid.HipHeight = originalHipHeight
			humanoid.WalkSpeed = originalWalkSpeed
			State.IsTackling[npcId] = false
		end
	end)

	return track
end

--------------------------------------------------------------------------------
-- ORIENTATION
--------------------------------------------------------------------------------

local function SetupOrientation(root)
	local rootAttachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if not rootAttachment then
		rootAttachment = Instance.new("Attachment")
		rootAttachment.Name = "RootAttachment"
		rootAttachment.Parent = root
	end

	local alignOrient = root:FindFirstChild("AIAlignOrient")
	if not alignOrient then
		alignOrient             = Instance.new("AlignOrientation")
		alignOrient.Name        = "AIAlignOrient"
		alignOrient.Mode        = Enum.OrientationAlignmentMode.OneAttachment
		alignOrient.Attachment0 = rootAttachment
		alignOrient.MaxTorque   = 400000
		alignOrient.Responsiveness = 25
		alignOrient.Parent      = root
	end

	return alignOrient
end

local function ApplyFacing(alignOrient, direction)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then return end
	alignOrient.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
end

--------------------------------------------------------------------------------
-- MAIN NPC UPDATE
--------------------------------------------------------------------------------

function AIBehavior.UpdateNPC(slot, teamName, role)
	local npc = slot.Model
	if not npc or not npc.Parent then return end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root     = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return end

	local npcId = tostring(npc)
	InitializeStamina(npcId)

	-- Skip updates while tackling to allow the slide to play out
	if State.IsTackling[npcId] then return end

	local now        = tick()
	local lastUpdate = State.Stamina[npcId].LastUpdate
	local dt         = now - lastUpdate
	State.Stamina[npcId].LastUpdate = now

	-- Face toward goal when we have ball, toward ball otherwise
	humanoid.AutoRotate = false
	local alignOrient = SetupOrientation(root)

	local hasBall = BallManager and (BallManager.GetCurrentOwner() == npc) or false

	local facingDir
	if hasBall then
		local goalPos = AIUtils.GetOpponentGoalPosition(teamName)
		if goalPos then facingDir = (goalPos - root.Position).Unit end
	else
		local ball = workspace:FindFirstChild("Ball")
		if ball then facingDir = (ball.Position - root.Position).Unit end
	end

	if facingDir then
		ApplyFacing(alignOrient, facingDir)
	end

	if hasBall then
		HandleBallPossession(slot, npc, humanoid, root, teamName, dt, npcId)
	else
		HandleRoleBasedBehavior(slot, npc, humanoid, root, teamName, role, dt, npcId)
	end
end

--------------------------------------------------------------------------------
-- ROLE BEHAVIOR
--------------------------------------------------------------------------------

function HandleRoleBasedBehavior(slot, npc, humanoid, root, teamName, role, dt, npcId)
	local ball      = workspace:FindFirstChild("Ball")
	local ballOwner = BallManager and BallManager.GetCurrentOwner() or nil
	local shouldSprint = false

	-- CHECK IF ANY GOALKEEPER HAS THE BALL (Our GK or Opponent's GK)
	-- If a goalkeeper has possession, field players should retreat to home positions and wait
	local goalkeeperHasBall = ballOwner and SlotManager and SlotManager.IsGoalkeeper(ballOwner)
	
	if goalkeeperHasBall then
		-- Retreat to home position and wait for goalkeeper to kick/distribute
		local homePos = slot.HomePosition or root.Position
		humanoid.WalkSpeed = Config.Speed.Normal
		MoveToTarget(humanoid, root, homePos, teamName, npc)
		return
	end

	-- DEFENSIVE: Opponent has ball
	if ballOwner and not AIUtils.IsTeammate(ballOwner, teamName) then
		local ballOwnerRoot = ballOwner:FindFirstChild("HumanoidRootPart")
		if ballOwnerRoot then
			if role == "Chaser" then
				shouldSprint = CanSprint(npcId)
				
				local targetPosition = ballOwnerRoot.Position
				local dist           = (targetPosition - root.Position).Magnitude

				-- CHASE LOGIC
				if dist < Config.Behavior.ChaseDistance then
					humanoid.WalkSpeed = shouldSprint and Config.Speed.Sprint or Config.Speed.Chase

					-- 1. Forward Lead: Aim ahead toward the goal to cut them off
					local ownGoal = AIUtils.GetOwnGoalPosition(teamName)
					if ownGoal then
						local dirToGoal = (ownGoal - targetPosition).Unit
						local leadDist  = math.clamp(dist * 0.25, 2, 6)
						targetPosition  = targetPosition + (dirToGoal * leadDist)
					end

					-- 2. Personal Space: Side-offset to avoid getting "stuck inside" the opponent
					-- Position ourselves to the side of the ball carrier
					if dist > 3 and dist < 12 then
						local dirToBallOwner = (targetPosition - root.Position).Unit
						-- Get perpendicular vector (rotate 90 degrees)
						local perpVector = Vector3.new(-dirToBallOwner.Z, 0, dirToBallOwner.X)
						-- Randomly choose left or right side
						local side = math.random() < 0.5 and 1 or -1
						targetPosition = targetPosition + (perpVector * side * 3.5)
					end

					-- 3. Tackle Check: Play a tackle animation occasionally when close
					local lastTackle = State.LastTackleTime[npcId] or 0
					if dist < Config.Tackle.Range and (tick() - lastTackle) > Config.Tackle.Cooldown then
						-- Chance to trigger the "Go Down and Boost" slide
						if math.random() < 0.05 then
							PlayTackleAnimation(npc, npcId)
							State.LastTackleTime[npcId] = tick()
							
							-- If BallManager has Disrupt, use it
							task.defer(function()
								if BallManager and BallManager.KickBall then
									local dir = (ballOwnerRoot.Position - root.Position).Unit
									BallManager.KickBall(npc, "Ground", 0.25, dir)
								end
							end)
							return
						end
					end
				else
					humanoid.WalkSpeed = shouldSprint and Config.Speed.Sprint or Config.Speed.Chase
				end

				MoveToTarget(humanoid, root, targetPosition, teamName, npc, ballOwner)
				UpdateStamina(npcId, dt, shouldSprint)
				return
			elseif role == "SecondPress" then
				humanoid.WalkSpeed = Config.Speed.Intercept
				local ownGoal = AIUtils.GetOwnGoalPosition(teamName)
				if ownGoal and ball then
					local ballToGoalDir = (ownGoal - ball.Position).Unit
					local cutoffPoint   = ball.Position + (ballToGoalDir * Config.Behavior.SecondPressCutoffDist)
					MoveToTarget(humanoid, root, cutoffPoint, teamName, npc)
				end
				return
			elseif role == "GoalCover" then
				humanoid.WalkSpeed = Config.Speed.Support
				local ownGoal = AIUtils.GetOwnGoalPosition(teamName)
				if ownGoal and ball then
					local ballToGoalDir = (ownGoal - ball.Position).Unit
					local coverPosition = ball.Position + (ballToGoalDir * Config.Behavior.GoalCoverDist)
					MoveToTarget(humanoid, root, coverPosition, teamName, npc)
				end
				return
			elseif role == "Support" then
				humanoid.WalkSpeed = Config.Speed.Support
				local homePos = slot.HomePosition or root.Position
				local targetZ = homePos.Z + (ball and (ball.Position.Z - homePos.Z) * 0.45 or 0)
				local targetX = homePos.X + (ball and (ball.Position.X - homePos.X) * 0.1  or 0)
				MoveToTarget(humanoid, root, Vector3.new(targetX, homePos.Y, targetZ), teamName, npc)
				return
			end
		end
	end

	-- ATTACKING/NEUTRAL
	if role == "Chaser" and ball then
		shouldSprint       = CanSprint(npcId)
		local mySpeed      = shouldSprint and Config.Speed.Sprint or Config.Speed.Chase
		humanoid.WalkSpeed = mySpeed

		local ballPos        = ball.Position
		local ballVel        = ball.AssemblyLinearVelocity
		local dist           = (ballPos - root.Position).Magnitude
		local predictionTime = math.min(dist / math.max(mySpeed, 1), 1.2)
		local targetPosition = ballPos + (ballVel * predictionTime)

		MoveToTarget(humanoid, root, targetPosition, teamName, npc)
		UpdateStamina(npcId, dt, shouldSprint)
	elseif role == "Support" and ball then
		local ownGoal = AIUtils.GetOwnGoalPosition(teamName)
		local opponentGoal = AIUtils.GetOpponentGoalPosition(teamName)
		local homePos = slot.HomePosition or root.Position
		
		if slot.Role == "DF" then
			-- Defenders stay back to secure defense and support from deep
			humanoid.WalkSpeed = Config.Speed.Support
			MoveToTarget(humanoid, root, homePos, teamName, npc)
		else
			-- Attackers (ST, LW, RW) make forward runs along their flanks
			if ownGoal and opponentGoal then
				local attackDir = (opponentGoal - ownGoal).Unit
				
				-- Project ball and player positions along the attacking axis
				local ballProj = (ball.Position - ownGoal):Dot(attackDir)
				local playerProj = (root.Position - ownGoal):Dot(attackDir)
				
				-- Target to stay at least Config.Behavior.SupportForwardRunLead studs ahead of the ball along the attack axis
				local runProgress = math.max(ballProj + Config.Behavior.SupportForwardRunLead, playerProj)
				
				-- Clamp to avoid running past Config.Behavior.AttackRunClampFraction of pitch length
				local pitchLength = (opponentGoal - ownGoal).Magnitude
				runProgress = math.clamp(runProgress, 0, pitchLength * Config.Behavior.AttackRunClampFraction)
				
				-- Build target position: progress along attack axis + original home position lateral width
				local targetPos = ownGoal + (attackDir * runProgress)
				
				local lateralDir = Vector3.new(-attackDir.Z, 0, attackDir.X)
				local lateralDist = (homePos - ownGoal):Dot(lateralDir)
				targetPos = targetPos + (lateralDir * lateralDist)
				
				humanoid.WalkSpeed = Config.Speed.Support
				MoveToTarget(humanoid, root, targetPos, teamName, npc)
			else
				-- Fallback
				humanoid.WalkSpeed = Config.Speed.Support
				MoveToTarget(humanoid, root, homePos, teamName, npc)
			end
		end
	else
		local homePos = slot.HomePosition or root.Position
		local targetZ = (ball and (homePos.Z + (ball.Position.Z - homePos.Z) * 0.2)) or homePos.Z
		humanoid.WalkSpeed = Config.Speed.Normal
		MoveToTarget(humanoid, root, Vector3.new(homePos.X, homePos.Y, targetZ), teamName, npc)
	end
end

--------------------------------------------------------------------------------
-- POSSESSION
--------------------------------------------------------------------------------

function HandleBallPossession(slot, npc, humanoid, root, teamName, dt, npcId)
	local now = tick()
	if not State.LastBallReceived[npcId] then State.LastBallReceived[npcId] = now end

	local timeHeld = now - State.LastBallReceived[npcId]
	local lastPass = State.LastPassTime[npcId] or 0
	local canPass  = (now - lastPass) > Config.PassCooldown

	local goalPos    = AIUtils.GetOpponentGoalPosition(teamName)
	local distToGoal = goalPos and (goalPos - root.Position).Magnitude or 999

	local nearbyEnemies   = AIUtils.GetNearbyPlayers(root.Position, AIUtils.GetOppositeTeam(teamName), Config.PressureDistance)
	local isUnderPressure = #nearbyEnemies > 0
	local closestEnemy    = nearbyEnemies[1]
	local closestEnemyDist = closestEnemy and closestEnemy.Distance or 999

	local shouldSprint = distToGoal < 60 and CanSprint(npcId)
	humanoid.WalkSpeed = shouldSprint and Config.Speed.Sprint or Config.Speed.Dribble
	UpdateStamina(npcId, dt, shouldSprint)

	-- 1. SHOOT
	if distToGoal < Config.Distance.ShootRange then
		if TryShoot(npc, root, teamName, goalPos, distToGoal) then
			State.LastBallReceived[npcId] = nil
			return
		end
	end

	-- 2. PASS
	if canPass and (isUnderPressure or timeHeld > Config.DribbleDelay) then
		if timeHeld > 0.4 then 
			if TryPass(npc, root, teamName) then
				State.LastPassTime[npcId]     = now
				State.LastBallReceived[npcId] = nil
				return
			end
		end
	end

	-- 3. EMERGENCY CLEARANCE: Under extreme pressure with no pass option
	-- If closest enemy is very close and we haven't passed, nudge the ball forward (dribble kick)
	if isUnderPressure and closestEnemyDist < 4 and timeHeld > Config.Behavior.PossessionDribbleKickThreshold then
		-- Try to nudge forward toward opponent goal
		if goalPos then
			local clearDir = (goalPos - root.Position).Unit
			
			-- 40% dribble kick, 20% powerful air kick, 40% do nothing (keep dribbling)
			local clearChoice = math.random()
			
			if clearChoice < 0.2 then
				-- 20% Powerful air kick with randomness
				local airPower = math.clamp(distToGoal / 100, 0.6, 0.9)
				-- Add randomness to direction (±30 degrees)
				local randomAngle = (math.random() - 0.5) * math.rad(60)
				local randomDir = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), randomAngle) * clearDir
				task.defer(function()
					if BallManager then BallManager.KickBall(npc, "Air", airPower, randomDir) end
				end)
				State.LastBallReceived[npcId] = nil
				return
			elseif clearChoice < 0.6 then
				-- 40% Subtle ground dribble kick
				local clearPower = math.clamp(distToGoal / 300, 0.15, 0.25)
				task.defer(function()
					if BallManager then BallManager.KickBall(npc, "Ground", clearPower, clearDir) end
				end)
				State.LastBallReceived[npcId] = nil
				return
			end
			-- 40% do nothing - continue dribbling
		end
	end

	-- 4. DRIBBLE
	DribbleTowardGoal(npc, humanoid, root, teamName, goalPos)
end

function TryShoot(npc, root, teamName, goalPos, dist)
	if not goalPos then return false end
	if AIUtils.IsPathBlocked(root.Position, goalPos, teamName) then return false end

	local dir      = (goalPos - root.Position).Unit
	local power    = math.clamp(dist / Config.Distance.ShootRange, 0.5, .8)
	local kickType = dist > 40 and "Air" or "Ground"

	PlayKickAnimation(npc, dir, power, kickType)
	task.defer(function()
		if BallManager then BallManager.KickBall(npc, kickType, power, dir) end
	end)
	return true
end

function TryPass(npc, root, teamName)
	local bestTarget = nil
	local bestScore  = -math.huge

	local myPos        = root.Position
	local slots        = SlotManager.GetTeamSlots(teamName)
	local opponentGoal = AIUtils.GetOpponentGoalPosition(teamName)
	local myGoalDist   = opponentGoal and (opponentGoal - myPos).Magnitude or 999

	-- 20% chance to consider pass backs (backward passes)
	local allowPassBack = math.random() < 0.4

	for _, slot in ipairs(slots) do
		local teammate = slot.Model
		if teammate and teammate ~= npc and teammate.Parent then
			local tRoot = teammate:FindFirstChild("HumanoidRootPart")
			if tRoot then
				local dist      = (tRoot.Position - myPos).Magnitude
				local tGoalDist = opponentGoal and (opponentGoal - tRoot.Position).Magnitude or 999

				-- Forward pass: teammate closer to goal
				-- Pass back: teammate further from goal (only if allowPassBack is true)
				local isForwardPass = tGoalDist < myGoalDist
				local isPassBack = tGoalDist > myGoalDist

				if dist > Config.Distance.MinimumPass and dist < Config.Distance.PassRange then
					-- Accept forward passes always, pass backs only 20% of the time
					if (isForwardPass or (isPassBack and allowPassBack)) and tGoalDist < (myGoalDist + 10) then
						if not AIUtils.IsPathBlocked(myPos, tRoot.Position, teamName) then
							local score = myGoalDist - tGoalDist
							if score > bestScore then
								bestScore  = score
								bestTarget = tRoot.Position
							end
						end
					end
				end
			end
		end
	end

	if bestTarget then
		local dir   = (bestTarget - myPos).Unit
		local dist  = (bestTarget - myPos).Magnitude
		local power = math.clamp(dist / Config.Distance.PassRange, 0.4, 0.8)

		PlayKickAnimation(npc, dir, power, "Ground")
		task.defer(function()
			if BallManager then BallManager.KickBall(npc, "Ground", power, dir) end
		end)
		return true
	end
	return false
end

function DribbleTowardGoal(npc, humanoid, root, teamName, goalPos)
	if not goalPos then return end
	local dir    = (goalPos - root.Position).Unit
	local target = root.Position + (dir * 20)
	MoveToTarget(humanoid, root, target, teamName, npc)
end

--------------------------------------------------------------------------------
-- MOVEMENT
--------------------------------------------------------------------------------

function MoveToTarget(humanoid, root, targetPos, teamName, npc, targetCharacter)
	local dist = (targetPos - root.Position).Magnitude
	if dist <= Config.Distance.StopDistance then
		humanoid:Move(Vector3.zero)
		return
	end

	local direction = (targetPos - root.Position).Unit
	humanoid:Move(direction, false)
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function AIBehavior.Cleanup()
	State.Stamina          = {}
	State.LastPassTime     = {}
	State.LastBallReceived = {}
	State.LastTackleTime   = {}
	State.IsTackling       = {}
end

return AIBehavior