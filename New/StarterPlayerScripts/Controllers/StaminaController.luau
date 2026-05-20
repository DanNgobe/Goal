--[[
	StaminaController.lua
	Handles player stamina logic, sprinting input, and StaminaBarUI coordination.

	Responsibilities:
	- Manage stamina state (drain on sprint, regen on rest)
	- Control Humanoid.WalkSpeed based on sprint state
	- Find the existing "Stamina" frame in PlayerGui and link StaminaBarUI to it
	- Input: LeftShift held/released to toggle sprint

	Architecture:
	- Stamina is fully client-authoritative (no server involvement)
	- StaminaBarUI is a pure visual module; this controller owns the logic
	- BallController owns kick speed — if it needs to slow the player during
	  dribble it should integrate here via SetDribbling(bool) in the future
]]

local StaminaController = {}

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- UI
local StaminaBarUI = require(script.Parent.Parent.UI.StaminaBarUI)

-- Logger
local Utils  = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("StaminaController")

-- ── Constants ─────────────────────────────────────────────────────────────────
local MAX_STAMINA   = 100
local SPRINT_SPEED  = 28
local NORMAL_SPEED  = 18
local DRAIN_RATE    = 18   -- Per second while sprinting
local REGEN_RATE    = 10   -- Per second while not sprinting
local MIN_TO_SPRINT = 10   -- Minimum stamina required to start a sprint

-- ── Private State ─────────────────────────────────────────────────────────────
local Player         = Players.LocalPlayer
local Character      = nil
local Humanoid       = nil
local StaminaFrame   = nil   -- Reference to the in-game Stamina frame

local CurrentStamina = MAX_STAMINA
local IsSprinting    = false

-- ── UI Discovery ──────────────────────────────────────────────────────────────

-- Searches every LayerCollector in PlayerGui for a Frame named "Stamina"
-- (matches the pattern from the Goal project's StaminaController)
local function FindStaminaFrame()
	local playerGui = Player:WaitForChild("PlayerGui")
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("LayerCollector") then
			local found = gui:FindFirstChild("Stamina", true)
			if found and found:IsA("Frame") then
				return found
			end
		end
	end
	return nil
end

-- ── Sprint Control ────────────────────────────────────────────────────────────

local function SetSprinting(sprinting)
	IsSprinting = sprinting
	if Humanoid then
		Humanoid.WalkSpeed = IsSprinting and SPRINT_SPEED or NORMAL_SPEED
	end
end

-- ── Heartbeat ─────────────────────────────────────────────────────────────────

local function OnHeartbeat(dt)
	if IsSprinting then
		CurrentStamina = math.max(0, CurrentStamina - DRAIN_RATE * dt)
		if CurrentStamina <= 0 then
			SetSprinting(false)  -- Force stop sprint when exhausted
		end
	else
		CurrentStamina = math.min(MAX_STAMINA, CurrentStamina + REGEN_RATE * dt)
	end

	-- Drive StaminaBarUI if the frame is linked
	if StaminaFrame and StaminaFrame.Parent then
		StaminaBarUI.Update(CurrentStamina, MAX_STAMINA)
	end
end

-- ── Character Handling ────────────────────────────────────────────────────────

local function OnCharacterAdded(char)
	Character = char
	Humanoid  = char:WaitForChild("Humanoid")
	-- Reset stamina on respawn
	CurrentStamina = MAX_STAMINA
	IsSprinting    = false
end

-- ── Initialization ────────────────────────────────────────────────────────────

function StaminaController.Initialize()
	Logger:info("Initializing Stamina Controller...")

	-- Try to find the Stamina frame; retry periodically if not yet loaded
	task.spawn(function()
		while true do
			if not StaminaFrame or not StaminaFrame.Parent then
				StaminaFrame = FindStaminaFrame()
				if StaminaFrame then
					StaminaBarUI.Initialize(StaminaFrame)
					Logger:info("Linked to in-game Stamina frame.")
				end
			end
			task.wait(1)
		end
	end)

	-- Character setup
	if Player.Character then
		OnCharacterAdded(Player.Character)
	end
	Player.CharacterAdded:Connect(OnCharacterAdded)

	-- Sprint input
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			if CurrentStamina > MIN_TO_SPRINT then
				SetSprinting(true)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			SetSprinting(false)
		end
	end)

	-- Stamina update loop
	RunService.Heartbeat:Connect(OnHeartbeat)

	Logger:info("Stamina Controller initialized.")
	return true
end

-- Read-only accessors for other systems
function StaminaController.GetStamina()
	return CurrentStamina
end

function StaminaController.IsSprinting()
	return IsSprinting
end

return StaminaController
