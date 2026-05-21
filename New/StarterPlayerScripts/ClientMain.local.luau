--[[
	ClientMain.lua
	Primary entry point for the client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("ClientMain")

-- Controllers
local UIController       = require(script.Parent.Controllers.UIController)
local TimeController     = require(script.Parent.Controllers.TimeController)
local SoundController    = require(script.Parent.Controllers.SoundController)
local BallController     = require(script.Parent.Controllers.BallController)
local StaminaController  = require(script.Parent.Controllers.StaminaController)
local CameraController   = require(script.Parent.Controllers.CameraController)
local BallEffects        = require(script.Parent.Controllers.BallEffects)

-- Helper Modules
local TeamHelper = require(script.Parent.Utils.TeamHelper)

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
	CameraController.Initialize()
	BallEffects.Initialize()
	
	Logger:info("Client bootstrap complete!")
end

-- Wait for game to load
if not game:IsLoaded() then
	game.Loaded:Wait()
end

wait(5)

Bootstrap()
