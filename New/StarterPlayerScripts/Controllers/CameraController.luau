--[[
	CameraController.luau
	Scriptable orbit camera with mouse-lock toggle and right-click drag support.

	Responsibilities:
	- Orbit camera positioned at configurable distance and height behind the character
	- M key toggles mouse lock:
	    Locked   → full orbit (horizontal + vertical); uses GetMouseDelta()
	    Unlocked → right-click drag for horizontal rotation only; uses InputChanged delta
	- When mouse-locked or RMB-dragging: disable Humanoid.AutoRotate and align the
	  character to face the camera's look direction via AlignOrientation
	- Restore Humanoid.AutoRotate = true when neither condition is active

	Public API:
	- Initialize()
	- LockMouse()
	- UnlockMouse()
	- IsMouseLocked() → boolean
]]

local CameraController = {}

-- Services
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Logger
local Utils  = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("CameraController")

-- ── Constants ──────────────────────────────────────────────────────────────────
local CAMERA_DISTANCE    = 16        -- Studs behind character
local CAMERA_HEIGHT      = 6         -- Studs above character
local MOUSE_SENSITIVITY  = 0.003     -- Radians per pixel
local MIN_VERTICAL_ANGLE = math.rad(-60)
local MAX_VERTICAL_ANGLE = math.rad(70)

-- ── References ─────────────────────────────────────────────────────────────────
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer

-- ── Private State ──────────────────────────────────────────────────────────────
local Character      = nil
local Humanoid       = nil
local RootPart       = nil
local AlignOrient    = nil   -- AlignOrientation constraint (persisted per character)
local RootAttachment = nil   -- Attachment on RootPart used by AlignOrientation

local MouseLocked    = false
local RightMouseDown = false

-- X = vertical (pitch), Y = horizontal (yaw), both in radians
local CameraRotation = Vector2.new(0, 0)

-- ── AlignOrientation Setup ─────────────────────────────────────────────────────

local function SetupAlignOrientation()
	-- Destroy previous constraint so we start clean on each character
	if AlignOrient then
		AlignOrient:Destroy()
		AlignOrient = nil
	end
	if RootAttachment then
		RootAttachment:Destroy()
		RootAttachment = nil
	end

	if not RootPart then return end

	RootAttachment = Instance.new("Attachment")
	RootAttachment.Name = "CameraAlignAttachment"
	RootAttachment.Parent = RootPart

	AlignOrient = Instance.new("AlignOrientation")
	AlignOrient.Name = "CameraAlignOrientation"
	AlignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AlignOrient.MaxTorque = 1e6
	AlignOrient.Responsiveness = 50
	AlignOrient.RigidityEnabled = false
	AlignOrient.Attachment0 = RootAttachment
	AlignOrient.Enabled = false   -- Disabled until needed
	AlignOrient.Parent = RootPart
end

-- ── Character Handling ─────────────────────────────────────────────────────────

local function SetupCharacter(char)
	Character = char
	Humanoid  = char:WaitForChild("Humanoid")
	RootPart  = char:WaitForChild("HumanoidRootPart")

	-- Reset vertical pitch on respawn; preserve horizontal yaw for continuity
	CameraRotation = Vector2.new(0, CameraRotation.Y)

	SetupAlignOrientation()

	Logger:info("CameraController: character connected.")
end

-- ── Public: Mouse Lock ─────────────────────────────────────────────────────────

function CameraController.LockMouse()
	MouseLocked = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	Logger:debug("Mouse locked.")
end

function CameraController.UnlockMouse()
	MouseLocked = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	Logger:debug("Mouse unlocked.")
end

function CameraController.IsMouseLocked()
	return MouseLocked
end

-- ── Input ──────────────────────────────────────────────────────────────────────

local function OnInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- M key: toggle mouse lock
	if input.KeyCode == Enum.KeyCode.M then
		if MouseLocked then
			CameraController.UnlockMouse()
		else
			CameraController.LockMouse()
		end
		return
	end

	-- Track RMB hold for unlocked-mode horizontal drag
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if not MouseLocked then
			RightMouseDown = true
		end
	end
end

local function OnInputEnded(input, _gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		RightMouseDown = false
	end
end

-- For right-click drag (unlocked mode): accumulate horizontal delta via InputChanged
local function OnInputChanged(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	if MouseLocked then return end   -- Locked mode uses GetMouseDelta() in RenderStepped
	if not RightMouseDown then return end

	local delta = input.Delta
	CameraRotation = Vector2.new(
		CameraRotation.X,
		CameraRotation.Y - delta.X * MOUSE_SENSITIVITY
	)
end

-- ── Camera & Character Update Loop ────────────────────────────────────────────

local function UpdateCamera()
	if not Character or not RootPart then return end

	-- Locked mode: read mouse delta each frame (only valid while cursor is locked)
	if MouseLocked then
		local delta = UserInputService:GetMouseDelta()
		CameraRotation = Vector2.new(
			math.clamp(
				CameraRotation.X - delta.Y * MOUSE_SENSITIVITY,
				MIN_VERTICAL_ANGLE,
				MAX_VERTICAL_ANGLE
			),
			CameraRotation.Y - delta.X * MOUSE_SENSITIVITY
		)
	end

	-- Build camera CFrame from orbit angles
	local horizontalAngle = CameraRotation.Y
	local verticalAngle   = CameraRotation.X

	local rotationCFrame =
		CFrame.Angles(0, horizontalAngle, 0) *
		CFrame.Angles(verticalAngle, 0, 0)

	local offset       = rotationCFrame * Vector3.new(0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	local characterPos = RootPart.Position

	Camera.CFrame = CFrame.new(characterPos + offset, characterPos)

	-- Determine whether we should control character rotation
	local shouldControl = MouseLocked or RightMouseDown

	if shouldControl and Humanoid and RootPart then
		Humanoid.AutoRotate = false

		if AlignOrient then
			-- Compute the horizontal look direction the character should face.
			-- Camera is behind/above the character looking at it, so character
			-- faces in the opposite direction of the camera offset (projected onto XZ).
			local _, cameraY, _ = Camera.CFrame:ToOrientation()
			local desiredLook = Vector3.new(
				-math.sin(cameraY),
				0,
				-math.cos(cameraY)
			)

			-- AlignOrientation.CFrame (OneAttachment mode) = target world-space orientation.
			-- CFrame.lookAt sets the LookVector to point toward desiredLook from origin.
			AlignOrient.CFrame = CFrame.lookAt(Vector3.zero, desiredLook)
			AlignOrient.Enabled = true
		end
	else
		-- Neither condition active — release character to its own rotation
		if AlignOrient then
			AlignOrient.Enabled = false
		end
		if Humanoid then
			Humanoid.AutoRotate = true
		end
	end
end

-- ── Public: Initialize ─────────────────────────────────────────────────────────

function CameraController.Initialize()
	Logger:info("Initializing Camera Controller...")

	Camera.CameraType = Enum.CameraType.Scriptable

	-- Wire input events
	UserInputService.InputBegan:Connect(OnInputBegan)
	UserInputService.InputEnded:Connect(OnInputEnded)
	UserInputService.InputChanged:Connect(OnInputChanged)

	-- Connect current or future character
	if Player.Character then
		task.spawn(function()
			SetupCharacter(Player.Character)
		end)
	end
	Player.CharacterAdded:Connect(function(char)
		task.wait(0.1)   -- Brief wait for character hierarchy to settle
		SetupCharacter(char)
	end)

	-- Camera + character orientation update each render frame
	RunService.RenderStepped:Connect(UpdateCamera)

	Logger:info("Camera Controller initialized.")
	return true
end

return CameraController
