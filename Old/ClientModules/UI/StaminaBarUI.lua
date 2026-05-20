--[[
	StaminaBarUI.lua
	Handles the visual representation of the stamina bar.
]]

local StaminaBarUI = {}

-- Services
local TweenService = game:GetService("TweenService")

-- Private variables
local ScreenGui = nil
local StaminaFrame = nil
local InnerBar = nil
local Icon = nil
local UIStroke = nil
local N_Label = nil
local InnerCorner = nil

function StaminaBarUI.Initialize(existingFrame)
	StaminaFrame = existingFrame
	if not StaminaFrame then return end

	-- Map existing children (matching the provided script's structure)
	InnerBar = StaminaFrame:WaitForChild("Inner")
	Detector = StaminaFrame:WaitForChild("Detector")
	N_Label = StaminaFrame:WaitForChild("N")
	Icon = StaminaFrame:WaitForChild("Icon")
	UIStroke = StaminaFrame:FindFirstChildOfClass("UIStroke") or StaminaFrame:WaitForChild("UIStroke")
	
	-- Setup Hover effects like the original script
	if Detector then
		Detector.MouseEnter:Connect(function()
			StaminaBarUI.ShowLabel(true)
		end)
		Detector.MouseLeave:Connect(function()
			StaminaBarUI.ShowLabel(false)
		end)
	end

	return StaminaFrame
end

function StaminaBarUI.Update(current, max)
	if not InnerBar or not InnerBar.Parent or not StaminaFrame or not StaminaFrame.Parent then return end
	
	local percent = math.clamp(current / max, 0, 1)
	
	-- Tween size (Match original logic)
	-- Use a pcall to prevent errors if the object is removed mid-tween
	pcall(function()
		InnerBar:TweenSize(UDim2.new(percent, 0, 1, 0), "InOut", "Quad", 0.5, true)
	end)

	-- Handle transparency (Match original script's full-stamina hiding logic)
	if percent >= 1 then
		StaminaFrame.BackgroundTransparency = 1
		if UIStroke then UIStroke.Transparency = 1 end
		InnerBar.BackgroundTransparency = 1
		Icon.BackgroundTransparency = 1
		local iconPic = Icon:FindFirstChild("IconPic")
		if iconPic then iconPic.ImageTransparency = 1 end
	else
		StaminaFrame.BackgroundTransparency = 0.35
		if UIStroke then UIStroke.Transparency = 0 end
		InnerBar.BackgroundTransparency = 0
		Icon.BackgroundTransparency = 0
		local iconPic = Icon:FindFirstChild("IconPic")
		if iconPic then iconPic.ImageTransparency = 0 end
	end
end

function StaminaBarUI.ShowLabel(visible)
	if not N_Label or not N_Label.Parent then return end
	local targetPos = visible and UDim2.new(-0.775, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
	pcall(function()
		N_Label:TweenPosition(targetPos, "Out", "Quad", .25, true)
	end)
end

return StaminaBarUI
