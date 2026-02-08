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
	-- Scoreboard Frame (top center, smaller and scalable)
	ScoreboardFrame = Instance.new("Frame")
	ScoreboardFrame.Name = "Scoreboard"
	ScoreboardFrame.Size = UDim2.new(0.3, 0, 0.1, 0)
	ScoreboardFrame.Position = UDim2.new(0.35, 0, 0.02, 0)
	ScoreboardFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	ScoreboardFrame.BackgroundTransparency = 0.15
	ScoreboardFrame.BorderSizePixel = 0
	ScoreboardFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
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

	-- Timer Label
	TimerLabel = Instance.new("TextLabel")
	TimerLabel.Name = "Timer"
	TimerLabel.Size = UDim2.new(0.28, 0, 0.32, 0)
	TimerLabel.Position = UDim2.new(0.36, 0, 0.08, 0)
	TimerLabel.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	TimerLabel.BackgroundTransparency = 0
	TimerLabel.BorderSizePixel = 0
	TimerLabel.Font = Enum.Font.GothamBold
	TimerLabel.TextScaled = true
	TimerLabel.TextColor3 = Color3.fromRGB(20, 20, 30)
	TimerLabel.Text = "5:00"
	TimerLabel.Parent = ScoreboardFrame

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0.25, 0)
	timerCorner.Parent = TimerLabel

	local timerPadding = Instance.new("UIPadding")
	timerPadding.PaddingLeft = UDim.new(0.1, 0)
	timerPadding.PaddingRight = UDim.new(0.1, 0)
	timerPadding.PaddingTop = UDim.new(0.15, 0)
	timerPadding.PaddingBottom = UDim.new(0.15, 0)
	timerPadding.Parent = TimerLabel

	-- Blue Score Label
	BlueScoreLabel = Instance.new("TextLabel")
	BlueScoreLabel.Name = "BlueScore"
	BlueScoreLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
	BlueScoreLabel.Position = UDim2.new(0.04, 0, 0.45, 0)
	BlueScoreLabel.BackgroundColor3 = Color3.fromRGB(30, 130, 255)
	BlueScoreLabel.BackgroundTransparency = 0.2
	BlueScoreLabel.BorderSizePixel = 0
	BlueScoreLabel.Font = Enum.Font.GothamBold
	BlueScoreLabel.TextScaled = true
	BlueScoreLabel.TextColor3 = Color3.new(1, 1, 1)
	BlueScoreLabel.Text = "0"
	BlueScoreLabel.Parent = ScoreboardFrame

	local blueCorner = Instance.new("UICorner")
	blueCorner.CornerRadius = UDim.new(0.2, 0)
	blueCorner.Parent = BlueScoreLabel

	local blueStroke = Instance.new("UIStroke")
	blueStroke.Color = Color3.fromRGB(100, 180, 255)
	blueStroke.Thickness = 2
	blueStroke.Parent = BlueScoreLabel

	local bluePadding = Instance.new("UIPadding")
	bluePadding.PaddingLeft = UDim.new(0.15, 0)
	bluePadding.PaddingRight = UDim.new(0.15, 0)
	bluePadding.PaddingTop = UDim.new(0.15, 0)
	bluePadding.PaddingBottom = UDim.new(0.15, 0)
	bluePadding.Parent = BlueScoreLabel

	-- VS Label
	local vsLabel = Instance.new("TextLabel")
	vsLabel.Name = "VS"
	vsLabel.Size = UDim2.new(0.16, 0, 0.35, 0)
	vsLabel.Position = UDim2.new(0.42, 0, 0.53, 0)
	vsLabel.BackgroundTransparency = 1
	vsLabel.Font = Enum.Font.GothamBold
	vsLabel.TextScaled = true
	vsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	vsLabel.Text = "VS"
	vsLabel.Parent = ScoreboardFrame

	local vsStroke = Instance.new("UIStroke")
	vsStroke.Color = Color3.fromRGB(0, 0, 0)
	vsStroke.Thickness = 2
	vsStroke.Parent = vsLabel

	-- Red Score Label
	RedScoreLabel = Instance.new("TextLabel")
	RedScoreLabel.Name = "RedScore"
	RedScoreLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
	RedScoreLabel.Position = UDim2.new(0.66, 0, 0.45, 0)
	RedScoreLabel.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	RedScoreLabel.BackgroundTransparency = 0.2
	RedScoreLabel.BorderSizePixel = 0
	RedScoreLabel.Font = Enum.Font.GothamBold
	RedScoreLabel.TextScaled = true
	RedScoreLabel.TextColor3 = Color3.new(1, 1, 1)
	RedScoreLabel.Text = "0"
	RedScoreLabel.Parent = ScoreboardFrame

	local redCorner = Instance.new("UICorner")
	redCorner.CornerRadius = UDim.new(0.2, 0)
	redCorner.Parent = RedScoreLabel

	local redStroke = Instance.new("UIStroke")
	redStroke.Color = Color3.fromRGB(255, 130, 130)
	redStroke.Thickness = 2
	redStroke.Parent = RedScoreLabel

	local redPadding = Instance.new("UIPadding")
	redPadding.PaddingLeft = UDim.new(0.15, 0)
	redPadding.PaddingRight = UDim.new(0.15, 0)
	redPadding.PaddingTop = UDim.new(0.15, 0)
	redPadding.PaddingBottom = UDim.new(0.15, 0)
	redPadding.Parent = RedScoreLabel

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
			Size = UDim2.new(originalSize.X.Scale * 1.15, 0, originalSize.Y.Scale * 1.15, 0)
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
	elseif timeRemaining <= 120 then
		TimerLabel.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	else
		TimerLabel.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	end
end

return ScoreboardUI
