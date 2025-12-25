--[[
	Main.lua
	Entry point for the soccer game server.
	
	Place this in ServerScriptService.
	This is the ONLY script that should run at startup (besides this, everything is modules).
]]

-- Wait a moment for workspace to fully load
task.wait(1)

print("============================================")
print("    6v6 SOCCER GAME - INITIALIZING")
print("============================================")

-- Get the ServerModules folder
local ServerModules = script.Parent:FindFirstChild("ServerModules")
if not ServerModules then
	error("[Main] ServerModules folder not found! Make sure it's in ServerScriptService.")
end

-- Load GameManager
local GameManager = require(ServerModules:WaitForChild("GameManager"))

-- Initialize the game
local success = GameManager.Initialize()

if success then
	print("[Main] ✓ Game ready - 6v6 mode")
else
	warn("[Main] ✗ Initialization failed!")
end
