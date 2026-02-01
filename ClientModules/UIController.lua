--[[
	UIController.lua
	Manages all client-side UI including scoreboard and intermission.
	
	Responsibilities:
	- Create and update scoreboard
	- Handle intermission screens
	- Display goal celebrations
	- Show game state (timer, scores, etc.)
	
	Batch 7: UI & Scoreboard
]]

local UIController = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Private variables
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local CameraController = nil

-- UI Elements
local ScreenGui = nil
local ScoreboardFrame = nil
local BlueScoreLabel = nil
local RedScoreLabel = nil
local TimerLabel = nil
local IntermissionFrame = nil
local GoalText = nil
local SubText = nil

-- Current scores
local CurrentBlueScore = 0
local CurrentRedScore = 0
local CurrentTime = 300  -- 5 minutes in seconds

-- Initialize the UI Controller
function UIController.Initialize(cameraController)
	-- Store reference to CameraController
	CameraController = cameraController

	-- Create main ScreenGui
	UIController._CreateUI()

	-- Connect to goal events
	UIController._ConnectGoalEvents()

	-- Connect to timer events
	UIController._ConnectTimerEvents()

	return true
end

-- Private: Create all UI elements
function UIController._CreateUI()
	-- Main ScreenGui
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "SoccerUI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Parent = PlayerGui

	-- Scoreboard Frame (top center, smaller and scalable)
	ScoreboardFrame = Instance.new("Frame")
	ScoreboardFrame.Name = "Scoreboard"
	ScoreboardFrame.Size = UDim2.new(0.3, 0, 0.1, 0)  -- Scale-based, slightly larger
	ScoreboardFrame.Position = UDim2.new(0.35, 0, 0.02, 0)
	ScoreboardFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	ScoreboardFrame.BackgroundTransparency = 0.15
	ScoreboardFrame.BorderSizePixel = 0
	ScoreboardFrame.Parent = ScreenGui

	-- Scoreboard Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = ScoreboardFrame

	-- Add subtle gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
	}
	gradient.Rotation = 90
	gradient.Parent = ScoreboardFrame

	-- Add border stroke (whitish/gray like join panel)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 180, 180)
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = ScoreboardFrame

	-- Timer Label (center, top of scoreboard)
	TimerLabel = Instance.new("TextLabel")
	TimerLabel.Name = "Timer"
	TimerLabel.Size = UDim2.new(0.28, 0, 0.32, 0)
	TimerLabel.Position = UDim2.new(0.36, 0, 0.08, 0)
	TimerLabel.BackgroundColor3 = Color3.fromRGB(240, 240, 240)  -- Light gray/white
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

	-- Intermission Frame (center screen, more styled)
	IntermissionFrame = Instance.new("Frame")
	IntermissionFrame.Name = "Intermission"
	IntermissionFrame.Size = UDim2.new(0.4, 0, 0.25, 0)
	IntermissionFrame.Position = UDim2.new(0.3, 0, 0.375, 0)
	IntermissionFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	IntermissionFrame.BackgroundTransparency = 0.1
	IntermissionFrame.BorderSizePixel = 0
	IntermissionFrame.Visible = false
	IntermissionFrame.Parent = ScreenGui

	local intermissionCorner = Instance.new("UICorner")
	intermissionCorner.CornerRadius = UDim.new(0.1, 0)
	intermissionCorner.Parent = IntermissionFrame

	local intermissionStroke = Instance.new("UIStroke")
	intermissionStroke.Color = Color3.fromRGB(255, 215, 0)
	intermissionStroke.Thickness = 4
	intermissionStroke.Parent = IntermissionFrame

	local intermissionGradient = Instance.new("UIGradient")
	intermissionGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
	}
	intermissionGradient.Rotation = 45
	intermissionGradient.Parent = IntermissionFrame

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

	-- Team Join Panel (bottom center)
	UIController._CreateTeamJoinPanel()
end

