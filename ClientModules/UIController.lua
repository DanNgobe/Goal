--[[
	UIController.lua
	Manages all client-side UI including scoreboard and intermission.
	
	Responsibilities:
	- Coordinate UI modules
	- Handle UI events from server
	- Manage UI state
]]

local UIController = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- UI Modules
local TeamColorHelper = require(script.Parent.TeamColorHelper)
local ScoreboardUI = require(script.Parent.UI.ScoreboardUI)
local IntermissionUI = require(script.Parent.UI.IntermissionUI)
local TeamJoinUI = require(script.Parent.UI.TeamJoinUI)
local MatchIntroUI = require(script.Parent.UI.MatchIntroUI)
local HelpUI = require(script.Parent.UI.HelpUI)
local InviteUI = require(script.Parent.UI.InviteUI)
local CameraEffects = require(script.Parent.CameraEffects)

-- Private variables
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local CameraController = nil

-- UI Elements
local ScreenGui = nil
local TeamJoinPanel = nil

-- Initialize the UI Controller
function UIController.Initialize(cameraController)
	CameraController = cameraController

	-- Initialize TeamColorHelper first
	TeamColorHelper.Initialize()
	
	-- Register callback for team changes
	TeamColorHelper.OnTeamsChange(function()
		print("[UIController] Teams changed, updating UI colors")
		ScoreboardUI.UpdateTeamColors()
		TeamJoinUI.UpdateTeamColors()
	end)

	-- Create main ScreenGui
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "SoccerUI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Enabled = false -- Keep hidden until initialization finishes
	ScreenGui.Parent = PlayerGui

	-- Create UI modules
	ScoreboardUI.Create(ScreenGui)
	IntermissionUI.Create(ScreenGui)
	MatchIntroUI.Create(ScreenGui)
	HelpUI.Create(ScreenGui)
	InviteUI.Create(ScreenGui)
	TeamJoinPanel = TeamJoinUI.Create(ScreenGui, cameraController)

	-- Connect to events
	UIController._ConnectGoalEvents()
	UIController._ConnectTimerEvents()
	UIController._ConnectMatchEvents()
	UIController._ConnectBallEvents()

	-- Delayed check for controls overlay (for new players)
	task.spawn(function()
		task.wait(10)
		local goalRemotes = ReplicatedStorage:WaitForChild("GoalRemotes", 5)
		if goalRemotes then
			local checkHasScored = goalRemotes:WaitForChild("CheckHasScored", 5)
			if checkHasScored then
				local hasScored = checkHasScored:InvokeServer()
				if not hasScored then
					-- User hasn't scored yet, show controls help
					HelpUI.Toggle()
				end
			end
		end
	end)

	-- Finally enable the UI
	ScreenGui.Enabled = true

	return true
end

-- Public: Toggle help UI
function UIController.ToggleHelp()
	HelpUI.Toggle()
end

-- Private: Connect to ball-related events (possession)
function UIController._ConnectBallEvents()
	task.spawn(function()
		local ballRemotes = ReplicatedStorage:WaitForChild("BallRemotes", 10)
		if not ballRemotes then return end

		local possessionChanged = ballRemotes:WaitForChild("PossessionChanged", 5)
		if possessionChanged then
			possessionChanged.OnClientEvent:Connect(function(hasBall)
				HelpUI.Update(hasBall)
			end)
		end
		
		-- Set initial state
		HelpUI.Update(false)
	end)
end

-- Private: Connect to goal scored events
function UIController._ConnectGoalEvents()
	local goalRemotes = ReplicatedStorage:WaitForChild("GoalRemotes")
	local goalScored = goalRemotes:WaitForChild("GoalScored")

	goalScored.OnClientEvent:Connect(function(scoringTeam, blueScore, redScore)
		UIController._OnGoalScored(scoringTeam, blueScore, redScore)
	end)
	
	-- Connect to goal celebration event (with scorer info)
	task.spawn(function()
		local goalCelebration = goalRemotes:WaitForChild("GoalCelebration", 5)
		if goalCelebration then
			goalCelebration.OnClientEvent:Connect(function(scorerCharacter)
				UIController._OnGoalCelebration(scorerCharacter)
			end)
		end
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

-- Private: Connect to general match events
function UIController._ConnectMatchEvents()
	task.spawn(function()
		local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes", 10)
		if not gameRemotes then return end

		-- Match Intro Event
		local matchIntro = gameRemotes:WaitForChild("MatchIntro", 5)
		if matchIntro then
			matchIntro.OnClientEvent:Connect(function(homeCode, awayCode)
				MatchIntroUI.Show(homeCode, awayCode)
			end)
		end
	end)
end

-- Private: Update timer display
function UIController._UpdateTimer(timeRemaining)
	ScoreboardUI.UpdateTimer(timeRemaining)
end

-- Private: Handle goal scored
function UIController._OnGoalScored(scoringTeam, blueScore, redScore)
	ScoreboardUI.UpdateScores(blueScore, redScore)
	IntermissionUI.ShowGoal(scoringTeam)
end

-- Private: Handle goal celebration camera
function UIController._OnGoalCelebration(scorerCharacter)
	if scorerCharacter and scorerCharacter.Parent then
		-- Trigger celebration camera zoom
		CameraEffects.CelebrationZoom(scorerCharacter, 5)

		-- If local player scored, hide controls overlay as they know how to play now
		if scorerCharacter == Player.Character then
			if HelpUI.IsVisible() then
				HelpUI.Toggle()
			end
		end
	end
end

-- Manually update scoreboard (for testing)
function UIController.UpdateScores(blueScore, redScore)
	ScoreboardUI.UpdateScores(blueScore, redScore)
end

-- Show custom message
function UIController.ShowMessage(message, duration, color)
	IntermissionUI.ShowMessage(message, duration, color)
end

-- Private: Handle match ended
function UIController._OnMatchEnded(winningTeam, blueScore, redScore)
	print("[UIController] Match ended! Winner:", winningTeam)

	-- Update final scores and show match end
	ScoreboardUI.UpdateScores(blueScore, redScore)
	IntermissionUI.ShowMatchEnd(winningTeam, blueScore, redScore)

	-- Wait 5 seconds then unlock mouse and show team selection
	task.wait(5)

	-- Unlock mouse
	if CameraController then
		CameraController.UnlockMouse()
	end

	-- Hide match end screen and show team selection
	IntermissionUI.Hide()
	TeamJoinUI.Show()

	-- Reset scoreboard for new match
	ScoreboardUI.UpdateScores(0, 0)
end

return UIController
