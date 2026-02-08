--[[
	ScoreboardUI.lua
	Creates and manages the scoreboard display.
]]

local ScoreboardUI = {}

local TweenService = game:GetService("TweenService")

-- UI Elements
local ScoreboardFrame = nil
local BlueScoreLabel = nil
local RedScoreLabel = nil
local TimerLabel = nil

-- Current state
local CurrentBlueScore = 0
local CurrentRedScore = 0

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

	-- Blue Score Label (left side)
	BlueScoreLabel = Instance.new("TextLabel")
	BlueScoreLabel.Name = "BlueScore"
	BlueScoreLabel.Size = UDim2.new(0, 50, 0, 35)
	BlueScoreLabel.Position = UDim2.new(0, 10, 0.5, -17.5)
	BlueScoreLabel.BackgroundColor3 = Color3.fromRGB(30, 130, 255)
	BlueScoreLabel.BackgroundTransparency = 0.2
	BlueScoreLabel.BorderSizePixel = 0
	BlueScoreLabel.Font = Enum.Font.GothamBold
	BlueScoreLabel.TextSize = 24
	BlueScoreLabel.TextColor3 = Color3.new(1, 1, 1)
	BlueScoreLabel.Text = "0"
	BlueScoreLabel.Parent = ScoreboardFrame

	local blueCorner = Instance.new("UICorner")
	blueCorner.CornerRadius = UDim.new(0, 8)
	blueCorner.Parent = BlueScoreLabel

	local blueStroke = Instance.new("UIStroke")
	blueStroke.Color = Color3.fromRGB(100, 180, 255)
	blueStroke.Thickness = 2
	blueStroke.Parent = BlueScoreLabel

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

	-- Red Score Label (right side)
	RedScoreLabel = Instance.new("TextLabel")
	RedScoreLabel.Name = "RedScore"
	RedScoreLabel.Size = UDim2.new(0, 50, 0, 35)
	RedScoreLabel.Position = UDim2.new(1, -60, 0.5, -17.5)
	RedScoreLabel.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	RedScoreLabel.BackgroundTransparency = 0.2
	RedScoreLabel.BorderSizePixel = 0
	RedScoreLabel.Font = Enum.Font.GothamBold
	RedScoreLabel.TextSize = 24
	RedScoreLabel.TextColor3 = Color3.new(1, 1, 1)
	RedScoreLabel.Text = "0"
	RedScoreLabel.Parent = ScoreboardFrame

	local redCorner = Instance.new("UICorner")
	redCorner.CornerRadius = UDim.new(0, 8)
	redCorner.Parent = RedScoreLabel

	local redStroke = Instance.new("UIStroke")
	redStroke.Color = Color3.fromRGB(255, 130, 130)
	redStroke.Thickness = 2
	redStroke.Parent = RedScoreLabel

	return ScoreboardFrame
end

-- Update scores with animation
function ScoreboardUI.UpdateScores(blueScore, redScore)
	CurrentBlueScore = blueScore
	CurrentRedScore = redScore

	BlueScoreLabel.Text = tostring(blueScore)
	RedScoreLabel.Text = tostring(redScore)

	-- Animate score change
	local targetLabel = nil
	if blueScore > redScore then
		targetLabel = BlueScoreLabel
	elseif redScore > blueScore then
		targetLabel = RedScoreLabel
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

return ScoreboardUI
