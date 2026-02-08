--[[
	TeamManager.lua
	Manages team structure, slots, and player assignments.
	
	Responsibilities:
	- Manage Blue and Red team data
	- Track which slots are NPC vs Player-controlled
	- Team assignment (auto-balance)
	- Store team colors, spawn points, goal references
	- Track scores
]]

local TeamManager = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Team data structure
local Teams = {
	Blue = {
		Name = "Blue",
		Color = Color3.fromRGB(0, 100, 255),
		Slots = {},  -- Will be populated with NPCs
		Score = 0,
		GoalPart = nil,
		Side = "Blue"  -- For position calculations
	},
	Red = {
		Name = "Red",
		Color = Color3.fromRGB(255, 50, 50),
		Slots = {},
		Score = 0,
		GoalPart = nil,
		Side = "Red"
	}
}

-- Track player assignments
local PlayerAssignments = {}  -- [Player] = {Team = "Blue"/"Red", SlotIndex = number}

-- Dependencies
local NPCManager = nil
local FormationData = nil

-- Game state
local FrozenTeams = {}  -- Array of team names that are currently frozen
local IsProcessingGoal = false

-- Goal settings
local GoalSettings = {
	IntermissionTime = 5,  -- Seconds between goals
}

-- Remote Events
local GoalRemoteFolder = nil
local GoalScored = nil
local GoalCelebration = nil

-- Initialize the Team Manager
function TeamManager.Initialize(blueGoal, redGoal, npcManager, formationData)
	Teams.Blue.GoalPart = blueGoal
	Teams.Red.GoalPart = redGoal
	NPCManager = npcManager
	FormationData = formationData

	if not blueGoal then
		warn("[TeamManager] Blue goal not found!")
	end
	if not redGoal then
		warn("[TeamManager] Red goal not found!")
	end

	-- Create RemoteEvents for goal scoring
	GoalRemoteFolder = ReplicatedStorage:FindFirstChild("GoalRemotes")
	if not GoalRemoteFolder then
		GoalRemoteFolder = Instance.new("Folder")
		GoalRemoteFolder.Name = "GoalRemotes"
		GoalRemoteFolder.Parent = ReplicatedStorage
	end

	GoalScored = Instance.new("RemoteEvent")
	GoalScored.Name = "GoalScored"
	GoalScored.Parent = GoalRemoteFolder
	
	GoalCelebration = Instance.new("RemoteEvent")
	GoalCelebration.Name = "GoalCelebration"
	GoalCelebration.Parent = GoalRemoteFolder

	-- Start in kickoff mode (Blue attacks, Red frozen)
	FrozenTeams = {"Red"}
	TeamManager.FreezeTeams({"Red"})

	return true
end

-- Create team slots from spawned NPCs
function TeamManager.SetupTeamSlots(teamName, npcDataList)
	if not Teams[teamName] then
		warn(string.format("[TeamManager] Invalid team: %s", teamName))
		return false
	end

	local team = Teams[teamName]
	team.Slots = {}

	for i, npcData in ipairs(npcDataList) do
		local slot = {
			Index = i,
			Role = npcData.Role,
			NPC = npcData.Model,
			HomePosition = npcData.HomePosition,
			Controller = nil,  -- nil = AI, Player object = player controlled
			IsAI = true
		}
		table.insert(team.Slots, slot)
	end

	return true
end

-- Get team data
function TeamManager.GetTeam(teamName)
	return Teams[teamName]
end

-- Get both teams
function TeamManager.GetAllTeams()
	return Teams
end

-- Get team by goal part (useful for goal detection)
function TeamManager.GetTeamByGoal(goalPart)
	if Teams.Blue.GoalPart == goalPart then
		return Teams.Blue
	elseif Teams.Red.GoalPart == goalPart then
		return Teams.Red
	end
	return nil
end

-- Get opposite team
function TeamManager.GetOppositeTeam(teamName)
	if teamName == "Blue" then
		return Teams.Red
	elseif teamName == "Red" then
		return Teams.Blue
	end
	return nil
end

