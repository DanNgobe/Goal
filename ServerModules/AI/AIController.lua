--[[
	AIController.lua
	Main AI coordinator - entry point for the AI system
	- Formation management (Attacking/Defensive/Neutral)
	- IMPROVED: Intelligent ball role assignment (multiple pressers, goal coverage)
	- Target-based movement orchestration
	
	Replaces AICore.lua and AITactics.lua
]]

local AIController = {}

-- Services
local RunService = game:GetService("RunService")

-- AI Modules
local AIUtils = require(script.Parent.AIUtils)
local AIBehavior = require(script.Parent.AIBehavior)
local AIGoalkeeper = require(script.Parent.AIGoalkeeper)

-- Dependencies (injected)
local TeamManager = nil
local NPCManager = nil
local BallManager = nil
local FormationData = nil

-- State
local State = {
	LastUpdate = 0,
	Formations = {HomeTeam = "Neutral", AwayTeam = "Neutral"},
	BallRoles = {HomeTeam = {}, AwayTeam = {}},
	LastRoleUpdate = 0
}

-- Configuration
local Config = {
	UpdateInterval = 0.1,
	RoleUpdateInterval = 0.3,  -- More frequent updates for fluid play
	BallChaseDistance = 100,
	DangerZoneDistance = 40,   -- Distance from goal considered "dangerous"
	SpaceSearchRadius = 25     -- Radius to check for crowded areas
}

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

	-- Initialize AI subsystems
	local utilsOk = AIUtils.Initialize(teamManager, npcManager)
	local behaviorOk = AIBehavior.Initialize(teamManager, ballManager)
	local gkOk = AIGoalkeeper.Initialize(teamManager, ballManager)

	if not (utilsOk and behaviorOk and gkOk) then
		warn("[AIController] Failed to initialize AI subsystems!")
		return false
	end

	-- Initialize role structures
	State.BallRoles.HomeTeam = {Chaser = nil, SecondPress = nil, GoalCover = nil, Supporters = {}}
	State.BallRoles.AwayTeam = {Chaser = nil, SecondPress = nil, GoalCover = nil, Supporters = {}}

	-- Connect to possession changes
	if BallManager then
		BallManager.OnPossessionChanged(function(character, hasBall)
			HandlePossessionChange(character, hasBall)
		end)
	end

	-- Register all goalkeepers with their slots
	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		local slots = TeamManager.GetAISlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.Role == "GK" then
				AIGoalkeeper.RegisterGoalkeeper(slot, teamName)
			end
		end
	end

	StartUpdateLoop()
	return true
end

--------------------------------------------------------------------------------
-- POSSESSION & FORMATIONS
--------------------------------------------------------------------------------

function HandlePossessionChange(character, hasBall)
	if not character then
		AIController.SetBothFormations("Neutral")
		return
	end

	local teamWithBall = AIUtils.FindCharacterTeam(character)
	if teamWithBall and hasBall then
		AIController.SetFormation(teamWithBall, "Attacking")
		AIController.SetFormation(AIUtils.GetOppositeTeam(teamWithBall), "Defensive")
	else
		AIController.SetBothFormations("Neutral")
	end
end

function AIController.SetFormation(teamName, formationType)
	if State.Formations[teamName] == formationType then return end
	State.Formations[teamName] = formationType
	UpdateTeamHomePositions(teamName)
end

function AIController.SetBothFormations(formationType)
	AIController.SetFormation("HomeTeam", formationType)
	AIController.SetFormation("AwayTeam", formationType)
end

function UpdateTeamHomePositions(teamName)
	if not FormationData or not TeamManager or not NPCManager then return end

	local formation = FormationData.GetFormationByName(State.Formations[teamName])
	local slots = TeamManager.GetTeamSlots(teamName)

	for i, slot in ipairs(slots) do
		if formation[i] then
			slot.HomePosition = NPCManager.CalculateWorldPosition(
				teamName, 
				formation[i].Position
			)
		end
	end
end

--------------------------------------------------------------------------------
-- IMPROVED BALL ROLE ASSIGNMENT
--------------------------------------------------------------------------------

