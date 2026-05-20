--[[
	MatchIntroUI.lua (IMPROVED VERSION)
	Full-screen intro showing the match matchup (Team A vs Team B).
	
	FIXED:
	- Resolved partial tweening by tracking active tweens and using robust sequencing.
	- Pulsing now returns to fixed absolute positions.
]]

local MatchIntroUI = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamData = require(ReplicatedStorage:WaitForChild("TeamData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

-- UI Elements
local IntroFrame = nil
local HomePanel = nil
local AwayPanel = nil
local VSLabel = nil
local VSScale = nil

-- Animation State
local ActiveTweens = {}

local function CancelActiveTweens()
	for _, t in ipairs(ActiveTweens) do
		if t.PlaybackState == Enum.PlaybackState.Playing then
			t:Cancel()
		end
	end
	ActiveTweens = {}
end

local function PlayTween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	table.insert(ActiveTweens, t)
	t:Play()
	return t
end

-- Create the Match Intro UI
function MatchIntroUI.Create(parent)
	IntroFrame = Instance.new("Frame")
	IntroFrame.Name = "MatchIntro"
	IntroFrame.Size = UDim2.new(1, 0, 1, 0)
	IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	IntroFrame.BackgroundTransparency = 1
	IntroFrame.BorderSizePixel = 0
	IntroFrame.Visible = false
	IntroFrame.ZIndex = 100
	IntroFrame.Parent = parent

	-- Container for centered matchup
	local matchupContainer = Instance.new("Frame")
	matchupContainer.Name = "MatchupContainer"
	matchupContainer.Size = UDim2.new(1, 0, 0.5, 0)
	matchupContainer.Position = UDim2.new(0, 0, 0.25, 0)
	matchupContainer.BackgroundTransparency = 1
	matchupContainer.ZIndex = 5
	matchupContainer.Parent = IntroFrame

	-- Left Panel (Home)
	HomePanel = Instance.new("Frame")
	HomePanel.Name = "HomePanel"
	HomePanel.Size = UDim2.new(0.45, 0, 1, 0)
	HomePanel.Position = UDim2.new(-0.45, 0, 0, 0)
	HomePanel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	HomePanel.BorderSizePixel = 0
	HomePanel.ZIndex = 10
	HomePanel.Parent = matchupContainer

	local homeCorner = Instance.new("UICorner")
	homeCorner.CornerRadius = UDim.new(0, 12)
	homeCorner.Parent = HomePanel

	local homeGradient = Instance.new("UIGradient")
	homeGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0.6, 0.6, 0.6))
	}
	homeGradient.Rotation = 0
	homeGradient.Parent = HomePanel

	local homeFlag = Instance.new("TextLabel")
	homeFlag.Name = "Flag"
	homeFlag.Size = UDim2.new(0, 120, 0, 120)
	homeFlag.Position = UDim2.new(0.5, -60, 0.15, 0)
	homeFlag.BackgroundTransparency = 1
	homeFlag.Text = "🌍"
	homeFlag.Font = Enum.Font.GothamBold
	homeFlag.TextSize = 100
	homeFlag.ZIndex = 15
	homeFlag.Parent = HomePanel

	local homeLabel = Instance.new("TextLabel")
	homeLabel.Name = "TeamName"
	homeLabel.Size = UDim2.new(0.9, 0, 0.3, 0)
	homeLabel.Position = UDim2.new(0.05, 0, 0.55, 0)
	homeLabel.BackgroundTransparency = 1
	homeLabel.Font = Enum.Font.GothamBlack
	homeLabel.TextScaled = true
	homeLabel.TextColor3 = Color3.new(1, 1, 1)
	homeLabel.ZIndex = 15
	homeLabel.Parent = HomePanel

	local homeStroke = Instance.new("UIStroke")
	homeStroke.Thickness = 4
	homeStroke.Parent = homeLabel

	-- Right Panel (Away)
	AwayPanel = Instance.new("Frame")
	AwayPanel.Name = "AwayPanel"
	AwayPanel.Size = UDim2.new(0.45, 0, 1, 0)
	AwayPanel.Position = UDim2.new(1.45, 0, 0, 0)
	AwayPanel.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
	AwayPanel.AnchorPoint = Vector2.new(1, 0)
	AwayPanel.ZIndex = 11
	AwayPanel.Parent = matchupContainer

	local awayCorner = Instance.new("UICorner")
	awayCorner.CornerRadius = UDim.new(0, 12)
	awayCorner.Parent = AwayPanel

	local awayGradient = Instance.new("UIGradient")
	awayGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0.6, 0.6, 0.6)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
	}
	awayGradient.Rotation = 0
	awayGradient.Parent = AwayPanel

	local awayFlag = Instance.new("TextLabel")
	awayFlag.Name = "Flag"
	awayFlag.Size = UDim2.new(0, 120, 0, 120)
	awayFlag.Position = UDim2.new(0.5, -60, 0.15, 0)
	awayFlag.BackgroundTransparency = 1
	awayFlag.TextSize = 100
	awayFlag.ZIndex = 15
	awayFlag.Parent = AwayPanel

	local awayLabel = Instance.new("TextLabel")
	awayLabel.Name = "TeamName"
	awayLabel.Size = UDim2.new(0.9, 0, 0.3, 0)
	awayLabel.Position = UDim2.new(0.05, 0, 0.55, 0)
	awayLabel.BackgroundTransparency = 1
	awayLabel.Font = Enum.Font.GothamBlack
	awayLabel.TextScaled = true
	awayLabel.TextColor3 = Color3.new(1, 1, 1)
	awayLabel.ZIndex = 15
	awayLabel.Parent = AwayPanel

	local awayStroke = Instance.new("UIStroke")
	awayStroke.Thickness = 4
	awayStroke.Parent = awayLabel

	-- VS Label
	VSLabel = Instance.new("TextLabel")
	VSLabel.Name = "VS"
	VSLabel.Size = UDim2.new(0, 120, 0, 120)
	VSLabel.Position = UDim2.new(0.5, -60, 0.5, -60)
	VSLabel.BackgroundTransparency = 1
	VSLabel.Font = Enum.Font.GothamBlack
	VSLabel.Text = "VS"
	VSLabel.TextColor3 = Color3.new(1, 1, 1)
	VSLabel.TextSize = 70
	VSLabel.ZIndex = 110
	VSLabel.TextTransparency = 1
	VSLabel.Parent = matchupContainer

	local vsStroke = Instance.new("UIStroke")
	vsStroke.Thickness = 3
	vsStroke.Color = Color3.new(0, 0, 0)
	vsStroke.Parent = VSLabel

	VSScale = Instance.new("UIScale")
	VSScale.Parent = VSLabel

	return IntroFrame
