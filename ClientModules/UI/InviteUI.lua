--[[
	InviteUI.lua
	Standalone invite button icon.
]]

local InviteUI = {}

-- Services
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

-- Private variables
local ScreenGui = nil
local InviteButton = nil

-- Standard Roblox icons
local INVITE_ICON = "rbxassetid://79869331183806" -- Social Plus Icon

function InviteUI.Create(parentGui)
	ScreenGui = parentGui

	-- Create button
	InviteButton = Instance.new("ImageButton")
	InviteButton.Name = "InvitePlayersButton"
	InviteButton.Size = UDim2.new(0, 40, 0, 40)
	InviteButton.Position = UDim2.new(0, 10, 0, 10) -- Top Left
	InviteButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	InviteButton.BackgroundTransparency = 0.5
	InviteButton.Image = INVITE_ICON
	InviteButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
	InviteButton.Parent = ScreenGui

	-- Round corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20)
	corner.Parent = InviteButton

	-- Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = InviteButton

	-- Tooltip (optional, just simple label on hover)
	local tooltip = Instance.new("TextLabel")
	tooltip.Size = UDim2.new(0, 100, 0, 20)
	tooltip.Position = UDim2.new(1, 10, 0.5, -10)
	tooltip.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	tooltip.BackgroundTransparency = 0.3
	tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
	tooltip.Text = "Invite Friends"
	tooltip.Font = Enum.Font.GothamMedium
	tooltip.TextSize = 12
	tooltip.Visible = false
	tooltip.Parent = InviteButton

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 4)
	tCorner.Parent = tooltip

	-- Click event
	InviteButton.MouseButton1Click:Connect(function()
		pcall(function()
			SocialService:PromptGameInvite(Players.LocalPlayer)
		end)
	end)

	-- Hover effects
	InviteButton.MouseEnter:Connect(function()
		tooltip.Visible = true
		TweenService:Create(InviteButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
	end)
	InviteButton.MouseLeave:Connect(function()
		tooltip.Visible = false
		TweenService:Create(InviteButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
	end)

	return InviteButton
end

return InviteUI
