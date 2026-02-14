--[[
	StaminaController.lua
	Handles player stamina logic, sprinting input, and UI coordination.
]]

local StaminaController = {}

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local StaminaBarUI = require(script.Parent.UI.StaminaBarUI)

-- Constants
local MAX_STAMINA = 100
local SPRINT_SPEED = 28
local NORMAL_SPEED = 23 -- Match user's InputEnded speed
local DRAIN_RATE = 8 -- User's (2 / 0.25)
local REGEN_RATE = 6 -- User's (1.5 / 0.25)
local MIN_TO_SPRINT = 5

-- Private variables
local Player = Players.LocalPlayer
local Character = nil
local Humanoid = nil
local StaminaFrame = nil
local SprintSound = nil

-- State
local CurrentStamina = MAX_STAMINA
local IsSprinting = false

-- Find existing UI in PlayerGui
local function FindStaminaUI()
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

-- Initialize
function StaminaController.Initialize()
	-- Search for the "Stamina" frame periodically
	task.spawn(function()
		while true do
			if not StaminaFrame or not StaminaFrame.Parent then
				StaminaFrame = FindStaminaUI()
				if StaminaFrame then
					StaminaBarUI.Initialize(StaminaFrame)
					print("[StaminaController] Linked to Stamina UI")
				end
			end
			task.wait(1)
		end
	end)

	-- Setup Character
	if Player.Character then
		OnCharacterAdded(Player.Character)
	end
	Player.CharacterAdded:Connect(OnCharacterAdded)

	-- Input handling
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

	-- Update loop
	RunService.Heartbeat:Connect(OnHeartbeat)

	print("[StaminaController] Initialized")
	return true
end

function OnCharacterAdded(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")

end

function SetSprinting(sprinting)
	IsSprinting = sprinting
	if Humanoid then
		Humanoid.WalkSpeed = IsSprinting and SPRINT_SPEED or NORMAL_SPEED
	end
	
	-- Notify server
	local playerRemotes = ReplicatedStorage:FindFirstChild("PlayerRemotes")
	if playerRemotes then
		local sprintRequest = playerRemotes:FindFirstChild("SprintRequest")
		if sprintRequest then
			sprintRequest:FireServer(IsSprinting)
		end
	end
end

function OnHeartbeat(dt)
	if IsSprinting then
		CurrentStamina = math.max(0, CurrentStamina - (DRAIN_RATE * dt))
		if CurrentStamina <= 2 then
			SetSprinting(false)
		end
	else
		CurrentStamina = math.min(MAX_STAMINA, CurrentStamina + (REGEN_RATE * dt))
	end

	-- Update UI if found
	if StaminaFrame then
		StaminaBarUI.Update(CurrentStamina, MAX_STAMINA)
	end
end

return StaminaController
