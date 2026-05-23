--[[
	SlotManager.lua
	Consolidated manager for all physical and logical team slots.
	
	Responsibilities:
	- Calculate field dimensions from Stadium.Pitch.Ground
	- Manage 10 Slots (5 Home, 5 Away)
	- Handle character spawning (AI or Player)
	- Apply team colors and attributes
]]

local SlotManager = {}

-- Services
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("SlotManager")
local PhysicsService = game:GetService("PhysicsService")

-- Modules
local TeamData = require(ReplicatedStorage:WaitForChild("TeamData"))
local FormationData = require(ReplicatedStorage:WaitForChild("FormationData"))

-- Dependencies (set during initialization)
local PlayerManagerRef = nil

-- Private constants
local TEAM_SIZE = 5

-- Private variables
local Ground = nil
local FieldCenter = nil
local FieldSize = nil

-- Current Match Teams (country codes)
-- Note: This will be populated by GameManager via SetMatchTeams()
local CurrentMatchCodes = {
	HomeTeam = nil,
	AwayTeam = nil
}

-- Team data structure
local Teams = {
	HomeTeam = { Slots = {} },
	AwayTeam = { Slots = {} }
}

-- Track player assignments: [Player] = {Team = "HomeTeam", SlotIndex = index}
local PlayerAssignments = {}
local LastTeleport = {} -- Private debounce table

-- Set PlayerManager dependency (called by GameManager after PlayerManager is initialized)
function SlotManager.SetPlayerManager(playerManager)
	PlayerManagerRef = playerManager
	Logger:info("PlayerManager dependency set")
end

-- Initialize the Slot Manager
function SlotManager.Initialize(groundPart, teleporterFolder)
	Ground = groundPart or workspace:FindFirstChild("Stadium") and workspace.Stadium:FindFirstChild("Pitch") and workspace.Stadium.Pitch:FindFirstChild("Ground")

	if not Ground then
		Logger:error("Ground part not found in Stadium.Pitch.Ground!")
		return false
	end

	-- 0. Setup Collision Groups
	-- Group NPCs so they don't collide with each other (preventing clumping/blocking)
	-- Group Players so they collide with everything.
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("NPCs") then
			PhysicsService:RegisterCollisionGroup("NPCs")
		end
		if not PhysicsService:IsCollisionGroupRegistered("Players") then
			PhysicsService:RegisterCollisionGroup("Players")
		end
		
		-- NPCs vs NPCs: NO collision
		PhysicsService:CollisionGroupSetCollidable("NPCs", "NPCs", false)
		-- NPCs vs Players: YES collision
		PhysicsService:CollisionGroupSetCollidable("NPCs", "Players", true)
		-- Players vs Players: YES collision
		PhysicsService:CollisionGroupSetCollidable("Players", "Players", true)
	end)

	-- 1. Calculate field properties
	FieldCenter = Ground.Position
	FieldSize = Ground.Size
	
	-- 2. Setup slots for both teams
	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		SlotManager.SetupTeam(teamName)
	end
	
	-- 3. Setup Teleporters if provided
	if teleporterFolder then
		SlotManager.SetupTeleporters(teleporterFolder)
	end

	Logger:info("Initialized with 10 slots. Field Center:", FieldCenter)
	return true
end

-- Setup physical teleporter pads
function SlotManager.SetupTeleporters(folder)
	if not folder then return end
	
	local function connectPad(name, teamName)
		local pad = folder:FindFirstChild(name)
		if not pad then return end
		
		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = game.Players:GetPlayerFromCharacter(character)
			if not player then return end

			-- Debounce: 3-second cooldown per player to prevent rapid re-triggers
			-- from multiple body parts and post-respawn re-touches
			local now = tick()
			if LastTeleport[player] and (now - LastTeleport[player]) < 3 then return end

			-- Skip if already assigned (avoids double-spawn on respawn touches)
			if PlayerAssignments[player] then return end

			LastTeleport[player] = now
			Logger:info(player.Name, "joined", teamName, "via teleporter")
			SlotManager.AssignPlayer(player, teamName)
		end)
	end
	
	connectPad("Home", "HomeTeam")
	connectPad("Away", "AwayTeam")
	Logger:info("Teleporters connected (Home/Away)")
end

-- Setup a team's initial state (all AI)
function SlotManager.SetupTeam(teamName)
	local formation = FormationData.GetDefaultFormation(teamName)
	local team = Teams[teamName]
	team.Slots = {}

	for i, posData in ipairs(formation) do
		local worldPos = SlotManager.CalculateWorldPosition(teamName, posData.Position)
		local npcModel = SlotManager.SpawnCharacter(teamName, posData.Role, worldPos, true)
		
		team.Slots[i] = {
			Index = i,
			Role = posData.Role,
			Model = npcModel,
			Controller = nil, -- Player object if player-controlled
			IsAI = true,
			HomePosition = worldPos
		}
	end
