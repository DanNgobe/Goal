--[[
	ChargeBarUI.lua
	Creates and manages the kick charge bar UI.
]]

local ChargeBarUI = {}

-- UI Elements
local ChargeFrame = nil
local ChargeBar = nil
local ChargeLabel = nil

-- Settings
local Settings = {
	ColorPowerLow = Color3.fromRGB(100, 255, 100),
	ColorPowerMed = Color3.fromRGB(255, 200, 0),
	ColorPowerHigh = Color3.fromRGB(255, 100, 100),
}

-- Create the charge bar UI
function ChargeBarUI.Create(parent)
	ChargeFrame = Instance.new("Frame")
	ChargeFrame.Name = "ChargeFrame"
	ChargeFrame.Size = UDim2.new(0, 350, 0, 50)
	ChargeFrame.Position = UDim2.new(0.5, -175, 0.85, 0)
	ChargeFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	ChargeFrame.BackgroundTransparency = 0.3
	ChargeFrame.BorderSizePixel = 0
	ChargeFrame.Visible = false
	ChargeFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = ChargeFrame

	-- Charge Bar Background
	local barBackground = Instance.new("Frame")
	barBackground.Name = "BarBackground"
	barBackground.Size = UDim2.new(1, -20, 0, 20)
	barBackground.Position = UDim2.new(0, 10, 0, 25)
	barBackground.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	barBackground.BorderSizePixel = 0
	barBackground.Parent = ChargeFrame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = barBackground

	-- Charge Bar (fills up)
	ChargeBar = Instance.new("Frame")
	ChargeBar.Name = "ChargeBar"
	ChargeBar.Size = UDim2.new(0, 0, 1, 0)
	ChargeBar.BackgroundColor3 = Settings.ColorPowerLow
	ChargeBar.BorderSizePixel = 0
	ChargeBar.ZIndex = 2
	ChargeBar.Parent = barBackground

	local chargeCorner = Instance.new("UICorner")
	chargeCorner.CornerRadius = UDim.new(0, 4)
	chargeCorner.Parent = ChargeBar

	-- Power zone markers
	CreatePowerZones(barBackground)

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

	return ChargeFrame
end

-- Create power zone markers
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

-- Update charge bar display
function ChargeBarUI.Update(power)
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

-- Set label text
function ChargeBarUI.SetLabel(text)
	ChargeLabel.Text = text
end

-- Show charge bar
function ChargeBarUI.Show()
	ChargeFrame.Visible = true
end

-- Hide charge bar
function ChargeBarUI.Hide()
	ChargeFrame.Visible = false
end

return ChargeBarUI
