--[[
	Logger.lua
	A centralized logging utility for consistent console output.
	
	Usage:
	local Logger = require(ReplicatedStorage.Utils.Logger).new("ModuleName")
	Logger:info("System started")
	Logger:debug("Variable value is:", someVar)
]]

local RunService = game:GetService("RunService")

local Logger = {}
Logger.__index = Logger

-- Log Levels
local LOG_LEVELS = {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3
}

-- Icons for console output
local ICONS = {
	DEBUG = "🔍",
	INFO = "ℹ️",
	WARN = "⚠️",
	ERROR = "❌"
}

-- Global configuration
local SHOW_DEBUG = RunService:IsStudio() -- Default to showing debug in Studio

-- Create a new logger instance for a specific module
function Logger.new(moduleName)
	local self = setmetatable({}, Logger)
	self.moduleName = moduleName or "Unknown"
	return self
end

-- Internal log function
function Logger:_log(levelName, ...)
	local level = LOG_LEVELS[levelName]
	
	-- Skip debug if disabled
	if levelName == "DEBUG" and not SHOW_DEBUG then
		return
	end
	
	local icon = ICONS[levelName] or ""
	local prefix = string.format("%s [%s] [%s]:", icon, self.moduleName, levelName)
	
	-- Flatten arguments for printing
	local args = {...}
	if levelName == "WARN" then
		warn(prefix, unpack(args))
	elseif levelName == "ERROR" then
		error(prefix .. " " .. tostring(args[1] or "Unknown Error"), 2)
	else
		print(prefix, unpack(args))
	end
end

-- Public Methods
function Logger:debug(...)
	self:_log("DEBUG", ...)
end

function Logger:info(...)
	self:_log("INFO", ...)
end

function Logger:warn(...)
	self:_log("WARN", ...)
end

function Logger:error(...)
	self:_log("ERROR", ...)
end

-- Global Control (Can be called from Server/Client main)
function Logger.SetDebugEnabled(enabled)
	SHOW_DEBUG = enabled
end

return Logger
