--[[
	ServerMain.lua
	Primary entry point for the server.
	Bootstrap for the GameManager.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("ServerMain")

-- Managers
local GameManager = require(script.Parent.Managers.GameManager)

-- Start initialization
local function Bootstrap()
	Logger:info("Bootstrapping Server...")
	
	-- Initialize GameManager
	GameManager.Initialize()
	
	Logger:info("Server bootstrap complete!")
end

Bootstrap()
