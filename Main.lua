--[[
	Main.lua
	Entry point for the soccer game server.
	
	Place this in ServerScriptService.
	This is the ONLY script that should run at startup (besides this, everything is modules).
]]

-- ============================================
-- GAME CONFIGURATION
-- ============================================
local TEAM_SIZE = 4  -- Set to 4 for 4v4, or 6 for 6v6

-- Wait a moment for workspace to fully load
task.wait(1)

print("============================================")
print(string.format("    %dv%d SOCCER GAME - INITIALIZING", TEAM_SIZE, TEAM_SIZE))
print("============================================")

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

-- Initialize the game
local success = GameManager.Initialize()

if success then
	print(string.format("[Main] ✓ Game ready - %dv%d mode", TEAM_SIZE, TEAM_SIZE))
else
	warn("[Main] ✗ Initialization failed!")
end
