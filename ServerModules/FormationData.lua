--[[
	FormationData.lua
	Defines the formation layouts with multiple tactical formations.
	Supports both 4v4 and 6v6 game modes.
	
	Formations:
	- NEUTRAL: Default formation, everyone in own half (used at kickoff and when no possession)
	- ATTACKING: Pushed forward (used when team has ball)
	- DEFENSIVE: Deep and compact (used when opponent has ball)
	
	6v6 Formation Layout:
	                    [GOAL]
	                      GK
	          		LB        RB
	          LW                    RW
	                     ST
	
	4v4 Formation Layout (excludes both defenders):
	                    [GOAL]
	                      GK
	          LW                    RW
	                     ST
	
	Positions are relative offsets from team's center point.
	X axis: Left (-) to Right (+)
	Z axis: Back (-) to Forward (+) relative to own goal
]]

local FormationData = {}

-- Configuration
local Config = {
	TeamSize = 6  -- Set to 4 for 4v4, or 6 for 6v6
}

-- Roles to exclude for 4v4 (excludes both defenders)
local EXCLUDED_4V4_ROLES = {
	"LB",  -- Left back removed
	"RB"   -- Right back removed
}

-- 4v4 Position Adjustments (compensate for missing defenders)
-- These override the 6v6 positions when in 4v4 mode
local ADJUSTMENTS_4V4 = {
	LW = Vector3.new(-0.15, 0, -0.25),  -- Move back and more central
	RW = Vector3.new(0.15, 0, -0.25),   -- Move back and more central
	ST = Vector3.new(0, 0, -0.1)        -- Drop back slightly
}

local ADJUSTMENTS_4V4_ATTACKING = {
	LW = Vector3.new(-0.2, 0, 0.05),    -- Still wide but not as far forward
	RW = Vector3.new(0.2, 0, 0.05),     -- Still wide but not as far forward
	ST = Vector3.new(0, 0, 0.25)        -- Still high but not as far
}

local ADJUSTMENTS_4V4_DEFENSIVE = {
	LW = Vector3.new(-0.12, 0, -0.28),  -- Very deep and narrow
	RW = Vector3.new(0.12, 0, -0.28),   -- Very deep and narrow
	ST = Vector3.new(0, 0, -0.18)       -- Drop very deep
}

-- 6v6 NEUTRAL Formation (Default - Everyone in own half)
-- Used at kickoff and when no team has clear possession
local NEUTRAL_FORMATION = {
	{
		Role = "GK",
		Name = "Goalkeeper",
		Position = Vector3.new(0, 0, -0.6),  -- Deep in goal
		ShortName = "GK"
	},
	{
		Role = "LB",
		Name = "LeftBack",
		Position = Vector3.new(-0.1, 0, -0.4),  -- Left defender
		ShortName = "LB"
	},
	{
		Role = "RB",
		Name = "RightBack",
		Position = Vector3.new(0.1, 0, -0.4),  -- Right defender
		ShortName = "RB"
	},
	{
		Role = "LW",
		Name = "LeftWing",
		Position = Vector3.new(-0.22, 0, -0.15),  -- Left winger (own half)
		ShortName = "LW"
	},
	{
		Role = "RW",
		Name = "RightWing",
		Position = Vector3.new(0.22, 0, -0.15),  -- Right winger (own half)
		ShortName = "RW"
	},
	{
		Role = "ST",
		Name = "Striker",
		Position = Vector3.new(0, 0, -0.05),  -- Striker (just behind center)
		ShortName = "ST"
	}
}

-- 6v6 ATTACKING Formation (When team has possession)
-- Pushed forward to press opponent
local ATTACKING_FORMATION = {
	{
		Role = "GK",
		Name = "Goalkeeper",
		Position = Vector3.new(0, 0, -0.5),  -- GK stays back
		ShortName = "GK"
	},
	{
		Role = "LB",
		Name = "LeftBack",
		Position = Vector3.new(-0.18, 0, -0.25),  -- Defenders push up slightly
		ShortName = "LB"
	},
	{
		Role = "RB",
		Name = "RightBack",
		Position = Vector3.new(0.18, 0, -0.25),  -- Defenders push up slightly
		ShortName = "RB"
	},
	{
		Role = "LW",
		Name = "LeftWing",
		Position = Vector3.new(-0.25, 0, 0.15),  -- Wingers wide and forward
		ShortName = "LW"
	},
	{
		Role = "RW",
		Name = "RightWing",
		Position = Vector3.new(0.25, 0, 0.15),  -- Wingers wide and forward
		ShortName = "RW"
	},
	{
		Role = "ST",
		Name = "Striker",
		Position = Vector3.new(0, 0, 0.35),  -- Striker pushed high
		ShortName = "ST"
	}
}

