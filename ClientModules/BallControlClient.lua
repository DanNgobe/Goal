--[[
	BallControlClient.lua (Enhanced)
	Client-side ball control with trajectory preview and power meter.
	
	Features:
	- Visual trajectory preview with physics simulation
	- Enhanced power meter with color zones
	- Clean, focused mechanics
]]

local BallControlClient = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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

-- 3D Visual Elements
local TrajectoryFolder = nil
local TrajectoryPoints = {}
local TrajectoryAttachments = {}
local TrajectoryBeam = nil

-- Remote Events
local BallRemotes = nil
local KickBall = nil
local PossessionChanged = nil

-- Settings
local Settings = {
	MaxChargeTime = 2,
	MinPower = 0.3,

	-- Trajectory Visual
	UseBeam = false,  -- true = smooth line, false = dots
	TrajectoryPointCount = 25,  -- Number of prediction points
	TrajectorySpacing = 0.05,   -- Time between points (smaller = more accurate)
	TrajectorySize = 0.4,       -- Size of each point (if using dots)
	BeamWidth = 0.5,            -- Width of trajectory line

	-- Kick Physics (must match server!)
	GroundKickSpeed = 100,
	AirKickSpeed = 90,
	AirKickUpwardForce = 40,

	-- Colors
	ColorPowerLow = Color3.fromRGB(100, 255, 100),
	ColorPowerMed = Color3.fromRGB(255, 200, 0),
	ColorPowerHigh = Color3.fromRGB(255, 100, 100),
	ColorTrajectory = Color3.fromRGB(255, 255, 100),
	ColorTrajectoryFaded = Color3.fromRGB(150, 150, 50)
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

	-- Create UI and 3D visuals
	CreateChargeUI()
	Create3DVisuals()

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

	print("[BallControlClient] Initialized with trajectory preview")
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
-- 3D TRAJECTORY VISUALS
--------------------------------------------------------------------------------

function Create3DVisuals()
	-- Create folder in workspace
	TrajectoryFolder = Instance.new("Folder")
	TrajectoryFolder.Name = "TrajectoryVisuals"
	TrajectoryFolder.Parent = workspace

	if Settings.UseBeam then
		-- Create beam-based trajectory (smooth line)
		CreateBeamTrajectory()
	else
		-- Create dot-based trajectory
		CreateDotTrajectory()
	end

	print("[BallControlClient] Created trajectory visuals (Beam mode: " .. tostring(Settings.UseBeam) .. ")")
end

function CreateBeamTrajectory()
	-- Create parts with attachments for the beam to connect
	for i = 1, Settings.TrajectoryPointCount do
		local point = Instance.new("Part")
		point.Name = "TrajectoryPoint_" .. i
		point.Size = Vector3.new(0.1, 0.1, 0.1)
		point.Transparency = 1  -- Invisible, just holds attachment
		point.CanCollide = false
		point.Anchored = true
		point.CastShadow = false
		point.Parent = TrajectoryFolder

		-- Create attachment for beam
		local attachment = Instance.new("Attachment")
		attachment.Name = "BeamAttachment"
		attachment.Parent = point

		table.insert(TrajectoryPoints, point)
		table.insert(TrajectoryAttachments, attachment)

		-- Create beam connecting to previous point
		if i > 1 then
			local beam = Instance.new("Beam")
			beam.Name = "TrajectoryBeam_" .. i
			beam.Attachment0 = TrajectoryAttachments[i - 1]
			beam.Attachment1 = attachment
			beam.Width0 = Settings.BeamWidth
			beam.Width1 = Settings.BeamWidth
			beam.Color = ColorSequence.new(Settings.ColorTrajectory)
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 0.8)
			})
			beam.FaceCamera = true
			beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 2
			beam.LightEmission = 0.8
			beam.LightInfluence = 0
			beam.Enabled = false  -- Start hidden
			beam.Parent = point
		end
	end
end