function UpdateBallRoles()
	local now = tick()
	if now - State.LastRoleUpdate < Config.RoleUpdateInterval then return end
	State.LastRoleUpdate = now

	local ball = workspace:FindFirstChild("Ball")
	if not ball then
		ClearBallRoles()
		return
	end

	local ballPos = ball.Position
	local ballOwner = BallManager and BallManager.GetCurrentOwner() or nil

	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		if ballOwner and AIUtils.IsTeammate(ballOwner, teamName) then
			-- Our team has the ball - assign attacking roles
			AssignAttackingRoles(teamName, ballPos, ballOwner)
		else
			-- Opponent has ball or it's loose - assign defensive roles
			AssignDefensiveRoles(teamName, ballPos, ballOwner)
		end
	end
end

function AssignAttackingRoles(teamName, ballPos, ballOwner)
	if not TeamManager then return end

	local slots = TeamManager.GetAISlots(teamName)
	local roles = State.BallRoles[teamName]
	
	-- Clear defensive roles
	roles.Chaser = nil
	roles.SecondPress = nil
	roles.GoalCover = nil
	roles.Supporters = {}

	-- If goalkeeper has ball, players return to formation positions
	if ballOwner and TeamManager.IsGoalkeeper(ballOwner) then
		return
	end

	-- For attacking, find players in OPEN SPACE to receive passes
	local candidates = {}
	
	for _, slot in ipairs(slots) do
		local npc = slot.NPC
		if npc and npc.Parent and npc ~= ballOwner then
			local root = npc:FindFirstChild("HumanoidRootPart")
			if root then
				local currentPos = root.Position
				
				-- Check how crowded this position is
				local crowdedness = GetPositionCrowdedness(currentPos, teamName)
				
				-- Distance from ball carrier
				local distFromBall = (ballPos - currentPos).Magnitude
				
				-- Prefer players that are:
				-- 1. Not too crowded (low crowdedness score)
				-- 2. At reasonable distance (not too far, not too close)
				-- 3. Ahead of ball carrier (moving forward)
				local goalPos = AIUtils.GetOpponentGoalPosition(teamName)
				local progressScore = 0
				if goalPos then
					local ballDistToGoal = (goalPos - ballPos).Magnitude
					local playerDistToGoal = (goalPos - currentPos).Magnitude
					progressScore = ballDistToGoal - playerDistToGoal  -- Positive if player is ahead
				end
				
				-- Lower score = better position
				local score = crowdedness * 5 + (distFromBall * 0.2) - (progressScore * 0.3)
				
				table.insert(candidates, {
					Slot = slot,
					Score = score,
					Crowdedness = crowdedness
				})
			end
		end
	end
	
	-- Sort by score (lower is better - less crowded, good position)
	table.sort(candidates, function(a, b) return a.Score < b.Score end)
	
	-- Assign supporters (best positioned players for receiving passes)
	for i = 1, math.min(3, #candidates) do
		table.insert(roles.Supporters, candidates[i].Slot)
	end
end

function AssignDefensiveRoles(teamName, ballPos, ballOwner)
	if not TeamManager then return end

	local slots = TeamManager.GetAISlots(teamName)
	local roles = State.BallRoles[teamName]
	local candidates = {}
	
	local ownGoalPos = AIUtils.GetOwnGoalPosition(teamName)
	local ballDistToGoal = ownGoalPos and (ownGoalPos - ballPos).Magnitude or 999

	for _, slot in ipairs(slots) do
		local npc = slot.NPC
		if npc and npc.Parent then
			local root = npc:FindFirstChild("HumanoidRootPart")
			if root then
				local distToBall = (ballPos - root.Position).Magnitude
				local distToGoal = ownGoalPos and (ownGoalPos - root.Position).Magnitude or 0

				-- Prioritize players closer to ball for pressing
				local score = distToBall

				if distToBall <= Config.BallChaseDistance then
					table.insert(candidates, {
						Slot = slot, 
						Score = score,
						DistToBall = distToBall,
						DistToGoal = distToGoal
					})
				end
			end
		end
	end

	-- Sort by score (lower = closer to ball)
	table.sort(candidates, function(a, b) return a.Score < b.Score end)

	roles.Chaser = nil
	roles.SecondPress = nil
	roles.GoalCover = nil
	roles.Supporters = {}

	-- If goalkeeper has ball, players return to formation positions (no active pressing)
	local ballOwnerIsGK = ballOwner and TeamManager.IsGoalkeeper(ballOwner)

	if #candidates > 0 and not ballOwnerIsGK then
		-- INTELLIGENT ROLE ASSIGNMENT
		
		-- 1. Primary presser (closest)
		roles.Chaser = candidates[1].Slot
		
		-- 2. Second presser (if ball is in dangerous zone, apply double press)
		if #candidates > 1 and ballDistToGoal < Config.DangerZoneDistance then
			roles.SecondPress = candidates[2].Slot
		end
		
		-- 3. Goal cover (if ball is dangerous, someone drops back to cover)
		if ballDistToGoal < Config.DangerZoneDistance and #candidates > 2 then
			-- Find the deepest player to cover goal
			local deepestIdx = 2  -- Start after chaser
			local deepestDist = candidates[2].DistToGoal
			
			for i = 3, #candidates do
				if candidates[i].DistToGoal < deepestDist then
					deepestDist = candidates[i].DistToGoal
					deepestIdx = i
				end
			end
			
			roles.GoalCover = candidates[deepestIdx].Slot
		end
		
		-- 4. Remaining players are supporters (mark dangerous areas)
		for i = 2, #candidates do
			local slot = candidates[i].Slot
			-- Skip if already assigned to SecondPress or GoalCover
			if slot ~= roles.SecondPress and slot ~= roles.GoalCover then
				table.insert(roles.Supporters, slot)
			end
		end
	end
end

function GetPositionCrowdedness(position, teamName)
	-- Count how many teammates and opponents are nearby
	local teammates = AIUtils.GetNearbyPlayers(position, teamName, Config.SpaceSearchRadius)
	local opponents = AIUtils.GetNearbyPlayers(position, AIUtils.GetOppositeTeam(teamName), Config.SpaceSearchRadius)
	
	-- Return total count (higher = more crowded)
	return #teammates + #opponents
end

function ClearBallRoles()
	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		State.BallRoles[teamName].Chaser = nil
		State.BallRoles[teamName].SecondPress = nil
		State.BallRoles[teamName].GoalCover = nil
		State.BallRoles[teamName].Supporters = {}
	end
end

function GetNPCRole(slot, teamName)
	local roles = State.BallRoles[teamName]

	if roles.Chaser == slot then return "Chaser" end
	if roles.SecondPress == slot then return "SecondPress" end
	if roles.GoalCover == slot then return "GoalCover" end

	for _, supporter in ipairs(roles.Supporters) do
		if supporter == slot then return "Support" end
	end

	return "Formation"
end

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function StartUpdateLoop()
	UpdateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - State.LastUpdate < Config.UpdateInterval then return end
		State.LastUpdate = now

		-- Update tactics logic
		UpdateBallRoles()

		-- Update all NPCs
		UpdateAllAI()
	end)
end

function UpdateAllAI()
	if TeamManager and TeamManager.IsProcessingGoal() then return end

	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		if TeamManager and TeamManager.IsTeamFrozen(teamName) then continue end

		local slots = TeamManager.GetAISlots(teamName)
		for _, slot in ipairs(slots) do
			-- Skip goalkeepers (updated on heartbeat in AIGoalkeeper)
			if slot.Role ~= "GK" then
				local role = GetNPCRole(slot, teamName)
				AIBehavior.UpdateNPC(slot, teamName, role)
			end
		end
	end
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
	AIController.SetFormation(teamName, formationType)
	return true
end

function AIController.RefreshAllPositions()
	UpdateTeamHomePositions("HomeTeam")
	UpdateTeamHomePositions("AwayTeam")
end

function AIController.Cleanup()
	if UpdateConnection then
		UpdateConnection:Disconnect()
		UpdateConnection = nil
	end

	AIBehavior.Cleanup()
	AIGoalkeeper.Cleanup()
end

return AIController