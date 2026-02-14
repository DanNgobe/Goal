--[[
	NPCManager.lua
	Handles NPC spawning, positioning, and field calculations.
	
	Responsibilities:
	- Calculate field dimensions from Ground part
	- Convert formation positions to world coordinates
	- Spawn NPCs from ServerStorage (Male template)
	- Apply team colors via SurfaceAppearance
	- Position NPCs on the field
	- Handle NPC respawning
]]

local NPCManager = {}

-- Services
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Modules
local TeamData = require(ReplicatedStorage:WaitForChild("TeamData"))

-- Private variables
local Ground = nil
local FormationData = nil
local FieldCenter = nil
local FieldSize = nil
local SpawnedNPCs = {}

-- Current Match Teams (country codes)
local CurrentMatchTeams = {
	HomeTeam = "BRA",  -- Default: Brazil
	AwayTeam = "ARG"   -- Default: Argentina
}

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
-- teamSide: "HomeTeam" or "AwayTeam"
-- formationPosition: Vector3 with percentage values (0 to 1)
-- formationType: Optional - "Neutral", "Attacking", or "Defensive" (defaults to current/stored formation)
function NPCManager.CalculateWorldPosition(teamSide, formationPosition, formationType)
	if not FieldCenter or not FieldSize then
		warn("[NPCManager] Field not initialized!")
		return Vector3.new(0, 10, 0)
	end

	-- Determine which side of field this team is on
	-- HomeTeam team: Negative Z (left side when looking from above)
	-- AwayTeam team: Positive Z (right side when looking from above)
	local sideMultiplier = (teamSide == "HomeTeam") and -1 or 1

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

-- Recalculate positions for a team with a specific formation
-- Returns array of {Role, WorldPosition} for each position
function NPCManager.RecalculateTeamPositions(teamName, formationType)
	if not FormationData then
		warn("[NPCManager] FormationData not initialized!")
		return {}
	end

	local formation = FormationData.GetFormationByName(formationType)
	local positions = {}

	for _, positionData in ipairs(formation) do
		local worldPos = NPCManager.CalculateWorldPosition(teamName, positionData.Position)
		table.insert(positions, {
			Role = positionData.Role,
			WorldPosition = worldPos
		})
	end

	return positions
end

