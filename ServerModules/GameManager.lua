--[[
	GameManager.lua
	Core game orchestrator - initializes and coordinates all systems.
	
	Responsibilities:
	- Initialize all managers in correct order
	- Store references to all managers
	- Handle game state (Waiting, Playing, Ended)
	- Coordinate between systems
]]

local GameManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Game states
local GameState = {
	Waiting = "Waiting",
	Playing = "Playing",
	Ended = "Ended"
}

-- Private variables
local CurrentState = GameState.Waiting
local Managers = {}

-- References to workspace objects
local WorkspaceRefs = {
	Pitch = nil,
	Ground = nil,
	BlueGoal = nil,
	RedGoal = nil,
	Ball = nil
}

-- Initialize the Game Manager
function GameManager.Initialize()
	-- Step 1: Find workspace objects
	if not GameManager._FindWorkspaceObjects() then
		warn("[GameManager] Failed to find required workspace objects!")
		return false
	end

	-- Step 2: Load all manager modules
	if not GameManager._LoadManagers() then
		warn("[GameManager] Failed to load managers!")
		return false
	end

	-- Step 4: Initialize NPCManager
	local npcSuccess = Managers.NPCManager.Initialize(WorkspaceRefs.Ground, Managers.FormationData)
	if not npcSuccess then
		warn("[GameManager] Failed to initialize NPCManager!")
		return false
	end

	-- Step 5: Initialize TeamManager
	local teamSuccess = Managers.TeamManager.Initialize(
		WorkspaceRefs.BlueGoal, 
		WorkspaceRefs.RedGoal,
		Managers.NPCManager,
		Managers.FormationData
	)
	if not teamSuccess then
		warn("[GameManager] Failed to initialize TeamManager!")
		return false
	end

	-- Step 6: Spawn NPCs for both teams
	local blueNPCs = Managers.NPCManager.SpawnTeamNPCs("Blue")
	local redNPCs = Managers.NPCManager.SpawnTeamNPCs("Red")

	-- Step 7: Setup team slots with spawned NPCs
	Managers.TeamManager.SetupTeamSlots("Blue", blueNPCs)
	Managers.TeamManager.SetupTeamSlots("Red", redNPCs)

	-- Step 8: Initialize BallManager with goals
	local fieldCenter = Managers.NPCManager.GetFieldCenter()
	local ballSuccess = Managers.BallManager.Initialize(
		WorkspaceRefs.Ball,
		WorkspaceRefs.BlueGoal,
		WorkspaceRefs.RedGoal,
		fieldCenter,
		Managers.TeamManager
	)
	if not ballSuccess then
		warn("[GameManager] Failed to initialize BallManager!")
		return false
	end

	-- Step 9: Initialize AIController (needs TeamManager for kickoff checks)
	local aiSuccess = Managers.AIController.Initialize(
		Managers.TeamManager,
		Managers.NPCManager,
		Managers.BallManager,
		Managers.FormationData
	)
	if not aiSuccess then
		warn("[GameManager] Failed to initialize AIController!")
		return false
	end

	-- Step 10: Initialize PlayerController
	local playerSuccess = Managers.PlayerController.Initialize(
		Managers.TeamManager,
		Managers.NPCManager
	)
	if not playerSuccess then
		warn("[GameManager] Failed to initialize PlayerController!")
		return false
	end

	-- Step 11: Initialize and start MatchTimer
	local timerSuccess = Managers.MatchTimer.Initialize(GameManager)  -- 5 minutes
	if not timerSuccess then
		warn("[GameManager] Failed to initialize MatchTimer!")
		return false
	end
	Managers.MatchTimer.Start()
	
	CurrentState = GameState.Playing
	return true
end

-- Private: Find all required workspace objects
function GameManager._FindWorkspaceObjects()

	-- Find Pitch
	WorkspaceRefs.Pitch = workspace:FindFirstChild("Pitch")
	if not WorkspaceRefs.Pitch then
		warn("[GameManager] Pitch model not found in workspace!")
		return false
	end

	-- Find Ground
	WorkspaceRefs.Ground = WorkspaceRefs.Pitch:FindFirstChild("Ground")
	if not WorkspaceRefs.Ground then
		warn("[GameManager] Ground part not found in Pitch!")
		return false
	end

	-- Find Goals
	WorkspaceRefs.BlueGoal = WorkspaceRefs.Pitch:FindFirstChild("BlueGoal")
	WorkspaceRefs.RedGoal = WorkspaceRefs.Pitch:FindFirstChild("RedGoal")

	if not WorkspaceRefs.BlueGoal then
		warn("[GameManager] BlueGoal not found in Pitch!")
	end
	if not WorkspaceRefs.RedGoal then
		warn("[GameManager] RedGoal not found in Pitch!")
	end

	-- Find Ball
	WorkspaceRefs.Ball = workspace:FindFirstChild("Ball")
	if not WorkspaceRefs.Ball then
		warn("[GameManager] Ball not found in workspace!")
		return false
	end

	return true
end

