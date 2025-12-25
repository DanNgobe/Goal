--[[
	NPCManager.lua
	Handles NPC spawning, positioning, and field calculations.
	
	Responsibilities:
	- Calculate field dimensions from Ground part
	- Convert formation positions to world coordinates
	- Spawn NPCs from ServerStorage
	- Position NPCs on the field
	- Handle NPC respawning
]]

local NPCManager = {}

-- Services
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

-- Private variables
local Ground = nil
local FormationData = nil
local FieldCenter = nil
local FieldSize = nil
local SpawnedNPCs = {}

-- Initialize the NPC Manager
function NPCManager.Initialize(groundPart, formationModule)
	Ground = groundPart
	FormationData = formationModule
	
	if not Ground then
		warn("[NPCManager] Ground part not found!")
		return false
	end
	
	-- Calculate field properties
	FieldCenter = Ground.Position
	FieldSize = Ground.Size
	
	print(string.format("[NPCManager] Initialized - Field Size: %.1f x %.1f, Center: %s", 
		FieldSize.X, FieldSize.Z, tostring(FieldCenter)))
	
	return true
end

-- Get the field center position
function NPCManager.GetFieldCenter()
	return FieldCenter
end

-- Get the field bounds
function NPCManager.GetFieldBounds()
	return {
		Width = FieldSize.X,
		Length = FieldSize.Z,
		Height = FieldSize.Y
	}
end

-- Calculate world position for a team side
-- teamSide: "Blue" or "Red"
-- formationPosition: Vector3 with percentage values (0 to 1)
function NPCManager.CalculateWorldPosition(teamSide, formationPosition)
	if not FieldCenter or not FieldSize then
		warn("[NPCManager] Field not initialized!")
		return Vector3.new(0, 10, 0)
	end
	
	-- Determine which side of field this team is on
	-- Blue team: Negative Z (left side when looking from above)
	-- Red team: Positive Z (right side when looking from above)
	local sideMultiplier = (teamSide == "Blue") and -1 or 1
	
	-- Scale formation positions by field size
	-- Multiply percentage by field dimensions
	local scaledX = formationPosition.X * FieldSize.X
	local scaledZ = formationPosition.Z * FieldSize.Z
	
	-- Calculate world position
	local worldX = FieldCenter.X + scaledX
	local worldY = FieldCenter.Y + 3  -- Spawn slightly above ground
	local worldZ = FieldCenter.Z + (scaledZ * sideMultiplier)
	
	return Vector3.new(worldX, worldY, worldZ)
end

-- Spawn a single NPC
-- npcTemplate: The template character from ServerStorage
-- teamName: "Blue" or "Red"
-- role: Position role (GK, LB, etc.)
-- worldPosition: Where to spawn the NPC
function NPCManager.SpawnNPC(npcTemplate, teamName, role, worldPosition)
	if not npcTemplate then
		warn("[NPCManager] NPC template is nil!")
		return nil
	end
	
	-- Clone the NPC
	local npc = npcTemplate:Clone()
	npc.Name = teamName .. "_" .. role
	
	-- Set up the NPC
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = teamName .. " " .. role
	end
	
	-- Position the NPC
	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if rootPart then
		npc:SetPrimaryPartCFrame(CFrame.new(worldPosition))
	end
	
	-- Parent to workspace
	npc.Parent = workspace
	
	-- Store reference
	local npcData = {
		Model = npc,
		TeamName = teamName,
		Role = role,
		HomePosition = worldPosition,
		IsAI = true  -- Default to AI controlled
	}
	table.insert(SpawnedNPCs, npcData)
	
	print(string.format("[NPCManager] Spawned %s at %s", npc.Name, tostring(worldPosition)))
	
	return npcData
end

-- Spawn all NPCs for a team
-- teamName: "Blue" or "Red"
function NPCManager.SpawnTeamNPCs(teamName)
	-- Get the NPC template from ServerStorage
	local npcFolder = ServerStorage:FindFirstChild("NPCs")
	if not npcFolder then
		warn("[NPCManager] NPCs folder not found in ServerStorage!")
		return {}
	end
	
	local npcTemplate = npcFolder:FindFirstChild(teamName)
	if not npcTemplate then
		warn(string.format("[NPCManager] %s NPC template not found!", teamName))
		return {}
	end
	
	-- Get formation data
	local formation = FormationData.GetFormation()
	local teamNPCs = {}
	
	print(string.format("[NPCManager] Spawning %s team with %d players...", teamName, #formation))
	
	-- Spawn each position
	for _, positionData in ipairs(formation) do
		local worldPos = NPCManager.CalculateWorldPosition(teamName, positionData.Position)
		local npcData = NPCManager.SpawnNPC(npcTemplate, teamName, positionData.Role, worldPos)
		
		if npcData then
			table.insert(teamNPCs, npcData)
		end
	end
	
	print(string.format("[NPCManager] Successfully spawned %d NPCs for %s team", #teamNPCs, teamName))
	
	return teamNPCs
end

-- Position an NPC at a specific world position
function NPCManager.PositionNPC(npcModel, worldPosition)
	if not npcModel or not npcModel:FindFirstChild("HumanoidRootPart") then
		warn("[NPCManager] Invalid NPC model for positioning")
		return false
	end
	
	npcModel:SetPrimaryPartCFrame(CFrame.new(worldPosition))
	return true
end

-- Get all spawned NPCs
function NPCManager.GetAllNPCs()
	return SpawnedNPCs
end

-- Get NPCs for a specific team
function NPCManager.GetTeamNPCs(teamName)
	local teamNPCs = {}
	for _, npcData in ipairs(SpawnedNPCs) do
		if npcData.TeamName == teamName then
			table.insert(teamNPCs, npcData)
		end
	end
	return teamNPCs
end

-- Find an NPC by role and team
function NPCManager.FindNPC(teamName, role)
	for _, npcData in ipairs(SpawnedNPCs) do
		if npcData.TeamName == teamName and npcData.Role == role then
			return npcData
		end
	end
	return nil
end

-- Respawn an NPC if destroyed
function NPCManager.RespawnNPC(npcData)
	if not npcData then return nil end
	
	-- Get template
	local npcFolder = ServerStorage:FindFirstChild("NPCs")
	if not npcFolder then return nil end
	
	local template = npcFolder:FindFirstChild(npcData.TeamName)
	if not template then return nil end
	
	-- Remove old NPC if it exists
	if npcData.Model and npcData.Model.Parent then
		npcData.Model:Destroy()
	end
	
	-- Spawn new NPC at home position
	local newNPC = NPCManager.SpawnNPC(
		template,
		npcData.TeamName,
		npcData.Role,
		npcData.HomePosition
	)
	
	-- Update reference
	if newNPC then
		npcData.Model = newNPC.Model
		print(string.format("[NPCManager] Respawned %s_%s", npcData.TeamName, npcData.Role))
	end
	
	return newNPC
end

-- Clear all NPCs
function NPCManager.ClearAllNPCs()
	for _, npcData in ipairs(SpawnedNPCs) do
		if npcData.Model and npcData.Model.Parent then
			npcData.Model:Destroy()
		end
	end
	SpawnedNPCs = {}
	print("[NPCManager] Cleared all NPCs")
end

return NPCManager
