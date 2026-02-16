--[[
	MatchIntroUI.lua (IMPROVED VERSION)
	Full-screen intro showing the match matchup (Team A vs Team B).
	
	IMPROVEMENTS:
	- Large, prominent country names
	- Centered design that avoids Roblox's top control bar
	- Maintained beautiful gradient effects
	- Rounded corners for modern look
	- Better flag display
]]

local MatchIntroUI = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamData = require(ReplicatedStorage:WaitForChild("TeamData"))
local SoundData = require(ReplicatedStorage:WaitForChild("SoundData"))

-- UI Elements
local IntroFrame = nil
local HomePanel = nil
local AwayPanel = nil
local VSLabel = nil
local VSScale = nil

-- Sounds
local function PlaySound(id, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 5)
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

	-- No overlay needed - let the colors shine through

	-- Container for centered matchup (avoids top control bar area)
	local matchupContainer = Instance.new("Frame")
	matchupContainer.Name = "MatchupContainer"
	matchupContainer.Size = UDim2.new(1, 0, 0.5, 0) -- Takes middle 50% of screen
	matchupContainer.Position = UDim2.new(0, 0, 0.25, 0) -- Centered vertically
	matchupContainer.BackgroundTransparency = 1
	matchupContainer.ZIndex = 5
	matchupContainer.Parent = IntroFrame

	-- Left Panel (Home) - Centered design
	HomePanel = Instance.new("Frame")
	HomePanel.Name = "HomePanel"
	HomePanel.Size = UDim2.new(0.55, 0, 1, 0)
	HomePanel.Position = UDim2.new(-0.55, 0, 0, 0)
	HomePanel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	HomePanel.BorderSizePixel = 0
	HomePanel.ZIndex = 10
	HomePanel.Parent = matchupContainer

	-- Add corner rounding for modern look
	local homeCorner = Instance.new("UICorner")
	homeCorner.CornerRadius = UDim.new(0, 12)
	homeCorner.Parent = HomePanel

	local homeGradient = Instance.new("UIGradient")
	homeGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0.6, 0.6, 0.6))
	}
	homeGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 0.6)
	}
	homeGradient.Rotation = 0
	homeGradient.Parent = HomePanel

	-- Large flag emoji at top
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

	-- Large country name
	local homeLabel = Instance.new("TextLabel")
	homeLabel.Name = "TeamName"
	homeLabel.Size = UDim2.new(0.9, 0, 0.22, 0)
	homeLabel.Position = UDim2.new(0.05, 0, 0.62, 0)
	homeLabel.BackgroundTransparency = 1
	homeLabel.Font = Enum.Font.GothamBlack
	homeLabel.TextScaled = true
	homeLabel.TextColor3 = Color3.new(1, 1, 1)
	homeLabel.TextXAlignment = Enum.TextXAlignment.Center
	homeLabel.ZIndex = 15
	homeLabel.Parent = HomePanel
	
	-- Subtle stroke for country name
	local homeStroke = Instance.new("UIStroke")
	homeStroke.Thickness = 2.5
	homeStroke.Transparency = 0
	homeStroke.Parent = homeLabel

	-- Right Panel (Away) - Centered design
	AwayPanel = Instance.new("Frame")
	AwayPanel.Name = "AwayPanel"
	AwayPanel.Size = UDim2.new(0.55, 0, 1, 0)
	AwayPanel.Position = UDim2.new(1.55, 0, 0, 0)
	AwayPanel.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
	AwayPanel.BorderSizePixel = 0
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
	awayGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.25, 0),
		NumberSequenceKeypoint.new(1, 0)
	}
	awayGradient.Rotation = 0
	awayGradient.Parent = AwayPanel

	-- Large flag emoji at top
	local awayFlag = Instance.new("TextLabel")
	awayFlag.Name = "Flag"
	awayFlag.Size = UDim2.new(0, 120, 0, 120)
	awayFlag.Position = UDim2.new(0.5, -60, 0.15, 0)
	awayFlag.BackgroundTransparency = 1
	awayFlag.Text = "🌍"
	awayFlag.Font = Enum.Font.GothamBold
	awayFlag.TextSize = 100
	awayFlag.ZIndex = 15
	awayFlag.Parent = AwayPanel

	-- Large country name
	local awayLabel = Instance.new("TextLabel")
	awayLabel.Name = "TeamName"
	awayLabel.Size = UDim2.new(0.9, 0, 0.22, 0)
	awayLabel.Position = UDim2.new(0.05, 0, 0.62, 0)
	awayLabel.BackgroundTransparency = 1
	awayLabel.Font = Enum.Font.GothamBlack
	awayLabel.TextScaled = true
	awayLabel.TextColor3 = Color3.new(1, 1, 1)
	awayLabel.TextXAlignment = Enum.TextXAlignment.Center
	awayLabel.ZIndex = 15
	awayLabel.Parent = AwayPanel

	local awayStroke = Instance.new("UIStroke")
	awayStroke.Thickness = 2.5
	awayStroke.Transparency = 0
	awayStroke.Parent = awayLabel

	-- VS Label in center
	VSLabel = Instance.new("TextLabel")
	VSLabel.Name = "VS"
	VSLabel.Size = UDim2.new(0, 150, 0, 150)
	VSLabel.Position = UDim2.new(0.5, -75, 0.5, -75)
	VSLabel.BackgroundTransparency = 1
	VSLabel.Font = Enum.Font.GothamBlack
	VSLabel.Text = "VS"
	VSLabel.TextColor3 = Color3.new(1, 1, 1)
	VSLabel.TextSize = 80
	VSLabel.ZIndex = 110
	VSLabel.TextTransparency = 1
	VSLabel.Parent = matchupContainer

	local vsStroke = Instance.new("UIStroke")
	vsStroke.Thickness = 4
	vsStroke.Color = Color3.new(0, 0, 0)
	vsStroke.Parent = VSLabel

	VSScale = Instance.new("UIScale")
	VSScale.Parent = VSLabel

	return IntroFrame