end

-- Calculate world position logic
function SlotManager.CalculateWorldPosition(side, formationPos)
	if not FieldCenter or not FieldSize then return Vector3.new(0, 5, 0) end

	local sideMultiplier = (side == "HomeTeam") and -1 or 1
	local scaledX = formationPos.X * FieldSize.X
	local scaledZ = formationPos.Z * FieldSize.Z

	return Vector3.new(
		FieldCenter.X + scaledX,
		FieldCenter.Y + 3.5,
		FieldCenter.Z + (scaledZ * sideMultiplier)
	)
end

-- Internal Character Spawner
function SlotManager.SpawnCharacter(teamSide, role, worldPos, isAI)
	local template = ServerStorage:FindFirstChild("NPCs") and ServerStorage.NPCs:FindFirstChild("Male")
	if not template then
		Logger:error("NPC template missing!")
		return nil
	end

	local character = template:Clone()
	character.Name = (isAI and "AI_" or "Player_") .. teamSide .. "_" .. role
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = role
	end

	-- Apply colors
	SlotManager.ApplyTeamColors(character, teamSide)

	-- Move to worldPos (humanoid:MoveTo is nicer than just CFrame for some reasons)
	character:SetPrimaryPartCFrame(CFrame.new(worldPos))
	character.Parent = workspace
	
	character:SetAttribute("Team", teamSide)
	character:SetAttribute("Role", role)
	character:SetAttribute("IsAI", isAI)

	-- Apply Collision Group
	local groupName = isAI and "NPCs" or "Players"
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end

	-- Option 5: Set Network Ownership to Server for NPCs
	if isAI then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
		end
	end

	return character
end

-- Character Customization
function SlotManager.ApplyTeamColors(character, teamSide)
	local code = CurrentMatchCodes[teamSide]
	local colors = TeamData.GetCustomizationColors(code)
	if not colors then return end

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			local colorKey = part.Name .. "Color"
			if colors[colorKey] then
				local sa = part:FindFirstChildOfClass("SurfaceAppearance")
				if sa then sa.Color = colors[colorKey] else part.Color = colors[colorKey] end
			elseif part.Name == "Body" then
				part.Color = colors.BodyColor
			end
		end
	end
end

-- Assign a player to a team slot
function SlotManager.AssignPlayer(player, teamName)
	if not Teams[teamName] then return false end
	
	SlotManager.RemovePlayer(player) -- Ensure they leave any previous team

	local team = Teams[teamName]
	local selectedSlot = nil
	
	-- Prioritize non-GK slots for players
	for _, slot in ipairs(team.Slots) do
		if slot.IsAI and slot.Role ~= "GK" then
			selectedSlot = slot
			break
		end
	end
	
	if not selectedSlot then
		for _, slot in ipairs(team.Slots) do
			if slot.IsAI then selectedSlot = slot; break end
		end
	end

	if not selectedSlot then return false end

	-- Update Slot Meta
	selectedSlot.Controller = player
	selectedSlot.IsAI = false
	
	-- Cleanup AI model
	if selectedSlot.Model then selectedSlot.Model:Destroy() end

	PlayerAssignments[player] = {
		Team = teamName,
		SlotIndex = selectedSlot.Index
	}

	-- Notify PlayerManager of assignment
	if PlayerManagerRef then
		PlayerManagerRef.OnPlayerAssigned(player, teamName, selectedSlot.Index)
	end

	player:LoadCharacter()
	
	-- Notify client that they have joined (hides UI)
	local events = ReplicatedStorage:FindFirstChild("Events")
	local playerRemotes = events and events:FindFirstChild("PlayerRemotes")
	local playerJoined = playerRemotes and playerRemotes:FindFirstChild("PlayerJoined")
	if playerJoined then
		playerJoined:FireClient(player)
	end

	Logger:info(player.Name, "assigned to", teamName, "Slot:", selectedSlot.Role)
	return true
end

-- Remove player from slot (reverts to AI)
function SlotManager.RemovePlayer(player)
	local assignment = PlayerAssignments[player]
	if not assignment then return end

	local team = Teams[assignment.Team]
	local slot = team.Slots[assignment.SlotIndex]
	
	if slot then
		slot.Controller = nil
		slot.IsAI = true
		
		-- Respawn the AI NPC
		local formation = FormationData.GetDefaultFormation(assignment.Team)
		local posData = formation[slot.Index]
		local worldPos = SlotManager.CalculateWorldPosition(assignment.Team, posData.Position)
		slot.Model = SlotManager.SpawnCharacter(assignment.Team, slot.Role, worldPos, true)
	end

	-- Notify PlayerManager of removal
	if PlayerManagerRef then
		PlayerManagerRef.OnPlayerRemoved(player)
	end

	PlayerAssignments[player] = nil
end

