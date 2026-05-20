--[[
	IntermissionUI.lua
	Premium intermission screens for goals and match ends.
	
	Aesthetics:
	- Glassmorphism & Blurs
	- Animated Shimmer Gradients
	- Smooth Spring-like Tweens
]]

local IntermissionUI = {}

-- Services
local TweenService = game:GetService("TweenService")

-- Load TeamHelper
local TeamHelper = require(script.Parent.Parent.Utils:WaitForChild("TeamHelper"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

-- UI Elements
local ScreenGui = nil
local MainFrame = nil
local TitleLabel = nil
local SubLabel = nil
local FlagLabel = nil
local Shimmer = nil

-- Create the UI
function IntermissionUI.Initialize(parentGui)
	ScreenGui = parentGui
	
	-- Main Container (Glassmorphism effect)
	MainFrame = Instance.new("Frame")
	MainFrame.Name = "IntermissionContainer"
	MainFrame.Size = UDim2.new(0.6, 0, 0, 140)
	MainFrame.Position = UDim2.new(0.2, 0, -0.3, 0) -- Starts off-screen
	MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MainFrame.BackgroundTransparency = 0.4
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	MainFrame.Visible = false
	MainFrame.Parent = ScreenGui

	local blur = Instance.new("UICorner")
	blur.CornerRadius = UDim.new(0, 20)
	blur.Parent = MainFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.6
	stroke.Parent = MainFrame

	-- Shimmer Gradient Effect
	Shimmer = Instance.new("Frame")
	Shimmer.Name = "Shimmer"
	Shimmer.Size = UDim2.new(2, 0, 1, 0)
	Shimmer.Position = UDim2.new(-1, 0, 0, 0)
	Shimmer.BackgroundTransparency = 1
	Shimmer.Parent = MainFrame
	
	local shimmerGradient = Instance.new("UIGradient")
	shimmerGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)),
		ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
	}
	shimmerGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1)
	}
	shimmerGradient.Rotation = 15
	shimmerGradient.Parent = Shimmer

	-- Flag Label (Large flag icon)
	FlagLabel = Instance.new("TextLabel")
	FlagLabel.Name = "Flag"
	FlagLabel.Size = UDim2.new(1, 0, 0.4, 0)
	FlagLabel.Position = UDim2.new(0, 0, 0.05, 0)
	FlagLabel.BackgroundTransparency = 1
	FlagLabel.Font = Enum.Font.GothamBold
	FlagLabel.TextScaled = true
	FlagLabel.Text = "🇧🇷"
	FlagLabel.Parent = MainFrame

	-- Title (e.g., GOAL!)
	TitleLabel = Instance.new("TextLabel")
	TitleLabel.Name = "Title"
	TitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	TitleLabel.Position = UDim2.new(0, 0, 0.35, 0)
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Font = Enum.Font.GothamBold
	TitleLabel.TextScaled = true
	TitleLabel.TextColor3 = Color3.new(1, 1, 1)
	TitleLabel.Text = "GOAL!"
	TitleLabel.Parent = MainFrame
	
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 4
	titleStroke.Color = Color3.new(0, 0, 0)
	titleStroke.Parent = TitleLabel

	-- Subtitle (e.g., PLAYER NAME SCORED)
	SubLabel = Instance.new("TextLabel")
	SubLabel.Name = "Subtitle"
	SubLabel.Size = UDim2.new(1, 0, 0.2, 0)
	SubLabel.Position = UDim2.new(0, 0, 0.75, 0)
	SubLabel.BackgroundTransparency = 1
	SubLabel.Font = Enum.Font.GothamMedium
	SubLabel.TextScaled = true
	SubLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
	SubLabel.Text = "BRAZIL SCORED!"
	SubLabel.Parent = MainFrame
end

-- Show Goal Celebration
function IntermissionUI.ShowGoal(scoringTeam)
	if not MainFrame then return end
	
	local color = TeamHelper.GetTeamColor(scoringTeam)
	local lightColor = TeamHelper.GetLightTeamColor(scoringTeam)
	local flag = TeamHelper.GetTeamFlag(scoringTeam)
	local teamName = TeamHelper.GetTeamName(scoringTeam)
	
	FlagLabel.Text = flag
	TitleLabel.Text = "GOAL!"
	TitleLabel.TextColor3 = lightColor
	
	-- We use the team name for now, player name can be passed later
	SubLabel.Text = teamName:upper() .. " SCORED!"
	SubLabel.TextColor3 = Color3.new(1, 1, 1)
	
	-- Slide down and fade in
	MainFrame.Visible = true
	MainFrame.Position = UDim2.new(0.2, 0, -0.3, 0)
	MainFrame.BackgroundTransparency = 1
	
	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(MainFrame, tweenInfo, {
		Position = UDim2.new(0.2, 0, 0.1, 0),
		BackgroundTransparency = 0.4
	}):Play()
	
	-- Animate Shimmer
	task.spawn(function()
		while MainFrame.Visible do
			Shimmer.Position = UDim2.new(-1.5, 0, 0, 0)
			local shimTween = TweenService:Create(Shimmer, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {
				Position = UDim2.new(1.5, 0, 0, 0)
			})
			shimTween:Play()
			shimTween.Completed:Wait()
			task.wait(1)
		end
	end)
end

-- Show Match End
function IntermissionUI.ShowMatchEnd(winnerText)
	if not MainFrame then return end
	
	TitleLabel.Text = "🏁 FULL TIME 🏁"
	TitleLabel.TextColor3 = Color3.new(1, 0.8, 0) -- Gold
	SubLabel.Text = winnerText or "THE MATCH HAS ENDED"
	
	-- Play full-time whistle
	MainFrame.Visible = true
	TweenService:Create(MainFrame, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.1, 0, 0.3, 0),
		Size = UDim2.new(0.8, 0, 0, 200),
		BackgroundTransparency = 0.2
	}):Play()
end

-- Hide the screen
function IntermissionUI.Hide()
	if not MainFrame then return end
	
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local t = TweenService:Create(MainFrame, tweenInfo, {
		Position = UDim2.new(0.2, 0, -0.3, 0),
		BackgroundTransparency = 1
	})
	t:Play()
	t.Completed:Connect(function()
		MainFrame.Visible = false
	end)
end

return IntermissionUI
