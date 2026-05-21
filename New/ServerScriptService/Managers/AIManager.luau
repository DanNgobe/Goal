local AIManager = {}
-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("AIManager")

-- AI Modules
local AIUtils = require(script.Parent.Parent:WaitForChild("Utils"):WaitForChild("AIUtils"))
local AIBehavior = require(script.Parent.Parent:WaitForChild("AI"):WaitForChild("AIBehavior"))
local AIGoalkeeper = require(script.Parent.Parent:WaitForChild("AI"):WaitForChild("AIGoalkeeper"))
local FormationData = require(ReplicatedStorage:WaitForChild("FormationData"))

-- Dependencies (injected)
-- Note: MatchManager removed - was unused (Requirement 7.3)
local SlotManager = nil
local BallManager = nil

-- State
local State = {
	LastUpdate = 0,
	BallRoles = {HomeTeam = {}, AwayTeam = {}},
	LastRoleUpdate = 0
}

-- Configuration
local Config = {
	UpdateInterval = 0.1,
	RoleUpdateInterval = 0.3,
	GoalBiasWeight = 0.15, -- Weight for own-goal proximity bias in Chaser selection
}

local UpdateConnection = nil

-- Pre-allocated module-level candidates table to avoid GC pressure in the
-- role-assignment hotpath that runs every 0.3 seconds (Requirements 8.1, 8.3)
local candidates = {}

-- Forward declarations so all internal functions are local-scoped and
-- can reference each other regardless of declaration order (Requirement 6.1)
local UpdateBallRoles
local AssignRolesForTeam
local GetNPCRole
local StartUpdateLoop
local UpdateAllAI

--------------------------------------------------------------------------------
-- INITIALIZATION
-- Public API: only Initialize and Cleanup are keys on AIManager (Requirement 6.4)
--------------------------------------------------------------------------------

-- matchManager parameter removed - it was never used inside this module (Requirements 7.1, 7.2)
function AIManager.Initialize(slotManager, ballManager)
	SlotManager = slotManager
	BallManager = ballManager

	if not (SlotManager and BallManager) then
		Logger:error("Missing required managers for AIManager!")
		return false
	end

	-- Initialize AI subsystems
	AIUtils.Initialize(SlotManager)
	AIBehavior.Initialize(SlotManager, BallManager)
	AIGoalkeeper.Initialize(SlotManager, BallManager)

	-- Initialize role structures
	State.BallRoles.HomeTeam = {Chaser = nil, SecondPress = nil, Support = {}}
	State.BallRoles.AwayTeam = {Chaser = nil, SecondPress = nil, Support = {}}

	-- References local function, not a global (Requirement 6.2)
	StartUpdateLoop()
	Logger:info("AI Manager and subsystems initialized.")
	return true
end

--------------------------------------------------------------------------------
-- ROLE ASSIGNMENT (all local - Requirement 6.1, 6.3)
--------------------------------------------------------------------------------

local function UpdateTeamHomePositions(teamName, formationType)
	local formation = FormationData.GetFormationByName(formationType)
	local slots = SlotManager.GetTeamSlots(teamName)

	for _, slot in ipairs(slots) do
		local posData = formation[slot.Index]
		if posData then
			slot.HomePosition = SlotManager.CalculateWorldPosition(teamName, posData.Position)
		end
	end
end

