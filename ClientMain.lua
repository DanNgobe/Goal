--[[
	ClientMain.lua
	Client-side entry point for the soccer game.
	
	Place this in StarterPlayer/StarterPlayerScripts
]]

-- Wait for game to fully load to match ReplicatedFirst loading screen
if not game:IsLoaded() then
	game.Loaded:Wait()
end
-- Wait a bit extra to ensure the custom loading screen (with its 5s wait) is finishing
task.wait(4.5)

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

-- Hide player's own nameplate
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function onCharacterAdded(character)
	-- Listen for when head is added
	character.ChildAdded:Connect(function(child)
		if child.Name == "Head" then
			-- Listen for billboard gui being added to head
			child.ChildAdded:Connect(function(gui)
				if gui:IsA("BillboardGui") then
					gui:Destroy()
				end
			end)
			
			-- Also check existing children in case it's already there
			for _, gui in ipairs(child:GetChildren()) do
				if gui:IsA("BillboardGui") then
					gui:Destroy()
				end
			end
		end
	end)
	
	-- Also check if head already exists
	local head = character:FindFirstChild("Head")
	if head then
		-- Listen for billboard gui being added to head
		head.ChildAdded:Connect(function(gui)
			if gui:IsA("BillboardGui") then
				gui:Destroy()
			end
		end)
		
		-- Check existing children
		for _, gui in ipairs(head:GetChildren()) do
			if gui:IsA("BillboardGui") then
				gui:Destroy()
			end
		end
	end
end

if player then
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end
