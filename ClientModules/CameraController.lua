--[[
	CameraController.lua
	Handles camera control and mouse lock for the soccer game.
	
	Key Features:
	- Locks mouse when player chooses a team
	- M key: Toggle mouse lock/unlock
	- Camera follows player with mouse control
]]

local CameraController = {}

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Module dependencies (loaded after initialization)
local CameraEffects = nil

-- Private variables
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer
local Character = nil
local Humanoid = nil
local HumanoidRootPart = nil

local IsMouseLocked = false
local CameraRotation = Vector2.new(0, 0)

-- Camera settings
local CAMERA_DISTANCE = 15
local CAMERA_HEIGHT = 5
local MOUSE_SENSITIVITY = 0.003
local MIN_VERTICAL_ANGLE = math.rad(-80)
local MAX_VERTICAL_ANGLE = math.rad(80)

-- Initialize
function CameraController.Initialize()
	-- Load CameraEffects module
	CameraEffects = require(script.Parent.CameraEffects)
	
	-- Set camera type
	Camera.CameraType = Enum.CameraType.Scriptable

	-- Connect input handling
	UserInputService.InputBegan:Connect(OnInputBegan)
	UserInputService.InputChanged:Connect(OnInputChanged)

	-- Handle character spawning
	if Player.Character then
		SetupCharacter(Player.Character)
	end
	Player.CharacterAdded:Connect(SetupCharacter)

	-- Update camera every frame
	RunService.RenderStepped:Connect(UpdateCamera)

	return true
end

-- Lock the mouse (called when player chooses team)
function CameraController.LockMouse()
	IsMouseLocked = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

end

-- Unlock the mouse
function CameraController.UnlockMouse()
	IsMouseLocked = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

end

-- Toggle mouse lock
function CameraController.ToggleMouseLock()
	if IsMouseLocked then
		CameraController.UnlockMouse()
	else
		CameraController.LockMouse()
	end
end

-- Check if mouse is locked
function CameraController.IsMouseLocked()
	return IsMouseLocked
end

-- Get mouse lock state (alias)
function CameraController.GetMouseLockState()
	return IsMouseLocked
end

-- Private: Setup character references
function SetupCharacter(character)
	Character = character
	Humanoid = character:WaitForChild("Humanoid")
	HumanoidRootPart = character:WaitForChild("HumanoidRootPart")

	-- Reset camera rotation when character respawns
	CameraRotation = Vector2.new(0, 0)

end

-- Private: Handle input began
function OnInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- Toggle mouse lock with M key
	if input.KeyCode == Enum.KeyCode.M then
		CameraController.ToggleMouseLock()
	end
end

-- Private: Handle input changes (mouse movement)
function OnInputChanged(input, gameProcessed)
	if not IsMouseLocked then return end
	if gameProcessed then return end

	-- Handle mouse movement
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Delta

		-- Update camera rotation
		CameraRotation = CameraRotation + Vector2.new(
			-delta.Y * MOUSE_SENSITIVITY,
			-delta.X * MOUSE_SENSITIVITY
		)

		-- Clamp vertical rotation
		CameraRotation = Vector2.new(
			math.clamp(CameraRotation.X, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE),
			CameraRotation.Y
		)
	end
end

-- Private: Update camera position and rotation
function UpdateCamera()
	-- Don't update camera if celebration is active
	if CameraEffects and CameraEffects.IsCelebrating() then
		return
	end
	
	if not Character or not HumanoidRootPart then return end

	-- Calculate camera position based on rotation
	local horizontalAngle = CameraRotation.Y
	local verticalAngle = CameraRotation.X

	-- Create rotation CFrame
	local rotationCFrame = CFrame.Angles(0, horizontalAngle, 0) * CFrame.Angles(verticalAngle, 0, 0)

	-- Calculate camera offset
	local offset = rotationCFrame * Vector3.new(0, CAMERA_HEIGHT, CAMERA_DISTANCE)

	-- Set camera position and look at character
	local characterPosition = HumanoidRootPart.Position
	Camera.CFrame = CFrame.new(characterPosition + offset, characterPosition)

	-- Safe character rotation based on camera yaw (fixed forward)
	if IsMouseLocked and Humanoid and HumanoidRootPart then
		Humanoid.AutoRotate = false

		-- Get camera yaw only
		local _, cameraY, _ = workspace.CurrentCamera.CFrame:ToOrientation()

		-- Current facing
		local currentLookVector = HumanoidRootPart.CFrame.LookVector
		local desiredLookVector = Vector3.new(-math.sin(cameraY), 0, -math.cos(cameraY))

		-- Calculate rotation needed
		local cross = currentLookVector:Cross(desiredLookVector)
		local dot = currentLookVector:Dot(desiredLookVector)
		local angle = math.asin(cross.Y)

		-- Apply angular velocity instead of teleporting
		local angularVelocity = Instance.new("BodyAngularVelocity")
		angularVelocity.MaxTorque = Vector3.new(0, math.huge, 0)
		angularVelocity.AngularVelocity = Vector3.new(0, angle * 10, 0) -- tweak multiplier for speed
		angularVelocity.P = 1000
		angularVelocity.Parent = HumanoidRootPart

		-- Remove after a tiny delay to avoid stacking
		game:GetService("Debris"):AddItem(angularVelocity, 0.05)
	else
		if Humanoid then
			Humanoid.AutoRotate = true
		end
	end

end

return CameraController