end

-- Show the intro animation
function MatchIntroUI.Show(homeCode, awayCode)
	local homeData = TeamData.GetTeam(homeCode)
	local awayData = TeamData.GetTeam(awayCode)

	if not homeData or not awayData then
		warn("[MatchIntroUI] Invalid team codes:", homeCode, awayCode)
		return
	end

	-- Setup colors and text
	HomePanel.BackgroundColor3 = homeData.PrimaryColor
	HomePanel:FindFirstChild("Flag").Text = homeData.Flag or "🌍"
	HomePanel:FindFirstChild("TeamName").Text = homeData.Name:upper()
	HomePanel:FindFirstChild("TeamName"):FindFirstChild("UIStroke").Color = homeData.SecondaryColor

	AwayPanel.BackgroundColor3 = awayData.PrimaryColor
	AwayPanel:FindFirstChild("Flag").Text = awayData.Flag or "🌍"
	AwayPanel:FindFirstChild("TeamName").Text = awayData.Name:upper()
	AwayPanel:FindFirstChild("TeamName"):FindFirstChild("UIStroke").Color = awayData.SecondaryColor

	-- Reset positions for animation
	HomePanel.Position = UDim2.new(-0.55, 0, 0, 0)
	AwayPanel.Position = UDim2.new(1.55, 0, 0, 0)
	VSLabel.TextTransparency = 1
	
	if VSScale then
		VSScale.Scale = 5
	end

	IntroFrame.Visible = true
	IntroFrame.BackgroundTransparency = 1

	-- Play Intro Music
	PlaySound(SoundData.Intro_Music, 0.7)

	-- Animations
	local slideTime = 1.2
	local tweenInfo = TweenInfo.new(slideTime, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

	-- Slide panels into view
	TweenService:Create(HomePanel, tweenInfo, {Position = UDim2.new(0, 0, 0, 0)}):Play()
	TweenService:Create(AwayPanel, tweenInfo, {Position = UDim2.new(1, 0, 0, 0)}):Play()
	
	task.delay(slideTime - 0.4, function()
		PlaySound(SoundData.VS_Slam, 1)
		
		-- VS Pop
		TweenService:Create(VSLabel, TweenInfo.new(0.4, Enum.EasingStyle.Bounce), {
			TextTransparency = 0
		}):Play()
		
		if VSScale then
			TweenService:Create(VSScale, TweenInfo.new(0.4, Enum.EasingStyle.Bounce), {
				Scale = 1
			}):Play()
		end
		
		-- Subtle pulse on panels when VS hits
		TweenService:Create(HomePanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Position = UDim2.new(-0.02, 0, 0, 0)
		}):Play()
		TweenService:Create(AwayPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Position = UDim2.new(1.02, 0, 0, 0)
		}):Play()
	end)

	-- Wait and hide
	task.delay(4.5, function()
		local fadeOut = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
		TweenService:Create(HomePanel, fadeOut, {Position = UDim2.new(-0.55, 0, 0, 0)}):Play()
		TweenService:Create(AwayPanel, fadeOut, {Position = UDim2.new(1.55, 0, 0, 0)}):Play()
		TweenService:Create(VSLabel, fadeOut, {TextTransparency = 1}):Play()
		
		task.wait(1.0)
		IntroFrame.Visible = false
	end)
end

return MatchIntroUI