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
local SlotManager = require(script.Parent.SlotManager)

-- Shared modules
local FormationData = require(ReplicatedStorage:WaitForChild("FormationData"))
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))
local TeamData = require(ReplicatedStorage:WaitForChild("TeamData"))

-- Dependencies (set during initialization)
local PlayerManagerRef = nil

-- Private constants
local WARMUP_DURATION = 15 -- Duration for Match Intro
local CELEBRATION_DURATION = 10 -- Seconds to play goal celebration dance

-- Private variables
local Ball = nil
local HomeGoal = nil
local AwayGoal = nil
local GameStateFolder = nil
local HomeGoalConnection = nil
local AwayGoalConnection = nil

-- Forward declaration so OnGoalScored can call it before its definition
local RepositionAllCharacters

-- Setup goal detection system
local function SetupGoalDetection()
	-- Get goal parts from workspace
	local stadium = workspace:FindFirstChild("Stadium")
	if not stadium then
		Logger:error("Stadium not found in workspace! Goal detection disabled.")
		return false
	end
	
	HomeGoal = stadium:FindFirstChild("HomeGoal")
	AwayGoal = stadium:FindFirstChild("AwayGoal")
	
	if not HomeGoal then
		Logger:error("HomeGoal not found in Stadium! Goal detection disabled.")
		return false
	end
	
	if not AwayGoal then
		Logger:error("AwayGoal not found in Stadium! Goal detection disabled.")
		return false
	end
	
	-- Get Ball reference from BallManager (Requirement 1.8)
	Ball = BallManager.GetBall()
	if not Ball then
		Logger:error("Ball not available from BallManager! Goal detection disabled.")
		return false
	end
	
	-- Setup GameState folder for score attributes
	GameStateFolder = ReplicatedStorage:FindFirstChild("GameState")
	if not GameStateFolder then
		GameStateFolder = Instance.new("Folder")
		GameStateFolder.Name = "GameState"
		GameStateFolder.Parent = ReplicatedStorage
	end
	
	-- Initialize score attributes (Requirement 1.5)
	GameStateFolder:SetAttribute("HomeScore", 0)
	GameStateFolder:SetAttribute("AwayScore", 0)
	
	-- Connect goal touch detection
	-- HomeGoal touch = Away team scores (Requirement 1.2)
	HomeGoalConnection = HomeGoal.Touched:Connect(function(otherPart)
		if otherPart == Ball then
			MatchManager.OnGoalScored("AwayTeam")
		end
	end)
	
	-- AwayGoal touch = Home team scores (Requirement 1.1)
	AwayGoalConnection = AwayGoal.Touched:Connect(function(otherPart)
		if otherPart == Ball then
			MatchManager.OnGoalScored("HomeTeam")
		end
	end)
	
	Logger:info("Goal detection initialized successfully")
	return true
end

