--[[
	BallController.lua
	Client-side ball control: kick charging and trajectory preview.

	Responsibilities:
	- Listen to PossessionChanged remote to know if this client has the ball
	- LMB held  = charge ground kick, show trajectory
	- RMB held  = charge air kick, show trajectory
	- On release = fire KickBall remote to server with (type, power, direction)
	- Play kick animation locally before firing remote
	- Coordinate ChargeBarUI and TrajectoryPredictor visuals

	Architecture:
	- Client NEVER moves the ball. All physics are server-authoritative.
	- Stamina / sprint speed are handled separately in StaminaController.
	- Animation plays on client immediately; server applies physics.
]]

local BallController = {}

-- Services
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

-- Shared
local Utils  = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("BallController")

-- UI / Visuals
local KickChargeUI       = require(script.Parent.Parent.UI.KickChargeUI)
local TrajectoryPredictor = require(script.Parent.Parent.UI.TrajectoryPredictor)

-- Local Player
local Player = Players.LocalPlayer

-- ── Private State ─────────────────────────────────────────────────────────────
local Character          = nil
local Humanoid           = nil
local RootPart           = nil

local HasBall            = false
local IsChargingGround   = false
local IsChargingAir      = false
local ChargeStartTime    = 0

-- Settings (must match BallManager server physics for realistic preview)
local Settings = {
	MaxChargeTime = 2,
	MinPower      = 0.3,
}

-- Remotes
local KickBall          = nil
local PossessionChanged = nil
local SwitchSlotRequest = nil

-- ── Character ─────────────────────────────────────────────────────────────────

local function ConnectCharacter(char)
	Character = char
	Humanoid  = char:WaitForChild("Humanoid")
	RootPart  = char:WaitForChild("HumanoidRootPart")
	HasBall   = false
end

-- ── Kick Direction ─────────────────────────────────────────────────────────────

local function GetKickDirection()
	local camera = workspace.CurrentCamera
	if not camera then
		return RootPart and RootPart.CFrame.LookVector or Vector3.new(0, 0, -1)
	end

	-- Use mouse cursor projected onto horizontal plane
	local mousePos = UserInputService:GetMouseLocation()
	local ray      = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local dir      = Vector3.new(ray.Direction.X, 0, ray.Direction.Z)

	if dir.Magnitude < 0.01 then
		return RootPart and RootPart.CFrame.LookVector or Vector3.new(0, 0, -1)
	end
	return dir.Unit
end

-- ── Power Calculation ─────────────────────────────────────────────────────────

local function GetChargePower()
	local held = tick() - ChargeStartTime
	return math.clamp(held / Settings.MaxChargeTime, Settings.MinPower, 1)
end

-- ── Animation ─────────────────────────────────────────────────────────────────

local function PlayKickAnimation(kickType, _power, _direction)
	if not Humanoid or not RootPart then return end

	-- Attempt to play a kick anim if AnimationData is available
	local ok, AnimationData = pcall(function()
		return require(ReplicatedStorage:WaitForChild("AnimationData", 2))
	end)

	local animId = nil
	if ok and AnimationData then
		if AnimationData.ChooseKickAnimation then
			animId = AnimationData.ChooseKickAnimation(RootPart, _direction, _power, kickType)
		elseif kickType == "Ground" and AnimationData.Kicks then
			animId = AnimationData.Kicks.Ground
		elseif kickType == "Air" and AnimationData.Kicks then
			animId = AnimationData.Kicks.Air
		end
	end

	if not animId then return end

	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator        = Instance.new("Animator")
		animator.Parent = Humanoid
	end

	local anim           = Instance.new("Animation")
	anim.AnimationId     = animId
	local track          = animator:LoadAnimation(anim)
	track.Looped         = false
	track:Play()

	-- Restore walk speed after animation
	local origSpeed      = Humanoid.WalkSpeed
	Humanoid.WalkSpeed   = 0
	RootPart.Anchored    = true
	task.spawn(function()
		task.wait(track.Length or 0.3)
		if RootPart and Humanoid then
			RootPart.Anchored  = false
			Humanoid.WalkSpeed = origSpeed
			track:Stop()
		end
	end)
