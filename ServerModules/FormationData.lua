--[[
	FormationData.lua
	Defines the 5v5 formation layout with relative positions for each role.
	
	Formation Layout:
	                    [GOAL]
	                      GK
	          LB                    RB
	               LCM        RCM
	          LW                    RW
	                     ST
	
	Positions are relative offsets from team's center point.
	X axis: Left (-) to Right (+)
	Z axis: Back (-) to Forward (+)
]]

local FormationData = {}

-- 5v5 Formation Definition
-- Positions are PERCENTAGES (0 to 1) of field dimensions
-- X: 0 = center, -0.5 = far left, 0.5 = far right
-- Z: 0 = center, -0.45 = back (near goal), 0.45 = forward (opponent goal)
local FORMATION = {
	{
		Role = "GK",
		Name = "Goalkeeper",
		Position = Vector3.new(0, 0, -0.6),  -- Goalkeeper (close to goal)
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
		Role = "LCM",
		Name = "LeftCenterMid",
		Position = Vector3.new(-0.15, 0, -0.12),  -- Left midfielder
		ShortName = "LCM"
	},
	{
		Role = "RCM",
		Name = "RightCenterMid",
		Position = Vector3.new(0.15, 0, -0.12),  -- Right midfielder
		ShortName = "RCM"
	},
	{
		Role = "LW",
		Name = "LeftWing",
		Position = Vector3.new(-0.22, 0, 0.1),  -- Left winger
		ShortName = "LW"
	},
	{
		Role = "RW",
		Name = "RightWing",
		Position = Vector3.new(0.22, 0, 0.1),  -- Right winger
		ShortName = "RW"
	},
	{
		Role = "ST",
		Name = "Striker",
		Position = Vector3.new(0, 0, 0.28),  -- Striker (forward)
		ShortName = "ST"
	}
}

-- Get the formation table
function FormationData.GetFormation()
	return FORMATION
end

-- Get total number of players per team
function FormationData.GetPositionCount()
	return #FORMATION
end

-- Get a specific position by role
function FormationData.GetPositionByRole(role)
	for _, positionData in ipairs(FORMATION) do
		if positionData.Role == role then
			return positionData
		end
	end
	return nil
end

-- Get all role names
function FormationData.GetAllRoles()
	local roles = {}
	for _, positionData in ipairs(FORMATION) do
		table.insert(roles, positionData.Role)
	end
	return roles
end

return FormationData
