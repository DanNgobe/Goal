--[[
	MatchTimer.lua
	Manages the match timer and broadcasts to clients.
	
	Responsibilities:
	- Track match time
	- Broadcast timer updates to clients
	- Handle match end when timer reaches 0
]]

local MatchTimer = {}

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Private variables
local GameManager = nil
local MatchDuration = 300  -- 5 minutes in seconds
local TimeRemaining = MatchDuration
local IsRunning = false
local HeartbeatConnection = nil

-- Remote Events
local RemoteFolder = nil
local TimerUpdate = nil
local MatchEnded = nil

-- Initialize the Match Timer
function MatchTimer.Initialize(gameManager, duration)
	GameManager = gameManager
	MatchDuration = duration or MatchDuration
	TimeRemaining = MatchDuration

	-- Create RemoteEvents
	RemoteFolder = ReplicatedStorage:FindFirstChild("GameRemotes")
	if not RemoteFolder then
		RemoteFolder = Instance.new("Folder")
		RemoteFolder.Name = "GameRemotes"
		RemoteFolder.Parent = ReplicatedStorage
	end

	TimerUpdate = Instance.new("RemoteEvent")
	TimerUpdate.Name = "TimerUpdate"
	TimerUpdate.Parent = RemoteFolder

	-- Ensure MatchEnded RemoteEvent exists early so clients can subscribe
	MatchEnded = RemoteFolder:FindFirstChild("MatchEnded")
	if not MatchEnded then
		MatchEnded = Instance.new("RemoteEvent")
		MatchEnded.Name = "MatchEnded"
		MatchEnded.Parent = RemoteFolder
	end

	return true
end

-- Start the match timer
function MatchTimer.Start()
	if IsRunning then
		return
	end

	IsRunning = true
	local lastUpdate = tick()

	HeartbeatConnection = RunService.Heartbeat:Connect(function()
		if not IsRunning then
			return
		end

		local currentTime = tick()
		local deltaTime = currentTime - lastUpdate

		-- Update every second
		if deltaTime >= 1 then
			lastUpdate = currentTime
			TimeRemaining = math.max(0, TimeRemaining - 1)

			-- Broadcast to all clients
			TimerUpdate:FireAllClients(TimeRemaining)

			-- Check if match ended
			if TimeRemaining <= 0 then
				MatchTimer.Stop()
				MatchTimer._OnMatchEnd()
			end
		end
	end)

	-- Send initial time
	TimerUpdate:FireAllClients(TimeRemaining)

end

-- Stop the timer
function MatchTimer.Stop()
	IsRunning = false
	if HeartbeatConnection then
		HeartbeatConnection:Disconnect()
		HeartbeatConnection = nil
	end
end

-- Pause the timer
function MatchTimer.Pause()
	IsRunning = false
end

-- Resume the timer
function MatchTimer.Resume()
	IsRunning = true
end

-- Reset the timer
function MatchTimer.Reset()
	TimeRemaining = MatchDuration
	TimerUpdate:FireAllClients(TimeRemaining)
end

-- Get time remaining
function MatchTimer.GetTimeRemaining()
	return TimeRemaining
end

-- Set time remaining
function MatchTimer.SetTimeRemaining(time)
	TimeRemaining = time
	TimerUpdate:FireAllClients(TimeRemaining)
end

-- Private: Handle match end
function MatchTimer._OnMatchEnd()
	-- Notify GameManager if available
	if GameManager then
		GameManager.EndMatch()
	end
end

-- Cleanup
function MatchTimer.Cleanup()
	MatchTimer.Stop()

	if RemoteFolder then
		RemoteFolder:Destroy()
	end
end

return MatchTimer
