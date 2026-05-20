--[[
	TimeManager.lua
	Manages the match timer and state using high-precision server time.
	
	Responsibilities:
	- Track match time via timestamps (optimized)
	- Manage Match States (Warmup, Active, GoalScored, Finished)
	- Replicate state to clients via ReplicatedStorage attributes
]]

-- Managers
local TimeManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("TimeManager")

-- Private constants
local CELEBRATION_DURATION = 10 -- seconds

-- Private variables
local GameStateFolder = nil
local MatchDuration = 300
local IsInitialized = false

-- State variables (stored in attributes but kept local for convenience)
local CurrentState = "Warmup"
local MatchEndTime = 0
local IsPaused = false
local ScoringTeam = ""

-- Initialize the Match Timer system
function TimeManager.Initialize(duration)
	MatchDuration = duration or MatchDuration
	
	-- Setup GameState folder in ReplicatedStorage if it doesn't exist
	GameStateFolder = ReplicatedStorage:FindFirstChild("GameState")
	if not GameStateFolder then
		GameStateFolder = Instance.new("Folder")
		GameStateFolder.Name = "GameState"
		GameStateFolder.Parent = ReplicatedStorage
	end
	
	-- Initialize attributes
	GameStateFolder:SetAttribute("MatchEndTime", 0)
	GameStateFolder:SetAttribute("MatchState", "Warmup")
	GameStateFolder:SetAttribute("IsPaused", false)
	GameStateFolder:SetAttribute("ScoringTeam", "")
	
	CurrentState = "Warmup"
	MatchEndTime = 0
	IsPaused = false
	ScoringTeam = ""

	IsInitialized = true
	Logger:info("Initialized with duration:", MatchDuration)
	return true
end

-- Start the match
function TimeManager.Start()
	if not IsInitialized then return end
	
	MatchEndTime = workspace:GetServerTimeNow() + MatchDuration
	IsPaused = false
	CurrentState = "Active"
	
	TimeManager._UpdateAttributes()
	Logger:info("Match Started. End Time:", MatchEndTime)
end

-- Pause the timer
function TimeManager.Pause()
	if not IsInitialized or IsPaused then return end
	
	-- Store the remaining time before pausing
	local remaining = math.max(0, MatchEndTime - workspace:GetServerTimeNow())
	GameStateFolder:SetAttribute("RemainingAtPause", remaining)
	
	IsPaused = true
	GameStateFolder:SetAttribute("IsPaused", true)
end

-- Resume the timer
function TimeManager.Resume()
	if not IsInitialized or not IsPaused then return end
	
	local remaining = GameStateFolder:GetAttribute("RemainingAtPause") or 0
	MatchEndTime = workspace:GetServerTimeNow() + remaining
	
	IsPaused = false
	GameStateFolder:SetAttribute("IsPaused", false)
	GameStateFolder:SetAttribute("MatchEndTime", MatchEndTime)
end

-- Handle Goal Scored
function TimeManager.OnGoalScored(teamName)
	if not IsInitialized or CurrentState == "GoalScored" then return end
	
	Logger:info("GOAL SCORED BY:", teamName)
	
	-- Store previous state and pause
	local previousState = CurrentState
	local remainingTime = math.max(0, MatchEndTime - workspace:GetServerTimeNow())
	
	CurrentState = "GoalScored"
	ScoringTeam = teamName
	
	-- Update attributes for clients to show celebration
	GameStateFolder:SetAttribute("ScoringTeam", teamName)
	GameStateFolder:SetAttribute("MatchState", "GoalScored")
	
	-- Celebration period
	task.delay(CELEBRATION_DURATION, function()
		if CurrentState == "GoalScored" then
			-- Resume timer (shift end time by the celebration duration)
			MatchEndTime = workspace:GetServerTimeNow() + remainingTime
			CurrentState = "Active"
			ScoringTeam = ""
			
			TimeManager._UpdateAttributes()
		end
	end)
end

-- Stop/Finish match
function TimeManager.Stop()
	CurrentState = "Finished"
	IsPaused = false
	TimeManager._UpdateAttributes()
end

-- Internal: Update all attributes
function TimeManager._UpdateAttributes()
	if not GameStateFolder then return end
	
	GameStateFolder:SetAttribute("MatchEndTime", MatchEndTime)
	GameStateFolder:SetAttribute("MatchState", CurrentState)
	GameStateFolder:SetAttribute("IsPaused", IsPaused)
	GameStateFolder:SetAttribute("ScoringTeam", ScoringTeam)
end

function TimeManager.GetState()
	return CurrentState
end

function TimeManager.GetTimeRemaining()
	if IsPaused then
		return GameStateFolder:GetAttribute("RemainingAtPause") or 0
	end
	return math.max(0, MatchEndTime - workspace:GetServerTimeNow())
end

return TimeManager
