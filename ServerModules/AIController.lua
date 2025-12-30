--[[
	AIController.lua (Refactored)
	Controls AI behavior for NPCs not possessed by players.
	
	Key Improvements:
	- Role-based ball chasing (closest chases, nearby support, others hold formation)
	- Cleaner state management
	- Better organized decision-making
	- Proper formation gravity system
]]

local AIController = {}

-- Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Dependencies (injected)
local TeamManager = nil
local NPCManager = nil
local BallManager = nil
local FormationData = nil

-- State
local State = {
	Formations = {
		Blue = "Neutral",
		Red = "Neutral"
	},
	BallRoles = {
		Blue = {},  -- {Chaser = slot, Supporters = {slot1, slot2}}
		Red = {}
	},
	LastUpdate = 0,
	LastRoleUpdate = 0,
	LastPassTime = {}  -- Track when each NPC last passed
}

-- Configuration
local Config = {
	-- Update intervals
	UpdateInterval = 0.1,  -- Main AI update
	RoleUpdateInterval = 0.3,  -- Ball role assignment update
	DecisionInterval = 0.5,  -- Tactical decision interval

	-- Movement speeds
	Speed = {
		Normal = 16,
		Dribble = 12,
		Chase = 20,
		Support = 18,
		Intercept = 18
	},

	-- Distances
	Distance = {
		Stop = 2,
		BallChase = 100,  -- Max distance to consider chasing ball
		Support = 40,  -- Distance for support players
		Defensive = 45,
		ShootRange = 80,
		PassRange = 70
	},

	-- Formation gravity (how much NPCs stick to formation vs ball)
	FormationWeight = {
		Chaser = 0.0,  -- 100% ball focus
		Support = 0.5,  -- 50/50 between formation and ball
		Formation = 0.65,  -- 85% formation, 15% ball awareness
		Defensive = 0.80  -- 90% formation when defending
	},

	-- Tactical
	ShootAngle = 0.7,  -- Dot product threshold
	PassAheadDistance = 5,

	-- Passing AI
	EnemyThreatDistance = 15,  -- Enemy within this distance threatens pass
	PassCooldown = 1.5,  -- Seconds before considering another pass
	EnemyCheckRadius = 25  -- Only check enemies within this radius for performance
}

-- Connection
local UpdateConnection = nil

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIController.Initialize(teamManager, npcManager, ballManager, formationData)
	TeamManager = teamManager
	NPCManager = npcManager
	BallManager = ballManager
	FormationData = formationData

	if not TeamManager or not NPCManager or not BallManager or not FormationData then
		warn("[AIController] Missing required managers!")
		return false
	end

	-- Initialize ball roles
	State.BallRoles.Blue = {Chaser = nil, Supporters = {}}
	State.BallRoles.Red = {Chaser = nil, Supporters = {}}

	-- Listen to possession changes
	BallManager.OnPossessionChanged(function(character, hasBall)
		HandlePossessionChange(character, hasBall)
	end)

	-- Start update loop
	StartUpdateLoop()

	print("[AIController] Initialized with role-based ball chasing")
	return true
end

--------------------------------------------------------------------------------
-- POSSESSION & FORMATION MANAGEMENT
--------------------------------------------------------------------------------

function HandlePossessionChange(character, hasBall)
	if not character then
		-- Ball is loose
		SetBothFormations("Neutral")
		return
	end

	local teamWithBall = FindCharacterTeam(character)

	if teamWithBall and hasBall then
		-- Set formations based on possession
		local oppositeTeam = GetOppositeTeam(teamWithBall)
		SetFormation(teamWithBall, "Attacking")
		SetFormation(oppositeTeam, "Defensive")
	else
		-- Ball lost
		SetBothFormations("Neutral")
	end
end

function SetFormation(teamName, formationType)
	if State.Formations[teamName] == formationType then
		return
	end

	State.Formations[teamName] = formationType
	UpdateTeamHomePositions(teamName)

	print(string.format("[AIController] %s → %s formation", teamName, formationType))
end

function SetBothFormations(formationType)
	SetFormation("Blue", formationType)
	SetFormation("Red", formationType)
end

function UpdateTeamHomePositions(teamName)
	local formation = FormationData.GetFormationByName(State.Formations[teamName])
	local slots = TeamManager.GetTeamSlots(teamName)

	for i, slot in ipairs(slots) do
		if formation[i] then
			local positionData = formation[i]
			slot.HomePosition = NPCManager.CalculateWorldPosition(
				teamName, 
				positionData.Position
			)
		end
	end
end

--------------------------------------------------------------------------------
-- MAIN UPDATE LOOP
--------------------------------------------------------------------------------

