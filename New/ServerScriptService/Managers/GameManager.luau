--[[
	GameManager.lua
	The central hub for server-side game orchestration.
	
	Responsibilities:
	- Initialize all other managers
	- Set up global data folders and RemoteEvents
	- Handle player high-level lifecycle events
	- Manage remote-to-manager callbacks
]]

local GameManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("GameManager")

-- Managers
local TimeManager  = require(script.Parent.TimeManager)
local SlotManager  = require(script.Parent.SlotManager)
local PlayerManager = require(script.Parent.PlayerManager)
local MatchManager = require(script.Parent.MatchManager)
local BallManager  = require(script.Parent.BallManager)
local AIManager = require(script.Parent.AIManager)

-- Private variables
local IsInitialized = false

-- Match Configuration (single source of truth for team matchup)
local MatchConfig = {
	HomeTeam = "BRA",
	AwayTeam = "ARG",
	MatchDuration = 300,      -- Seconds
	CelebrationTime = 10,     -- Goal celebration duration
	IntermissionTime = 10,    -- Post-match intermission
	WarmupTime = 15          -- Pre-match warmup
}

-- Internal: Ensures all required folders and Remotes exist
local function SetupInfrastructure()
	-- 1. Events Folder & Remotes
	local events = ReplicatedStorage:FindFirstChild("Events")
	if not events then
		events = Instance.new("Folder")
		events.Name = "Events"
		events.Parent = ReplicatedStorage
	end
	
	local playerRemotes = events:FindFirstChild("PlayerRemotes")
	if not playerRemotes then
		playerRemotes = Instance.new("Folder")
		playerRemotes.Name = "PlayerRemotes"
		playerRemotes.Parent = events
	end
	
	-- JoinTeamRequest Remote
	if not playerRemotes:FindFirstChild("JoinTeamRequest") then
		local joinTeamRequest = Instance.new("RemoteEvent")
		joinTeamRequest.Name = "JoinTeamRequest"
		joinTeamRequest.Parent = playerRemotes
	end
	
	-- BallEvents folder (populated by BallManager)
	if not events:FindFirstChild("BallEvents") then
		local ballEvents = Instance.new("Folder")
		ballEvents.Name = "BallEvents"
		ballEvents.Parent = events
	end
	
	-- PlayerJoined Remote
	if not playerRemotes:FindFirstChild("PlayerJoined") then
		local playerJoined = Instance.new("RemoteEvent")
		playerJoined.Name = "PlayerJoined"
		playerJoined.Parent = playerRemotes
	end
	
	-- JoinTeamFailed Remote (Requirement 13.7)
	if not playerRemotes:FindFirstChild("JoinTeamFailed") then
		local joinTeamFailed = Instance.new("RemoteEvent")
		joinTeamFailed.Name = "JoinTeamFailed"
		joinTeamFailed.Parent = playerRemotes
	end

	-- SwitchSlotRequest Remote (D.2 — slot switching via C key)
	if not playerRemotes:FindFirstChild("SwitchSlotRequest") then
		local switchSlotRequest = Instance.new("RemoteEvent")
		switchSlotRequest.Name = "SwitchSlotRequest"
		switchSlotRequest.Parent = playerRemotes
	end
	
	-- 2. MatchTeams Folder - Read from MatchConfig
	local matchTeams = ReplicatedStorage:FindFirstChild("MatchTeams")
	if not matchTeams then
		matchTeams = Instance.new("Folder")
		matchTeams.Name = "MatchTeams"
		matchTeams.Parent = ReplicatedStorage
	end
	
	-- Validate team codes and apply fallback if needed
	local TeamData = require(ReplicatedStorage:WaitForChild("TeamData"))
	local homeCode = MatchConfig.HomeTeam
	local awayCode = MatchConfig.AwayTeam
	
	if not TeamData.GetTeam(homeCode) then
		Logger:warn("Invalid HomeTeam code '" .. tostring(homeCode) .. "' in MatchConfig. Falling back to 'BRA'.")
		homeCode = "BRA"
	end
	
	if not TeamData.GetTeam(awayCode) then
		Logger:warn("Invalid AwayTeam code '" .. tostring(awayCode) .. "' in MatchConfig. Falling back to 'ARG'.")
		awayCode = "ARG"
	end
	
	-- Create or update HomeTeam StringValue
	local home = matchTeams:FindFirstChild("HomeTeam")
	if not home then
		home = Instance.new("StringValue")
		home.Name = "HomeTeam"
		home.Parent = matchTeams
	end
	home.Value = homeCode
	
	-- Create or update AwayTeam StringValue
	local away = matchTeams:FindFirstChild("AwayTeam")
	if not away then
		away = Instance.new("StringValue")
		away.Name = "AwayTeam"
		away.Parent = matchTeams
	end
	away.Value = awayCode
end

