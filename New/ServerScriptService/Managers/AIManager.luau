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
local SlotManager = nil
local BallManager = nil
local MatchManager = nil

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
	GoalBiasWeight = 0.15, -- Weight for own-goal proximity bias in Chaser selection (favoring defensive players)
}

local UpdateConnection = nil

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIManager.Initialize(slotManager, ballManager, matchManager)
	SlotManager = slotManager
	BallManager = ballManager
	MatchManager = matchManager

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

	StartUpdateLoop()
	Logger:info("AI Manager and subsystems initialized.")
	return true
end

--------------------------------------------------------------------------------
-- ROLE ASSIGNMENT
--------------------------------------------------------------------------------

function UpdateBallRoles()
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

function AssignRolesForTeam(teamName, ballPos, ballOwner)
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

	local candidates = {}
	for _, slot in ipairs(slots) do
		if slot.Role ~= "GK" and slot.Model and slot.Model.Parent then
			-- Use actual current position of the player
			local root = slot.Model:FindFirstChild("HumanoidRootPart")
			if root then
				local distToBall = (ballPos - root.Position).Magnitude
				
				-- Apply home position bias: penalize players too far from their zone
				-- This keeps players from abandoning their defensive/formation positions
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
end

function GetNPCRole(slot, teamName)
	local roles = State.BallRoles[teamName]
	if roles.Chaser == slot then return "Chaser" end
	if roles.SecondPress == slot then return "SecondPress" end
	for _, s in ipairs(roles.Support) do
		if s == slot then return "Support" end
	end
	return "Support"
end

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function StartUpdateLoop()
	if UpdateConnection then UpdateConnection:Disconnect() end
	
	UpdateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - State.LastUpdate < Config.UpdateInterval then return end
		State.LastUpdate = now

		UpdateBallRoles()
		UpdateAllAI()
	end)
end

function UpdateAllAI()
	-- Check global match state if needed (MatchManager)
	
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

function AIManager.Cleanup()
	if UpdateConnection then UpdateConnection:Disconnect() end
	AIBehavior.Cleanup()
	AIGoalkeeper.Cleanup()
end

return AIManager
