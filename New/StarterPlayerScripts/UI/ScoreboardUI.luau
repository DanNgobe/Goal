--[[
	ScoreboardUI.lua
	Creates and manages the scoreboard display.
]]

local ScoreboardUI = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("ScoreboardUI")

-- Load TeamHelper
local TeamHelper = require(script.Parent.Parent.Utils:WaitForChild("TeamHelper"))

-- UI Elements
local ScoreboardFrame = nil
local HomeScoreLabel = nil
local AwayScoreLabel = nil
local TimerLabel = nil

-- Current state
local CurrentHomeScore = 0
local CurrentAwayScore = 0

-- Create the scoreboard UI
function ScoreboardUI.Create(parent)
	-- Scoreboard Frame (half-circle design)
	ScoreboardFrame = Instance.new("Frame")
	ScoreboardFrame.Name = "Scoreboard"
	ScoreboardFrame.Size = UDim2.new(0, 200, 0, 50)
	ScoreboardFrame.Position = UDim2.new(0.5, -100, 0, 0)
	ScoreboardFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	ScoreboardFrame.BackgroundTransparency = 0.15
	ScoreboardFrame.BorderSizePixel = 0
	ScoreboardFrame.Parent = parent

	-- Rounded bottom corners only (half-circle effect)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 25)
	corner.Parent = ScoreboardFrame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
	}
	gradient.Rotation = 90
	gradient.Parent = ScoreboardFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 180, 180)
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = ScoreboardFrame

	-- HomeTeam Score Label (left side)
	HomeScoreLabel = Instance.new("TextLabel")
	HomeScoreLabel.Name = "HomeScore"
	HomeScoreLabel.Size = UDim2.new(0, 50, 0, 35)
	HomeScoreLabel.Position = UDim2.new(0, 10, 0.5, -17.5)
	HomeScoreLabel.BackgroundColor3 = TeamHelper.GetTeamColor("HomeTeam")
	HomeScoreLabel.BackgroundTransparency = 0.2
	HomeScoreLabel.BorderSizePixel = 0
	HomeScoreLabel.Font = Enum.Font.GothamBold
	HomeScoreLabel.TextSize = 24
	HomeScoreLabel.TextColor3 = Color3.new(1, 1, 1)
	HomeScoreLabel.Text = "0"
	HomeScoreLabel.Parent = ScoreboardFrame

	local homeCorner = Instance.new("UICorner")
	homeCorner.CornerRadius = UDim.new(0, 8)
	homeCorner.Parent = HomeScoreLabel

	local homeStroke = Instance.new("UIStroke")
	homeStroke.Color = TeamHelper.GetLightTeamColor("HomeTeam")
	homeStroke.Thickness = 2
	homeStroke.Parent = HomeScoreLabel

	-- Timer Label (center)
	TimerLabel = Instance.new("TextLabel")
	TimerLabel.Name = "Timer"
	TimerLabel.Size = UDim2.new(0, 70, 0, 35)
	TimerLabel.Position = UDim2.new(0.5, -35, 0.5, -17.5)
	TimerLabel.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	TimerLabel.BackgroundTransparency = 0
	TimerLabel.BorderSizePixel = 0
	TimerLabel.Font = Enum.Font.GothamBold
	TimerLabel.TextSize = 18
	TimerLabel.TextColor3 = Color3.fromRGB(20, 20, 30)
	TimerLabel.Text = "5:00"
	TimerLabel.Parent = ScoreboardFrame

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0, 8)
	timerCorner.Parent = TimerLabel

	-- AwayTeam Score Label (right side)
	AwayScoreLabel = Instance.new("TextLabel")
	AwayScoreLabel.Name = "AwayScore"
	AwayScoreLabel.Size = UDim2.new(0, 50, 0, 35)
	AwayScoreLabel.Position = UDim2.new(1, -60, 0.5, -17.5)
	AwayScoreLabel.BackgroundColor3 = TeamHelper.GetTeamColor("AwayTeam")
	AwayScoreLabel.BackgroundTransparency = 0.2
	AwayScoreLabel.BorderSizePixel = 0
	AwayScoreLabel.Font = Enum.Font.GothamBold
	AwayScoreLabel.TextSize = 24
	AwayScoreLabel.TextColor3 = Color3.new(1, 1, 1)
	AwayScoreLabel.Text = "0"
	AwayScoreLabel.Parent = ScoreboardFrame

	local awayCorner = Instance.new("UICorner")
	awayCorner.CornerRadius = UDim.new(0, 8)
	awayCorner.Parent = AwayScoreLabel

	local awayStroke = Instance.new("UIStroke")
	awayStroke.Color = TeamHelper.GetLightTeamColor("AwayTeam")
	awayStroke.Thickness = 2
	awayStroke.Parent = AwayScoreLabel

	return ScoreboardFrame
end

-- Update scores with animation
function ScoreboardUI.UpdateScores(homeScore, awayScore)
	CurrentHomeScore = homeScore
	CurrentAwayScore = awayScore

	HomeScoreLabel.Text = tostring(homeScore)
	AwayScoreLabel.Text = tostring(awayScore)

	-- Animate score change
	local targetLabel = nil
	if homeScore > awayScore then
		targetLabel = HomeScoreLabel
	elseif awayScore > homeScore then
		targetLabel = AwayScoreLabel
	end

	if targetLabel then
		local originalSize = targetLabel.Size
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
		local tween = TweenService:Create(targetLabel, tweenInfo, {
			Size = UDim2.new(0, originalSize.X.Offset * 1.15, 0, originalSize.Y.Offset * 1.15)
		})
		tween:Play()
		tween.Completed:Connect(function()
			local tweenBack = TweenService:Create(targetLabel, TweenInfo.new(0.2), {
				Size = originalSize
			})
			tweenBack:Play()
		end)
	end
end

-- Update timer display
function ScoreboardUI.UpdateTimer(timeRemaining)
	local minutes = math.floor(timeRemaining / 60)
	local seconds = timeRemaining % 60
	TimerLabel.Text = string.format("%d:%02d", minutes, seconds)

	-- Change color based on time remaining
	if timeRemaining <= 60 then
		TimerLabel.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
		TimerLabel.TextColor3 = Color3.new(1, 1, 1)
	elseif timeRemaining <= 120 then
		TimerLabel.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
		TimerLabel.TextColor3 = Color3.fromRGB(20, 20, 30)
	else
		TimerLabel.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
		TimerLabel.TextColor3 = Color3.fromRGB(20, 20, 30)
	end
end

-- Update team colors (called when teams change)
function ScoreboardUI.UpdateTeamColors()
	if HomeScoreLabel then
		HomeScoreLabel.BackgroundColor3 = TeamHelper.GetTeamColor("HomeTeam")
		local homeStroke = HomeScoreLabel:FindFirstChildOfClass("UIStroke")
		if homeStroke then
			homeStroke.Color = TeamHelper.GetLightTeamColor("HomeTeam")
		end
	end

	if AwayScoreLabel then
		AwayScoreLabel.BackgroundColor3 = TeamHelper.GetTeamColor("AwayTeam")
		local awayStroke = AwayScoreLabel:FindFirstChildOfClass("UIStroke")
		if awayStroke then
			awayStroke.Color = TeamHelper.GetLightTeamColor("AwayTeam")
		end
	end

	Logger:debug("Updated team colors")
end

return ScoreboardUI