-- Initialize the Server
function GameManager.Initialize()
	if IsInitialized then return end
	
	Logger:info("Initializing Game Manager...")
	
	-- 1. Setup Infrastructure
	SetupInfrastructure()
	
	-- 2. Get validated team codes from MatchTeams (already validated in SetupInfrastructure)
	local matchTeams = ReplicatedStorage:WaitForChild("MatchTeams")
	local homeTeam = matchTeams:WaitForChild("HomeTeam")
	local awayTeam = matchTeams:WaitForChild("AwayTeam")
	local homeCode = homeTeam.Value
	local awayCode = awayTeam.Value
	
	-- 3. Initialize Managers
	-- Find foundations for SlotManager
	local stadium = workspace:FindFirstChild("Stadium")
	local pitch = stadium and stadium:FindFirstChild("Pitch")
	local ground = pitch and pitch:FindFirstChild("Ground")
	local teleporters = workspace:FindFirstChild("Teleporters")
	
	SlotManager.Initialize(ground, teleporters)
	
	-- Initialize PlayerManager and wire it to SlotManager
	PlayerManager.Initialize(SlotManager)
	SlotManager.SetPlayerManager(PlayerManager)
	
	-- Set match teams from MatchConfig (via validated codes)
	SlotManager.SetMatchTeams(homeCode, awayCode)
	
	TimeManager.Initialize(300) -- Default 5 min match
	
	-- Find the ball and field center, then initialize BallManager
	-- BallManager must be initialized BEFORE MatchManager (Requirement 1.8)
	local ball = workspace:FindFirstChild("Ball")
	if not ball then
		Logger:warn("Ball part not found in Workspace! BallManager will not initialize.")
	else
		-- Field center: use the ground part's position if available, else origin
		local fieldCenter = ground and ground.Position or Vector3.new(0, 0, 0)
		BallManager.Initialize(ball, fieldCenter)
	end
	
	-- Initialize MatchManager after BallManager so goal detection can access the ball (Requirement 1.8)
	-- Pass all four dependencies explicitly for clean dependency injection
	MatchManager.Initialize(TimeManager, BallManager, SlotManager, PlayerManager)
	
	-- 4. Initialize AI (Intelligent NPCs)
	-- matchManager argument removed - AIManager no longer accepts it (Requirement 7.2)
	AIManager.Initialize(SlotManager, BallManager)
	
	-- 5. Connect Events
	local events = ReplicatedStorage:WaitForChild("Events")
	local playerRemotes = events:WaitForChild("PlayerRemotes")
	local joinTeamRequest = playerRemotes:WaitForChild("JoinTeamRequest")
	
	joinTeamRequest.OnServerEvent:Connect(function(player, teamName)
		local joinTeamFailed = playerRemotes:FindFirstChild("JoinTeamFailed")

		-- Requirement 14.7 / 13.6: Reject if player is already assigned
		if PlayerManager.IsPlayerAssigned(player) then
			Logger:warn(player.Name, "attempted to join", teamName, "but is already assigned")
			if joinTeamFailed then
				joinTeamFailed:FireClient(player, "AlreadyAssigned")
			end
			return
		end

		-- Requirement 13.4 / 13.5: Reject if no non-GK AI slot is available
		if not SlotManager.HasAvailableSlot(teamName) then
			Logger:warn(player.Name, "attempted to join", teamName, "but no slot is available (TeamFull)")
			if joinTeamFailed then
				joinTeamFailed:FireClient(player, "TeamFull")
			end
			return
		end

		-- Both checks passed — assign the player
		SlotManager.AssignPlayer(player, teamName)
	end)
	
	-- D.2: Handle slot switching requests from clients (C key)
	local switchSlotRequest = playerRemotes:WaitForChild("SwitchSlotRequest")
	switchSlotRequest.OnServerEvent:Connect(function(player)
		-- Guard: player must be assigned
		if not PlayerManager.IsPlayerAssigned(player) then
			Logger:warn(player.Name, "fired SwitchSlotRequest but is not assigned")
			return
		end

		local teamName    = PlayerManager.GetPlayerTeam(player)
		local currentSlot = PlayerManager.GetPlayerSlot(player)

		-- Find the Ball for distance comparison
		local ball     = workspace:FindFirstChild("Ball")
		local ballPos  = ball and ball.Position or nil

		if not ballPos then
			Logger:warn("SwitchSlotRequest: Ball not found in workspace")
			return
		end

		-- Find the closest non-GK AI slot (exclude player's current slot)
		local bestSlot     = nil
		local bestDistance = math.huge

		for _, slot in ipairs(SlotManager.GetTeamSlots(teamName)) do
			-- Must be AI-controlled, not GK, and not the player's current position
			if slot.IsAI and slot.Role ~= "GK" and slot.Index ~= currentSlot then
				local slotPos = slot.HomePosition
				local dist    = (slotPos - ballPos).Magnitude
				if dist < bestDistance then
					bestDistance = dist
					bestSlot     = slot
				end
			end
		end

		if not bestSlot then
			Logger:warn(player.Name, "SwitchSlotRequest: no eligible AI slot found on", teamName)
			return
		end

		Logger:info(player.Name, "switching from slot", currentSlot, "to slot", bestSlot.Index, "on", teamName)
		SlotManager.SwitchPlayerSlot(player, bestSlot.Index)
	end)
	
	Players.PlayerAdded:Connect(function(player)
		-- Detach ball immediately when character is removed (reset/death)
		-- so there's no window where the ball stays attached to a ghost character
		player.CharacterRemoving:Connect(function(character)
			if BallManager.GetCurrentOwner() == character then
				BallManager.DetachBall()
			end
		end)

		player.CharacterAdded:Connect(function(character)
			-- Brief yield so physics/hierarchy is fully settled before repositioning
			task.wait(0.1)
			SlotManager.HandleCharacterSpawn(player, character)
		end)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		SlotManager.RemovePlayer(player)
	end)
	
	IsInitialized = true
	Logger:info("Game Manager Initialized Successfully!")
end

return GameManager