-- Apply team colors to a character (NPC or Player)
-- character: The character model
-- teamName: "HomeTeam" or "AwayTeam"
function NPCManager.ApplyTeamColors(character, teamName)
	-- Get the country code for this team
	local countryCode = CurrentMatchTeams[teamName]
	if not countryCode then
		warn(string.format("[NPCManager] No country code set for %s", teamName))
		return false
	end

	-- Get the team colors from TeamData
	local colors = TeamData.GetCustomizationColors(countryCode)
	if not colors then
		warn(string.format("[NPCManager] Invalid country code: %s", countryCode))
		return false
	end

	-- Apply colors to clothing parts via SurfaceAppearance
	local clothingParts = {"Shirt", "Shorts", "Socks"}
	for _, partName in ipairs(clothingParts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local surfaceAppearance = part:FindFirstChildOfClass("SurfaceAppearance")
			if surfaceAppearance then
				-- Set the color tint on the SurfaceAppearance
				local colorKey = partName .. "Color"
				local color = colors[colorKey]
				if color then
					surfaceAppearance.Color = color
				end
			else
				-- If no SurfaceAppearance, apply color directly to part
				local colorKey = partName .. "Color"
				local color = colors[colorKey]
				if color then
					part.Color = color
				end
			end
		end
	end

	-- Apply body color
	local bodyPart = character:FindFirstChild("Body")
	if bodyPart and bodyPart:IsA("BasePart") then
		local surfaceAppearance = bodyPart:FindFirstChildOfClass("SurfaceAppearance")
		if surfaceAppearance then
			surfaceAppearance.Color = colors.BodyColor
		else
			bodyPart.Color = colors.BodyColor
		end
	end

	return true
end

-- Spawn a single NPC
-- teamName: "HomeTeam" or "AwayTeam"
-- role: Position role (GK, LB, etc.)
-- worldPosition: Where to spawn the NPC
function NPCManager.SpawnNPC(teamName, role, worldPosition)
	-- Get the Male template
	local npcFolder = ServerStorage:FindFirstChild("NPCs")
	if not npcFolder then
		warn("[NPCManager] NPCs folder not found in ServerStorage!")
		return nil
	end

	local npcTemplate = npcFolder:FindFirstChild("Male")
	if not npcTemplate then
		warn("[NPCManager] Male NPC template not found in NPCs folder!")
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

	-- Apply team colors
	NPCManager.ApplyTeamColors(npc, teamName)

	-- Position the NPC
	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if rootPart then
		npc:SetPrimaryPartCFrame(CFrame.new(worldPosition))
	end

	-- Parent to workspace
	npc.Parent = workspace

	-- Set collision group for NPCs
	task.defer(function()
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				pcall(function()
					part.CollisionGroup = "NPCs"
				end)
			end
		end
	end)

	-- Store reference
	local npcData = {
		Model = npc,
		TeamName = teamName,
		Role = role,
		HomePosition = worldPosition,
		IsAI = true  -- Default to AI controlled
	}
	table.insert(SpawnedNPCs, npcData)

	return npcData
end

-- Spawn all NPCs for a team
-- teamName: "HomeTeam" or "AwayTeam"
function NPCManager.SpawnTeamNPCs(teamName)
	-- Get formation data
	local formation = FormationData.GetFormation()
	local teamNPCs = {}

	-- Spawn each position
	for _, positionData in ipairs(formation) do
		local worldPos = NPCManager.CalculateWorldPosition(teamName, positionData.Position)
		local npcData = NPCManager.SpawnNPC(teamName, positionData.Role, worldPos)

		if npcData then
			table.insert(teamNPCs, npcData)
		end
	end

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

-- Reset all NPCs to their home positions
function NPCManager.ResetAllPositions()
	for _, npcData in ipairs(SpawnedNPCs) do
		if npcData.Model and npcData.Model.Parent and npcData.HomePosition then
			local humanoid = npcData.Model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:MoveTo(npcData.HomePosition)
				NPCManager.PositionNPC(npcData.Model, npcData.HomePosition)
			end
		end
	end
	print("[NPCManager] Reset all NPCs to home positions")
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

	-- Remove old NPC if it exists
	if npcData.Model and npcData.Model.Parent then
		npcData.Model:Destroy()
	end

	-- Spawn new NPC at home position
	local newNPC = NPCManager.SpawnNPC(
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

-- Get team customization data
function NPCManager.GetTeamCustomization(teamName)
	local countryCode = CurrentMatchTeams[teamName]
	if not countryCode then
		return nil
	end
	return TeamData.GetTeam(countryCode)
end

-- Set the current match teams (country codes)
function NPCManager.SetMatchTeams(homeCode, awayCode)
	if not TeamData.GetTeam(homeCode) then
		warn(string.format("[NPCManager] Invalid home team code: %s", homeCode))
		return false
	end
	if not TeamData.GetTeam(awayCode) then
		warn(string.format("[NPCManager] Invalid away team code: %s", awayCode))
		return false
	end

	CurrentMatchTeams.HomeTeam = homeCode
	CurrentMatchTeams.AwayTeam = awayCode

	-- Replicate to clients via a StringValue
	local matchTeamsFolder = ReplicatedStorage:FindFirstChild("MatchTeams")
	if not matchTeamsFolder then
		matchTeamsFolder = Instance.new("Folder")
		matchTeamsFolder.Name = "MatchTeams"
		matchTeamsFolder.Parent = ReplicatedStorage
	end

	local homeValue = matchTeamsFolder:FindFirstChild("HomeTeam") or Instance.new("StringValue")
	homeValue.Name = "HomeTeam"
	homeValue.Value = homeCode
	homeValue.Parent = matchTeamsFolder

	local awayValue = matchTeamsFolder:FindFirstChild("AwayTeam") or Instance.new("StringValue")
	awayValue.Name = "AwayTeam"
	awayValue.Value = awayCode
	awayValue.Parent = matchTeamsFolder


	-- Color workspace parts (goals and team parts)
	NPCManager.ColorWorkspaceParts()

	return true
end

-- Set random match teams
function NPCManager.SetRandomMatchTeams()
	local codes = TeamData.GetAllCodes()

	-- Pick two different teams
	local homeIndex = math.random(1, #codes)
	local awayIndex = math.random(1, #codes)

	-- Make sure they're different
	while awayIndex == homeIndex do
		awayIndex = math.random(1, #codes)
	end

	return NPCManager.SetMatchTeams(codes[homeIndex], codes[awayIndex])
end

-- Get current match teams
function NPCManager.GetMatchTeams()
	return {
		HomeTeam = CurrentMatchTeams.HomeTeam,
		AwayTeam = CurrentMatchTeams.AwayTeam
	}
end

-- Color workspace parts based on team colors (goals and team parts folders)
function NPCManager.ColorWorkspaceParts()
	local homeTeam = TeamData.GetTeam(CurrentMatchTeams.HomeTeam)
	local awayTeam = TeamData.GetTeam(CurrentMatchTeams.AwayTeam)

	if not homeTeam or not awayTeam then
		warn("[NPCManager] Cannot color workspace parts - invalid teams")
		return false
	end

	local pitch = workspace:FindFirstChild("Pitch")
	if not pitch then
		warn("[NPCManager] Pitch not found in workspace!")
		return false
	end

	-- Color BlueGoal (HomeTeam side)
	local blueGoal = pitch:FindFirstChild("BlueGoal")
	if blueGoal then
		blueGoal.Color = homeTeam.PrimaryColor
	end

	-- Color RedGoal (AwayTeam side)
	local redGoal = pitch:FindFirstChild("RedGoal")
	if redGoal then
		redGoal.Color = awayTeam.PrimaryColor
	end

	-- Color HomeParts folder
	local homeParts = workspace:FindFirstChild("HomeParts")
	if homeParts then
		for _, part in ipairs(homeParts:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = homeTeam.PrimaryColor
			end
		end
		print(string.format("[NPCManager] Colored HomeParts for %s", homeTeam.Name))
	end

	-- Color AwayParts folder
	local awayParts = workspace:FindFirstChild("AwayParts")
	if awayParts then
		for _, part in ipairs(awayParts:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = awayTeam.PrimaryColor
			end
		end
		print(string.format("[NPCManager] Colored AwayParts for %s", awayTeam.Name))
	end

	return true
end

-- Legacy function for compatibility
function NPCManager.SetTeamColors(teamName, shirtColor, shortsColor, socksColor, bodyColor)
	warn("[NPCManager] SetTeamColors is deprecated. Use SetMatchTeams with country codes instead.")
	return false
end

return NPCManager

