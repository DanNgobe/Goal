--[[
	AIController.lua
	Main AI coordinator - entry point for the AI system
	- Formation management (Attacking/Defensive/Neutral)
	- Ball role assignment (Chaser/Supporters)
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
	Formations = {Blue = "Neutral", Red = "Neutral"},
	BallRoles = {Blue = {}, Red = {}},
	LastRoleUpdate = 0
}

-- Configuration
local Config = {
	UpdateInterval = 0.1,
	RoleUpdateInterval = 0.5,
	BallChaseDistance = 100
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
	State.BallRoles.Blue = {Chaser = nil, Supporters = {}}
	State.BallRoles.Red = {Chaser = nil, Supporters = {}}

	-- Connect to possession changes
	if BallManager then
		BallManager.OnPossessionChanged(function(character, hasBall)
			HandlePossessionChange(character, hasBall)
		end)
	end

	-- Register all goalkeepers with their slots
	for _, teamName in ipairs({"Blue", "Red"}) do
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
	AIController.SetFormation("Blue", formationType)
	AIController.SetFormation("Red", formationType)
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
-- BALL ROLE ASSIGNMENT
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

	for _, teamName in ipairs({"Blue", "Red"}) do
		AssignBallRoles(teamName, ballPos, ballOwner)
	end
end

function AssignBallRoles(teamName, ballPos, ballOwner)
	if not TeamManager then return end

	local slots = TeamManager.GetAISlots(teamName)
	local roles = State.BallRoles[teamName]
	local candidates = {}

	for _, slot in ipairs(slots) do
		local npc = slot.NPC
		if npc and npc.Parent then
			local root = npc:FindFirstChild("HumanoidRootPart")
			if root then
				local distToBall = (ballPos - root.Position).Magnitude
				local distFromHome = slot.HomePosition and (slot.HomePosition - root.Position).Magnitude or 0

				-- Calculate a weighted score: lower is better
				-- Penalize being far from home position
				local score = distToBall + (distFromHome * 0.3)

				if distToBall <= Config.BallChaseDistance then
					table.insert(candidates, {
						Slot = slot, 
						Score = score
					})
				end
			end
		end
	end

	-- Sort by score (lower is better)
	table.sort(candidates, function(a, b) return a.Score < b.Score end)

	roles.Chaser = nil
	roles.Supporters = {}

	if #candidates > 0 then
		-- Only assign chaser if no teammate has the ball
		if not ballOwner or not AIUtils.IsTeammate(ballOwner, teamName) then
			roles.Chaser = candidates[1].Slot
		end

		-- Assign supporters (2nd and 3rd closest by score)
		for i = 2, math.min(3, #candidates) do
			table.insert(roles.Supporters, candidates[i].Slot)
		end
	end
end

function ClearBallRoles()
	for _, teamName in ipairs({"Blue", "Red"}) do
		State.BallRoles[teamName].Chaser = nil
		State.BallRoles[teamName].Supporters = {}
	end
end

function GetNPCRole(slot, teamName)
	local roles = State.BallRoles[teamName]

	if roles.Chaser == slot then return "Chaser" end

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

	for _, teamName in ipairs({"Blue", "Red"}) do
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
	UpdateTeamHomePositions("Blue")
	UpdateTeamHomePositions("Red")
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
