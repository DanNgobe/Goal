--[[
	AITactics.lua
	Team tactics, formations, and role assignments
	- Formation management (Attacking/Defensive/Neutral)
	- Ball role assignment (Chaser/Supporters)
	- Home position calculations
]]

local AITactics = {}

-- Dependencies
local AIUtils = require(script.Parent.AIUtils)

-- Injected dependencies
local TeamManager = nil
local NPCManager = nil
local BallManager = nil
local FormationData = nil

-- State
local State = {
	Formations = {Blue = "Neutral", Red = "Neutral"},
	BallRoles = {Blue = {}, Red = {}},
	LastRoleUpdate = 0
}

-- Configuration
local Config = {
	RoleUpdateInterval = 0.5,
	BallChaseDistance = 100
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AITactics.Initialize(teamManager, npcManager, ballManager, formationData)
	TeamManager = teamManager
	NPCManager = npcManager
	BallManager = ballManager
	FormationData = formationData

	-- Initialize AIUtils
	AIUtils.Initialize(teamManager, npcManager)

	-- Initialize role structures
	State.BallRoles.Blue = {Chaser = nil, Supporters = {}}
	State.BallRoles.Red = {Chaser = nil, Supporters = {}}

	-- Connect to possession changes
	if BallManager then
		BallManager.OnPossessionChanged(function(character, hasBall)
			AITactics.HandlePossessionChange(character, hasBall)
		end)
	end

	return TeamManager ~= nil and NPCManager ~= nil and BallManager ~= nil and FormationData ~= nil
end

--------------------------------------------------------------------------------
-- FORMATION MANAGEMENT
--------------------------------------------------------------------------------

function AITactics.HandlePossessionChange(character, hasBall)
	if not character then
		AITactics.SetBothFormations("Neutral")
		return
	end

	local teamWithBall = AIUtils.FindCharacterTeam(character)
	if teamWithBall and hasBall then
		AITactics.SetFormation(teamWithBall, "Attacking")
		AITactics.SetFormation(AIUtils.GetOppositeTeam(teamWithBall), "Defensive")
	else
		AITactics.SetBothFormations("Neutral")
	end
end

function AITactics.SetFormation(teamName, formationType)
	if State.Formations[teamName] == formationType then return end
	State.Formations[teamName] = formationType
	AITactics.UpdateTeamHomePositions(teamName)
end

function AITactics.SetBothFormations(formationType)
	AITactics.SetFormation("Blue", formationType)
	AITactics.SetFormation("Red", formationType)
end

function AITactics.UpdateTeamHomePositions(teamName)
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

function AITactics.UpdateBallRoles()
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
						DistanceToBall = distToBall,
						DistanceFromHome = distFromHome,
						Score = score
					})
				end
			end
		end
	end

	-- Sort by score (lower is better - closer to ball and closer to home)
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

function AITactics.GetNPCRole(slot, teamName)
	local roles = State.BallRoles[teamName]

	if roles.Chaser == slot then return "Chaser" end

	for _, supporter in ipairs(roles.Supporters) do
		if supporter == slot then return "Support" end
	end

	return "Formation"
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function AITactics.GetTeamFormation(teamName)
	return State.Formations[teamName]
end

function AITactics.GetBallRoles(teamName)
	return State.BallRoles[teamName]
end

function AITactics.ForceFormationUpdate(teamName, formationType)
	AITactics.SetFormation(teamName, formationType)
	return true
end

function AITactics.RefreshAllPositions()
	AITactics.UpdateTeamHomePositions("Blue")
	AITactics.UpdateTeamHomePositions("Red")
end

return AITactics
