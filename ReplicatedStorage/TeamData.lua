--[[
	TeamData.lua
	Shared module for team/country definitions
	
	Used by both server and client to maintain consistent team data
]]

local TeamData = {}

-- Country Team Definitions
TeamData.Countries = {
	-- South American Teams
	BRA = {
		Name = "Brazil",
		Code = "BRA",
		PrimaryColor = Color3.fromRGB(255, 220, 0),  -- Yellow
		SecondaryColor = Color3.fromRGB(0, 100, 40),  -- Green
		ShortsColor = Color3.fromRGB(30, 70, 200),    -- Blue
		SocksColor = Color3.fromRGB(255, 255, 255)    -- White
	},
	ARG = {
		Name = "Argentina",
		Code = "ARG",
		PrimaryColor = Color3.fromRGB(115, 195, 230), -- Light Blue
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(20, 20, 30),     -- Black
		SocksColor = Color3.fromRGB(255, 255, 255)    -- White
	},
	URU = {
		Name = "Uruguay",
		Code = "URU",
		PrimaryColor = Color3.fromRGB(85, 165, 220),  -- Sky Blue
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(20, 20, 40),     -- Black
		SocksColor = Color3.fromRGB(20, 20, 40)       -- Black
	},
	
	-- European Teams
	ENG = {
		Name = "England",
		Code = "ENG",
		PrimaryColor = Color3.fromRGB(255, 255, 255), -- White
		SecondaryColor = Color3.fromRGB(200, 30, 50), -- Red
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(255, 255, 255)    -- White
	},
	FRA = {
		Name = "France",
		Code = "FRA",
		PrimaryColor = Color3.fromRGB(30, 60, 140),   -- Navy Blue
		SecondaryColor = Color3.fromRGB(230, 30, 50), -- Red
		ShortsColor = Color3.fromRGB(30, 60, 140),    -- Navy Blue
		SocksColor = Color3.fromRGB(200, 30, 50)      -- Red
	},
	ESP = {
		Name = "Spain",
		Code = "ESP",
		PrimaryColor = Color3.fromRGB(200, 30, 40),   -- Red
		SecondaryColor = Color3.fromRGB(255, 200, 0), -- Gold
		ShortsColor = Color3.fromRGB(30, 40, 80),     -- Navy
		SocksColor = Color3.fromRGB(30, 40, 80)       -- Navy
	},
	GER = {
		Name = "Germany",
		Code = "GER",
		PrimaryColor = Color3.fromRGB(255, 255, 255), -- White
		SecondaryColor = Color3.fromRGB(20, 20, 20),  -- Black
		ShortsColor = Color3.fromRGB(20, 20, 20),     -- Black
		SocksColor = Color3.fromRGB(255, 255, 255)    -- White
	},
	ITA = {
		Name = "Italy",
		Code = "ITA",
		PrimaryColor = Color3.fromRGB(20, 70, 160),   -- Blue
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(20, 70, 160)      -- Blue
	},
	NED = {
		Name = "Netherlands",
		Code = "NED",
		PrimaryColor = Color3.fromRGB(255, 100, 30),  -- Orange
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(20, 20, 30),     -- Black
		SocksColor = Color3.fromRGB(255, 100, 30)     -- Orange
	},
	POR = {
		Name = "Portugal",
		Code = "POR",
		PrimaryColor = Color3.fromRGB(200, 30, 50),   -- Red
		SecondaryColor = Color3.fromRGB(0, 100, 60),  -- Green
		ShortsColor = Color3.fromRGB(200, 30, 50),    -- Red
		SocksColor = Color3.fromRGB(0, 100, 60)       -- Green
	},
	
	-- African Teams
	RSA = {
		Name = "South Africa",
		Code = "RSA",
		PrimaryColor = Color3.fromRGB(255, 200, 0),   -- Gold
		SecondaryColor = Color3.fromRGB(0, 110, 50),  -- Green
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(255, 200, 0)      -- Gold
	},
	NGA = {
		Name = "Nigeria",
		Code = "NGA",
		PrimaryColor = Color3.fromRGB(0, 130, 60),    -- Green
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(0, 130, 60)       -- Green
	},
	
	-- North American Teams
	USA = {
		Name = "United States",
		Code = "USA",
		PrimaryColor = Color3.fromRGB(255, 255, 255), -- White
		SecondaryColor = Color3.fromRGB(180, 30, 50), -- Red
		ShortsColor = Color3.fromRGB(30, 50, 120),    -- Blue
		SocksColor = Color3.fromRGB(180, 30, 50)      -- Red
	},
	MEX = {
		Name = "Mexico",
		Code = "MEX",
		PrimaryColor = Color3.fromRGB(0, 100, 60),    -- Green
		SecondaryColor = Color3.fromRGB(200, 30, 50), -- Red
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(200, 30, 50)      -- Red
	},
	
	-- Asian Teams
	JPN = {
		Name = "Japan",
		Code = "JPN",
		PrimaryColor = Color3.fromRGB(30, 50, 140),   -- Blue
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(30, 50, 140),    -- Blue
		SocksColor = Color3.fromRGB(30, 50, 140)      -- Blue
	},
	KOR = {
		Name = "South Korea",
		Code = "KOR",
		PrimaryColor = Color3.fromRGB(200, 30, 50),   -- Red
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(200, 30, 50),    -- Red
		SocksColor = Color3.fromRGB(200, 30, 50)      -- Red
	},
}

-- Get a team by code
function TeamData.GetTeam(code)
	return TeamData.Countries[code]
end

-- Get all team codes
function TeamData.GetAllCodes()
	local codes = {}
	for code, _ in pairs(TeamData.Countries) do
		table.insert(codes, code)
	end
	return codes
end

-- Get a random team code
function TeamData.GetRandomCode()
	local codes = TeamData.GetAllCodes()
	return codes[math.random(1, #codes)]
end

-- Get team colors for UI (returns primary color for main display)
function TeamData.GetDisplayColor(code)
	local team = TeamData.Countries[code]
	return team and team.PrimaryColor or Color3.fromRGB(128, 128, 128)
end

-- Get team colors for customization (shirt = primary, for consistency)
function TeamData.GetCustomizationColors(code)
	local team = TeamData.Countries[code]
	if not team then
		-- Default fallback
		return {
			ShirtColor = Color3.fromRGB(100, 100, 100),
			ShortsColor = Color3.fromRGB(80, 80, 80),
			SocksColor = Color3.fromRGB(255, 255, 255),
			BodyColor = Color3.fromRGB(255, 205, 180)
		}
	end
	
	return {
		ShirtColor = team.PrimaryColor,
		ShortsColor = team.ShortsColor,
		SocksColor = team.SocksColor,
		BodyColor = Color3.fromRGB(255, 205, 180)  -- Standard skin tone
	}
end

return TeamData
