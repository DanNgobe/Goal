--[[
	MatchManager.lua
	Handles the overall match flow, state transitions, and game loop.
	
	Flow:
	1. Warmup (MatchIntro)
	2. Active Play
	3. Goal Scored (Celebration/Intermission)
	4. Finished (Post-game Intermission)
]]

local MatchManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("MatchManager")

-- Managers
local TimeManager = require(script.Parent.TimeManager)
local BallManager = require(script.Parent.BallManager)

-- Private constants
local WARMUP_DURATION = 15 -- Duration for Match Intro

-- Initialization
function MatchManager.Initialize()
	Logger:info("Initializing Match Manager...")
	
	-- Start the Match Orchestration Loop
	task.spawn(MatchManager.RunMatchFlow)
end

-- Core logic loop for the match
function MatchManager.RunMatchFlow()
	while true do
		-- 1. Warmup Phase (Intro)
		Logger:info("Phase: Warmup")
		-- TimeManager already initializes to Warmup state
		task.wait(WARMUP_DURATION)
		
		-- 2. Transition to Active
		Logger:info("Phase: Kickoff")
		TimeManager.Start() -- Sets state to "Active" and starts timer
		
		-- Wait until the match is finished
		-- The TimeManager handles the GoalScored transitions internally for now
		while TimeManager.GetState() ~= "Finished" do
			local remaining = TimeManager.GetTimeRemaining()
			if remaining <= 0 and TimeManager.GetState() == "Active" then
				TimeManager.Stop() -- Set state to Finished
			end
			task.wait(1)
		end
		
		Logger:info("Phase: Match Finished")
		task.wait(10) -- Intermission/Post-game duration
		
		-- 4. Reset for new match
		Logger:info("Phase: Restarting...")
		TimeManager.Initialize(300) -- Reset timer/state
		BallManager.Reset()         -- Return ball to center
	end
end

return MatchManager
