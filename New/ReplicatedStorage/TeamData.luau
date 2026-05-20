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
		Flag = "🇧🇷",
		PrimaryColor = Color3.fromRGB(255, 220, 0),  -- Yellow
		SecondaryColor = Color3.fromRGB(0, 100, 40),  -- Green
		ShortsColor = Color3.fromRGB(30, 70, 200),    -- Blue
		SocksColor = Color3.fromRGB(255, 255, 255),    -- White
		TextureId = "rbxassetid://8875945327"
	},
	ARG = {
		Name = "Argentina",
		Code = "ARG",
		Flag = "🇦🇷",
		PrimaryColor = Color3.fromRGB(115, 195, 230), -- Light Blue
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(20, 20, 30),     -- Black
		SocksColor = Color3.fromRGB(255, 255, 255),    -- White
		TextureId = "rbxassetid://12124468537"
	},
	URU = {
		Name = "Uruguay",
		Code = "URU",
		Flag = "🇺🇾",
		PrimaryColor = Color3.fromRGB(85, 165, 220),  -- Sky Blue
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(20, 20, 40),     -- Black
		SocksColor = Color3.fromRGB(20, 20, 40),       -- Black
		TextureId = "rbxassetid://9633044262"
	},

	-- European Teams
	ENG = {
		Name = "England",
		Code = "ENG",
		Flag = "🏴󠁧󠁢󠁥󠁮󠁧󠁿",
		PrimaryColor = Color3.fromRGB(255, 255, 255), -- White
		SecondaryColor = Color3.fromRGB(200, 30, 50), -- Red
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(255, 255, 255),    -- White
		TextureId = "rbxassetid://82688212"
	},
	FRA = {
		Name = "France",
		Code = "FRA",
		Flag = "🇫🇷",
		PrimaryColor = Color3.fromRGB(30, 60, 140),   -- Navy Blue
		SecondaryColor = Color3.fromRGB(230, 30, 50), -- Red
		ShortsColor = Color3.fromRGB(30, 60, 140),    -- Navy Blue
		SocksColor = Color3.fromRGB(200, 30, 50),      -- Red
		TextureId = "rbxassetid://13539436075"
	},
	ESP = {
		Name = "Spain",
		Code = "ESP",
		Flag = "🇪🇸",
		PrimaryColor = Color3.fromRGB(200, 30, 40),   -- Red
		SecondaryColor = Color3.fromRGB(255, 200, 0), -- Gold
		ShortsColor = Color3.fromRGB(30, 40, 80),     -- Navy
		SocksColor = Color3.fromRGB(30, 40, 80),       -- Navy
		TextureId = "rbxassetid://6729418246"
	},
	GER = {
		Name = "Germany",
		Code = "GER",
		Flag = "🇩🇪",
		PrimaryColor = Color3.fromRGB(255, 255, 255), -- White
		SecondaryColor = Color3.fromRGB(20, 20, 20),  -- Black
		ShortsColor = Color3.fromRGB(20, 20, 20),     -- Black
		SocksColor = Color3.fromRGB(255, 255, 255),    -- White
		TextureId = "rbxassetid://6220915168"
	},
	ITA = {
		Name = "Italy",
		Code = "ITA",
		Flag = "🇮🇹",
		PrimaryColor = Color3.fromRGB(20, 70, 160),   -- Blue
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(20, 70, 160),      -- Blue
		TextureId = "rbxassetid://7801898291"
	},
	NED = {
		Name = "Netherlands",
		Code = "NED",
		Flag = "🇳🇱",
		PrimaryColor = Color3.fromRGB(255, 100, 30),  -- Orange
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(20, 20, 30),     -- Black
		SocksColor = Color3.fromRGB(255, 100, 30),     -- Orange
		TextureId = "rbxassetid://8120356264"
	},
	POR = {
		Name = "Portugal",
		Code = "POR",
		Flag = "🇵🇹",
		PrimaryColor = Color3.fromRGB(200, 30, 50),   -- Red
		SecondaryColor = Color3.fromRGB(0, 100, 60),  -- Green
		ShortsColor = Color3.fromRGB(200, 30, 50),    -- Red
		SocksColor = Color3.fromRGB(0, 100, 60),       -- Green
		TextureId = "rbxassetid://12221216855"
	},

	-- African Teams
	RSA = {
		Name = "South Africa",
		Code = "RSA",
		Flag = "🇿🇦",
		PrimaryColor = Color3.fromRGB(255, 200, 0),   -- Gold
		SecondaryColor = Color3.fromRGB(0, 110, 50),  -- Green
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(255, 200, 0),      -- Gold
		TextureId = "rbxassetid://14959587818"
	},
	NGA = {
		Name = "Nigeria",
		Code = "NGA",
		Flag = "🇳🇬",
		PrimaryColor = Color3.fromRGB(0, 130, 60),    -- Green
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(0, 130, 60),       -- Green
		TextureId = "rbxassetid://11858119964"
	},

	-- North American Teams
	USA = {
		Name = "United States",
		Code = "USA",
		Flag = "🇺🇸",
		PrimaryColor = Color3.fromRGB(255, 255, 255), -- White
		SecondaryColor = Color3.fromRGB(180, 30, 50), -- Red
		ShortsColor = Color3.fromRGB(30, 50, 120),    -- Blue
		SocksColor = Color3.fromRGB(180, 30, 50),      -- Red
		TextureId = "rbxassetid://7213809722"
	},
	MEX = {
		Name = "Mexico",
		Code = "MEX",
		Flag = "🇲🇽",
		PrimaryColor = Color3.fromRGB(0, 100, 60),    -- Green
		SecondaryColor = Color3.fromRGB(200, 30, 50), -- Red
		ShortsColor = Color3.fromRGB(255, 255, 255),  -- White
		SocksColor = Color3.fromRGB(200, 30, 50),      -- Red
		TextureId = "rbxassetid://1071314300"
	},

	-- Asian Teams
	JPN = {
		Name = "Japan",
		Code = "JPN",
		Flag = "🇯🇵",
		PrimaryColor = Color3.fromRGB(30, 50, 140),   -- Blue
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(30, 50, 140),    -- Blue
		SocksColor = Color3.fromRGB(30, 50, 140),      -- Blue
		TextureId = "rbxassetid://82331599408797"
	},
	KOR = {
		Name = "South Korea",
		Code = "KOR",
		Flag = "🇰🇷",
		PrimaryColor = Color3.fromRGB(200, 30, 50),   -- Red
		SecondaryColor = Color3.fromRGB(255, 255, 255), -- White
		ShortsColor = Color3.fromRGB(200, 30, 50),    -- Red
		SocksColor = Color3.fromRGB(200, 30, 50),      -- Red
		TextureId = "rbxassetid://8230893525"
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
