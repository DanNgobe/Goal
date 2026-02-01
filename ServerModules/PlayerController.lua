--[[
	PlayerController.lua
	Manages player joining teams and slot switching.
	
	Key Features:
	- Players join teams via UI request
	- Players replace an NPC slot
	- Players can switch to NPC closest to ball (C key)
	- Auto-balance teams
]]

local PlayerController = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies (injected)
local TeamManager = nil
local NPCManager = nil

-- Player tracking
local PlayerSlots = {}  -- {[Player] = {Team = "Blue", SlotIndex = 1}}

-- Remote Events
local RemoteFolder = nil
local JoinTeamRequest = nil
local SwitchSlotRequest = nil
local PlayerJoined = nil

-- Initialize
function PlayerController.Initialize(teamManager, npcManager)
	TeamManager = teamManager
	NPCManager = npcManager

	if not TeamManager or not NPCManager then
		warn("[PlayerController] Missing required managers!")
		return false
	end

	-- Create RemoteEvents
	RemoteFolder = ReplicatedStorage:FindFirstChild("PlayerRemotes")
	if not RemoteFolder then
		RemoteFolder = Instance.new("Folder")
		RemoteFolder.Name = "PlayerRemotes"
		RemoteFolder.Parent = ReplicatedStorage
	end

	JoinTeamRequest = Instance.new("RemoteEvent")
	JoinTeamRequest.Name = "JoinTeamRequest"
	JoinTeamRequest.Parent = RemoteFolder

	SwitchSlotRequest = Instance.new("RemoteEvent")
	SwitchSlotRequest.Name = "SwitchSlotRequest"
	SwitchSlotRequest.Parent = RemoteFolder

	PlayerJoined = Instance.new("RemoteEvent")
	PlayerJoined.Name = "PlayerJoined"
	PlayerJoined.Parent = RemoteFolder

	-- Connect events
	JoinTeamRequest.OnServerEvent:Connect(OnJoinTeamRequest)
	SwitchSlotRequest.OnServerEvent:Connect(OnSwitchSlotRequest)

	-- Handle player leaving
	Players.PlayerRemoving:Connect(OnPlayerLeaving)

	return true
end

-- Private: Handle join team request from client
function OnJoinTeamRequest(player, requestedTeam)
	-- Check if player already on a team
	if PlayerSlots[player] then
		warn(string.format("[PlayerController] %s already on a team!", player.Name))
		return
	end

	-- Auto-balance if no team specified
	local teamName = requestedTeam
	if not teamName or (teamName ~= "Blue" and teamName ~= "Red") then
		teamName = TeamManager.GetSmallerTeam()
	end

	-- Find available slot
	local slotIndex = FindAvailableSlot(teamName)
	if not slotIndex then
		warn(string.format("[PlayerController] No available slots on %s team!", teamName))
		return
	end

	-- Assign player to slot
	AssignPlayerToSlot(player, teamName, slotIndex)
end

-- Private: Find an available AI slot on team
function FindAvailableSlot(teamName)
	local slots = TeamManager.GetTeamSlots(teamName)

	for i, slot in ipairs(slots) do
		if slot.IsAI then
			return i
		end
	end

	return nil  -- No available slots
end

-- Private: Assign player to a specific slot
function AssignPlayerToSlot(player, teamName, slotIndex)
	local slots = TeamManager.GetTeamSlots(teamName)
	local slot = slots[slotIndex]

	if not slot then
		warn("[PlayerController] Invalid slot index:", slotIndex)
		return
	end

	-- Remove NPC from this slot
	if slot.NPC and slot.NPC.Parent then
		slot.NPC:Destroy()
	end

	-- Update slot data
	slot.IsAI = false
	slot.NPC = player.Character

	-- Track player
	PlayerSlots[player] = {
		Team = teamName,
		SlotIndex = slotIndex
	}

	-- Move player character to slot position
	if player.Character and slot.HomePosition then
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(slot.HomePosition)
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end

	-- Notify client
	PlayerJoined:FireClient(player, teamName, slotIndex, slot.HomePosition)
end

-- Private: Handle slot switch request
function OnSwitchSlotRequest(player)
	local playerData = PlayerSlots[player]
	if not playerData then
		return  -- Player not on a team
	end

	-- Find ball position
	local ball = workspace:FindFirstChild("Ball")
	if not ball then
		print("[PlayerController] Ball not found")
		return
	end

	local ballPosition = ball.Position

	-- Find AI slot closest to ball
	local slots = TeamManager.GetTeamSlots(playerData.Team)
	local currentIndex = playerData.SlotIndex
	local closestIndex = nil
	local closestDistance = math.huge

	for i, slot in ipairs(slots) do
		if slot.IsAI and i ~= currentIndex and slot.NPC then
			local npcRoot = slot.NPC:FindFirstChild("HumanoidRootPart")
			if npcRoot then
				local distance = (npcRoot.Position - ballPosition).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestIndex = i
				end
			end
		end
	end

	if closestIndex then
		SwitchPlayerSlot(player, playerData.Team, closestIndex)
	else
		print(string.format("[PlayerController] %s: No AI slots available to switch to", player.Name))
	end