-- Private: Create team join panel
function UIController._CreateTeamJoinPanel()
	local JoinPanel = Instance.new("Frame")
	JoinPanel.Name = "TeamJoinPanel"
	JoinPanel.Size = UDim2.new(0.25, 0, 0.12, 0)
	JoinPanel.Position = UDim2.new(0.375, 0, 0.85, 0)
	JoinPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	JoinPanel.BackgroundTransparency = 0.15
	JoinPanel.BorderSizePixel = 0
	JoinPanel.Parent = ScreenGui

	local joinCorner = Instance.new("UICorner")
	joinCorner.CornerRadius = UDim.new(0.15, 0)
	joinCorner.Parent = JoinPanel

	local joinStroke = Instance.new("UIStroke")
	joinStroke.Color = Color3.fromRGB(150, 150, 150)
	joinStroke.Thickness = 2
	joinStroke.Transparency = 0.5
	joinStroke.Parent = JoinPanel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.9, 0, 0.25, 0)
	title.Position = UDim2.new(0.05, 0, 0.05, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "JOIN TEAM"
	title.Parent = JoinPanel

	-- Blue Team Button
	local blueButton = Instance.new("TextButton")
	blueButton.Name = "BlueButton"
	blueButton.Size = UDim2.new(0.42, 0, 0.55, 0)
	blueButton.Position = UDim2.new(0.05, 0, 0.38, 0)
	blueButton.BackgroundColor3 = Color3.fromRGB(30, 130, 255)
	blueButton.BorderSizePixel = 0
	blueButton.Font = Enum.Font.GothamBold
	blueButton.TextScaled = true
	blueButton.TextColor3 = Color3.new(1, 1, 1)
	blueButton.Text = "BLUE"
	blueButton.Parent = JoinPanel

	local blueButtonCorner = Instance.new("UICorner")
	blueButtonCorner.CornerRadius = UDim.new(0.2, 0)
	blueButtonCorner.Parent = blueButton

	local blueButtonStroke = Instance.new("UIStroke")
	blueButtonStroke.Color = Color3.fromRGB(100, 180, 255)
	blueButtonStroke.Thickness = 2
	blueButtonStroke.Parent = blueButton

	-- Red Team Button
	local redButton = Instance.new("TextButton")
	redButton.Name = "RedButton"
	redButton.Size = UDim2.new(0.42, 0, 0.55, 0)
	redButton.Position = UDim2.new(0.53, 0, 0.38, 0)
	redButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	redButton.BorderSizePixel = 0
	redButton.Font = Enum.Font.GothamBold
	redButton.TextScaled = true
	redButton.TextColor3 = Color3.new(1, 1, 1)
	redButton.Text = "RED"
	redButton.Parent = JoinPanel

	local redButtonCorner = Instance.new("UICorner")
	redButtonCorner.CornerRadius = UDim.new(0.2, 0)
	redButtonCorner.Parent = redButton

	local redButtonStroke = Instance.new("UIStroke")
	redButtonStroke.Color = Color3.fromRGB(255, 130, 130)
	redButtonStroke.Thickness = 2
	redButtonStroke.Parent = redButton

	-- Button events
	local playerRemotes = ReplicatedStorage:WaitForChild("PlayerRemotes")
	local joinTeamRequest = playerRemotes:WaitForChild("JoinTeamRequest")

	blueButton.MouseButton1Click:Connect(function()
		joinTeamRequest:FireServer("Blue")
		JoinPanel.Visible = false

		-- Lock mouse when team is selected
		if CameraController then
			CameraController.LockMouse()
		end
	end)

	redButton.MouseButton1Click:Connect(function()
		joinTeamRequest:FireServer("Red")
		JoinPanel.Visible = false

		-- Lock mouse when team is selected
		if CameraController then
			CameraController.LockMouse()
		end
	end)

	-- Hide panel when player joins
	local playerJoined = playerRemotes:WaitForChild("PlayerJoined")
	playerJoined.OnClientEvent:Connect(function()
		JoinPanel.Visible = false
	end)
end

-- Private: Connect to goal scored events
function UIController._ConnectGoalEvents()
	local goalRemotes = ReplicatedStorage:WaitForChild("GoalRemotes")
	local goalScored = goalRemotes:WaitForChild("GoalScored")

	goalScored.OnClientEvent:Connect(function(scoringTeam, blueScore, redScore)
		UIController._OnGoalScored(scoringTeam, blueScore, redScore)
	end)
end

-- Private: Connect to timer events
function UIController._ConnectTimerEvents()
	task.spawn(function()
		local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes", 10)
		if not gameRemotes then return end

		local timerUpdate = gameRemotes:WaitForChild("TimerUpdate", 5)
		if not timerUpdate then return end

		timerUpdate.OnClientEvent:Connect(function(timeRemaining)
			UIController._UpdateTimer(timeRemaining)
		end)

		-- Connect to match ended event
		local matchEnded = gameRemotes:WaitForChild("MatchEnded", 5)
		if matchEnded then
			matchEnded.OnClientEvent:Connect(function(winningTeam, blueScore, redScore)
				UIController._OnMatchEnded(winningTeam, blueScore, redScore)
			end)
		end
	end)
end

-- Private: Update timer display
function UIController._UpdateTimer(timeRemaining)
	CurrentTime = timeRemaining
	local minutes = math.floor(timeRemaining / 60)
	local seconds = timeRemaining % 60
	TimerLabel.Text = string.format("%d:%02d", minutes, seconds)

	-- Change color based on time remaining
	if timeRemaining <= 60 then
		TimerLabel.BackgroundColor3 = Color3.fromRGB(255, 60, 60)  -- Red for last minute
	elseif timeRemaining <= 120 then
		TimerLabel.BackgroundColor3 = Color3.fromRGB(255, 180, 0)  -- Orange for last 2 minutes
	else
		TimerLabel.BackgroundColor3 = Color3.fromRGB(240, 240, 240)  -- Light gray/white
	end
end

-- Private: Handle goal scored
function UIController._OnGoalScored(scoringTeam, blueScore, redScore)
	-- Update scores
	CurrentBlueScore = blueScore
	CurrentRedScore = redScore

	-- Update scoreboard
	UIController._UpdateScoreboard()

	-- Show intermission
	UIController._ShowIntermission(scoringTeam)
end

-- Private: Update scoreboard display
function UIController._UpdateScoreboard()
	BlueScoreLabel.Text = tostring(CurrentBlueScore)
	RedScoreLabel.Text = tostring(CurrentRedScore)

	-- Animate score change
	local targetLabel = nil
	if CurrentBlueScore > CurrentRedScore then
		targetLabel = BlueScoreLabel
	elseif CurrentRedScore > CurrentBlueScore then
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

-- Private: Show intermission screen
function UIController._ShowIntermission(scoringTeam)
	-- Set goal text with team color
	local teamColor = scoringTeam == "Blue" and Color3.fromRGB(30, 130, 255) or Color3.fromRGB(255, 60, 60)
	GoalText.TextColor3 = teamColor
	GoalText.Text = "⚽ GOAL! ⚽"
	SubText.Text = string.format("%s TEAM SCORED!", scoringTeam:upper())
	SubText.TextColor3 = teamColor

	-- Show intermission frame
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

	-- Pulse animation
	local pulseTween = TweenService:Create(GoalText, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true), {
		TextSize = 60
	})

	-- Hide after 4 seconds
	task.wait(4)

	pulseTween:Cancel()

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
end

