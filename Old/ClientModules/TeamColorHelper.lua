--[[
	TeamColorHelper.lua
	Client-side helper to get current match team colors
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamData = require(ReplicatedStorage:WaitForChild("TeamData"))
local TeamColorHelper = {}

-- Cache for team colors
local CurrentTeamColors = {
	HomeTeam = nil,
	AwayTeam = nil
}

-- Callbacks for when teams change
local TeamChangeCallbacks = {}

-- Wait for match teams to be set
local function WaitForMatchTeams()
	local matchTeamsFolder = ReplicatedStorage:WaitForChild("MatchTeams", 10)
	if not matchTeamsFolder then
		warn("[TeamColorHelper] MatchTeams folder not found, using defaults")
		return false
	end
	
	local homeValue = matchTeamsFolder:WaitForChild("HomeTeam", 5)
	local awayValue = matchTeamsFolder:WaitForChild("AwayTeam", 5)
	
	if homeValue and awayValue then
		CurrentTeamColors.HomeTeam = TeamData.GetDisplayColor(homeValue.Value)
		CurrentTeamColors.AwayTeam = TeamData.GetDisplayColor(awayValue.Value)
		
		-- Listen for changes
		homeValue:GetPropertyChangedSignal("Value"):Connect(function()
			CurrentTeamColors.HomeTeam = TeamData.GetDisplayColor(homeValue.Value)
			print(string.format("[TeamColorHelper] HomeTeam changed to %s", homeValue.Value))
			-- Notify callbacks
			for _, callback in ipairs(TeamChangeCallbacks) do
				callback()
			end
		end)
		
		awayValue:GetPropertyChangedSignal("Value"):Connect(function()
			CurrentTeamColors.AwayTeam = TeamData.GetDisplayColor(awayValue.Value)
			print(string.format("[TeamColorHelper] AwayTeam changed to %s", awayValue.Value))
			-- Notify callbacks
			for _, callback in ipairs(TeamChangeCallbacks) do
				callback()
			end
		end)
		
		return true
	end
	
	return false
end

-- Initialize
function TeamColorHelper.Initialize()
	if not WaitForMatchTeams() then
		-- Use defaults if not available
		CurrentTeamColors.HomeTeam = Color3.fromRGB(0, 100, 255)  -- Blue
		CurrentTeamColors.AwayTeam = Color3.fromRGB(255, 50, 50)   -- Red
	end
	
	print(string.format("[TeamColorHelper] Initialized with colors: Home=%s, Away=%s", 
		tostring(CurrentTeamColors.HomeTeam), 
		tostring(CurrentTeamColors.AwayTeam)))
end

-- Get team color
function TeamColorHelper.GetTeamColor(teamName)
	return CurrentTeamColors[teamName] or Color3.fromRGB(128, 128, 128)
end

-- Get lighter version of team color (for strokes/highlights)
function TeamColorHelper.GetLightTeamColor(teamName)
	local color = TeamColorHelper.GetTeamColor(teamName)
	local r = math.min(255, color.R * 255 + 70)
	local g = math.min(255, color.G * 255 + 70)
	local b = math.min(255, color.B * 255 + 70)
	return Color3.fromRGB(r, g, b)
end

-- Get team name from code
function TeamColorHelper.GetTeamName(teamName)
	local matchTeamsFolder = ReplicatedStorage:FindFirstChild("MatchTeams")
	if not matchTeamsFolder then
		return teamName == "HomeTeam" and "Home" or "Away"
	end
	
	local codeValue = matchTeamsFolder:FindFirstChild(teamName)
	if not codeValue then
		return teamName == "HomeTeam" and "Home" or "Away"
	end
	
	local teamData = TeamData.GetTeam(codeValue.Value)
	return teamData and teamData.Name or teamName
end

-- Register a callback for when teams change
function TeamColorHelper.OnTeamsChange(callback)
	table.insert(TeamChangeCallbacks, callback)
end

return TeamColorHelper
