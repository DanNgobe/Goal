--[[
	CameraController.lua
	Scriptable camera in locked mode, orbital in unlocked mode.
]]

local CameraController = {}

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

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
local CharacterAngularVelocity = nil

-- Settings
local CAMERA_DISTANCE = 15
local CAMERA_HEIGHT = 5
local MOUSE_SENSITIVITY = 0.003
local MIN_VERTICAL_ANGLE = math.rad(-80)
local MAX_VERTICAL_ANGLE = math.rad(80)

-- Initialize
function CameraController.Initialize()
	CameraEffects = require(script.Parent.CameraEffects)

	-- Start in orbital (unlocked) mode
	Camera.CameraType = Enum.CameraType.Custom

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
	Camera.CameraType = Enum.CameraType.Scriptable
	-- Sync CameraRotation to current orbital camera angle so it doesnt snap
	local _, currentY, _ = Camera.CFrame:ToOrientation()
	CameraRotation = Vector2.new(0, currentY)
end

-- Unlock mouse
function CameraController.UnlockMouse()
	IsMouseLocked = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	Camera.CameraType = Enum.CameraType.Custom
	CameraRotation = Vector2.new(0, 0)
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
	CharacterAngularVelocity = nil
end

-- Input began
function OnInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.M then
		CameraController.ToggleMouseLock()
	end

	if not IsMouseLocked and input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsRightMouseDown = true
	end
end

-- Input ended
function OnInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		IsRightMouseDown = false
		if not IsMouseLocked then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
end

-- Input changed
function OnInputChanged(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

	-- Only manually track mouse delta in locked (scriptable) mode
	if not IsMouseLocked then return end

	local delta = input.Delta

	CameraRotation = Vector2.new(
		math.clamp(
			CameraRotation.X + (-delta.Y * MOUSE_SENSITIVITY),
			MIN_VERTICAL_ANGLE,
			MAX_VERTICAL_ANGLE
		),
		CameraRotation.Y + (-delta.X * MOUSE_SENSITIVITY)
	)
end

-- Camera update
function UpdateCamera()
	if CameraEffects and CameraEffects.IsCelebrating() then return end
	if not Character or not HumanoidRootPart or not Humanoid then return end

	-- Locked mode: drive camera manually (scriptable)
	if IsMouseLocked then
		local horizontalAngle = CameraRotation.Y
		local verticalAngle = CameraRotation.X

		local rotationCFrame =
			CFrame.Angles(0, horizontalAngle, 0) *
			CFrame.Angles(verticalAngle, 0, 0)

		local offset = rotationCFrame * Vector3.new(0, CAMERA_HEIGHT, CAMERA_DISTANCE)
		local characterPosition = HumanoidRootPart.Position

		Camera.CFrame = CFrame.new(characterPosition + offset, characterPosition)
	end

	-- Character rotation: locked mode OR right-click drag in orbital mode
	local shouldControlRotation = IsMouseLocked or IsRightMouseDown

	if shouldControlRotation then
		Humanoid.AutoRotate = false

		if not CharacterAngularVelocity or not CharacterAngularVelocity.Parent then
			CharacterAngularVelocity = Instance.new("BodyAngularVelocity")
			CharacterAngularVelocity.MaxTorque = Vector3.new(0, math.huge, 0)
			CharacterAngularVelocity.P = 1000
			CharacterAngularVelocity.Parent = HumanoidRootPart
		end

		local _, cameraY, _ = Camera.CFrame:ToOrientation()
		local currentLook = HumanoidRootPart.CFrame.LookVector
		local desiredLook = Vector3.new(-math.sin(cameraY), 0, -math.cos(cameraY))

		local cross = currentLook:Cross(desiredLook)
		local angle = math.asin(math.clamp(cross.Y, -1, 1))

		CharacterAngularVelocity.AngularVelocity = Vector3.new(0, angle * 10, 0)

	else
		Humanoid.AutoRotate = true

		if CharacterAngularVelocity then
			CharacterAngularVelocity:Destroy()
			CharacterAngularVelocity = nil
		end
	end
end

return CameraController