-- Private: Load all manager modules
function GameManager._LoadManagers()

	local ServerModules = script.Parent
	if not ServerModules then
		warn("[GameManager] Cannot find ServerModules folder!")
		return false
	end

	-- Load each manager
	local managersToLoad = {
		"FormationData",
		"NPCManager",
		"TeamManager",
		"BallManager",
		"PlayerController",
		"MatchTimer"
	}

	-- Load AI system (new modular structure)
	local aiCoreModule = ServerModules:FindFirstChild("AI")
	if aiCoreModule then
		aiCoreModule = aiCoreModule:FindFirstChild("AICore")
	end
	if not aiCoreModule then
		warn("[GameManager] AI/AICore module not found!")
		return false
	end
	local success, aiCore = pcall(require, aiCoreModule)
	if not success then
		warn("[GameManager] Failed to load AICore: " .. tostring(aiCore))
		return false
	end
	Managers.AIController = aiCore  -- Keep same name for compatibility

	for _, managerName in ipairs(managersToLoad) do
		local moduleScript = ServerModules:FindFirstChild(managerName)
		if not moduleScript then
			warn(string.format("[GameManager] Module '%s' not found!", managerName))
			return false
		end

		local success, module = pcall(require, moduleScript)
		if not success then
			warn(string.format("[GameManager] Failed to load '%s': %s", managerName, module))
			return false
		end

		Managers[managerName] = module
	end

	return true
end

-- Get a specific manager
function GameManager.GetManager(managerName)
	return Managers[managerName]
end

-- Get all managers
function GameManager.GetAllManagers()
	return Managers
end

-- Get current game state
function GameManager.GetState()
	return CurrentState
end

-- Get workspace references
function GameManager.GetWorkspaceRefs()
	return WorkspaceRefs
end

-- Start the match (for future use)
function GameManager.StartMatch()
	if CurrentState ~= GameState.Waiting then
		warn("[GameManager] Cannot start match - not in Waiting state")
		return false
	end

	CurrentState = GameState.Playing
	print("[GameManager] Match started!")
	return true
end

-- End the match (for future use)
function GameManager.EndMatch()
	if CurrentState ~= GameState.Playing then
		warn("[GameManager] Cannot end match - not in Playing state")
		return false
	end

	CurrentState = GameState.Ended

	-- Determine winning team
	local blueScore = Managers.TeamManager and Managers.TeamManager.GetScore("Blue") or 0
	local redScore = Managers.TeamManager and Managers.TeamManager.GetScore("Red") or 0
	local winningTeam = "Draw"

	if blueScore > redScore then
		winningTeam = "Blue"
	elseif redScore > blueScore then
		winningTeam = "Red"
	end

	-- Notify all clients
	local gameRemotes = ReplicatedStorage:FindFirstChild("GameRemotes")
	if gameRemotes then
		local matchEnded = gameRemotes:FindFirstChild("MatchEnded")
		if not matchEnded then
			matchEnded = Instance.new("RemoteEvent")
			matchEnded.Name = "MatchEnded"
			matchEnded.Parent = gameRemotes
		end
		matchEnded:FireAllClients(winningTeam, blueScore, redScore)
	end

	-- Freeze all players
	if Managers.TeamManager then
		Managers.TeamManager.FreezeTeams({"Blue", "Red"})
	end

	-- Reset players: restore NPCs to slots and kill player characters
	if Managers.PlayerController and Managers.PlayerController.ResetAllPlayersForNewMatch then
		Managers.PlayerController.ResetAllPlayersForNewMatch()
	end

	-- Wait for clients to show match end screen (5 seconds as per UIController)
	-- Players will respawn during this time
	task.wait(5)

	-- Reset all player/NPC positions similar to goal reset
	if Managers.TeamManager then
		Managers.TeamManager.ResetAllPositions()
	end

	-- Reset game state (ball to center)
	GameManager.ResetRound()

	-- Reset scores
	if Managers.TeamManager then
		Managers.TeamManager.ResetScores()
	end

	-- Unfreeze all teams for the new match
	if Managers.TeamManager then
		Managers.TeamManager.UnfreezeAllTeams()
	end

	-- Immediately start a new match: reset and restart timer
	if Managers.MatchTimer then
		Managers.MatchTimer.Reset()
		Managers.MatchTimer.Start()
	end

	-- Set state to Playing for the new match
	CurrentState = GameState.Playing
	print("[GameManager] New match started")

	return true
end

-- Reset the round (for future use)
function GameManager.ResetRound()
	print("[GameManager] Resetting round...")

	-- Detach ball first if possessed
	if Managers.BallManager then
		Managers.BallManager.DetachBall()
	end

	-- Reset ball to center with zero velocity
	if WorkspaceRefs.Ball and WorkspaceRefs.Ground then
		local center = WorkspaceRefs.Ground.Position
		WorkspaceRefs.Ball.CFrame = CFrame.new(center + Vector3.new(0, 5, 0))
		WorkspaceRefs.Ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		WorkspaceRefs.Ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end

	-- TODO: Return NPCs to positions (will be handled by AIController in later batch)

	print("[GameManager] Round reset complete")
	return true
end

-- Cleanup (for testing)
function GameManager.Cleanup()
	if Managers.MatchTimer then
		Managers.MatchTimer.Cleanup()
	end
	if Managers.AIController then
		Managers.AIController.Cleanup()
	end
	if Managers.BallManager then
		Managers.BallManager.Cleanup()
	end
	if Managers.TeamManager then
		Managers.TeamManager.Cleanup()
	end
	if Managers.NPCManager then
		Managers.NPCManager.ClearAllNPCs()
	end

	CurrentState = GameState.Waiting
	print("[GameManager] Cleaned up")
end

return GameManager
