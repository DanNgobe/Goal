--[[
	PlayerManager.luau
	Centralized player state tracking and team assignment management.
	
	Responsibilities:
	- Track player team and slot assignments
	- Provide clean API for player state queries
	- Handle player join/leave callbacks
	- Manage player state cleanup for match restarts
]]

local PlayerManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("PlayerManager")

-- Dependencies
local SlotManagerRef = nil

-- Player assignment tracking: [Player] = {Team = "HomeTeam", SlotIndex = number, JoinTime = number}
local PlayerAssignments = {}

-- Initialize PlayerManager with SlotManager dependency
function PlayerManager.Initialize(slotManager)
	if not slotManager then
		Logger:error("PlayerManager.Initialize requires SlotManager dependency")
		return false
	end
	
	SlotManagerRef = slotManager
	
	-- Connect to Players service for cleanup
	Players.PlayerRemoving:Connect(function(player)
		PlayerManager.OnPlayerRemoved(player)
	end)
	
	Logger:info("PlayerManager initialized successfully")
	return true
end

-- Callback: Called when a player is assigned to a team slot
function PlayerManager.OnPlayerAssigned(player, teamName, slotIndex)
	if not player or not teamName or not slotIndex then
		Logger:error("OnPlayerAssigned called with invalid parameters:", player, teamName, slotIndex)
		return
	end
	
	PlayerAssignments[player] = {
		Team = teamName,
		SlotIndex = slotIndex,
		JoinTime = tick()
	}
	
	Logger:info(player.Name, "assigned to", teamName, "slot", slotIndex)
end

-- Callback: Called when a player is removed from their slot
function PlayerManager.OnPlayerRemoved(player)
	if not player then return end
	
	local assignment = PlayerAssignments[player]
	if assignment then
		Logger:info(player.Name, "removed from", assignment.Team, "slot", assignment.SlotIndex)
		PlayerAssignments[player] = nil
	end
end

-- API: Get the team a player is assigned to
function PlayerManager.GetPlayerTeam(player)
	if not player then return nil end
	
	local assignment = PlayerAssignments[player]
	return assignment and assignment.Team or nil
end

-- API: Get the slot index a player is occupying
function PlayerManager.GetPlayerSlot(player)
	if not player then return nil end
	
	local assignment = PlayerAssignments[player]
	return assignment and assignment.SlotIndex or nil
end

-- API: Check if a player is currently assigned to a slot
function PlayerManager.IsPlayerAssigned(player)
	if not player then return false end
	return PlayerAssignments[player] ~= nil
end

-- Clear all player state (called during match restart)
function PlayerManager.ClearState()
	local count = 0
	for player, _ in pairs(PlayerAssignments) do
		count = count + 1
	end
	
	table.clear(PlayerAssignments)
	
	if count > 0 then
		Logger:info("Cleared state for", count, "players")
	end
end

return PlayerManager
