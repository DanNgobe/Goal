--[[
	BallControlClient.lua
	Client-side ball control with power meter.
	
	Features:
	- Enhanced power meter with color zones
	- Clean, focused mechanics
]]

local BallControlClient = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Modules
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))
local ChargeBarUI = require(script.Parent.UI.ChargeBarUI)
local TrajectoryPredictor = require(script.Parent.TrajectoryPredictor)

-- Private variables
local Player = Players.LocalPlayer
local Character = nil
local Humanoid = nil
local RootPart = nil

local HasBall = false
local IsChargingGroundKick = false
local IsChargingAirKick = false
local ChargeStartTime = 0
local LastTackleTime = 0

-- Remote Events
local BallRemotes = nil
local KickBall = nil
local PossessionChanged = nil

local PlayerRemotes = nil
local TackleRequest = nil

-- Settings
local Settings = {
	MaxChargeTime = 2,
	MinPower = 0.3,
	TackleCooldown = 4.0,

	-- Kick Physics (must match server!)
	GroundKickSpeed = 100,
	AirKickSpeed = 90,
	AirKickUpwardForce = 40,
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function BallControlClient.Initialize()
	-- Wait for remotes
	BallRemotes = ReplicatedStorage:WaitForChild("BallRemotes", 10)
	if not BallRemotes then
		warn("[BallControlClient] BallRemotes folder not found!")
		return false
	end

	KickBall = BallRemotes:WaitForChild("KickBall", 5)
	PossessionChanged = BallRemotes:WaitForChild("PossessionChanged", 5)

	if not KickBall or not PossessionChanged then
		warn("[BallControlClient] Ball remote events not found!")
		return false
	end

	PlayerRemotes = ReplicatedStorage:WaitForChild("PlayerRemotes", 5)
	if PlayerRemotes then
		TackleRequest = PlayerRemotes:WaitForChild("TackleRequest", 5)
	end

	-- Create UI
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local screenGui = PlayerGui:FindFirstChild("BallUI") or Instance.new("ScreenGui")
	screenGui.Name = "BallUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = PlayerGui

	ChargeBarUI.Create(screenGui)

	-- Initialize trajectory predictor
	TrajectoryPredictor.Initialize()

	-- Listen for possession changes
	PossessionChanged.OnClientEvent:Connect(function(hasBall)
		OnPossessionChanged(hasBall)
	end)

	-- Setup systems
	SetupInput()
	SetupUpdateLoop()
	ConnectCharacter()

	Player.CharacterAdded:Connect(function()
		task.wait(0.5)
		ConnectCharacter()
	end)

	return true
end

--------------------------------------------------------------------------------
-- INPUT & CHARACTER
--------------------------------------------------------------------------------

function ConnectCharacter()
	Character = Player.Character
	if not Character then return end

	Humanoid = Character:WaitForChild("Humanoid")
	RootPart = Character:WaitForChild("HumanoidRootPart")
end

function SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			StartGroundKick()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			StartAirKick()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			ReleaseGroundKick()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			ReleaseAirKick()
		end
	end)
