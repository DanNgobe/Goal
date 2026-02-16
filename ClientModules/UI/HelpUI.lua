--[[
	HelpUI.lua
	Clean, context-sensitive overlay for controls in the bottom-right corner.
]]

local HelpUI = {}

-- Private variables
local ScreenGui = nil
local MainFrame = nil
local ControlsLabel = nil
local Visible = false

-- Initialize the Help UI
function HelpUI.Create(parentGui)
	ScreenGui = parentGui

	-- Main Frame
	MainFrame = Instance.new("Frame")
	MainFrame.Name = "HelpOverlay"
	MainFrame.Size = UDim2.new(0, 220, 0, 120) -- Reduced height
	MainFrame.Position = UDim2.new(1, -230, 1, -140) -- Adjusted position
	MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	MainFrame.BackgroundTransparency = 0.4
	MainFrame.BorderSizePixel = 0
	MainFrame.Visible = false -- Start hidden
	MainFrame.Parent = ScreenGui

	-- Add UICorner for rounded look
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = MainFrame

	-- Add UIStroke for a subtle border
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.8
	stroke.Thickness = 1.5
	stroke.Parent = MainFrame

	-- List Layout for vertical stacking
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = MainFrame

	-- Header / Help Toggle info
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(0.9, 0, 0, 20)
	header.BackgroundTransparency = 1
	header.Text = "[H] TO TOGGLE HELP"
	header.TextColor3 = Color3.fromRGB(200, 200, 200)
	header.TextSize = 12
	header.Font = Enum.Font.GothamBold
	header.Parent = MainFrame

	-- Controls Label
	ControlsLabel = Instance.new("TextLabel")
	ControlsLabel.Name = "ControlsList"
	ControlsLabel.Size = UDim2.new(0.9, 0, 0, 80)
	ControlsLabel.BackgroundTransparency = 1
	ControlsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	ControlsLabel.TextSize = 14
	ControlsLabel.Font = Enum.Font.GothamMedium
	ControlsLabel.TextYAlignment = Enum.TextYAlignment.Center
	ControlsLabel.Text = "MB1 - Ground Kick\nMB2 - Air Kick\nM - Mouse Lock"
	ControlsLabel.Parent = MainFrame

	return MainFrame
end

-- Update the controls based on context (possession)
function HelpUI.Update(hasBall)
	if not ControlsLabel then return end

	local text = ""
	if hasBall then
		text = "<b>MB1</b> - Ground Kick\n<b>MB2</b> - Air Kick\n<b>SHIFT</b> - Sprint\n<b>M</b> - Mouse Lock"
	else
		text = "<b>Q</b> - Tackle\n<b>C</b> - Switch NPC\n<b>SHIFT</b> - Sprint\n<b>M</b> - Mouse Lock"
	end

	ControlsLabel.RichText = true
	ControlsLabel.Text = text
end

-- Toggle visibility
function HelpUI.Toggle()
	Visible = not Visible
	if MainFrame then
		MainFrame.Visible = Visible
	end
	return Visible
end

-- Get visibility state
function HelpUI.IsVisible()
	return Visible
end

return HelpUI