end

-- Private: Switch player to a different slot
function SwitchPlayerSlot(player, teamName, newSlotIndex)
	local playerData = PlayerSlots[player]
	if not playerData then return end

	local slots = TeamManager.GetTeamSlots(teamName)
	local oldSlot = slots[playerData.SlotIndex]
	local newSlot = slots[newSlotIndex]

	if not newSlot or not newSlot.IsAI then
		return
	end

	-- Save current positions for swap
	local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local npcRoot = newSlot.NPC and newSlot.NPC:FindFirstChild("HumanoidRootPart")

	if not playerRoot or not npcRoot then
		warn("[PlayerController] Missing HumanoidRootPart for swap")
		return
	end

	local playerCurrentPosition = playerRoot.Position
	local npcCurrentPosition = npcRoot.Position

	-- Remove NPC from new slot
	if newSlot.NPC and newSlot.NPC.Parent then
		newSlot.NPC:Destroy()
	end

	-- Spawn NPC back in old slot at player's current position
	local npcTemplate = game:GetService("ServerStorage"):FindFirstChild("NPCs")
	if npcTemplate then
		local teamTemplate = npcTemplate:FindFirstChild(teamName)
		if teamTemplate then
			local npcData = NPCManager.SpawnNPC(teamTemplate, teamName, oldSlot.Role, playerCurrentPosition)
			if npcData then
				oldSlot.NPC = npcData.Model
				oldSlot.IsAI = true
			end
		end
	end

	-- Update new slot with player
	newSlot.IsAI = false
	newSlot.NPC = player.Character

	-- Update tracking
	PlayerSlots[player].SlotIndex = newSlotIndex

	-- Move player to NPC's old position (swap positions)
	if playerRoot then
		playerRoot.CFrame = CFrame.new(npcCurrentPosition)
		playerRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		playerRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end

	-- Notify client
	PlayerJoined:FireClient(player, teamName, newSlotIndex, newSlot.HomePosition)
end

-- Private: Handle player leaving
function OnPlayerLeaving(player)
	local playerData = PlayerSlots[player]
	if not playerData then return end

	-- Respawn NPC in their slot
	local slots = TeamManager.GetTeamSlots(playerData.Team)
	local slot = slots[playerData.SlotIndex]

	if slot then
		local npcTemplate = game:GetService("ServerStorage"):FindFirstChild("NPCs")
		if npcTemplate then
			local teamTemplate = npcTemplate:FindFirstChild(playerData.Team)
			if teamTemplate then
				local npcData = NPCManager.SpawnNPC(teamTemplate, playerData.Team, slot.Role, slot.HomePosition)
				if npcData then
					slot.NPC = npcData.Model
					slot.IsAI = true
				end
			end
		end
	end

	-- Remove from tracking
	PlayerSlots[player] = nil
end

-- Public: Get player's team
function PlayerController.GetPlayerTeam(player)
	local playerData = PlayerSlots[player]
	return playerData and playerData.Team
end

-- Public: Get player's slot
function PlayerController.GetPlayerSlot(player)
	local playerData = PlayerSlots[player]
	return playerData and playerData.SlotIndex
end

-- Public: Check if player is on a team
function PlayerController.IsPlayerOnTeam(player)
	return PlayerSlots[player] ~= nil
end

-- Public: Reset all players back to NPCs and kill characters (for match end)
function PlayerController.ResetAllPlayersForNewMatch()
	-- Replace player-controlled slots with NPCs
	for player, data in pairs(PlayerSlots) do
		-- Kill player character
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end

		local slots = TeamManager.GetTeamSlots(data.Team)
		local slot = slots[data.SlotIndex]
		if slot then
			local npcTemplate = game:GetService("ServerStorage"):FindFirstChild("NPCs")
			if npcTemplate then
				local teamTemplate = npcTemplate:FindFirstChild(data.Team)
				if teamTemplate then
					local spawnPos = slot.HomePosition
					if NPCManager and teamTemplate then
						local npcData = NPCManager.SpawnNPC(teamTemplate, data.Team, slot.Role, spawnPos)
						if npcData then
							slot.NPC = npcData.Model
							slot.IsAI = true
						end
					end
				end
			end
		end
	end

	PlayerSlots = {}
end

-- Cleanup
function PlayerController.Cleanup()
	if RemoteFolder then
		RemoteFolder:Destroy()
	end

	PlayerSlots = {}

	print("[PlayerController] Cleaned up")
end

return PlayerController