function CreateDotTrajectory()
	-- Create trajectory point pool (original dot method)
	for i = 1, Settings.TrajectoryPointCount do
		local point = Instance.new("Part")
		point.Name = "TrajectoryPoint_" .. i
		point.Size = Vector3.new(Settings.TrajectorySize, Settings.TrajectorySize, Settings.TrajectorySize)
		point.Shape = Enum.PartType.Ball
		point.Material = Enum.Material.Neon
		point.Color = Settings.ColorTrajectory
		point.CanCollide = false
		point.Anchored = true
		point.Transparency = 1  -- Start hidden
		point.CastShadow = false
		point.Parent = TrajectoryFolder

		-- Add glow effect
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 8
		light.Color = Settings.ColorTrajectory
		light.Enabled = false
		light.Parent = point

		table.insert(TrajectoryPoints, point)
	end
end

function ShowTrajectory()
	if Settings.UseBeam then
		-- Enable all beams
		for _, point in ipairs(TrajectoryPoints) do
			local beam = point:FindFirstChildOfClass("Beam")
			if beam then
				beam.Enabled = true
			end
		end
	end
end

function HideTrajectory()
	if Settings.UseBeam then
		-- Disable all beams
		for _, point in ipairs(TrajectoryPoints) do
			local beam = point:FindFirstChildOfClass("Beam")
			if beam then
				beam.Enabled = false
			end
		end
	else
		-- Hide dots
		for _, point in ipairs(TrajectoryPoints) do
			point.Transparency = 1
			local light = point:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = false
			end
		end
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
			UpdateTrajectoryPreview()
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

function UpdateTrajectoryPreview()
	if not RootPart or not Character then 
		print("[Trajectory] No RootPart or Character!")
		HideTrajectory()
		return 
	end

	local direction = GetKickDirection()
	local power = GetChargePower()
	local kickType = IsChargingAirKick and "Air" or "Ground"

	-- Calculate initial velocity
	local baseSpeed = kickType == "Air" and Settings.AirKickSpeed or Settings.GroundKickSpeed
	local velocity = direction * (baseSpeed * power)

	-- Add upward component
	if kickType == "Air" then
		velocity = velocity + Vector3.new(0, Settings.AirKickUpwardForce * power, 0)
	else
		-- Ground kicks also need a small upward component for realistic arc
		velocity = velocity + Vector3.new(0, 5 * power, 0)  -- Small lift
	end

	-- Starting position (in front of player at chest/head height)
	local heightOffset = 2  -- Start at chest height (humanoids are ~5 studs tall)
	local forwardOffset = 3   -- Distance in front of player
	local startPos = RootPart.Position + direction * forwardOffset + Vector3.new(0, heightOffset, 0)

	-- CRITICAL: Force trajectory to start above ground
	-- If player is somehow underground, clamp the Y position
	if startPos.Y < 2 then
		warn("[Trajectory] Player appears underground! Y=" .. startPos.Y .. ", forcing to Y=2")
		startPos = Vector3.new(startPos.X, 2, startPos.Z)
	end

	-- Gravity
	local gravity = Vector3.new(0, -workspace.Gravity, 0)

	print(string.format("[Trajectory] Start: %s, Vel: %s, Points: %d", tostring(startPos), tostring(velocity), #TrajectoryPoints))

	-- Simulate trajectory
	local hitGround = false
	local lastValidIndex = Settings.TrajectoryPointCount

	for i = 1, Settings.TrajectoryPointCount do
		-- Calculate position at this time step
		local t = (i - 1) * Settings.TrajectorySpacing
		local position = startPos + velocity * t + 0.5 * gravity * t * t

		-- Check if point exists
		if not TrajectoryPoints[i] then
			warn("TrajectoryPoints[" .. i .. "] is nil!")
			break
		end

		-- Check if hit ground
		if position.Y < 1 then
			-- Clamp to ground level
			position = Vector3.new(position.X, 1, position.Z)
			hitGround = true
			lastValidIndex = i
			if i <= 3 then
				print(string.format("[Trajectory] Hit ground at point %d, Y was %.2f", i, (startPos + velocity * t + 0.5 * gravity * t * t).Y))
			end
		end

		-- Update point position
		TrajectoryPoints[i].Position = position

		if Settings.UseBeam then
			-- Beams are always visible when enabled, just update positions
			-- Fade far points by adjusting beam transparency
			local beam = TrajectoryPoints[i]:FindFirstChildOfClass("Beam")
			if beam then
				local fadeRatio = i / Settings.TrajectoryPointCount
				beam.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2 + fadeRatio * 0.3),
					NumberSequenceKeypoint.new(1, 0.5 + fadeRatio * 0.4)
				})

				-- Hide beam if past ground hit
				if hitGround and i > lastValidIndex then
					beam.Enabled = false
				else
					beam.Enabled = true
				end

				if i == 2 then
					print(string.format("[Trajectory] Beam 2 enabled: %s, transparency: %s", tostring(beam.Enabled), tostring(beam.Transparency)))
				end
			else
				if i == 2 then
					print("[Trajectory] Point 2 has NO BEAM!")
				end
			end
		else
			-- Dot mode: update transparency and color
			local fadeRatio = i / Settings.TrajectoryPointCount
			TrajectoryPoints[i].Transparency = 0.2 + (fadeRatio * 0.7)
			TrajectoryPoints[i].Color = Settings.ColorTrajectory:Lerp(Settings.ColorTrajectoryFaded, fadeRatio)

			local light = TrajectoryPoints[i]:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = not hitGround or i <= lastValidIndex
				light.Brightness = 2 * (1 - fadeRatio)
			end

			-- Hide if past ground hit
			if hitGround and i > lastValidIndex then
				TrajectoryPoints[i].Transparency = 1
				if light then
					light.Enabled = false
				end
			end
		end

		-- Stop calculating if we hit ground
		if hitGround and i >= lastValidIndex then
			-- Hide remaining points
			for j = i + 1, Settings.TrajectoryPointCount do
				if Settings.UseBeam then
					local remainingBeam = TrajectoryPoints[j]:FindFirstChildOfClass("Beam")
					if remainingBeam then
						remainingBeam.Enabled = false
					end
				else
					TrajectoryPoints[j].Transparency = 1
					local remainingLight = TrajectoryPoints[j]:FindFirstChildOfClass("PointLight")
					if remainingLight then
						remainingLight.Enabled = false
					end
				end
			end
			break
		end
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
-- KICK ACTIONS
--------------------------------------------------------------------------------

