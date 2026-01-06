--[[
	ClientMain.lua
	Client-side entry point for the soccer game.
	
	Place this in StarterPlayer/StarterPlayerScripts
]]

-- Wait for game to load
task.wait(1)

print("[ClientMain] Initializing client...")

-- Get ClientModules folder
local ClientModules = script.Parent:FindFirstChild("ClientModules")
if not ClientModules then
	warn("[ClientMain] ClientModules folder not found!")
	return
end

-- Load UIController
local UIController = require(ClientModules:WaitForChild("UIController"))

-- Load BallControlClient
local BallControlClient = require(ClientModules:WaitForChild("BallControlClient"))

-- Load InputHandler
local InputHandler = require(ClientModules:WaitForChild("InputHandler"))

-- Initialize UI
local uiSuccess = UIController.Initialize()

-- Initialize Ball Control
local ballSuccess = BallControlClient.Initialize()

-- Initialize Input Handler
local inputSuccess = InputHandler.Initialize()

if uiSuccess and ballSuccess and inputSuccess then
	print("[ClientMain] ✓ Client ready")
else
	warn("[ClientMain] ✗ Client initialization failed!")
end