function StartUpdateLoop()
	UpdateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()

		-- Throttle main update
		if now - State.LastUpdate < Config.UpdateInterval then
			return
		end
		State.LastUpdate = now

		-- Update ball roles periodically
		if now - State.LastRoleUpdate > Config.RoleUpdateInterval then
			UpdateBallRoles()
			State.LastRoleUpdate = now
		end

		-- Update all AI NPCs
		UpdateAllAI()
	end)
end

function UpdateAllAI()
	-- Update each team
	for _, teamName in ipairs({"Blue", "Red"}) do
		local slots = TeamManager.GetAISlots(teamName)
		for _, slot in ipairs(slots) do
			UpdateNPC(slot, teamName)
		end
	end
end

--------------------------------------------------------------------------------
-- BALL ROLE ASSIGNMENT (Closest chases, 2 support, rest hold formation)
--------------------------------------------------------------------------------

function UpdateBallRoles()
	local ball = workspace:FindFirstChild("Ball")
	if not ball then
		-- No ball - clear roles
		ClearBallRoles()
		return
	end

	local ballPos = ball.Position
	local ballOwner = BallManager.GetCurrentOwner()

	-- Update roles for each team
	for _, teamName in ipairs({"Blue", "Red"}) do
		AssignBallRoles(teamName, ballPos, ballOwner)
	end
end