-- 6v6 DEFENSIVE Formation (When opponent has possession)
-- Deep and compact to protect goal
local DEFENSIVE_FORMATION = {
	{
		Role = "GK",
		Name = "Goalkeeper",
		Position = Vector3.new(0, 0, -0.6),  -- GK deep in goal
		ShortName = "GK"
	},
	{
		Role = "LB",
		Name = "LeftBack",
		Position = Vector3.new(-0.1, 0, -0.35),  -- Defenders very deep
		ShortName = "LB"
	},
	{
		Role = "RB",
		Name = "RightBack",
		Position = Vector3.new(0.1, 0, -0.35),  -- Defenders very deep
		ShortName = "RB"
	},
	{
		Role = "LW",
		Name = "LeftWing",
		Position = Vector3.new(-0.18, 0, -0.22),  -- Wingers drop back, narrow
		ShortName = "LW"
	},
	{
		Role = "RW",
		Name = "RightWing",
		Position = Vector3.new(0.18, 0, -0.22),  -- Wingers drop back, narrow
		ShortName = "RW"
	},
	{
		Role = "ST",
		Name = "Striker",
		Position = Vector3.new(0, 0, -0.12),  -- Striker drops to help defend
		ShortName = "ST"
	}
}

-- Formation types
local FormationType = {
	Neutral = "Neutral",
	Attacking = "Attacking",
	Defensive = "Defensive"
}

-- Helper: Filter formation based on team size
local function FilterFormationByTeamSize(formation, formationType)
	if Config.TeamSize == 6 then
		return formation  -- Return full 6v6 formation
	elseif Config.TeamSize == 4 then
		-- Get appropriate adjustments based on formation type
		local adjustments
		if formationType == FormationType.Attacking then
			adjustments = ADJUSTMENTS_4V4_ATTACKING
		elseif formationType == FormationType.Defensive then
			adjustments = ADJUSTMENTS_4V4_DEFENSIVE
		else
			adjustments = ADJUSTMENTS_4V4
		end

		-- Filter out excluded roles and apply position adjustments
		local filtered = {}
		for _, positionData in ipairs(formation) do
			local isExcluded = false
			for _, excludedRole in ipairs(EXCLUDED_4V4_ROLES) do
				if positionData.Role == excludedRole then
					isExcluded = true
					break
				end
			end

			if not isExcluded then
				-- Apply position adjustment if exists
				local adjusted = {
					Role = positionData.Role,
					Name = positionData.Name,
					ShortName = positionData.ShortName,
					Position = adjustments[positionData.Role] or positionData.Position
				}
				table.insert(filtered, adjusted)
			end
		end
		return filtered
	else
		warn("[FormationData] Invalid TeamSize: " .. tostring(Config.TeamSize))
		return formation
	end
end

-- Get the current formation (defaults to Neutral)
function FormationData.GetFormation(formationType)
	formationType = formationType or FormationType.Neutral

	local baseFormation
	if formationType == FormationType.Attacking then
		baseFormation = ATTACKING_FORMATION
	elseif formationType == FormationType.Defensive then
		baseFormation = DEFENSIVE_FORMATION
	else
		baseFormation = NEUTRAL_FORMATION
	end

	return FilterFormationByTeamSize(baseFormation, formationType)
end

-- Get formation by name (string)
function FormationData.GetFormationByName(name)
	local baseFormation
	local formationType
	if name == "Attacking" then
		baseFormation = ATTACKING_FORMATION
		formationType = FormationType.Attacking
	elseif name == "Defensive" then
		baseFormation = DEFENSIVE_FORMATION
		formationType = FormationType.Defensive
	else
		baseFormation = NEUTRAL_FORMATION
		formationType = FormationType.Neutral
	end

	return FilterFormationByTeamSize(baseFormation, formationType)
end

-- Get the default (neutral) formation
function FormationData.GetDefaultFormation()
	return FilterFormationByTeamSize(NEUTRAL_FORMATION, FormationType.Neutral)
end

-- Get total number of players per team based on configuration
function FormationData.GetPositionCount()
	return Config.TeamSize
end

-- Set team size (4 or 6)
function FormationData.SetTeamSize(size)
	if size ~= 4 and size ~= 6 then
		warn("[FormationData] Invalid team size: " .. tostring(size) .. ". Must be 4 or 6.")
		return false
	end
	Config.TeamSize = size
	print(string.format("[FormationData] Team size set to %dv%d", size, size))
	return true
end

-- Get current team size
function FormationData.GetTeamSize()
	return Config.TeamSize
end

-- Get a specific position by role from a formation
function FormationData.GetPositionByRole(role, formationType)
	local formation = FormationData.GetFormation(formationType)

	for _, positionData in ipairs(formation) do
		if positionData.Role == role then
			return positionData
		end
	end
	return nil
end

-- Get all role names
function FormationData.GetAllRoles()
	local roles = {}
	for _, positionData in ipairs(NEUTRAL_FORMATION) do
		table.insert(roles, positionData.Role)
	end
	return roles
end

-- Get formation type enum (for external use)
function FormationData.GetFormationTypes()
	return FormationType
end

return FormationData
