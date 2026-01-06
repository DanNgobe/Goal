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
	local teamSuccess = Managers.TeamManager.Initialize(WorkspaceRefs.BlueGoal, WorkspaceRefs.RedGoal)
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

	-- Step 8: Initialize BallManager
	local ballSuccess = Managers.BallManager.Initialize(WorkspaceRefs.Ball)
	if not ballSuccess then
		warn("[GameManager] Failed to initialize BallManager!")
		return false
	end

	-- Step 9: Initialize GoalManager FIRST (before AI)
	local fieldCenter = Managers.NPCManager.GetFieldCenter()
	local goalSuccess = Managers.GoalManager.Initialize(
		Managers.TeamManager,
		Managers.BallManager,
		WorkspaceRefs.Ball,
		WorkspaceRefs.BlueGoal,
		WorkspaceRefs.RedGoal,
		fieldCenter
	)
	if not goalSuccess then
		warn("[GameManager] Failed to initialize GoalManager!")
		return false
	end

	-- Step 10: Initialize AIController (needs GoalManager for kickoff checks)
	local aiSuccess = Managers.AIController.Initialize(
		Managers.TeamManager,
		Managers.NPCManager,
		Managers.BallManager,
		Managers.FormationData,
		Managers.GoalManager  -- Pass GoalManager for kickoff coordination
	)
	if not aiSuccess then
		warn("[GameManager] Failed to initialize AIController!")
		return false
	end

	-- Step 11: Connect BallManager to GoalManager for kickoff handling
	Managers.BallManager.SetGoalManager(Managers.GoalManager)
	
	-- Step 12: Initialize PlayerController
	local playerSuccess = Managers.PlayerController.Initialize(
		Managers.TeamManager,
		Managers.NPCManager,
		Managers.GoalManager
	)
	if not playerSuccess then
		warn("[GameManager] Failed to initialize PlayerController!")
		return false
	end

	-- Step 13: Initialize and start MatchTimer
	local timerSuccess = Managers.MatchTimer.Initialize(GameManager, 300)  -- 5 minutes
	if not timerSuccess then
		warn("[GameManager] Failed to initialize MatchTimer!")
		return false
	end
	Managers.MatchTimer.Start()

	print(string.format("[GameManager] Spawned %d Blue + %d Red NPCs", #blueNPCs, #redNPCs))

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
		"AIController",
		"GoalManager",
		"PlayerController",
		"MatchTimer"
	}

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
	print("[GameManager] Match ended!")
	return true
end

-- Reset the round (for future use)
function GameManager.ResetRound()
	print("[GameManager] Resetting round...")

	-- Reset ball to center
	if WorkspaceRefs.Ball and WorkspaceRefs.Ground then
		local center = WorkspaceRefs.Ground.Position
		WorkspaceRefs.Ball.Position = center + Vector3.new(0, 5, 0)
		WorkspaceRefs.Ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		WorkspaceRefs.Ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end

	-- Detach ball if possessed
	if Managers.BallManager then
		Managers.BallManager.DetachBall()
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
	if Managers.GoalManager then
		Managers.GoalManager.Cleanup()
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
