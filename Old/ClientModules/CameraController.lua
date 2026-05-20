--[[
	CameraController.lua
	Handles camera control and mouse lock for the soccer game.
]]

local CameraController = {}

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

-- Module dependencies
local CameraEffects = nil

-- References
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer
local Character = nil
local Humanoid = nil
local HumanoidRootPart = nil

-- State
local IsMouseLocked = false
local IsRightMouseDown = false
local CameraRotation = Vector2.new(0, 0)

-- Settings
local CAMERA_DISTANCE = 15
local CAMERA_HEIGHT = 5
local MOUSE_SENSITIVITY = 0.003
local MIN_VERTICAL_ANGLE = math.rad(-80)
local MAX_VERTICAL_ANGLE = math.rad(80)

-- Initialize
function CameraController.Initialize()

	CameraEffects = require(script.Parent.CameraEffects)
	Camera.CameraType = Enum.CameraType.Scriptable

	UserInputService.InputBegan:Connect(OnInputBegan)
	UserInputService.InputChanged:Connect(OnInputChanged)
	UserInputService.InputEnded:Connect(OnInputEnded)

	if Player.Character then
		SetupCharacter(Player.Character)
	end
	Player.CharacterAdded:Connect(SetupCharacter)

	RunService.RenderStepped:Connect(UpdateCamera)

	return true
end

-- Lock mouse
function CameraController.LockMouse()
	IsMouseLocked = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

-- Unlock mouse
function CameraController.UnlockMouse()
	IsMouseLocked = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

function CameraController.ToggleMouseLock()
	if IsMouseLocked then
		CameraController.UnlockMouse()
	else
		CameraController.LockMouse()
	end
end

function CameraController.IsMouseLocked()
	return IsMouseLocked
end

function CameraController.GetMouseLockState()
	return IsMouseLocked
end

-- Character setup
function SetupCharacter(character)
	Character = character
	Humanoid = character:WaitForChild("Humanoid")
	HumanoidRootPart = character:WaitForChild("HumanoidRootPart")

	CameraRotation = Vector2.new(0, 0)
end

-- Input began
function OnInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.M then
		CameraController.ToggleMouseLock()
	end

	-- Right mouse drag for unlocked mode
	if not IsMouseLocked and input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsRightMouseDown = true
	end
end

-- Input ended
function OnInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsRightMouseDown = false
	end
end

-- Input changed
function OnInputChanged(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

	local delta = input.Delta

	-- Locked mode (full control)
	if IsMouseLocked then
		CameraRotation = CameraRotation + Vector2.new(
			-delta.Y * MOUSE_SENSITIVITY,
			-delta.X * MOUSE_SENSITIVITY
		)

		CameraRotation = Vector2.new(
			math.clamp(CameraRotation.X, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE),
			CameraRotation.Y
		)

	-- Unlocked + right click drag (horizontal only)
	elseif IsRightMouseDown then
		CameraRotation = CameraRotation + Vector2.new(
			0,
			-delta.X * MOUSE_SENSITIVITY
		)
	end
end

-- Camera update
function UpdateCamera()

	if CameraEffects and CameraEffects.IsCelebrating() then
		return
	end

	if not Character or not HumanoidRootPart then return end

	local horizontalAngle = CameraRotation.Y
	local verticalAngle = CameraRotation.X

	local rotationCFrame =
		CFrame.Angles(0, horizontalAngle, 0) *
		CFrame.Angles(verticalAngle, 0, 0)

	local offset = rotationCFrame * Vector3.new(0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	local characterPosition = HumanoidRootPart.Position

	Camera.CFrame = CFrame.new(characterPosition + offset, characterPosition)

	-- Character rotation when mouse locked OR right-dragging
	if (IsMouseLocked or IsRightMouseDown) and Humanoid and HumanoidRootPart then
		Humanoid.AutoRotate = false

		local _, cameraY, _ = Camera.CFrame:ToOrientation()

		local currentLook = HumanoidRootPart.CFrame.LookVector
		local desiredLook = Vector3.new(-math.sin(cameraY), 0, -math.cos(cameraY))

		local cross = currentLook:Cross(desiredLook)
		local angle = math.asin(cross.Y)

		local angularVelocity = Instance.new("BodyAngularVelocity")
		angularVelocity.MaxTorque = Vector3.new(0, math.huge, 0)
		angularVelocity.AngularVelocity = Vector3.new(0, angle * 10, 0)
		angularVelocity.P = 1000
		angularVelocity.Parent = HumanoidRootPart

		Debris:AddItem(angularVelocity, 0.05)

	else
		if Humanoid then
			Humanoid.AutoRotate = true
		end
	end
end

return CameraController