-- Get a specific slot by role
function TeamManager.GetSlotByRole(teamName, role)
	local team = Teams[teamName]
	if not team then return nil end

	for _, slot in ipairs(team.Slots) do
		if slot.Role == role then
			return slot
		end
	end
	return nil
end

-- Check if a character is currently in a goalkeeper slot
function TeamManager.IsGoalkeeper(character)
	if not character then return false end

	for _, team in pairs(Teams) do
		for _, slot in ipairs(team.Slots) do
			if slot.NPC == character and slot.Role == "GK" then
				return true
			end
		end
	end
	return false
end

-- Get all slots for a team
function TeamManager.GetTeamSlots(teamName)
	local team = Teams[teamName]
	return team and team.Slots or {}
end

-- Get only AI-controlled NPCs
function TeamManager.GetAISlots(teamName)
	local team = Teams[teamName]
	if not team then return {} end

	local aiSlots = {}
	for _, slot in ipairs(team.Slots) do
		if slot.IsAI and not slot.Controller then
			table.insert(aiSlots, slot)
		end
	end
	return aiSlots
end

-- Get only player-controlled NPCs
function TeamManager.GetPlayerSlots(teamName)
	local team = Teams[teamName]
	if not team then return {} end

	local playerSlots = {}
	for _, slot in ipairs(team.Slots) do
		if not slot.IsAI and slot.Controller then
			table.insert(playerSlots, slot)
		end
	end
	return playerSlots
end

-- Find the team a player is on
function TeamManager.GetPlayerTeam(player)
	local assignment = PlayerAssignments[player]
	if assignment then
		return assignment.Team, assignment.SlotIndex
	end
	return nil, nil
end

-- Find which slot a player is controlling
function TeamManager.GetPlayerSlot(player)
	local teamName, slotIndex = TeamManager.GetPlayerTeam(player)
	if teamName and slotIndex then
		local team = Teams[teamName]
		return team.Slots[slotIndex]
	end
	return nil
end

-- Assign a player to a team (auto-balance)
function TeamManager.AssignPlayerToTeam(player)
	-- Count players on each team
	local blueCount = 0
	local redCount = 0

	for _, assignment in pairs(PlayerAssignments) do
		if assignment.Team == "Blue" then
			blueCount = blueCount + 1
		elseif assignment.Team == "Red" then
			redCount = redCount + 1
		end
	end

	-- Assign to team with fewer players
	local teamName = (blueCount <= redCount) and "Blue" or "Red"
	local team = Teams[teamName]

	-- Find first available slot (AI-controlled), prioritizing non-GK
	local availableSlot = nil
	for i, slot in ipairs(team.Slots) do
		if slot.IsAI and not slot.Controller and slot.Role ~= "GK" then
			availableSlot = i
			break
		end
	end

	-- Fallback to GK if no field player slots available
	if not availableSlot then
		for i, slot in ipairs(team.Slots) do
			if slot.IsAI and not slot.Controller and slot.Role == "GK" then
				availableSlot = i
				break
			end
		end
	end

	if not availableSlot then
		warn(string.format("[TeamManager] No available slots on %s team", teamName))
		return nil, nil
	end

	-- Assign player to slot
	local slot = team.Slots[availableSlot]
	slot.Controller = player
	slot.IsAI = false

	PlayerAssignments[player] = {
		Team = teamName,
		SlotIndex = availableSlot
	}

	print(string.format("[TeamManager] Assigned %s to %s team, slot %d (%s)", 
		player.Name, teamName, availableSlot, slot.Role))

	return teamName, availableSlot
end

-- Remove a player from their team
function TeamManager.RemovePlayer(player)
	local assignment = PlayerAssignments[player]
	if not assignment then
		return false
	end

	local team = Teams[assignment.Team]
	if team then
		local slot = team.Slots[assignment.SlotIndex]
		if slot then
			slot.Controller = nil
			slot.IsAI = true
			print(string.format("[TeamManager] Removed %s from %s team", player.Name, assignment.Team))
		end
	end

	PlayerAssignments[player] = nil
	return true
end

