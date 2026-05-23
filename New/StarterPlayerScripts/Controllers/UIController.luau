--[[
	UIController.lua
	Central orchestrator for all client-side UI.
	
	Responsibilities:
	- Create and manage the main GameHUD ScreenGui
	- Initialize all UI sub-modules
	- Listen to GameState changes to show/hide relevant screens
	- Handle UI transitions (Intro -> Scoreboard -> Intermission)
]]

local UIController = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Modules
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("UIController")

local SoundController = require(script.Parent.SoundController)
local ScoreboardUI = require(script.Parent.Parent.UI.ScoreboardUI)
local TeamJoinUI = require(script.Parent.Parent.UI.TeamJoinUI)
local IntermissionUI = require(script.Parent.Parent.UI.IntermissionUI)
local MatchIntroUI = require(script.Parent.Parent.UI.MatchIntroUI)

-- Variables
local GameHUD = nil
local CurrentMatchCodes = { Home = "BRA", Away = "ARG" }
local LastState = ""

-- Initialization
function UIController.Initialize()
	Logger:info("Initializing UI Controller...")
	
	-- 1. Create Main HUD
	GameHUD = Instance.new("ScreenGui")
	GameHUD.Name = "GameHUD"
	GameHUD.ResetOnSpawn = false
	GameHUD.DisplayOrder = 10
	GameHUD.Parent = PlayerGui
	
	-- 2. Fetch Match Data
	local matchTeams = ReplicatedStorage:WaitForChild("MatchTeams")
	CurrentMatchCodes.Home = matchTeams:WaitForChild("HomeTeam").Value
	CurrentMatchCodes.Away = matchTeams:WaitForChild("AwayTeam").Value
	
	-- 3. Initialize UI Sub-modules
	ScoreboardUI.Create(GameHUD)
	TeamJoinUI.Create(GameHUD)
	IntermissionUI.Initialize(GameHUD)
	MatchIntroUI.Create(GameHUD)
	
	-- 4. Set Initial Visibility
	TeamJoinUI.Show()
	
	-- 5. Connect State Listeners
	local gameState = ReplicatedStorage:WaitForChild("GameState")
	gameState:GetAttributeChangedSignal("MatchState"):Connect(UIController.HandleStateChange)
	
	-- Initial state check
	UIController.HandleStateChange()
	
	-- 6. Connect Player Events
	local events = ReplicatedStorage:WaitForChild("Events")
	local playerRemotes = events:WaitForChild("PlayerRemotes")
	local playerJoined = playerRemotes:WaitForChild("PlayerJoined")
	
	playerJoined.OnClientEvent:Connect(function()
		Logger:info("Player joined a team. Hiding TeamJoinUI and locking mouse.")
		TeamJoinUI.Hide()
		-- Lock mouse so the player has full control on the pitch
		local playerScripts = Player:WaitForChild("PlayerScripts")
		local toggleEvent = playerScripts:FindFirstChild("ToggleMouseLock")
		if toggleEvent then
			toggleEvent:Fire()
		else
			game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end)
	
	Logger:info("UI Controller Initialized Successfully!")
end

-- Handle transitions between game states
function UIController.HandleStateChange()
	local gameState = ReplicatedStorage:WaitForChild("GameState")
	local state = gameState:GetAttribute("MatchState") or "Warmup"
	
	if state == LastState then return end
	Logger:info("State changed:", LastState, "->", state)
	
	if state == "Warmup" then
		SoundController.PlayLooping("Intro_Music", 0.6)
		MatchIntroUI.Show(CurrentMatchCodes.Home, CurrentMatchCodes.Away)
	elseif state == "Active" then
		-- Whistle and Ambience for Kickoff
		if LastState == "Warmup" then
			SoundController.StopSound("Intro_Music")
			SoundController.PlaySFX("Whistle_Start", 0.8)
			SoundController.PlayLooping("Stadium_Ambience", 0.4)
		end
		-- Hide intro if it was still showing (though it has its own timer)
		IntermissionUI.Hide()
	elseif state == "GoalScored" then
		local scoringTeam = gameState:GetAttribute("ScoringTeam")
		SoundController.PlaySFX("Goal_Cheer", 1.0)
		IntermissionUI.ShowGoal(scoringTeam)
	elseif state == "Finished" then
		SoundController.StopSound("Stadium_Ambience")
		SoundController.StopSound("Intro_Music")
		SoundController.PlaySFX("Whistle_End", 0.8)
		IntermissionUI.ShowMatchEnd("MATCH FINISHED")
	end
	
	LastState = state
end

return UIController
