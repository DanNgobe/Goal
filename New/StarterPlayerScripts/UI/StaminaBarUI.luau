--[[
	StaminaBarUI.lua
	Handles the visual representation of the stamina bar.
]]

local StaminaBarUI = {}

-- Services
local TweenService = game:GetService("TweenService")

-- Private variables
local StaminaFrame = nil
local InnerBar     = nil
local Detector     = nil
local Icon         = nil
local IconPic      = nil   -- Cached at Initialize — never searched per-frame
local UIStroke     = nil
local N_Label      = nil
local LastPercent  = -1    -- Dirty flag: skip writes when value hasn't changed

function StaminaBarUI.Initialize(existingFrame)
	StaminaFrame = existingFrame
	if not StaminaFrame then return end

	-- Map existing children
	InnerBar  = StaminaFrame:WaitForChild("Inner")
	Detector  = StaminaFrame:WaitForChild("Detector")
	N_Label   = StaminaFrame:WaitForChild("N")
	Icon      = StaminaFrame:WaitForChild("Icon")
	UIStroke  = StaminaFrame:FindFirstChildOfClass("UIStroke") or StaminaFrame:WaitForChild("UIStroke")
	IconPic   = Icon and Icon:FindFirstChild("IconPic")  -- Cached once, never searched again
	LastPercent = -1  -- Force a full update on first call

	-- Hover effects
	if Detector then
		Detector.MouseEnter:Connect(function() StaminaBarUI.ShowLabel(true)  end)
		Detector.MouseLeave:Connect(function() StaminaBarUI.ShowLabel(false) end)
	end

	return StaminaFrame
end

function StaminaBarUI.Update(current, max)
	if not InnerBar or not InnerBar.Parent or not StaminaFrame or not StaminaFrame.Parent then return end

	local percent = math.clamp(current / max, 0, 1)

	-- Dirty check: quantise to 0.005 steps so we skip near-identical frames
	local quantised = math.floor(percent * 200) / 200
	if quantised == LastPercent then return end
	LastPercent = quantised

	-- Tween the fill bar
	pcall(function()
		InnerBar:TweenSize(UDim2.new(percent, 0, 1, 0), "InOut", "Quad", 0.5, true)
	end)

	-- Show/hide the frame based on fullness
	if percent >= 1 then
		StaminaFrame.BackgroundTransparency = 1
		if UIStroke then UIStroke.Transparency = 1 end
		InnerBar.BackgroundTransparency     = 1
		if Icon    then Icon.BackgroundTransparency  = 1 end
		if IconPic then IconPic.ImageTransparency    = 1 end
	else
		StaminaFrame.BackgroundTransparency = 0.35
		if UIStroke then UIStroke.Transparency = 0 end
		InnerBar.BackgroundTransparency     = 0
		if Icon    then Icon.BackgroundTransparency  = 0 end
		if IconPic then IconPic.ImageTransparency    = 0 end
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