-- Handle character spawning for players
function SlotManager.HandleCharacterSpawn(player, character)
	local assignment = PlayerAssignments[player]
	if not assignment then return end
	
	local team = Teams[assignment.Team]
	local slot = team.Slots[assignment.SlotIndex]
	if not slot then return end

	-- Update slot to reference the new character
	slot.Model = character

	local formation = FormationData.GetDefaultFormation(assignment.Team)
	local worldPos = SlotManager.CalculateWorldPosition(assignment.Team, formation[slot.Index].Position)

	-- Wait for the HumanoidRootPart to exist before teleporting
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then return end

	character:SetPrimaryPartCFrame(CFrame.new(worldPos))
	SlotManager.ApplyTeamColors(character, assignment.Team)
	
	character:SetAttribute("Team", assignment.Team)
	character:SetAttribute("Role", slot.Role)
	character:SetAttribute("IsAI", false)

	-- Apply Collision Group
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
end

-- Setter for codes
function SlotManager.SetMatchTeams(homeCode, awayCode)
	CurrentMatchCodes.HomeTeam = homeCode
	CurrentMatchCodes.AwayTeam = awayCode
	Logger:info("Match teams set to Home:", homeCode, "Away:", awayCode)
end

-- ── AI Helpers ────────────────────────────────────────────────────────────────

-- Returns all slots for a team (AI or Player)
function SlotManager.GetTeamSlots(teamName)
	return Teams[teamName] and Teams[teamName].Slots or {}
end

-- Returns only slots currently controlled by AI
function SlotManager.GetAISlots(teamName)
	local aiSlots = {}
	local team = Teams[teamName]
	if not team then return aiSlots end
	
	for _, slot in ipairs(team.Slots) do
		if slot.IsAI and slot.Model then
			table.insert(aiSlots, slot)
		end
	end
	return aiSlots
end

-- Checks if a specific character is a goalkeeper
function SlotManager.IsGoalkeeper(character)
	if not character then return false end
	return character:GetAttribute("Role") == "GK"
end

-- Returns true if there is at least one non-GK AI slot available for the given team (Requirement 13.4)
function SlotManager.HasAvailableSlot(teamName)
	local team = Teams[teamName]
	if not team then return false end

	for _, slot in ipairs(team.Slots) do
		if slot.IsAI and slot.Role ~= "GK" then
			return true
		end
	end
	return false
end

-- Switch a player from their current slot to a new AI slot (D.2)
-- Vacates the old slot (spawns an AI NPC there) and moves the player into the new slot.
function SlotManager.SwitchPlayerSlot(player, newSlotIndex)
	local assignment = PlayerAssignments[player]
	if not assignment then
		Logger:warn("SwitchPlayerSlot: player", player.Name, "has no assignment")
		return false
	end

	local teamName    = assignment.Team
	local team        = Teams[teamName]
	local oldSlotIdx  = assignment.SlotIndex
	local oldSlot     = team.Slots[oldSlotIdx]
	local newSlot     = team.Slots[newSlotIndex]

	if not oldSlot or not newSlot then
		Logger:warn("SwitchPlayerSlot: invalid slot indices", oldSlotIdx, newSlotIndex)
		return false
	end

	if not newSlot.IsAI then
		Logger:warn("SwitchPlayerSlot: target slot", newSlotIndex, "is not AI-controlled")
		return false
	end

	-- 1. Destroy the AI model currently in the new slot
	if newSlot.Model then
		newSlot.Model:Destroy()
		newSlot.Model = nil
	end

	-- 2. Move the player into the new slot
	newSlot.Controller = player
	newSlot.IsAI       = false

	-- 3. Vacate the old slot — restore it to AI control
	oldSlot.Controller = nil
	oldSlot.IsAI       = true

	-- Spawn a replacement AI NPC at the old slot's home position
	local formation    = FormationData.GetDefaultFormation(teamName)
	local posData      = formation[oldSlotIdx]
	local oldWorldPos  = SlotManager.CalculateWorldPosition(teamName, posData.Position)
	oldSlot.HomePosition = oldWorldPos
	oldSlot.Model      = SlotManager.SpawnCharacter(teamName, oldSlot.Role, oldWorldPos, true)

	-- 4. Update PlayerAssignments
	PlayerAssignments[player] = {
		Team      = teamName,
		SlotIndex = newSlotIndex
	}

	-- 5. Notify PlayerManager
	if PlayerManagerRef then
		PlayerManagerRef.OnPlayerAssigned(player, teamName, newSlotIndex)
	end

	-- 6. Respawn the player at the new slot position
	player:LoadCharacter()

	Logger:info(player.Name, "switched from slot", oldSlotIdx, "to slot", newSlotIndex, "on", teamName)
	return true
end

-- Get a slot by model
function SlotManager.GetSlotByModel(character)
	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		for _, slot in ipairs(Teams[teamName].Slots) do
			if slot.Model == character then
				return slot, teamName
			end
		end
	end
	return nil
end

return SlotManager
