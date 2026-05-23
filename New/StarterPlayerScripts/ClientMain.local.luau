--[[
	ClientMain.lua
	Primary entry point for the client.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("ClientMain")

-- Controllers
local UIController       = require(script.Parent.Controllers.UIController)
local TimeController     = require(script.Parent.Controllers.TimeController)
local SoundController    = require(script.Parent.Controllers.SoundController)
local BallController     = require(script.Parent.Controllers.BallController)
local StaminaController  = require(script.Parent.Controllers.StaminaController)
local BallEffects        = require(script.Parent.Controllers.BallEffects)

-- Helper Modules
local TeamHelper = require(script.Parent.Utils.TeamHelper)

-- M key: toggle Roblox built-in mouse lock via the engine's ToggleMouseLock BindableEvent.
-- If the event doesn't exist yet (e.g. custom place setup), create it so the M key always works.
local function SetupMouseLockToggle()
	local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")

	local toggleEvent = playerScripts:FindFirstChild("ToggleMouseLock")
	if not toggleEvent then
		Logger:warn("ToggleMouseLock not found — creating it.")
		toggleEvent = Instance.new("BindableEvent")
		toggleEvent.Name = "ToggleMouseLock"
		toggleEvent.Parent = playerScripts
	end

	-- Ensure mouse starts unlocked regardless of any engine default
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.M then
			toggleEvent:Fire()
		end
	end)
	Logger:info("M key mouse lock wired via ToggleMouseLock.")
end

-- Start initialization
local function Bootstrap()
	Logger:info("Bootstrapping Client...")
	
	-- 1. Initialize Helpers
	TeamHelper.Initialize()
	
	-- 2. Initialize Controllers
	SoundController.Initialize()
	UIController.Initialize()
	TimeController.Initialize()
	BallController.Initialize()
	StaminaController.Initialize()
	BallEffects.Initialize()

	-- 3. Wire M key mouse lock (uses Roblox built-in ToggleMouseLock BindableEvent)
	SetupMouseLockToggle()
	
	Logger:info("Client bootstrap complete!")
end

-- Wait for game to load
if not game:IsLoaded() then
	game.Loaded:Wait()
end

wait(5)

Bootstrap()
