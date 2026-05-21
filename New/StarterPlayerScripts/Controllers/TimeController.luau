--[[
	TimeController.lua
	Client-side synchronization for the match timer and states.
	
	Responsibilities:
	- Sync with ReplicatedStorage attributes
	- Update local UI (Scoreboard) every frame
	- Trigger Intermission screens on state changes
]]

local TimeController = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("TimeController")

-- UI References (will be loaded on Initialize)
local ScoreboardUI = nil
local IntermissionUI = nil

-- Private state
local GameStateFolder = nil
local HeartbeatConnection = nil
local LastState = ""

-- Initialize the Controller
function TimeController.Initialize()
	GameStateFolder = ReplicatedStorage:WaitForChild("GameState", 10)
	if not GameStateFolder then
		Logger:warn("GameState folder not found!")
		return
	end
	
	-- Loading UI Modules
	ScoreboardUI = require(script.Parent.Parent.UI.ScoreboardUI)
	IntermissionUI = require(script.Parent.Parent.UI.IntermissionUI)

	-- Score sync helper: reads current attributes and pushes them to the scoreboard
	local function SyncScores()
		local homeScore = GameStateFolder:GetAttribute("HomeScore") or 0
		local awayScore = GameStateFolder:GetAttribute("AwayScore") or 0
		ScoreboardUI.UpdateScores(homeScore, awayScore)
	end

	-- Wire score attribute signals so the scoreboard updates whenever a goal is scored
	GameStateFolder:GetAttributeChangedSignal("HomeScore"):Connect(SyncScores)
	GameStateFolder:GetAttributeChangedSignal("AwayScore"):Connect(SyncScores)

	-- Sync scores immediately to display the correct initial state (0–0 or resumed match)
	SyncScores()

	-- Initial Sync
	TimeController._SyncTimerLoop()
	
	-- Listen for status changes
	GameStateFolder:GetAttributeChangedSignal("MatchState"):Connect(function()
		TimeController._SyncTimerLoop()
	end)
	
	-- Listen for pause changes
	GameStateFolder:GetAttributeChangedSignal("IsPaused"):Connect(TimeController._SyncTimerLoop)
end

-- Update the clock locally for smoothness
function TimeController._SyncTimerLoop()
	local state = GameStateFolder:GetAttribute("MatchState")
	local isPaused = GameStateFolder:GetAttribute("IsPaused")
	
	-- Optimized: Only run Heartbeat if Active AND Not Paused
	if state == "Active" and not isPaused then
		if not HeartbeatConnection then
			HeartbeatConnection = RunService.Heartbeat:Connect(function()
				local endTime = GameStateFolder:GetAttribute("MatchEndTime") or 0
				local remaining = math.max(0, endTime - workspace:GetServerTimeNow())
				
				ScoreboardUI.UpdateTimer(remaining)

				if remaining <= 0 then
					-- Server handles state change, loop will stop on next check
				end
			end)
			Logger:debug("Timer loop started")
		end
	else
		-- Stop the loop if not active or paused
		if HeartbeatConnection then
			HeartbeatConnection:Disconnect()
			HeartbeatConnection = nil
			Logger:debug("Timer loop stopped (State: " .. tostring(state) .. ")")
		end
	end
end


function TimeController.GetRemainingTime()
	if not GameStateFolder then return 0 end
	
	local isPaused = GameStateFolder:GetAttribute("IsPaused")
	if isPaused then
		return GameStateFolder:GetAttribute("RemainingAtPause") or 0
	end
	
	local endTime = GameStateFolder:GetAttribute("MatchEndTime") or 0
	return math.max(0, endTime - workspace:GetServerTimeNow())
end

return TimeController