-- Uses pre-allocated module-level candidates table; clears it at the start
-- of each call so stale data never persists (Requirements 8.1, 8.2, 8.3)
AssignRolesForTeam = function(teamName, ballPos, ballOwner)
	-- Determine active formation for this team based on ball ownership
	local formationType = "Neutral"
	if ballOwner then
		local teamHasPossession = AIUtils.IsTeammate(ballOwner, teamName)
		formationType = teamHasPossession and "Attacking" or "Defensive"
	end
	UpdateTeamHomePositions(teamName, formationType)

	local slots = SlotManager.GetAISlots(teamName)
	local roles = State.BallRoles[teamName]

	-- Reset roles
	roles.Chaser = nil
	roles.SecondPress = nil
	roles.Support = {}

	if #slots == 0 then return end

	local ownGoal = AIUtils.GetOwnGoalPosition(teamName)

	-- Clear pre-allocated table instead of allocating a new one (Requirement 8.1)
	table.clear(candidates)

	for _, slot in ipairs(slots) do
		if slot.Role ~= "GK" and slot.Model and slot.Model.Parent then
			-- Use actual current position of the player
			local root = slot.Model:FindFirstChild("HumanoidRootPart")
			if root then
				local distToBall = (ballPos - root.Position).Magnitude

				-- Apply home position bias: penalize players too far from their zone
				local homePos = slot.HomePosition
				local homeBias = 0
				if homePos then
					local distFromHome = (root.Position - homePos).Magnitude
					-- Add 15% penalty for every 10 units away from home (max 30% penalty)
					homeBias = math.min(distFromHome / 10 * 0.15, 0.3)
				end

				local adjustedDist = distToBall * (1 + homeBias)

				-- Apply own goal proximity bias (favoring players positioned closer to our goal)
				local selectionScore = adjustedDist
				if ownGoal then
					local distToGoal = (ownGoal - root.Position).Magnitude
					selectionScore = selectionScore + (distToGoal * Config.GoalBiasWeight)
				end

				table.insert(candidates, {Slot = slot, Score = selectionScore, Distance = distToBall})
			end
		end
	end

	-- Sort by selection score (lower score is prioritized)
	table.sort(candidates, function(a, b) return a.Score < b.Score end)

	if #candidates > 0 then
		-- 1. Primary Chaser - closest player to ball (respecting home position)
		roles.Chaser = candidates[1].Slot

		-- 2. Secondary Presser - second closest for strategic pressing
		if #candidates > 1 then
			roles.SecondPress = candidates[2].Slot
		end

		-- 3. Everyone else is strictly Support
		for i = 1, #candidates do
			local slot = candidates[i].Slot
			if slot ~= roles.Chaser and slot ~= roles.SecondPress then
				table.insert(roles.Support, slot)
			end
		end
	end

	-- Clear the table after use so stale entries don't persist across calls (Requirement 8.2)
	table.clear(candidates)
end

UpdateBallRoles = function()
	local now = tick()
	if now - State.LastRoleUpdate < Config.RoleUpdateInterval then return end
	State.LastRoleUpdate = now

	local ball = workspace:FindFirstChild("Ball")
	if not ball then return end

	local ballPos = ball.Position
	local ballOwner = BallManager and BallManager.GetCurrentOwner() or nil

	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		AssignRolesForTeam(teamName, ballPos, ballOwner)
	end
end

GetNPCRole = function(slot, teamName)
	local roles = State.BallRoles[teamName]
	if roles.Chaser == slot then return "Chaser" end
	if roles.SecondPress == slot then return "SecondPress" end
	for _, s in ipairs(roles.Support) do
		if s == slot then return "Support" end
	end
	return "Support"
end

--------------------------------------------------------------------------------
-- UPDATE LOOP (all local - Requirement 6.1, 6.3)
--------------------------------------------------------------------------------

StartUpdateLoop = function()
	if UpdateConnection then UpdateConnection:Disconnect() end

	UpdateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - State.LastUpdate < Config.UpdateInterval then return end
		State.LastUpdate = now

		UpdateBallRoles()
		UpdateAllAI()
	end)
end

UpdateAllAI = function()
	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		-- Update Field Players
		local slots = SlotManager.GetAISlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.Role ~= "GK" then
				local roleName = GetNPCRole(slot, teamName)
				AIBehavior.UpdateNPC(slot, teamName, roleName)
			end
		end
	end

	-- Update Goalkeepers
	AIGoalkeeper.Update()
end

--------------------------------------------------------------------------------
-- PUBLIC API (only Initialize and Cleanup - Requirement 6.4)
--------------------------------------------------------------------------------

function AIManager.Cleanup()
	if UpdateConnection then UpdateConnection:Disconnect() end
	AIBehavior.Cleanup()
	AIGoalkeeper.Cleanup()
end

return AIManager
