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
local BallManager = nil

-- Modules
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))

-- Player tracking
local PlayerSlots = {}  -- {[Player] = {Team = "HomeTeam", SlotIndex = 1}}
local TacklingPlayers = {} -- {[Player] = true}

-- Remote Events
local RemoteFolder = nil
local JoinTeamRequest = nil
local SwitchSlotRequest = nil
local PlayerJoined = nil
local TackleRequest = nil
local SprintRequest = nil

-- Initialize
function PlayerController.Initialize(teamManager, npcManager, ballManager)
	TeamManager = teamManager
	NPCManager = npcManager
	BallManager = ballManager

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

	TackleRequest = Instance.new("RemoteEvent")
	TackleRequest.Name = "TackleRequest"
	TackleRequest.Parent = RemoteFolder

	SprintRequest = Instance.new("RemoteEvent")
	SprintRequest.Name = "SprintRequest"
	SprintRequest.Parent = RemoteFolder

	-- Connect events
	JoinTeamRequest.OnServerEvent:Connect(OnJoinTeamRequest)
	SwitchSlotRequest.OnServerEvent:Connect(OnSwitchSlotRequest)
	TackleRequest.OnServerEvent:Connect(OnTackleRequest)
	SprintRequest.OnServerEvent:Connect(OnSprintRequest)

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
	if not teamName or (teamName ~= "HomeTeam" and teamName ~= "AwayTeam") then
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

	-- First, look for any field player slot (non-GK)
	for i, slot in ipairs(slots) do
		if slot.IsAI and slot.Role ~= "GK" then
			return i
		end
	end

	-- If only GK is left, then assign to GK
	for i, slot in ipairs(slots) do
		if slot.IsAI and slot.Role == "GK" then
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

	-- Apply team colors to player character
	if player.Character and NPCManager then
		NPCManager.ApplyTeamColors(player.Character, teamName)
	end

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
		-- Players cannot switch to Goalkeeper role (can only spawn as GK)
		if slot.IsAI and i ~= currentIndex and slot.NPC and slot.Role ~= "GK" then
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
	local npcData = NPCManager.SpawnNPC(teamName, oldSlot.Role, playerCurrentPosition)
	if npcData then
		oldSlot.NPC = npcData.Model
		oldSlot.IsAI = true
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

-- Private: Handle sprint request
function OnSprintRequest(player, isSprinting)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Authoritative speed change
	-- Sprint: 28, Normal: 23 (matching user specs)
	humanoid.WalkSpeed = isSprinting and 28 or 23
end

-- Private: Handle player leaving
function OnPlayerLeaving(player)
	local playerData = PlayerSlots[player]
	if not playerData then return end

	-- Respawn NPC in their slot
	local slots = TeamManager.GetTeamSlots(playerData.Team)
	local slot = slots[playerData.SlotIndex]

	if slot then
		local npcData = NPCManager.SpawnNPC(playerData.Team, slot.Role, slot.HomePosition)
		if npcData then
			slot.NPC = npcData.Model
			slot.IsAI = true
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
		if slot and NPCManager then
			local spawnPos = slot.HomePosition
			local npcData = NPCManager.SpawnNPC(data.Team, slot.Role, spawnPos)
			if npcData then
				slot.NPC = npcData.Model
				slot.IsAI = true
			end
		end
	end

	PlayerSlots = {}
end

-- Private: Handle tackle request from client
function OnTackleRequest(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 then return end

	-- Cooldown / Prevent multiple tackles
	if TacklingPlayers[player] then return end
	TacklingPlayers[player] = true

	-- Find parts to check for collision during tackle
	local components = {}
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(components, child)
		end
	end

	local hitTargets = {}
	local connections = {}

	-- Listen for hits during tackle window
	for _, part in pairs(components) do
		local conn = part.Touched:Connect(function(hit)
			local targetChar = hit.Parent
			if targetChar and targetChar ~= character and not hitTargets[targetChar] then
				-- Check if hit player's shoes AND they have the ball
				local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
				if targetHumanoid and BallManager and BallManager.IsCharacterOwner(targetChar) then
					hitTargets[targetChar] = true
					-- Play reaction animation
					PlayTackleReaction(targetChar)

					-- Detach the ball
					BallManager.DetachBall()
				end
			end
		end)
		table.insert(connections, conn)
	end

	-- Wait for tackle animation duration (roughly)
	task.wait(1.5)

	-- Cleanup
	for _, conn in pairs(connections) do
		conn:Disconnect()
	end

	-- Cooldown before next tackle
	task.wait(1.5)
	TacklingPlayers[player] = nil
end

-- Private: Play tackle reaction animation on a character
function PlayTackleReaction(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = AnimationData.Defense.Tackle_Reaction

	local track = animator:LoadAnimation(anim)
	track.Looped = false

	-- Anchor the player so they can't move during the reaction
	root.Anchored = true

	track.Ended:Connect(function()
		if root and root.Parent then
			root.Anchored = false
		end
	end)

	track:Play()

	-- Fallback unanchor in case Ended doesn't fire for some reason
	task.delay(track.Length + 0.1, function()
		if root and root.Parent and root.Anchored then
			root.Anchored = false
		end
	end)
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
