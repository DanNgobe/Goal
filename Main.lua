--[[
	Main.lua
	Entry point for the soccer game server.
	
	Place this in ServerScriptService.
	This is the ONLY script that should run at startup (besides this, everything is modules).
]]

-- ============================================
-- GAME CONFIGURATION
-- ============================================
local TEAM_SIZE = 5  -- Set to 5 for 5v5 mode

-- Wait a moment for workspace to fully load
task.wait(1)

print("============================================")
print(string.format("    %dv%d SOCCER GAME - INITIALIZING", TEAM_SIZE, TEAM_SIZE))
print("============================================")

-- ============================================
-- SETUP COLLISION GROUPS
-- ============================================
local function SetupCollisionGroups()
	local PhysicsService = game:GetService("PhysicsService")

	-- Register collision groups
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("Players") then
			PhysicsService:RegisterCollisionGroup("Players")
		end
	end)
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("NPCs") then
			PhysicsService:RegisterCollisionGroup("NPCs")
		end
	end)
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("Ball") then
			PhysicsService:RegisterCollisionGroup("Ball")
		end
	end)

	-- Set collision rules
	pcall(function()
		-- Players and NPCs don't collide with each other
		PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
		PhysicsService:CollisionGroupSetCollidable("NPCs", "NPCs", false)
		PhysicsService:CollisionGroupSetCollidable("Players", "NPCs", false)

		-- Ball doesn't collide with Players or NPCs (handled by touch/magnets)
		PhysicsService:CollisionGroupSetCollidable("Ball", "Players", false)
		PhysicsService:CollisionGroupSetCollidable("Ball", "NPCs", false)

		-- All groups can collide with Default (ground, goals, walls, etc.)
		PhysicsService:CollisionGroupSetCollidable("Players", "Default", true)
		PhysicsService:CollisionGroupSetCollidable("NPCs", "Default", true)
		PhysicsService:CollisionGroupSetCollidable("Ball", "Default", true)
	end)

end

-- Setup collision groups before initializing game systems
SetupCollisionGroups()

-- Get the ServerModules folder
local ServerModules = script.Parent:FindFirstChild("ServerModules")
if not ServerModules then
	error("[Main] ServerModules folder not found! Make sure it's in ServerScriptService.")
end

-- Load FormationData first to set team size
local FormationData = require(ServerModules:WaitForChild("FormationData"))
FormationData.SetTeamSize(TEAM_SIZE)

-- Load GameManager
local GameManager = require(ServerModules:WaitForChild("GameManager"))

-- Load DonationHandler
local DonationHandler = require(ServerModules:WaitForChild("DonationHandler"))

-- Initialize the game
local success = GameManager.Initialize()

if not success then
	warn("[Main] ✗ Initialization failed!")
end

-- Initialize donation system
DonationHandler.Initialize()