end

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function SetupUpdateLoop()
	RunService.RenderStepped:Connect(function(dt)
		if IsChargingGroundKick or IsChargingAirKick then
			local power = GetChargePower()
			ChargeBarUI.Update(power)

			-- Update trajectory prediction
			if RootPart then
				local direction = GetKickDirection()
				local startPos = RootPart.Position + Vector3.new(0, 2, 0) + direction * 3
				local kickType = IsChargingGroundKick and "Ground" or "Air"
				TrajectoryPredictor.Update(kickType, startPos, direction, power)
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- KICK DIRECTION
--------------------------------------------------------------------------------

function GetKickDirection()
	local Camera = workspace.CurrentCamera
	if not Camera then
		return RootPart.CFrame.LookVector
	end

	local MousePos = UserInputService:GetMouseLocation()
	local Ray = Camera:ViewportPointToRay(MousePos.X, MousePos.Y)

	-- Project direction onto horizontal plane (no vertical aiming)
	local Direction = Ray.Direction
	Direction = Vector3.new(Direction.X, 0, Direction.Z)

	-- Handle edge case where direction is vertical
	if Direction.Magnitude < 0.01 then
		return RootPart.CFrame.LookVector
	end

	return Direction.Unit
end

--------------------------------------------------------------------------------
-- ANIMATION
--------------------------------------------------------------------------------

-- Play kick animation for player
local function PlayKickAnimation(kickType, power, direction)
	if not Character or not Humanoid or not RootPart then
		return
	end

	-- Choose appropriate animation
	local animId = AnimationData.ChooseKickAnimation(RootPart, direction, power, kickType)

	-- Stop character movement
	local originalWalkSpeed = Humanoid.WalkSpeed
	Humanoid.WalkSpeed = 0
	RootPart.Anchored = true

	-- Load and play animation
	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = Humanoid
	end

	local kickAnimation = Instance.new("Animation")
	kickAnimation.AnimationId = animId
	local animTrack = animator:LoadAnimation(kickAnimation)
	animTrack:Play()

	-- Restore movement after animation
	task.spawn(function()
		task.wait(animTrack.Length)
		if RootPart and Humanoid then
			RootPart.Anchored = false
			Humanoid.WalkSpeed = originalWalkSpeed
			animTrack:Stop()
		end
	end)
end

--------------------------------------------------------------------------------
-- KICK ACTIONS
--------------------------------------------------------------------------------

function StartGroundKick()
	if not HasBall or not Character then return end

	IsChargingGroundKick = true
	ChargeStartTime = tick()
	ChargeBarUI.SetLabel("GROUND KICK")
	ChargeBarUI.Show()
	TrajectoryPredictor.Show()
end

function ReleaseGroundKick()
	if not IsChargingGroundKick then return end

	IsChargingGroundKick = false
	ChargeBarUI.Hide()
	TrajectoryPredictor.Hide()

	if HasBall and Character and RootPart then
		local power = GetChargePower()
		local direction = GetKickDirection()

		-- Play animation instantly on client
		PlayKickAnimation("Ground", power, direction)

		-- Send kick request to server
		KickBall:FireServer("Ground", power, direction)
	end
end

function StartAirKick()
	if not HasBall or not Character then return end

	IsChargingAirKick = true
	ChargeStartTime = tick()
	ChargeBarUI.SetLabel("AIR KICK")
	ChargeBarUI.Show()
	TrajectoryPredictor.Show()
end

function ReleaseAirKick()
	if not IsChargingAirKick then return end

	IsChargingAirKick = false
	ChargeBarUI.Hide()
	TrajectoryPredictor.Hide()

	if HasBall and Character and RootPart then
		local power = GetChargePower()
		local direction = GetKickDirection()

		-- Play animation instantly on client
		PlayKickAnimation("Air", power, direction)

		-- Send kick request to server
		KickBall:FireServer("Air", power, direction)
	end
end

--------------------------------------------------------------------------------
-- UTILITY
--------------------------------------------------------------------------------

function GetChargePower()
	local ChargeTime = tick() - ChargeStartTime
	return math.clamp(ChargeTime / Settings.MaxChargeTime, Settings.MinPower, 1)
end

function OnPossessionChanged(hasBall)
	HasBall = hasBall

	if not hasBall then
		IsChargingGroundKick = false
		IsChargingAirKick = false
		ChargeBarUI.Hide()
		TrajectoryPredictor.Hide()
	end
end

--------------------------------------------------------------------------------
-- TACKLE ACTION
--------------------------------------------------------------------------------

function BallControlClient.Tackle()
	if not Character or not Humanoid or not RootPart then return end

	-- Don't tackle if we have the ball
	if HasBall then return end

	-- Cooldown check
	if tick() - LastTackleTime < Settings.TackleCooldown then return end
	LastTackleTime = tick()

	-- Play animation locally
	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = AnimationData.Defense.Tackle
		local track = animator:LoadAnimation(anim)
		track.Looped = false
		track:Play()

		-- Push RootPart down by adjusting HipHeight during the slide
		local originalHipHeight = Humanoid.HipHeight
		local originalWalkSpeed = Humanoid.WalkSpeed
		Humanoid.HipHeight = 2.0 -- Lower to the ground for the slide
		Humanoid.WalkSpeed *= 1.5 -- Reduce speed for the slide
		-- Reset after animation roughly halfway or full duration
		task.delay(1.0, function()
			if Humanoid then
				Humanoid.HipHeight = originalHipHeight
				Humanoid.WalkSpeed = originalWalkSpeed
			end
		end)
	end

	-- Fire remote to server
	if TackleRequest then
		TackleRequest:FireServer()
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function BallControlClient.HasBall()
	return HasBall
end

return BallControlClient