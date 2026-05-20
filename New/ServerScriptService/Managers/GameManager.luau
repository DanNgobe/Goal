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
local MatchManager = require(script.Parent.MatchManager)
local BallManager  = require(script.Parent.BallManager)
local AIManager = require(script.Parent.AIManager)

-- Private variables
local IsInitialized = false

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
	
	-- 2. MatchTeams Folder
	local matchTeams = ReplicatedStorage:FindFirstChild("MatchTeams")
	if not matchTeams then
		matchTeams = Instance.new("Folder")
		matchTeams.Name = "MatchTeams"
		matchTeams.Parent = ReplicatedStorage
		
		local home = Instance.new("StringValue")
		home.Name = "HomeTeam"
		home.Value = "BRA"
		home.Parent = matchTeams
		
		local away = Instance.new("StringValue")
		away.Name = "AwayTeam"
		away.Value = "ARG"
		away.Parent = matchTeams
	end
end

-- Initialize the Server
function GameManager.Initialize()
	if IsInitialized then return end
	
	Logger:info("Initializing Game Manager...")
	
	-- 1. Setup Infrastructure
	SetupInfrastructure()
	
	-- 2. Initialize Managers
	-- Find foundations for SlotManager
	local stadium = workspace:FindFirstChild("Stadium")
	local pitch = stadium and stadium:FindFirstChild("Pitch")
	local ground = pitch and pitch:FindFirstChild("Ground")
	local teleporters = workspace:FindFirstChild("Teleporters")
	
	SlotManager.Initialize(ground, teleporters)
	TimeManager.Initialize(300) -- Default 5 min match
	MatchManager.Initialize()

	-- Find the ball and field center, then initialize BallManager
	local ball = workspace:FindFirstChild("Ball")
	if not ball then
		Logger:warn("Ball part not found in Workspace! BallManager will not initialize.")
	else
		-- Field center: use the ground part's position if available, else origin
		local fieldCenter = ground and ground.Position or Vector3.new(0, 0, 0)
		BallManager.Initialize(ball, fieldCenter)
	end
	
	-- 3. Initialize AI (Intelligent NPCs)
	AIManager.Initialize(SlotManager, BallManager, MatchManager)
	
	-- 3. Connect Events
	local events = ReplicatedStorage:WaitForChild("Events")
	local playerRemotes = events:WaitForChild("PlayerRemotes")
	local joinTeamRequest = playerRemotes:WaitForChild("JoinTeamRequest")
	
	joinTeamRequest.OnServerEvent:Connect(function(player, teamName)
		SlotManager.AssignPlayer(player, teamName)
	end)
	
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
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
