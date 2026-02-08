--[[
	IntermissionUI.lua
	Creates and manages intermission screens (goals, match end).
]]

local IntermissionUI = {}

local TweenService = game:GetService("TweenService")

-- UI Elements
local IntermissionFrame = nil
local GoalText = nil
local SubText = nil

-- Create the intermission UI
function IntermissionUI.Create(parent)
	IntermissionFrame = Instance.new("Frame")
	IntermissionFrame.Name = "Intermission"
	IntermissionFrame.Size = UDim2.new(0.4, 0, 0.25, 0)
	IntermissionFrame.Position = UDim2.new(0.3, 0, 0.375, 0)
	IntermissionFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	IntermissionFrame.BackgroundTransparency = 0.1
	IntermissionFrame.BorderSizePixel = 0
	IntermissionFrame.Visible = false
	IntermissionFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent = IntermissionFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 4
	stroke.Parent = IntermissionFrame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
	}
	gradient.Rotation = 45
	gradient.Parent = IntermissionFrame

	-- Goal Text
	GoalText = Instance.new("TextLabel")
	GoalText.Name = "GoalText"
	GoalText.Size = UDim2.new(0.9, 0, 0.5, 0)
	GoalText.Position = UDim2.new(0.05, 0, 0.15, 0)
	GoalText.BackgroundTransparency = 1
	GoalText.Font = Enum.Font.GothamBold
	GoalText.TextScaled = true
	GoalText.TextColor3 = Color3.new(1, 1, 1)
	GoalText.Text = "⚽ GOAL!"
	GoalText.Parent = IntermissionFrame

	local goalStroke = Instance.new("UIStroke")
	goalStroke.Color = Color3.new(0, 0, 0)
	goalStroke.Thickness = 4
	goalStroke.Parent = GoalText

	-- Sub Text
	SubText = Instance.new("TextLabel")
	SubText.Name = "SubText"
	SubText.Size = UDim2.new(0.9, 0, 0.25, 0)
	SubText.Position = UDim2.new(0.05, 0, 0.68, 0)
	SubText.BackgroundTransparency = 1
	SubText.Font = Enum.Font.Gotham
	SubText.TextScaled = true
	SubText.TextColor3 = Color3.fromRGB(255, 215, 0)
	SubText.Text = "Blue Team Scored!"
	SubText.Parent = IntermissionFrame

	local subStroke = Instance.new("UIStroke")
	subStroke.Color = Color3.new(0, 0, 0)
	subStroke.Thickness = 2
	subStroke.Parent = SubText

	return IntermissionFrame
end

-- Show goal celebration
function IntermissionUI.ShowGoal(scoringTeam)
	local teamColor = scoringTeam == "Blue" and Color3.fromRGB(30, 130, 255) or Color3.fromRGB(255, 60, 60)
	
	GoalText.TextColor3 = teamColor
	GoalText.Text = "⚽ GOAL! ⚽"
	SubText.Text = string.format("%s TEAM SCORED!", scoringTeam:upper())
	SubText.TextColor3 = teamColor

	IntermissionFrame.Visible = true
	IntermissionFrame.BackgroundTransparency = 1
	GoalText.TextTransparency = 1
	SubText.TextTransparency = 1

	-- Fade in animation
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeIn = TweenService:Create(IntermissionFrame, tweenInfo, {
		BackgroundTransparency = 0.1
	})
	local textFadeIn = TweenService:Create(GoalText, tweenInfo, {
		TextTransparency = 0
	})
	local subFadeIn = TweenService:Create(SubText, tweenInfo, {
		TextTransparency = 0
	})

	fadeIn:Play()
	textFadeIn:Play()
	subFadeIn:Play()

	-- Hide after 4 seconds
	task.spawn(function()
		task.wait(4)

		local fadeOut = TweenService:Create(IntermissionFrame, tweenInfo, {
			BackgroundTransparency = 1
		})
		local textFadeOut = TweenService:Create(GoalText, tweenInfo, {
			TextTransparency = 1
		})
		local subFadeOut = TweenService:Create(SubText, tweenInfo, {
			TextTransparency = 1
		})

		fadeOut:Play()
		textFadeOut:Play()
		subFadeOut:Play()

		fadeOut.Completed:Connect(function()
			IntermissionFrame.Visible = false
		end)
	end)
end

-- Show match end screen
function IntermissionUI.ShowMatchEnd(winningTeam, blueScore, redScore)
	local winnerText = ""
	local winnerColor = Color3.new(1, 1, 1)

	if winningTeam == "Blue" then
		winnerText = "🏆 BLUE TEAM WINS! 🏆"
		winnerColor = Color3.fromRGB(30, 130, 255)
	elseif winningTeam == "Red" then
		winnerText = "🏆 RED TEAM WINS! 🏆"
		winnerColor = Color3.fromRGB(255, 60, 60)
	else
		winnerText = "⚖️ DRAW! ⚖️"
		winnerColor = Color3.fromRGB(255, 215, 0)
	end

	GoalText.TextColor3 = winnerColor
	GoalText.Text = winnerText
	SubText.Text = string.format("Final Score: %d - %d", blueScore, redScore)
	SubText.TextColor3 = Color3.fromRGB(255, 255, 255)

	IntermissionFrame.Visible = true
	IntermissionFrame.BackgroundTransparency = 0.1
	GoalText.TextTransparency = 0
	SubText.TextTransparency = 0
end

-- Hide intermission screen
function IntermissionUI.Hide()
	IntermissionFrame.Visible = false
end

-- Show custom message
function IntermissionUI.ShowMessage(message, duration, color)
	duration = duration or 2
	color = color or Color3.new(1, 1, 1)

	GoalText.TextColor3 = color
	GoalText.Text = message
	SubText.Text = ""
	IntermissionFrame.Visible = true

	task.spawn(function()
		task.wait(duration)
		IntermissionFrame.Visible = false
	end)
end

return IntermissionUI