end

-- ── Kick Actions ──────────────────────────────────────────────────────────────

local function StartCharge(kickType)
	if not HasBall or not Character then return end
	IsChargingGround  = (kickType == "Ground")
	IsChargingAir     = (kickType == "Air")
	ChargeStartTime   = tick()
	KickChargeUI.SetLabel(kickType == "Ground" and "GROUND KICK" or "AIR KICK")
	KickChargeUI.Show()
	TrajectoryPredictor.Show()
end

local function ReleaseCharge(kickType)
	local isCharging = (kickType == "Ground" and IsChargingGround) or (kickType == "Air" and IsChargingAir)
	if not isCharging then return end

	IsChargingGround = false
	IsChargingAir    = false
	KickChargeUI.Hide()
	TrajectoryPredictor.Hide()

	if HasBall and Character and RootPart then
		local power     = GetChargePower()
		local direction = GetKickDirection()

		-- Play animation locally for instant feedback
		PlayKickAnimation(kickType, power, direction)

		-- Fire to server
		KickBall:FireServer(kickType, power, direction)

		-- Optimistically clear possession
		HasBall = false
		Logger:debug(string.format("Kicked [%s] power=%.2f", kickType, power))
	end
end

-- ── Input ─────────────────────────────────────────────────────────────────────

local function SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			StartCharge("Ground")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			StartCharge("Air")
		elseif input.KeyCode == Enum.KeyCode.C then
			-- D.2: Request slot switch only when player does NOT have possession
			if HasBall then
				Logger:debug("C pressed but player has ball — ignoring slot switch")
			else
				if SwitchSlotRequest then
					SwitchSlotRequest:FireServer()
					Logger:debug("Fired SwitchSlotRequest")
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			ReleaseCharge("Ground")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			ReleaseCharge("Air")
		end
	end)
end

-- ── Update Loop ───────────────────────────────────────────────────────────────

local function SetupUpdateLoop()
	RunService.RenderStepped:Connect(function()
		if (IsChargingGround or IsChargingAir) and RootPart then
			local power     = GetChargePower()
			local direction = GetKickDirection()
			local kickType  = IsChargingGround and "Ground" or "Air"

			KickChargeUI.Update(power)

			local startPos  = RootPart.Position + Vector3.new(0, 2, 0) + direction * 3
			TrajectoryPredictor.Update(kickType, startPos, direction, power)
		end
	end)
end

-- ── Possession ────────────────────────────────────────────────────────────────

local function OnPossessionChanged(hasBall)
	HasBall = hasBall

	if not hasBall then
		IsChargingGround = false
		IsChargingAir    = false
		KickChargeUI.Hide()
		TrajectoryPredictor.Hide()
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function BallController.Initialize()
	Logger:info("Initializing Ball Controller...")

	-- Get remotes (created on server by BallManager)
	local events     = ReplicatedStorage:WaitForChild("Events")
	local ballEvents = events:WaitForChild("BallEvents")
	KickBall          = ballEvents:WaitForChild("KickBall")
	PossessionChanged = ballEvents:WaitForChild("PossessionChanged")

	-- D.2: Get slot-switch remote (created by GameManager)
	local playerRemotes = events:WaitForChild("PlayerRemotes")
	SwitchSlotRequest   = playerRemotes:WaitForChild("SwitchSlotRequest")

	-- Create BallUI ScreenGui for KickChargeUI
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local ballUI    = Instance.new("ScreenGui")
	ballUI.Name          = "BallUI"
	ballUI.ResetOnSpawn  = false
	ballUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ballUI.Parent        = PlayerGui

	KickChargeUI.Create(ballUI)
	TrajectoryPredictor.Initialize()

	-- Wire possession remote
	PossessionChanged.OnClientEvent:Connect(OnPossessionChanged)

	-- Connect current character
	if Player.Character then
		ConnectCharacter(Player.Character)
	end
	Player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		ConnectCharacter(char)
	end)

	SetupInput()
	SetupUpdateLoop()

	Logger:info("Ball Controller initialized.")
end

function BallController.HasBall()
	return HasBall
end

return BallController
