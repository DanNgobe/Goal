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

-- Load CameraController
local CameraController = require(ClientModules:WaitForChild("CameraController"))

-- Load BallEffects
local BallEffects = require(ClientModules:WaitForChild("BallEffects"))

-- Load StaminaController
local StaminaController = require(ClientModules:WaitForChild("StaminaController"))

-- Initialize Camera Controller first
local cameraSuccess = CameraController.Initialize()

-- Initialize Ball Effects
local ballEffectsSuccess = BallEffects.Initialize()

-- Initialize UI (pass CameraController reference)
local uiSuccess = UIController.Initialize(CameraController)

-- Initialize Stamina Controller
local staminaSuccess = StaminaController.Initialize()

-- Initialize Ball Control
local ballSuccess = BallControlClient.Initialize()

-- Initialize Input Handler (pass BallControlClient reference)
local inputSuccess = InputHandler.Initialize(BallControlClient)

if uiSuccess and ballSuccess and inputSuccess and cameraSuccess and ballEffectsSuccess and staminaSuccess then
	print("[ClientMain] ✓ Client ready")
else
	warn("[ClientMain] ✗ Client initialization failed!")
end
