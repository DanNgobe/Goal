--[[
	AICore.lua
	Main AI coordinator - entry point for the AI system
	
	This module orchestrates all AI subsystems:
	- AIUtils: Shared utilities
	- AITactics: Formations and roles
	- AIBehavior: Field player actions
	- AIGoalkeeper: Goalkeeper behavior (stub)
	
	Replaces the monolithic AIController.lua
]]

local AICore = {}

-- Services
local RunService = game:GetService("RunService")

-- AI Modules
local AIUtils = require(script.Parent.AIUtils)
local AITactics = require(script.Parent.AITactics)
local AIBehavior = require(script.Parent.AIBehavior)
local AIGoalkeeper = require(script.Parent.AIGoalkeeper)

-- Dependencies (injected)
local TeamManager = nil
local NPCManager = nil
local BallManager = nil
local FormationData = nil

-- State
local State = {
	LastUpdate = 0
}

-- Configuration
local Config = {
	UpdateInterval = 0.1
}

local UpdateConnection = nil

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AICore.Initialize(teamManager, npcManager, ballManager, formationData)
	TeamManager = teamManager
	NPCManager = npcManager
	BallManager = ballManager
	FormationData = formationData

	if not TeamManager or not NPCManager or not BallManager or not FormationData then
		warn("[AICore] Missing required managers!")
		return false
	end

	-- Initialize all AI subsystems
	local utilsOk = AIUtils.Initialize(teamManager, npcManager)
	local tacticsOk = AITactics.Initialize(teamManager, npcManager, ballManager, formationData)
	local behaviorOk = AIBehavior.Initialize(teamManager, ballManager)
	local gkOk = AIGoalkeeper.Initialize(teamManager, ballManager)

	if not (utilsOk and tacticsOk and behaviorOk and gkOk) then
		warn("[AICore] Failed to initialize AI subsystems!")
		return false
	end

	StartUpdateLoop()
	print("[AICore] Initialized with modular AI system")
	return true
end

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function StartUpdateLoop()
	UpdateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - State.LastUpdate < Config.UpdateInterval then return end
		State.LastUpdate = now

		-- Update tactics (formations, roles)
		AITactics.UpdateBallRoles()

		-- Update all NPCs
		UpdateAllAI()
	end)
end

function UpdateAllAI()
	if TeamManager and TeamManager.IsProcessingGoal() then return end

	for _, teamName in ipairs({"Blue", "Red"}) do
		if TeamManager and TeamManager.IsTeamFrozen(teamName) then continue end

		local slots = TeamManager.GetAISlots(teamName)
		for _, slot in ipairs(slots) do
			UpdateNPC(slot, teamName)
		end
	end
end

function UpdateNPC(slot, teamName)
	-- Get NPC role from tactics
	local role = AITactics.GetNPCRole(slot, teamName)

	-- Check if this is a goalkeeper
	local isGoalkeeper = slot.Role == "GK"

	if isGoalkeeper then
		AIGoalkeeper.UpdateGoalkeeper(slot, teamName)
	else
		AIBehavior.UpdateNPC(slot, teamName, role)
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API (for compatibility with existing code)
--------------------------------------------------------------------------------

function AICore.GetTeamFormation(teamName)
	return AITactics.GetTeamFormation(teamName)
end

function AICore.GetBallRoles(teamName)
	return AITactics.GetBallRoles(teamName)
end

function AICore.ForceFormationUpdate(teamName, formationType)
	return AITactics.ForceFormationUpdate(teamName, formationType)
end

function AICore.RefreshAllPositions()
	return AITactics.RefreshAllPositions()
end

function AICore.Cleanup()
	if UpdateConnection then
		UpdateConnection:Disconnect()
		UpdateConnection = nil
	end

	AIBehavior.Cleanup()
	AIGoalkeeper.Cleanup()

	print("[AICore] Cleaned up")
end

return AICore