function StartGroundKick()
	if not HasBall or not Character then return end

	IsChargingGroundKick = true
	ChargeStartTime = tick()
	ChargeFrame.Visible = true
	ChargeLabel.Text = "GROUND KICK"
	ShowTrajectory()

	print("[BallControlClient] Started ground kick charge")
end

function ReleaseGroundKick()
	if not IsChargingGroundKick then return end

	IsChargingGroundKick = false
	ChargeFrame.Visible = false
	HideTrajectory()

	if HasBall and Character and RootPart then
		local power = GetChargePower()
		local direction = GetKickDirection()

		print(string.format("[BallControlClient] Ground kick: Power=%.2f, Direction=%s", power, tostring(direction)))
		KickBall:FireServer("Ground", power, direction)
	end
end

function StartAirKick()
	if not HasBall or not Character then return end

	IsChargingAirKick = true
	ChargeStartTime = tick()
	ChargeFrame.Visible = true
	ChargeLabel.Text = "AIR KICK"
	ShowTrajectory()

	print("[BallControlClient] Started air kick charge")
end

function ReleaseAirKick()
	if not IsChargingAirKick then return end

	IsChargingAirKick = false
	ChargeFrame.Visible = false
	HideTrajectory()

	if HasBall and Character and RootPart then
		local power = GetChargePower()
		local direction = GetKickDirection()

		print(string.format("[BallControlClient] Air kick: Power=%.2f, Direction=%s", power, tostring(direction)))
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
		HideTrajectory()
	end

	print("[BallControlClient] Possession changed: " .. tostring(hasBall))
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function BallControlClient.HasBall()
	return HasBall
end

-- Allow external tweaking of trajectory settings
function BallControlClient.SetTrajectorySettings(pointCount, spacing, size)
	if pointCount then Settings.TrajectoryPointCount = pointCount end
	if spacing then Settings.TrajectorySpacing = spacing end
	if size then Settings.TrajectorySize = size end
end

return BallControlClient