-- Handle goal scored event
function MatchManager.OnGoalScored(scoringTeam)
	-- Requirement 1.3: Ignore goals when MatchState is not "Active"
	local currentState = TimeManager.GetState()
	if currentState ~= "Active" then
		Logger:debug("Goal touch ignored - MatchState is", currentState)
		return
	end
	
	-- Get current scores
	local homeScore = GameStateFolder:GetAttribute("HomeScore") or 0
	local awayScore = GameStateFolder:GetAttribute("AwayScore") or 0
	
	-- Increment appropriate score (Requirements 1.1, 1.2)
	if scoringTeam == "HomeTeam" then
		homeScore = homeScore + 1
		Logger:info("GOAL! HomeTeam scores! New score:", homeScore, "-", awayScore)
	elseif scoringTeam == "AwayTeam" then
		awayScore = awayScore + 1
		Logger:info("GOAL! AwayTeam scores! New score:", homeScore, "-", awayScore)
	else
		Logger:error("Invalid scoring team:", scoringTeam)
		return
	end
	
	-- Requirement 1.6: Update score attributes BEFORE setting MatchState to "GoalScored"
	-- This ensures atomic update within the same server frame
	GameStateFolder:SetAttribute("HomeScore", homeScore)
	GameStateFolder:SetAttribute("AwayScore", awayScore)
	
	-- Requirement 1.4: Set MatchState to "GoalScored" via TimeManager.OnGoalScored()
	-- This also handles Requirement 1.7: duplicate prevention during "GoalScored" state
	TimeManager.OnGoalScored(scoringTeam)

	-- Reset ball and reposition all characters once the celebration ends
	task.spawn(function()
		-- Wait for MatchState to leave GoalScored (TimeManager handles the delay)
		while TimeManager.GetState() == "GoalScored" do
			task.wait(0.5)
		end
		-- Only reset if we returned to Active (not Finished)
		if TimeManager.GetState() == "Active" then
			BallManager.Reset()
			RepositionAllCharacters()
			Logger:info("Post-goal reset: ball and characters repositioned.")
		end
	end)

	-- D.4: Goal celebration dance for scoring AI characters
	local lastKicker = BallManager.GetLastKicker()
	if lastKicker and lastKicker:GetAttribute("IsAI") == true then
		-- Collect all dance animation IDs into an array for random selection
		local danceAnims = {}
		for _, animId in pairs(AnimationData.Dance) do
			table.insert(danceAnims, animId)
		end

		if #danceAnims > 0 then
			local chosenAnimId = danceAnims[math.random(1, #danceAnims)]

			local humanoid = lastKicker:FindFirstChildOfClass("Humanoid")
			if humanoid then
				-- Get or create an Animator on the Humanoid
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if not animator then
					animator = Instance.new("Animator")
					animator.Parent = humanoid
				end

				-- Create an Animation instance and load the track
				local animInstance = Instance.new("Animation")
				animInstance.AnimationId = chosenAnimId

				local track = animator:LoadAnimation(animInstance)
				track.Looped = true
				track:Play()

				Logger:info("Playing celebration dance for", lastKicker.Name, "animId:", chosenAnimId)

				-- Stop the dance after CELEBRATION_DURATION or when state returns to Active
				task.spawn(function()
					local elapsed = 0
					local interval = 0.5
					while elapsed < CELEBRATION_DURATION do
						task.wait(interval)
						elapsed = elapsed + interval
						-- Stop early if match returned to Active
						if TimeManager.GetState() == "Active" then
							break
						end
					end
					if track and track.IsPlaying then
						track:Stop()
						Logger:debug("Celebration dance stopped for", lastKicker.Name)
					end
				end)
			end
		end
	end
end

-- Reposition all characters to their default formation positions (Requirement 3.3, 3.4)
RepositionAllCharacters = function()
	Logger:info("Repositioning all characters to default formation positions...")
	
	-- Reposition both teams
	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		local slots = SlotManager.GetTeamSlots(teamName)
		
		for _, slot in ipairs(slots) do
			if slot.IsAI and slot.Model then
				-- Reposition AI character (Requirement 3.3)
				local character = slot.Model
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					rootPart.CFrame = CFrame.new(slot.HomePosition)
					Logger:debug("Repositioned AI", character.Name, "to", slot.HomePosition)
				end
			elseif not slot.IsAI and slot.Controller then
				-- Reposition player character (Requirement 3.4)
				local player = slot.Controller
				if player.Character then
					local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
					if rootPart then
						rootPart.CFrame = CFrame.new(slot.HomePosition)
						Logger:debug("Repositioned Player", player.Name, "to", slot.HomePosition)
					end
				end
			end
		end
	end
	
	Logger:info("Character repositioning complete")
end

-- Pick two different random team codes for the next match (D.5)
local function PickNewTeams()
	local codes = TeamData.GetAllCodes()
	local homeCode = codes[math.random(1, #codes)]
	local awayCode
	repeat
		awayCode = codes[math.random(1, #codes)]
	until awayCode ~= homeCode
	return homeCode, awayCode
end

-- Initialization
function MatchManager.Initialize(timeManager, ballManager, slotManager, playerManager)
	Logger:info("Initializing Match Manager...")
	
	-- Override module-level dependencies with explicitly passed references if provided
	-- This supports clean dependency injection while keeping module-level requires as fallbacks
	if timeManager then TimeManager = timeManager end
	if ballManager then BallManager = ballManager end
	if slotManager then SlotManager = slotManager end
	if playerManager then PlayerManagerRef = playerManager end

	-- D.5: Randomize teams for the very first match too
	local newHome, newAway = PickNewTeams()
	Logger:info("First match teams: Home =", newHome, "Away =", newAway)
	SlotManager.SetMatchTeams(newHome, newAway)
	local matchTeams = ReplicatedStorage:FindFirstChild("MatchTeams")
	if matchTeams then
		local homeTV = matchTeams:FindFirstChild("HomeTeam")
		local awayTV = matchTeams:FindFirstChild("AwayTeam")
		if homeTV then homeTV.Value = newHome end
		if awayTV then awayTV.Value = newAway end
	end
	for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
		for _, slot in ipairs(SlotManager.GetTeamSlots(teamName)) do
			if slot.IsAI and slot.Model then
				SlotManager.ApplyTeamColors(slot.Model, teamName)
			end
		end
	end
	
	-- Setup goal detection system (Requirements 1.1-1.8)
	SetupGoalDetection()
	
	-- Start the Match Orchestration Loop
	task.spawn(MatchManager.RunMatchFlow)
end

-- Core logic loop for the match
function MatchManager.RunMatchFlow()
	while true do
		-- 1. Warmup Phase (Intro)
		Logger:info("Phase: Warmup")
		
		-- Requirement 3.8: Set MatchEndBroadcast to false when new warmup begins
		if GameStateFolder then
			GameStateFolder:SetAttribute("MatchEndBroadcast", false)
		end
		
		-- TimeManager already initializes to Warmup state
		task.wait(WARMUP_DURATION)
		
		-- 2. Transition to Active
		Logger:info("Phase: Kickoff")
		TimeManager.Start() -- Sets state to "Active" and starts timer
		
		-- Wait until the match is finished
		-- The TimeManager handles the GoalScored transitions internally for now
		while TimeManager.GetState() ~= "Finished" do
			local remaining = TimeManager.GetTimeRemaining()
			-- Requirement 2.1: When time reaches 0 and state is Active, call Stop()
			if remaining <= 0 and TimeManager.GetState() == "Active" then
				TimeManager.Stop() -- Triggers winner determination (Requirements 2.2-2.6)
			end
			task.wait(1)
		end
		
		Logger:info("Phase: Match Finished")
		
		-- Requirement 3.7: Set MatchEndBroadcast to true when match finishes
		if GameStateFolder then
			GameStateFolder:SetAttribute("MatchEndBroadcast", true)
		end
		
		task.wait(10) -- Intermission/Post-game duration
		
		-- 4. Reset for new match
		Logger:info("Phase: Restarting...")
		
		-- Requirement 3.6: Clear MatchResult before warmup phase starts
		if GameStateFolder then
			GameStateFolder:SetAttribute("MatchResult", "")
		end
		
		-- Requirement 3.1: Reset scores to 0 before beginning next warmup phase
		if GameStateFolder then
			GameStateFolder:SetAttribute("HomeScore", 0)
			GameStateFolder:SetAttribute("AwayScore", 0)
		end
		
		-- D.5: Randomize team matchup for next match
		local newHome, newAway = PickNewTeams()
		Logger:info("New matchup: Home =", newHome, "Away =", newAway)

		-- Update SlotManager with the new team codes
		SlotManager.SetMatchTeams(newHome, newAway)

		-- Update ReplicatedStorage.MatchTeams so clients see the new matchup
		local matchTeams = ReplicatedStorage:FindFirstChild("MatchTeams")
		if matchTeams then
			local homeTV = matchTeams:FindFirstChild("HomeTeam")
			local awayTV = matchTeams:FindFirstChild("AwayTeam")
			if homeTV then homeTV.Value = newHome end
			if awayTV then awayTV.Value = newAway end
		end

		-- Re-apply team colors to all AI characters with the new codes
		for _, teamName in ipairs({"HomeTeam", "AwayTeam"}) do
			for _, slot in ipairs(SlotManager.GetTeamSlots(teamName)) do
				if slot.IsAI and slot.Model then
					SlotManager.ApplyTeamColors(slot.Model, teamName)
				end
			end
		end

		-- Requirement 14.8: Clear PlayerManager state (ALREADY EXISTS - verify it's called)
		if PlayerManagerRef then
			PlayerManagerRef.ClearState()
		end
		
		-- Requirement 3.5: Call TimeManager.Initialize() to reset match clock
		TimeManager.Initialize(300) -- Reset timer/state
		
		-- Requirement 3.2: Call BallManager.Reset() (ALREADY EXISTS - verify it's called)
		BallManager.Reset()         -- Return ball to center
		
		-- Requirements 3.3, 3.4: Reposition all characters to default formation positions
		RepositionAllCharacters()
	end
end

return MatchManager
