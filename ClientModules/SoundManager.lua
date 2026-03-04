--[[
	SoundManager.lua
	Manages all game sounds (match events, goals, ambience).
	Listens to server events and plays appropriate sounds.
]]

local SoundManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Modules
local SoundData = require(ReplicatedStorage:WaitForChild("SoundData"))

-- Private variables
local AmbienceSound = nil

-- Play a sound once
local function PlaySound(soundId, volume, parent)
	if not soundId then return end
	
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = parent or SoundService
	sound:Play()
	
	-- Clean up after sound finishes
	game:GetService("Debris"):AddItem(sound, 10)
	
	return sound
end

-- Play looping background sound
local function PlayLoopingSound(soundId, volume)
	if not soundId then return nil end
	
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.3
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	
	return sound
end

-- Initialize the Sound Manager
function SoundManager.Initialize()
	print("[SoundManager] Initializing...")
	
	-- Start stadium ambience immediately
	if SoundData.Stadium_Ambience then
		AmbienceSound = PlayLoopingSound(SoundData.Stadium_Ambience, 0.25)
		print("[SoundManager] Stadium ambience playing")
	end
	
	-- Listen for match events
	SoundManager._ConnectMatchEvents()
	SoundManager._ConnectGoalEvents()
	
	return true
end

-- Connect to match start/end events
function SoundManager._ConnectMatchEvents()
	task.spawn(function()
		local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
		
		-- Match Start Whistle
		local matchStart = gameRemotes:WaitForChild("MatchStart")
		matchStart.OnClientEvent:Connect(function()
			PlaySound(SoundData.Whistle_Start, 0.6)
			print("[SoundManager] Match start whistle played")
		end)
		
		-- Match End Whistle
		local matchEnded = gameRemotes:WaitForChild("MatchEnded")
		matchEnded.OnClientEvent:Connect(function(winningTeam, blueScore, redScore)
			PlaySound(SoundData.Whistle_End, 0.6)
			print("[SoundManager] Match end whistle played")
		end)
	end)
end

-- Connect to goal scored events
function SoundManager._ConnectGoalEvents()
	task.spawn(function()
		local goalRemotes = ReplicatedStorage:WaitForChild("GoalRemotes")
		local goalScored = goalRemotes:WaitForChild("GoalScored")
		goalScored.OnClientEvent:Connect(function(scoringTeam, blueScore, redScore, scorerName, assisterName)
			-- Play goal cheer
			PlaySound(SoundData.Goal_Cheer, 0.7)
			print("[SoundManager] Goal cheer played")
		end)
	end)
end

-- Stop ambience (for cleanup)
function SoundManager.StopAmbience()
	if AmbienceSound then
		AmbienceSound:Stop()
		AmbienceSound:Destroy()
		AmbienceSound = nil
	end
end

-- Cleanup
function SoundManager.Cleanup()
	SoundManager.StopAmbience()
end

return SoundManager
