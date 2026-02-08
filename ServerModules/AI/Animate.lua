--[[
	Animate.lua
	Simplified NPC animation controller.
	Handles: Idle, Running, Jumping, and FreeFall.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))

local Figure = script.Parent
local Humanoid = Figure:WaitForChild("Humanoid")

-- State
local currentAnimTrack = nil
local currentAnimName = ""

-- Configuration
local ANIM_FADE_TIME = 0.1

--------------------------------------------------------------------------------
-- CORE FUNCTIONS
--------------------------------------------------------------------------------

local function stopAllAnimations()
	if currentAnimTrack then
		currentAnimTrack:Stop(ANIM_FADE_TIME)
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end
	currentAnimName = ""
end

local function playAnimation(name, assetId, loop)
	if currentAnimName == name or not assetId then 
		if not assetId then
			warn("[Animate] Cannot play animation '" .. tostring(name) .. "' - AssetId is nil")
		end
		return 
	end
	
	-- Store previous track to destroy it after fade
	local oldTrack = currentAnimTrack
	
	local animation = Instance.new("Animation")
	animation.AnimationId = assetId
	
	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = Humanoid
	end
	
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	
	if success and track then
		track.Priority = Enum.AnimationPriority.Core
		track.Looped = loop or false
		track:Play(ANIM_FADE_TIME)
		currentAnimTrack = track
		currentAnimName = name
		
		-- Smoothly clean up the old track
		if oldTrack then
			oldTrack:Stop(ANIM_FADE_TIME)
			task.delay(ANIM_FADE_TIME + 0.1, function()
				oldTrack:Destroy()
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- EVENT HANDLERS
--------------------------------------------------------------------------------

local function onRunning(speed)
	if speed > 0.1 then
		playAnimation("Running", AnimationData.Movement.Running, true)
		if currentAnimTrack then
			-- Scale animation speed with movement speed (standard is 16)
			currentAnimTrack:AdjustSpeed(speed / 16)
		end
	else
		-- Default to Offensive idle for field players
		playAnimation("Idle", AnimationData.Idle.Offensive, true)
	end
end

local function onJumping()
	playAnimation("Jumping", AnimationData.Movement.Jump, false)
end

local function onFreeFall()
	playAnimation("Fall", AnimationData.Movement.Fall, true)
end

local function onDied()
	stopAllAnimations()
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

-- Connect events
Humanoid.Running:Connect(onRunning)
Humanoid.Jumping:Connect(onJumping)
Humanoid.FreeFalling:Connect(onFreeFall)
Humanoid.Died:Connect(onDied)

-- Start in Idle
playAnimation("Idle", AnimationData.Idle.Offensive, true)


