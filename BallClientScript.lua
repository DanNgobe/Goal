-- StarterPlayer/StarterCharacterScripts/BallControl
local Services = {
	Players = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	UserInputService = game:GetService("UserInputService"),
	RunService = game:GetService("RunService")
}

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Root = Character:WaitForChild("HumanoidRootPart")

-- Wait for remotes
local RemoteFolder = Services.ReplicatedStorage:WaitForChild("BallRemotes")
local KickBall = RemoteFolder:WaitForChild("KickBall")
local PossessionChanged = RemoteFolder:WaitForChild("PossessionChanged")

-- Settings
local Settings = {
	Max_Charge_Time = 2,
	Min_Power = 0.3
}

-- State
local HasPossession = false
local IsCharging = false
local ChargeStart = 0
local ChargingType = nil

-- UI for charge indicator
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BallUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local ChargeFrame = Instance.new("Frame")
ChargeFrame.Name = "ChargeFrame"
ChargeFrame.Size = UDim2.new(0, 300, 0, 30)
ChargeFrame.Position = UDim2.new(0.5, -150, 0.8, 0)
ChargeFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ChargeFrame.BorderSizePixel = 2
ChargeFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
ChargeFrame.Visible = false
ChargeFrame.Parent = ScreenGui

local ChargeBar = Instance.new("Frame")
ChargeBar.Name = "ChargeBar"
ChargeBar.Size = UDim2.new(0, 0, 1, 0)
ChargeBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
ChargeBar.BorderSizePixel = 0
ChargeBar.Parent = ChargeFrame

local ChargeLabel = Instance.new("TextLabel")
ChargeLabel.Size = UDim2.new(1, 0, 1, 0)
ChargeLabel.BackgroundTransparency = 1
ChargeLabel.Text = "GROUND KICK"
ChargeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ChargeLabel.TextScaled = true
ChargeLabel.Font = Enum.Font.GothamBold
ChargeLabel.Parent = ChargeFrame

-- Listen for possession changes from server
PossessionChanged.OnClientEvent:Connect(function(HasBall)
	HasPossession = HasBall

	if not HasBall then
		-- Lost possession, cancel any charging
		IsCharging = false
		ChargingType = nil
		ChargeFrame.Visible = false
	end
end)

-- Get kick direction based on camera
local function GetKickDirection()
	local Camera = workspace.CurrentCamera
	local MousePos = Services.UserInputService:GetMouseLocation()
	local Ray = Camera:ViewportPointToRay(MousePos.X, MousePos.Y)

	-- Project direction onto horizontal plane
	local Direction = Ray.Direction
	Direction = Vector3.new(Direction.X, 0, Direction.Z).Unit

	return Direction
end

-- Calculate charge power
local function GetChargePower()
	local ChargeTime = tick() - ChargeStart
	local Power = math.clamp(ChargeTime / Settings.Max_Charge_Time, Settings.Min_Power, 1)
	return Power
end

-- Update charge UI
Services.RunService.RenderStepped:Connect(function()
	if IsCharging then
		local Power = GetChargePower()
		ChargeBar.Size = UDim2.new(Power, 0, 1, 0)

		-- Change color based on power
		if Power < 0.5 then
			ChargeBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
		elseif Power < 0.8 then
			ChargeBar.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
		else
			ChargeBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		end
	end
end)

-- Handle input
Services.UserInputService.InputBegan:Connect(function(Input, Processed)
	if Processed then return end

	-- Only allow charging if we have possession
	if not HasPossession then return end

	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Left click - Ground kick
		IsCharging = true
		ChargingType = "Ground"
		ChargeStart = tick()
		ChargeFrame.Visible = true
		ChargeLabel.Text = "GROUND KICK"

	elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
		-- Right click - Air kick
		IsCharging = true
		ChargingType = "Air"
		ChargeStart = tick()
		ChargeFrame.Visible = true
		ChargeLabel.Text = "AIR KICK"
	end
end)

Services.UserInputService.InputEnded:Connect(function(Input, Processed)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 and ChargingType == "Ground" then
		if IsCharging and HasPossession then
			local Power = GetChargePower()
			local Direction = GetKickDirection()
			KickBall:FireServer("Ground", Power, Direction)

			IsCharging = false
			ChargingType = nil
			ChargeFrame.Visible = false
		end

	elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and ChargingType == "Air" then
		if IsCharging and HasPossession then
			local Power = GetChargePower()
			local Direction = GetKickDirection()
			KickBall:FireServer("Air", Power, Direction)

			IsCharging = false
			ChargingType = nil
			ChargeFrame.Visible = false
		end
	end
end)