-- Manually update scoreboard (for testing)
function UIController.UpdateScores(blueScore, redScore)
	CurrentBlueScore = blueScore
	CurrentRedScore = redScore
	UIController._UpdateScoreboard()
end

-- Show custom message
function UIController.ShowMessage(message, duration, color)
	if not IntermissionFrame then return end

	duration = duration or 2
	color = color or Color3.new(1, 1, 1)

	GoalText.TextColor3 = color
	GoalText.Text = message
	IntermissionFrame.Visible = true

	task.wait(duration)
	IntermissionFrame.Visible = false
end

-- Private: Handle match ended
function UIController._OnMatchEnded(winningTeam, blueScore, redScore)
	print("[UIController] Match ended! Winner:", winningTeam)

	-- Update final scores
	CurrentBlueScore = blueScore
	CurrentRedScore = redScore
	UIController._UpdateScoreboard()

	-- Determine winner text and color
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

	-- Show match end screen
	GoalText.TextColor3 = winnerColor
	GoalText.Text = winnerText
	SubText.Text = string.format("Final Score: %d - %d", blueScore, redScore)
	SubText.TextColor3 = Color3.fromRGB(255, 255, 255)

	IntermissionFrame.Visible = true
	IntermissionFrame.BackgroundTransparency = 0.1
	GoalText.TextTransparency = 0
	SubText.TextTransparency = 0

	-- Wait 5 seconds then unlock mouse and show team selection
	task.wait(5)

	-- Unlock mouse
	if CameraController then
		CameraController.UnlockMouse()
	end

	-- Hide match end screen
	IntermissionFrame.Visible = false

	-- Show team selection panel
	local teamJoinPanel = ScreenGui:FindFirstChild("TeamJoinPanel")
	if teamJoinPanel then
		teamJoinPanel.Visible = true
	end

	-- Reset scoreboard for new match
	CurrentBlueScore = 0
	CurrentRedScore = 0
	UIController._UpdateScoreboard()
end

return UIController
