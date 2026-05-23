--[[
	FormationData.lua
	Defines the formation layouts for 5v5 soccer.
	
	Formations:
	- NEUTRAL: Default formation, everyone in own half (used at kickoff and when no possession)
	- ATTACKING: Pushed forward with WIDE wingers for passing options
	- DEFENSIVE: Deep and compact (used when opponent has ball)
	
	5v5 Formation Layout:
	                    [GOAL]
	                      GK  (stationary)
	                      DF 
	          LW                    RW
	                     ST
	
	Positions are relative offsets from team's center point.
	X axis: Left (-) to Right (+)
	Z axis: Back (-) to Forward (+) relative to own goal
]]

local FormationData = {}

-- Configuration
local Config = {
	TeamSize = 5  -- Fixed 5v5
}

-- NEUTRAL Formation (Default - Everyone in own half)
-- Used at kickoff and when no team has clear possession
-- Shape: GK + DF + LW + RW + ST (1-1-2-1 with wingers)
local NEUTRAL_FORMATION = {
	{
		Role = "GK",
		Name = "Goalkeeper",
		Position = Vector3.new(0, 0, -0.48),
		ShortName = "GK"
	},
	{
		Role = "DF",
		Name = "Defender",
		Position = Vector3.new(0, 0, -0.35),
		ShortName = "DF"
	},
	{
		Role = "LW",
		Name = "LeftWing",
		Position = Vector3.new(-0.18, 0, -0.2),  -- Moderate width
		ShortName = "LW"
	},
	{
		Role = "RW",
		Name = "RightWing",
		Position = Vector3.new(0.18, 0, -0.2),  -- Moderate width
		ShortName = "RW"
	},
	{
		Role = "ST",
		Name = "Striker",
		Position = Vector3.new(0, 0, -0.1),
		ShortName = "ST"
	}
}

-- NEUTRAL_ALT Formation (Away team default)
-- Shape: GK + LB + RB + CM + ST (2-1-1 flat back line, no wingers)
-- Gives the away team a visually distinct kickoff shape
local NEUTRAL_ALT_FORMATION = {
	{
		Role = "GK",
		Name = "Goalkeeper",
		Position = Vector3.new(0, 0, -0.48),
		ShortName = "GK"
	},
	{
		Role = "DF",
		Name = "LeftBack",
		Position = Vector3.new(-0.14, 0, -0.38),
		ShortName = "LB"
	},
	{
		Role = "LW",
		Name = "RightBack",
		Position = Vector3.new(0.14, 0, -0.38),
		ShortName = "RB"
	},
	{
		Role = "RW",
		Name = "CentreMid",
		Position = Vector3.new(0, 0, -0.22),
		ShortName = "CM"
	},
	{
		Role = "ST",
		Name = "Striker",
		Position = Vector3.new(0, 0, -0.07),
		ShortName = "ST"
	}
}

-- ATTACKING Formation (When team has possession)
-- Pushed forward with wider wingers to create passing lanes
local ATTACKING_FORMATION = {
	{
		Role = "GK",
		Name = "Goalkeeper",
		Position = Vector3.new(0, 0, -0.4),
		ShortName = "GK"
	},
	{
		Role = "DF",
		Name = "Defender",
		Position = Vector3.new(0, 0, -0.05),  -- Much further up to support attacks
		ShortName = "DF"
	},
	{
		Role = "LW",
		Name = "LeftWing",
		Position = Vector3.new(-0.25, 0, 0.25),  -- Wide and high up
		ShortName = "LW"
	},
	{
		Role = "RW",
		Name = "RightWing",
		Position = Vector3.new(0.25, 0, 0.25),  -- Wide and high up
		ShortName = "RW"
	},
	{
		Role = "ST",
		Name = "Striker",
		Position = Vector3.new(0, 0, 0.4),  -- Very high up the pitch
		ShortName = "ST"
	}
}

-- DEFENSIVE Formation (When opponent has possession)
-- Deep and compact to protect goal
local DEFENSIVE_FORMATION = {
	{
		Role = "GK",
		Name = "Goalkeeper",
		Position = Vector3.new(0, 0, -0.49),
		ShortName = "GK"
	},
	{
		Role = "DF",
		Name = "Defender",
		Position = Vector3.new(0, 0, -0.4),
		ShortName = "DF"
	},
	{
		Role = "LW",
		Name = "LeftWing",
		Position = Vector3.new(-0.2, 0, -0.25),
		ShortName = "LW"
	},
	{
		Role = "RW",
		Name = "RightWing",
		Position = Vector3.new(0.2, 0, -0.25),
		ShortName = "RW"
	},
	{
		Role = "ST",
		Name = "Striker",
		Position = Vector3.new(0, 0, -0.1),
		ShortName = "ST"
	}
}

-- Formation types
local FormationType = {
	Neutral = "Neutral",
	Attacking = "Attacking",
	Defensive = "Defensive"
}

-- Get the current formation (defaults to Neutral)
function FormationData.GetFormation(formationType)
	formationType = formationType or FormationType.Neutral

	if formationType == FormationType.Attacking then
		return ATTACKING_FORMATION
	elseif formationType == FormationType.Defensive then
		return DEFENSIVE_FORMATION
	else
		return NEUTRAL_FORMATION
	end
end

-- Get formation by name (string)
function FormationData.GetFormationByName(name)
	if name == "Attacking" then
		return ATTACKING_FORMATION
	elseif name == "Defensive" then
		return DEFENSIVE_FORMATION
	else
		return NEUTRAL_FORMATION
	end
end

-- Get the default (neutral) formation
-- Pass "AwayTeam" to get the alternate formation used by the away team
function FormationData.GetDefaultFormation(teamName)
	if teamName == "AwayTeam" then
		return NEUTRAL_ALT_FORMATION
	end
	return NEUTRAL_FORMATION
end

-- Get total number of players per team
function FormationData.GetPositionCount()
	return Config.TeamSize
end

-- Set team size (currently only 5 is supported)
function FormationData.SetTeamSize(size)
	if size ~= 5 then
		warn("[FormationData] Only 5v5 is currently supported. Requested: " .. tostring(size))
		return false
	end
	Config.TeamSize = size
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