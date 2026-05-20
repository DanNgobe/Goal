--[[
	SoundController.lua
	Global orchestrator for client-side audio.
	
	Optimizations:
	- Uses a Sound Pool to reuse instances (prevents memory fragmentation)
	- Decoupled logic from data (uses ReplicatedStorage.SoundData)
	
	- Moved Pool Parent to Workspace for better client-side reach (Studio compatibility)
	- Added robust reset logic for recycled sounds
	- Added detailed debug logging
]]

local SoundController = {}

-- Services
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("SoundController")

-- Data
local SoundData = require(ReplicatedStorage:WaitForChild("SoundData"))

-- Pool Settings
local SoundPool = {}
local ActiveSounds = {} -- Track looping sounds for stopping
local MAX_POOL_SIZE = 15
local IsInitialized = false

-- The folder where we store our pooled sounds (Workspace is most reliable for global audio)
local PoolParent = nil

-- Initialize the pooling system
function SoundController.Initialize()
	if IsInitialized then return end
	
	Logger:info("Initializing Sound Pool...")
	
	-- Create/Find a folder in Workspace for our sounds
	PoolParent = Workspace:FindFirstChild("ClientAudioPool")
	if not PoolParent then
		PoolParent = Instance.new("Folder")
		PoolParent.Name = "ClientAudioPool"
		PoolParent.Parent = Workspace
	end
	
	-- Pre-warm floor of the pool
	for i = 1, 5 do
		local s = Instance.new("Sound")
		s.Name = "Pool_Sound_" .. i
		s.Parent = PoolParent
		table.insert(SoundPool, s)
	end
	
	IsInitialized = true
	Logger:info("Sound pool successfully parented to Workspace.")
end

-- Find an available sound instance and reset its properties
local function GetAvailableSound()
	local sound = nil
	for _, s in ipairs(SoundPool) do
		if not s.IsPlaying then
			sound = s
			break
		end
	end
	
	-- Expand if needed
	if not sound and #SoundPool < MAX_POOL_SIZE then
		sound = Instance.new("Sound")
		sound.Name = "Pool_Sound_" .. (#SoundPool + 1)
		sound.Parent = PoolParent
		table.insert(SoundPool, sound)
	end
	
	-- RESET properties for fresh use
	if sound then
		sound:Stop() -- Should already be stopped but good safety
		sound.Looped = false
		sound.Volume = 0.5
		sound.PlaybackSpeed = 1
	end
	
	return sound
end

-- Play a sound by name from the SoundData library
function SoundController.PlaySFX(name, volume, pitch)
	local soundId = SoundData[name]
	if not soundId then
		Logger:warn("Sound not found in SoundData:", name)
		return
	end
	
	local sound = GetAvailableSound()
	
	if sound then
		Logger:info("Playing SFX:", name, "ID:", soundId)
		sound.SoundId = soundId
		sound.Volume = volume or 0.5
		sound.PlaybackSpeed = pitch or 1
		sound:Play()
	else
		Logger:warn("Sound pool exhausted! Cannot play SFX:", name)
	end
end

-- Play a sound on loop (Ambience/Music)
function SoundController.PlayLooping(name, volume)
	local soundId = SoundData[name]
	if not soundId then
		Logger:warn("Sound not found in SoundData (Looping):", name)
		return
	end
	
	-- Stop if already playing this specifically
	if ActiveSounds[name] then
		Logger:debug("Restarting looping sound:", name)
		ActiveSounds[name]:Stop()
	end
	
	local sound = GetAvailableSound()
	
	if sound then
		Logger:info("Starting Looping Sound:", name, "ID:", soundId)
		sound.SoundId = soundId
		sound.Volume = volume or 0.5
		sound.Looped = true
		sound:Play()
		ActiveSounds[name] = sound
		return sound
	else
		Logger:warn("Sound pool exhausted! Cannot play Looping:", name)
	end
end

-- Stop a specific sound by library name
function SoundController.StopSound(name)
	local sound = ActiveSounds[name]
	if sound then
		Logger:debug("Stopping sound:", name)
		sound:Stop()
		sound.Looped = false -- Reset for future pool use
		ActiveSounds[name] = nil
	else
		Logger:debug("Attempted to stop sound but it wasn't active:", name)
	end
end

-- Backward compatibility for raw ID calls
function SoundController.PlayRaw(soundId, volume, pitch)
	local sound = GetAvailableSound()
	if sound then
		sound.SoundId = soundId
		sound.Volume = volume or 0.5
		sound.PlaybackSpeed = pitch or 1
		sound:Play()
	end
end

return SoundController
