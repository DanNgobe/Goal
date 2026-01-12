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

-- Private variables
local Player = Players.LocalPlayer
local Character = nil
local Humanoid = nil
local RootPart = nil

local HasBall = false
local IsChargingGroundKick = false
local IsChargingAirKick = false
local ChargeStartTime = 0

-- UI Elements
local ScreenGui = nil
local ChargeFrame = nil
local ChargeBar = nil
local ChargeLabel = nil

-- 3D Visual Elements (removed)

-- Remote Events
local BallRemotes = nil
local KickBall = nil
local PossessionChanged = nil

-- Settings
local Settings = {
	MaxChargeTime = 2,
	MinPower = 0.3,

	-- Kick Physics (must match server!)
	GroundKickSpeed = 100,
	AirKickSpeed = 90,
	AirKickUpwardForce = 40,

	-- Colors
	ColorPowerLow = Color3.fromRGB(100, 255, 100),
	ColorPowerMed = Color3.fromRGB(255, 200, 0),
	ColorPowerHigh = Color3.fromRGB(255, 100, 100),
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

	-- Create UI
	CreateChargeUI()

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

	print("[BallControlClient] Initialized")
	return true
end

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

function CreateChargeUI()
	local PlayerGui = Player:WaitForChild("PlayerGui")

	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "BallUI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	-- Charge Frame Container
	ChargeFrame = Instance.new("Frame")
	ChargeFrame.Name = "ChargeFrame"
	ChargeFrame.Size = UDim2.new(0, 350, 0, 50)
	ChargeFrame.Position = UDim2.new(0.5, -175, 0.85, 0)
	ChargeFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	ChargeFrame.BackgroundTransparency = 0.3
	ChargeFrame.BorderSizePixel = 0
	ChargeFrame.Visible = false
	ChargeFrame.Parent = ScreenGui

	-- Rounded corners
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 8)
	Corner.Parent = ChargeFrame

	-- Charge Bar Background
	local BarBackground = Instance.new("Frame")
	BarBackground.Name = "BarBackground"
	BarBackground.Size = UDim2.new(1, -20, 0, 20)
	BarBackground.Position = UDim2.new(0, 10, 0, 25)
	BarBackground.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	BarBackground.BorderSizePixel = 0
	BarBackground.Parent = ChargeFrame

	local BarCorner = Instance.new("UICorner")
	BarCorner.CornerRadius = UDim.new(0, 4)
	BarCorner.Parent = BarBackground

	-- Charge Bar (fills up)
	ChargeBar = Instance.new("Frame")
	ChargeBar.Name = "ChargeBar"
	ChargeBar.Size = UDim2.new(0, 0, 1, 0)
	ChargeBar.BackgroundColor3 = Settings.ColorPowerLow
	ChargeBar.BorderSizePixel = 0
	ChargeBar.ZIndex = 2
	ChargeBar.Parent = BarBackground

	local ChargeCorner = Instance.new("UICorner")
	ChargeCorner.CornerRadius = UDim.new(0, 4)
	ChargeCorner.Parent = ChargeBar

	-- Power zone markers
	CreatePowerZones(BarBackground)

	-- Charge Label
	ChargeLabel = Instance.new("TextLabel")
	ChargeLabel.Name = "ChargeLabel"
	ChargeLabel.Size = UDim2.new(1, 0, 0, 20)
	ChargeLabel.Position = UDim2.new(0, 0, 0, 3)
	ChargeLabel.BackgroundTransparency = 1
	ChargeLabel.Text = "GROUND KICK"
	ChargeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	ChargeLabel.TextSize = 16
	ChargeLabel.Font = Enum.Font.GothamBold
	ChargeLabel.ZIndex = 3
	ChargeLabel.Parent = ChargeFrame
end

function CreatePowerZones(parent)
	local zones = {
		{Position = 0.33, Color = Color3.fromRGB(150, 150, 150)},
		{Position = 0.66, Color = Color3.fromRGB(200, 200, 200)},
	}

	for _, zone in ipairs(zones) do
		local marker = Instance.new("Frame")
		marker.Size = UDim2.new(0, 2, 1, 0)
		marker.Position = UDim2.new(zone.Position, 0, 0, 0)
		marker.BackgroundColor3 = zone.Color
		marker.BorderSizePixel = 0
		marker.ZIndex = 3
		marker.Parent = parent
	end
end

--------------------------------------------------------------------------------
-- INPUT & CHARACTER
--------------------------------------------------------------------------------

function ConnectCharacter()
	Character = Player.Character
	if not Character then return end

	Humanoid = Character:WaitForChild("Humanoid")
	RootPart = Character:WaitForChild("HumanoidRootPart")

	print("[BallControlClient] Character connected")
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
			UpdateChargeBar()
		end
	end)
end

function UpdateChargeBar()
	local power = GetChargePower()

	-- Update size
	ChargeBar.Size = UDim2.new(power, 0, 1, 0)

	-- Update color based on power
	if power < 0.4 then
		ChargeBar.BackgroundColor3 = Settings.ColorPowerLow
	elseif power < 0.75 then
		ChargeBar.BackgroundColor3 = Settings.ColorPowerMed
	else
		ChargeBar.BackgroundColor3 = Settings.ColorPowerHigh
	end
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
	ChargeFrame.Visible = true
	ChargeLabel.Text = "GROUND KICK"

	print("[BallControlClient] Started ground kick charge")
end

function ReleaseGroundKick()
	if not IsChargingGroundKick then return end

	IsChargingGroundKick = false
	ChargeFrame.Visible = false

	if HasBall and Character and RootPart then
		local power = GetChargePower()
		local direction = GetKickDirection()

		print(string.format("[BallControlClient] Ground kick: Power=%.2f, Direction=%s", power, tostring(direction)))

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
	ChargeFrame.Visible = true
	ChargeLabel.Text = "AIR KICK"

	print("[BallControlClient] Started air kick charge")
end

function ReleaseAirKick()
	if not IsChargingAirKick then return end

	IsChargingAirKick = false
	ChargeFrame.Visible = false

	if HasBall and Character and RootPart then
		local power = GetChargePower()
		local direction = GetKickDirection()

		print(string.format("[BallControlClient] Air kick: Power=%.2f, Direction=%s", power, tostring(direction)))

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
		ChargeFrame.Visible = false
	end

	print("[BallControlClient] Possession changed: " .. tostring(hasBall))
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function BallControlClient.HasBall()
	return HasBall
end

return BallControlClient