function AssignBallRoles(teamName, ballPos, ballOwner)
	local slots = TeamManager.GetAISlots(teamName)
	local roles = State.BallRoles[teamName]

	-- Calculate distances to ball for all NPCs
	local distances = {}
	for _, slot in ipairs(slots) do
		local npc = slot.NPC
		if npc and npc.Parent then
			local root = npc:FindFirstChild("HumanoidRootPart")
			if root then
				local dist = (ballPos - root.Position).Magnitude
				if dist <= Config.Distance.BallChase then
					table.insert(distances, {
						Slot = slot,
						Distance = dist
					})
				end
			end
		end
	end

	-- Sort by distance (closest first)
	table.sort(distances, function(a, b)
		return a.Distance < b.Distance
	end)

	-- Assign roles
	roles.Chaser = nil
	roles.Supporters = {}

	if #distances > 0 then
		-- Closest becomes chaser (unless teammate has ball)
		if not ballOwner or not IsTeammate(ballOwner, teamName) then
			roles.Chaser = distances[1].Slot
		end

		-- Next 2 become supporters
		for i = 2, math.min(3, #distances) do
			table.insert(roles.Supporters, distances[i].Slot)
		end
	end
end

function ClearBallRoles()
	for _, teamName in ipairs({"Blue", "Red"}) do
		State.BallRoles[teamName].Chaser = nil
		State.BallRoles[teamName].Supporters = {}
	end
end

--------------------------------------------------------------------------------
-- NPC BEHAVIOR
--------------------------------------------------------------------------------

function UpdateNPC(slot, teamName)
	local npc = slot.NPC
	if not npc or not npc.Parent then
		return
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	-- Determine NPC's current role
	local role = GetNPCRole(slot, teamName)

	-- Check if NPC has ball
	local hasBall = BallManager.IsCharacterOwner(npc)

	if hasBall then
		-- NPC with ball - tactical decision making
		HandleBallPossession(slot, npc, humanoid, root, teamName)
	else
		-- NPC without ball - role-based behavior
		HandleRoleBasedBehavior(slot, npc, humanoid, root, teamName, role)
	end
end

function GetNPCRole(slot, teamName)
	local roles = State.BallRoles[teamName]

	if roles.Chaser == slot then
		return "Chaser"
	end

	for _, supporter in ipairs(roles.Supporters) do
		if supporter == slot then
			return "Support"
		end
	end

	return "Formation"
end

function HandleRoleBasedBehavior(slot, npc, humanoid, root, teamName, role)
	local ball = workspace:FindFirstChild("Ball")
	local ballOwner = BallManager.GetCurrentOwner()

	-- Check if opponent has ball (defensive behavior)
	if ballOwner and not IsTeammate(ballOwner, teamName) then
		if role == "Chaser" then
			-- Pressure ball carrier
			humanoid.WalkSpeed = Config.Speed.Intercept
			MoveToward(humanoid, root, ballOwner:FindFirstChild("HumanoidRootPart").Position)
			return
		elseif role == "Support" then
			-- Support defensive pressure
			local target = CalculateInterceptPosition(root.Position, slot.HomePosition, ballOwner)
			humanoid.WalkSpeed = Config.Speed.Support
			MoveToward(humanoid, root, target)
			return
		end
	end

	-- Role-based positioning
	if role == "Chaser" and ball then
		-- Chase the ball aggressively
		humanoid.WalkSpeed = Config.Speed.Chase
		MoveToward(humanoid, root, ball.Position)

	elseif role == "Support" and ball then
		-- Blend between formation and ball support
		local target = CalculateBlendedPosition(
			root.Position,
			slot.HomePosition,
			ball.Position,
			Config.FormationWeight.Support
		)
		humanoid.WalkSpeed = Config.Speed.Support
		MoveToward(humanoid, root, target)

	else
		-- Hold formation with slight ball awareness
		local target = slot.HomePosition

		if ball then
			target = CalculateBlendedPosition(
				root.Position,
				slot.HomePosition,
				ball.Position,
				Config.FormationWeight.Formation
			)
		end

		humanoid.WalkSpeed = Config.Speed.Normal
		MoveToward(humanoid, root, target)
	end
end

--------------------------------------------------------------------------------
-- BALL POSSESSION (Shoot, Pass, Dribble)
--------------------------------------------------------------------------------

function HandleBallPossession(slot, npc, humanoid, root, teamName)
	humanoid.WalkSpeed = Config.Speed.Dribble

	-- Check pass cooldown
	local npcId = tostring(npc)
	local lastPass = State.LastPassTime[npcId] or 0
	local canPass = (tick() - lastPass) > Config.PassCooldown

	-- Decision priority: Shoot → Pass (if ready) → Dribble
	if TryShoot(slot, npc, root, teamName) then
		return
	end

	if canPass and TryPass(slot, npc, root, teamName) then
		State.LastPassTime[npcId] = tick()
		return
	end

	-- Default: Dribble toward goal
	DribbleTowardGoal(npc, humanoid, root, teamName)
end

function TryShoot(slot, npc, root, teamName)
	local goalPos = GetOpponentGoalPosition(teamName)
	if not goalPos then return false end

	local dist = (goalPos - root.Position).Magnitude

	-- Check range
	if dist > Config.Distance.ShootRange then
		return false
	end

	-- Check angle
	local dirToGoal = (goalPos - root.Position).Unit
	local facing = root.CFrame.LookVector

	if dirToGoal:Dot(facing) < Config.ShootAngle then
		-- Turn toward goal
		MoveToward(npc:FindFirstChildOfClass("Humanoid"), root, goalPos)
		return false
	end

	-- Shoot!
	local power = math.clamp(dist / Config.Distance.ShootRange, 0.5, 1)
	local kickType = dist > 40 and "Air" or "Ground"
	BallManager.KickBall(npc, kickType, power, dirToGoal)

	return true
end

function TryPass(slot, npc, root, teamName)
	local bestTarget = FindBestPassTarget(npc, root, teamName)

	if not bestTarget then
		return false
	end

	-- Pass to target
	local dir = (bestTarget.Position - root.Position).Unit
	local power = math.clamp(bestTarget.Distance / Config.Distance.PassRange, 0.3, 0.8)
	BallManager.KickBall(npc, "Ground", power, dir)

	return true
end

function FindBestPassTarget(npc, root, teamName)
	local slots = TeamManager.GetTeamSlots(teamName)
	local myPos = root.Position
	local goalPos = GetOpponentGoalPosition(teamName)

	if not goalPos then return nil end

	local myDistToGoal = (goalPos - myPos).Magnitude
	local oppositeTeam = GetOppositeTeam(teamName)

	-- Get nearby enemies ONCE for efficiency (spatial filtering)
	local nearbyEnemies = GetNearbyEnemies(myPos, oppositeTeam, Config.EnemyCheckRadius)

	local bestTarget = nil
	local bestScore = -math.huge

	for _, slot in ipairs(slots) do
		if slot.NPC ~= npc and slot.NPC.Parent then
			local teammateRoot = slot.NPC:FindFirstChild("HumanoidRootPart")
			local teammateHumanoid = slot.NPC:FindFirstChildOfClass("Humanoid")

			if teammateRoot and teammateHumanoid and teammateHumanoid.Health > 0 then
				local teammatePos = teammateRoot.Position
				local dist = (teammatePos - myPos).Magnitude
				local teammateDistToGoal = (goalPos - teammatePos).Magnitude

				-- Must be in pass range
				if dist > 5 and dist < Config.Distance.PassRange then
					local progressAmount = myDistToGoal - teammateDistToGoal

					-- Check if pass lane is threatened by enemies
					local isSafe = IsPassLaneSafe(myPos, teammatePos, nearbyEnemies)

					if isSafe then
						-- Score based on progression and distance
						local score = progressAmount * 2 - (dist * 0.15)

						-- Big bonus for teammates very close to goal
						if teammateDistToGoal < 40 then
							score = score + 20
						elseif teammateDistToGoal < 60 then
							score = score + 10
						end

						-- Bonus for teammates in advanced positions
						if progressAmount > 15 then
							score = score + 8
						end

						if score > bestScore then
							bestScore = score
							bestTarget = {
								Position = teammatePos,
								Distance = dist
							}
						end
					end
				end
			end
		end
	end

	return bestTarget
end

-- Efficiently get enemies near a position (spatial filtering)
function GetNearbyEnemies(position, enemyTeamName, radius)
	local enemies = {}
	local slots = TeamManager.GetTeamSlots(enemyTeamName)

	for _, slot in ipairs(slots) do
		if slot.NPC and slot.NPC.Parent then
			local enemyRoot = slot.NPC:FindFirstChild("HumanoidRootPart")
			local enemyHumanoid = slot.NPC:FindFirstChildOfClass("Humanoid")

			if enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 then
				local dist = (enemyRoot.Position - position).Magnitude

				-- Only include enemies within radius
				if dist <= radius then
					table.insert(enemies, {
						Position = enemyRoot.Position,
						Distance = dist
					})
				end
			end
		end
	end

	return enemies
end

-- Check if pass lane is safe from interception
function IsPassLaneSafe(fromPos, toPos, nearbyEnemies)
	-- If no enemies nearby, pass is safe
	if #nearbyEnemies == 0 then
		return true
	end

	local passDir = (toPos - fromPos).Unit
	local passLength = (toPos - fromPos).Magnitude

	-- Check each nearby enemy
	for _, enemy in ipairs(nearbyEnemies) do
		-- Calculate perpendicular distance from enemy to pass line
		local toEnemy = enemy.Position - fromPos
		local projection = toEnemy:Dot(passDir)

		-- Only check enemies along the pass path
		if projection > 0 and projection < passLength then
			local perpDist = (toEnemy - (passDir * projection)).Magnitude

			-- If enemy is too close to pass line, it's threatened
			if perpDist < Config.EnemyThreatDistance then
				return false
			end
		end
	end

	return true
end

function DribbleTowardGoal(npc, humanoid, root, teamName)
	local goalPos = GetOpponentGoalPosition(teamName)
	if not goalPos then
		humanoid:MoveTo(root.Position)
		return
	end

	local dir = (goalPos - root.Position).Unit
	local target = root.Position + (dir * 20)
	MoveToward(humanoid, root, target)
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

function CalculateBlendedPosition(currentPos, formationPos, ballPos, formationWeight)
	-- formationWeight: 0 = all ball, 1 = all formation
	local ballWeight = 1 - formationWeight

	-- Blend between formation position and ball position
	return formationPos * formationWeight + ballPos * ballWeight
end

function CalculateInterceptPosition(currentPos, homePos, target)
	-- Position between home and target for interception
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return homePos
	end

	local targetPos = targetRoot.Position
	return homePos * 0.3 + targetPos * 0.7
end

function MoveToward(humanoid, root, targetPos)
	local dist = (targetPos - root.Position).Magnitude

	if dist <= Config.Distance.Stop then
		humanoid:MoveTo(root.Position)
	else
		humanoid:MoveTo(targetPos)
	end
end

function FindCharacterTeam(character)
	for _, teamName in ipairs({"Blue", "Red"}) do
		local npcs = NPCManager.GetTeamNPCs(teamName)
		for _, npcData in ipairs(npcs) do
			if npcData.Model == character then
				return teamName
			end
		end

		local slots = TeamManager.GetTeamSlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.NPC == character then
				return teamName
			end
		end
	end
	return nil
end

function IsTeammate(character, teamName)
	return FindCharacterTeam(character) == teamName
end

function GetOppositeTeam(teamName)
	return teamName == "Blue" and "Red" or "Blue"
end

function GetOpponentGoalPosition(teamName)
	local oppositeTeam = GetOppositeTeam(teamName)
	local teamData = TeamManager.GetTeam(oppositeTeam)
	return teamData and teamData.GoalPart and teamData.GoalPart.Position
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function AIController.GetTeamFormation(teamName)
	return State.Formations[teamName]
end

function AIController.GetBallRoles(teamName)
	return State.BallRoles[teamName]
end

function AIController.ForceFormationUpdate(teamName, formationType)
	SetFormation(teamName, formationType)
	return true
end

function AIController.RefreshAllPositions()
	UpdateTeamHomePositions("Blue")
	UpdateTeamHomePositions("Red")
end

function AIController.Cleanup()
	if UpdateConnection then
		UpdateConnection:Disconnect()
		UpdateConnection = nil
	end

	State.Formations.Blue = "Neutral"
	State.Formations.Red = "Neutral"
	ClearBallRoles()

	print("[AIController] Cleaned up")
end

return AIController