end

-- Show the intro animation
function MatchIntroUI.Show(homeCode, awayCode)
	CancelActiveTweens()

	local homeData = TeamData.GetTeam(homeCode)
	local awayData = TeamData.GetTeam(awayCode)

	if not homeData or not awayData then return end

	-- Setup colors and text
	HomePanel.BackgroundColor3 = homeData.PrimaryColor
	HomePanel:FindFirstChild("Flag").Text = homeData.Flag or "🌍"
	HomePanel:FindFirstChild("TeamName").Text = homeData.Name:upper()
	HomePanel:FindFirstChild("TeamName"):FindFirstChild("UIStroke").Color = homeData.SecondaryColor

	AwayPanel.BackgroundColor3 = awayData.PrimaryColor
	AwayPanel:FindFirstChild("Flag").Text = awayData.Flag or "🌍"
	AwayPanel:FindFirstChild("TeamName").Text = awayData.Name:upper()
	AwayPanel:FindFirstChild("TeamName"):FindFirstChild("UIStroke").Color = awayData.SecondaryColor

	-- Reset positions
	HomePanel.Position = UDim2.new(-0.45, 0, 0, 0)
	AwayPanel.Position = UDim2.new(1.45, 0, 0, 0)
	VSLabel.TextTransparency = 1
	if VSScale then VSScale.Scale = 1 end

	IntroFrame.Visible = true

	-- 1. Primary Slide In
	local slideTime = 1.2
	local slideInfo = TweenInfo.new(slideTime, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	PlayTween(HomePanel, slideInfo, {Position = UDim2.new(0, 0, 0, 0)})
	PlayTween(AwayPanel, slideInfo, {Position = UDim2.new(1, 0, 0, 0)})

	-- 2. VS Appearance and Impact Pulse
	task.delay(slideTime - 0.4, function()
		-- Fade in VS
		PlayTween(VSLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
		
		-- Scale Pulse (VS)
		if VSScale then
			PlayTween(VSScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {Scale = 1.15})
		end

		-- IMPACT: Panels pulse outwards and return to FIXED target (prevents partial offset)
		local impactTime = 0.2
		local impactOut = TweenInfo.new(impactTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local impactReturn = TweenInfo.new(impactTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		-- Sequence: Out then Return to absolute center
		task.spawn(function()
			local t1H = PlayTween(HomePanel, impactOut, {Position = UDim2.new(-0.02, 0, 0, 0)})
			local t1A = PlayTween(AwayPanel, impactOut, {Position = UDim2.new(1.02, 0, 0, 0)})
			
			t1H.Completed:Wait()
			
			PlayTween(HomePanel, impactReturn, {Position = UDim2.new(0, 0, 0, 0)})
			PlayTween(AwayPanel, impactReturn, {Position = UDim2.new(1, 0, 0, 0)})
		end)
	end)

	-- 3. Exit sequence
	task.delay(4.5, function()
		local fadeOut = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
		PlayTween(HomePanel, fadeOut, {Position = UDim2.new(-0.45, 0, 0, 0)})
		PlayTween(AwayPanel, fadeOut, {Position = UDim2.new(1.45, 0, 0, 0)})
		PlayTween(VSLabel, fadeOut, {TextTransparency = 1})

		task.wait(1.0)
		IntroFrame.Visible = false
	end)
end

return MatchIntroUI