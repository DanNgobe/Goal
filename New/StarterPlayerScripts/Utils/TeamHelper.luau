local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamData = require(ReplicatedStorage:WaitForChild("TeamData"))
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("TeamHelper")

local TeamHelper = {}

-- Cache for current match data
local CurrentTeams = {
	HomeTeam = {
		Color = Color3.fromRGB(0, 100, 255),
		Name = "Home",
		Flag = "🏳️"
	},
	AwayTeam = {
		Color = Color3.fromRGB(255, 50, 50),
		Name = "Away",
		Flag = "🏳️"
	}
}

-- Initialize and listen for team changes
function TeamHelper.Initialize()
	local matchTeams = ReplicatedStorage:WaitForChild("MatchTeams", 5)
	if not matchTeams then
		Logger:warn("MatchTeams folder not found, using defaults")
		return
	end
	
	local function updateTeams()
		for _, teamPin in ipairs({"HomeTeam", "AwayTeam"}) do
			local val = matchTeams:FindFirstChild(teamPin)
			if val and val:IsA("StringValue") and val.Value ~= "" then
				local data = TeamData.GetTeam(val.Value)
				if data then
					CurrentTeams[teamPin].Color = data.PrimaryColor
					CurrentTeams[teamPin].Name = data.Name
					CurrentTeams[teamPin].Flag = data.Flag or "🏳️"
				end
			end
		end
	end
	
	matchTeams.ChildAdded:Connect(updateTeams)
	updateTeams()
end

function TeamHelper.GetTeamColor(teamPin)
	return CurrentTeams[teamPin] and CurrentTeams[teamPin].Color or Color3.fromRGB(128, 128, 128)
end

function TeamHelper.GetLightTeamColor(teamPin)
	local color = TeamHelper.GetTeamColor(teamPin)
	return Color3.new(
		math.min(1, color.R + 0.3),
		math.min(1, color.G + 0.3),
		math.min(1, color.B + 0.3)
	)
end

function TeamHelper.GetTeamName(teamPin)
	return CurrentTeams[teamPin] and CurrentTeams[teamPin].Name or teamPin
end

function TeamHelper.GetTeamFlag(teamPin)
	return CurrentTeams[teamPin] and CurrentTeams[teamPin].Flag or "🏳️"
end

-- Helper to get text color based on background luminance
function TeamHelper.GetContrastColor(backgroundColor)
	local r, g, b = backgroundColor.R, backgroundColor.G, backgroundColor.B
	-- Simple luminance formula
	local luminance = (0.299 * r + 0.587 * g + 0.114 * b)
	return luminance > 0.6 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
end

return TeamHelper
