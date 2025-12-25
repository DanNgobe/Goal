--[[
	FormationData.lua
	Defines the 6v6 formation layouts with multiple tactical formations.
	
	Formations:
	- NEUTRAL: Default formation, everyone in own half (used at kickoff and when no possession)
	- ATTACKING: Pushed forward (used when team has ball)
	- DEFENSIVE: Deep and compact (used when opponent has ball)
	
	Formation Layout (6v6):
	                    [GOAL]
	                      GK
	          		LB        RB
	          LW                    RW
	                     ST
	
	Positions are relative offsets from team's center point.
	X axis: Left (-) to Right (+)
	Z axis: Back (-) to Forward (+) relative to own goal
]]

local FormationData = {}

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
function FormationData.GetDefaultFormation()
	return NEUTRAL_FORMATION
end

-- Get total number of players per team
function FormationData.GetPositionCount()
	return #NEUTRAL_FORMATION  -- All formations have same count
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