-- Switch a player to a different slot on the same team
function TeamManager.SwitchPlayerSlot(player, newSlotIndex)
	local assignment = PlayerAssignments[player]
	if not assignment then
		warn("[TeamManager] Player not assigned to any team")
		return false
	end

	local team = Teams[assignment.Team]
	local oldSlot = team.Slots[assignment.SlotIndex]
	local newSlot = team.Slots[newSlotIndex]

	if not newSlot then
		warn("[TeamManager] Invalid slot index")
		return false
	end

	-- Check if new slot is available
	if not newSlot.IsAI or newSlot.Controller then
		warn("[TeamManager] Target slot is not available")
		return false
	end

	-- Release old slot
	oldSlot.Controller = nil
	oldSlot.IsAI = true

	-- Take new slot
	newSlot.Controller = player
	newSlot.IsAI = false

	-- Update assignment
	assignment.SlotIndex = newSlotIndex

	print(string.format("[TeamManager] Switched %s from %s to %s", 
		player.Name, oldSlot.Role, newSlot.Role))

	return true
end

-- Find closest available slot on a team
function TeamManager.FindClosestSlot(teamName, position)
	local team = Teams[teamName]
	if not team then return nil end

	local closestSlot = nil
	local closestDistance = math.huge

	for _, slot in ipairs(team.Slots) do
		if slot.IsAI and not slot.Controller then
			local distance = (slot.HomePosition - position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestSlot = slot
			end
		end
	end

	return closestSlot
end

-- Update team score
function TeamManager.AddScore(teamName, points)
	local team = Teams[teamName]
	if not team then return false end

	team.Score = team.Score + (points or 1)

	return true
end

-- Get team score
function TeamManager.GetScore(teamName)
	local team = Teams[teamName]
	return team and team.Score or 0
end

-- Reset scores
function TeamManager.ResetScores()
	Teams.Blue.Score = 0
	Teams.Red.Score = 0
	print("[TeamManager] Scores reset")
end

-- Reset all players and NPCs to their home positions
function TeamManager.ResetAllPositions()
	if not NPCManager or not FormationData then
		warn("[TeamManager] NPCManager or FormationData not available for reset!")
		return
	end

	-- First, set both teams to Neutral formation
	for _, teamName in ipairs({"Blue", "Red"}) do
		local team = Teams[teamName]
		if team then
			team.Formation = "Neutral"
		end
	end

	-- Use NPCManager to recalculate positions for Neutral formation
	for _, teamName in ipairs({"Blue", "Red"}) do
		local team = Teams[teamName]
		local slots = team.Slots

		-- Get Neutral formation positions from NPCManager
		local neutralPositions = NPCManager.RecalculateTeamPositions(teamName, "Neutral")

		for i, slot in ipairs(slots) do
			if neutralPositions[i] then
				-- Update home position to Neutral formation position
				slot.HomePosition = neutralPositions[i].WorldPosition
			end

			if slot.NPC and slot.NPC.Parent and slot.HomePosition then
				local root = slot.NPC:FindFirstChild("HumanoidRootPart")
				local humanoid = slot.NPC:FindFirstChildOfClass("Humanoid")
				if root and humanoid then
					-- Teleport to home position
					root.CFrame = CFrame.new(slot.HomePosition)
					root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					humanoid:MoveTo(slot.HomePosition)
				end
			end
		end
	end
end

-- Get all players on a team
function TeamManager.GetTeamPlayers(teamName)
	local players = {}
	for player, assignment in pairs(PlayerAssignments) do
		if assignment.Team == teamName then
			table.insert(players, player)
		end
	end
	return players
end

-- Get total player count
function TeamManager.GetTotalPlayerCount()
	local count = 0
	for _ in pairs(PlayerAssignments) do
		count = count + 1
	end
	return count
end

-- Get team with fewer players (for auto-balance)
function TeamManager.GetSmallerTeam()
	local bluePlayerCount = 0
	local redPlayerCount = 0

	-- Count non-AI slots for each team
	local blueSlots = TeamManager.GetTeamSlots("Blue")
	local redSlots = TeamManager.GetTeamSlots("Red")

	for _, slot in ipairs(blueSlots) do
		if not slot.IsAI then
			bluePlayerCount = bluePlayerCount + 1
		end
	end

	for _, slot in ipairs(redSlots) do
		if not slot.IsAI then
			redPlayerCount = redPlayerCount + 1
		end
	end

	-- Return team with fewer players
	if bluePlayerCount < redPlayerCount then
		return "Blue"
	elseif redPlayerCount < bluePlayerCount then
		return "Red"
	else
		-- Equal, return random
		return math.random() > 0.5 and "Blue" or "Red"
	end
end

-- Freeze specific teams (stop movement)
function TeamManager.FreezeTeams(teamNames)
	-- Update frozen teams array
	FrozenTeams = teamNames

	for _, teamName in ipairs(teamNames) do
		local slots = TeamManager.GetTeamSlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.NPC and slot.NPC.Parent then
				local humanoid = slot.NPC:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 0
					humanoid:MoveTo(slot.NPC.HumanoidRootPart.Position)
				end
			end
		end
	end
end

-- Unfreeze all teams (restore movement)
function TeamManager.UnfreezeAllTeams()
	-- Clear frozen teams array
	FrozenTeams = {}

	for _, teamName in ipairs({"Blue", "Red"}) do
		local slots = TeamManager.GetTeamSlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.NPC and slot.NPC.Parent then
				local humanoid = slot.NPC:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 16  -- Default AI speed
				end
			end
		end
	end
end

-- Handle goal scored
function TeamManager.OnGoalScored(scoringTeam, scorerCharacter)
	if IsProcessingGoal then
		return
	end

	IsProcessingGoal = true

	-- Add score to team
	TeamManager.AddScore(scoringTeam, 1)

	-- Get current scores
	local blueScore = TeamManager.GetScore("Blue")
	local redScore = TeamManager.GetScore("Red")

	-- Broadcast to all clients
	if GoalScored then
		GoalScored:FireAllClients(scoringTeam, blueScore, redScore)
	end
	
	-- Broadcast celebration camera event with scorer
	if GoalCelebration and scorerCharacter and scorerCharacter.Parent then
		GoalCelebration:FireAllClients(scorerCharacter)
	end


	-- Reset all positions (players and NPCs)
	TeamManager.ResetAllPositions()

	-- Freeze everyone after reset
	TeamManager.FreezeTeams({"Blue", "Red"})

	-- Wait for intermission
	task.wait(GoalSettings.IntermissionTime)

	-- Setup kickoff: Losing team attacks, winning team (defending) is frozen
	local defendingTeam = scoringTeam  -- Team that just scored now defends
	FrozenTeams = {defendingTeam}

	-- Unfreeze everyone, then freeze defending team for kickoff
	TeamManager.UnfreezeAllTeams()
	TeamManager.FreezeTeams({defendingTeam})

	IsProcessingGoal = false
end

-- Check if kickoff and handle ball touch
function TeamManager.OnBallTouched()
	-- If any team is frozen (kickoff state), unfreeze everyone
	if #FrozenTeams > 0 and not IsProcessingGoal then
		FrozenTeams = {}
		TeamManager.UnfreezeAllTeams()
	end
end

-- Get current processing state
function TeamManager.IsProcessingGoal()
	return IsProcessingGoal
end

-- Get list of frozen teams
function TeamManager.GetFrozenTeams()
	return FrozenTeams
end

-- Check if a specific team is frozen
function TeamManager.IsTeamFrozen(teamName)
	for _, frozenTeam in ipairs(FrozenTeams) do
		if frozenTeam == teamName then
			return true
		end
	end
	return false
end

-- Start a new kickoff (called by GameManager for match start/restart)
-- attackingTeam: The team that will attack (other team is frozen)
function TeamManager.StartKickoff(attackingTeam)
	attackingTeam = attackingTeam or "Blue"
	local defendingTeam = (attackingTeam == "Blue") and "Red" or "Blue"
	FrozenTeams = {defendingTeam}
	TeamManager.FreezeTeams({defendingTeam})
end

-- Cleanup (for testing)
function TeamManager.Cleanup()
	PlayerAssignments = {}
	for _, team in pairs(Teams) do
		team.Score = 0
		for _, slot in ipairs(team.Slots) do
			slot.Controller = nil
			slot.IsAI = true
		end
	end
	print("[TeamManager] Cleaned up")
end

return TeamManager
