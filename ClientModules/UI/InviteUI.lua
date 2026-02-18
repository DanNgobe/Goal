--[[
	InviteUI.lua
	Developer info & support panel with invite and donation options.
]]

local InviteUI = {}

-- Services
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Private variables
local ScreenGui = nil
local InviteButton = nil
local InfoPanel = nil
local isInfoPanelOpen = false

-- Standard Roblox icons
local INFO_ICON = "rbxassetid://79869331183806" -- Social Plus Icon

-- Donation amounts (in Robux) with Product IDs
local DONATION_OPTIONS = {
	{amount = 10, productId = 3537974762},
	{amount = 100, productId = 3537976383},
	{amount = 1000, productId = 3537976964}
}

function InviteUI.Create(parentGui)
	ScreenGui = parentGui

	-- Create button (Right side now)
	InviteButton = Instance.new("ImageButton")
	InviteButton.Name = "InfoButton"
	InviteButton.Size = UDim2.new(0, 40, 0, 40)
	InviteButton.Position = UDim2.new(1, -50, 0, 10) -- Top Right
	InviteButton.AnchorPoint = Vector2.new(0, 0)
	InviteButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	InviteButton.BackgroundTransparency = 0.5
	InviteButton.Image = INFO_ICON
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

	-- Tooltip
	local tooltip = Instance.new("TextLabel")
	tooltip.Size = UDim2.new(0, 80, 0, 20)
	tooltip.Position = UDim2.new(0, -90, 0.5, -10)
	tooltip.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	tooltip.BackgroundTransparency = 0.3
	tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
	tooltip.Text = "Info & Support"
	tooltip.Font = Enum.Font.GothamMedium
	tooltip.TextSize = 12
	tooltip.Visible = false
	tooltip.Parent = InviteButton

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 4)
	tCorner.Parent = tooltip

	-- Create Info Panel
	InfoPanel = Instance.new("Frame")
	InfoPanel.Name = "InfoPanel"
	InfoPanel.Size = UDim2.new(0, 320, 0, 0) -- Start collapsed
	InfoPanel.Position = UDim2.new(1, -330, 0, 60)
	InfoPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	InfoPanel.BackgroundTransparency = 0.1
	InfoPanel.Visible = false
	InfoPanel.Parent = ScreenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = InfoPanel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(255, 255, 255)
	panelStroke.Thickness = 2
	panelStroke.Transparency = 0.7
	panelStroke.Parent = InfoPanel

	-- Panel Layout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = InfoPanel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 15)
	padding.PaddingBottom = UDim.new(0, 15)
	padding.PaddingLeft = UDim.new(0, 15)
	padding.PaddingRight = UDim.new(0, 15)
	padding.Parent = InfoPanel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "About & Support"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.Parent = InfoPanel

	-- Developer Info
	local devInfo = Instance.new("TextLabel")
	devInfo.Name = "DevInfo"
	devInfo.Size = UDim2.new(1, 0, 0, 95)
	devInfo.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	devInfo.BackgroundTransparency = 0.3
	devInfo.TextColor3 = Color3.fromRGB(220, 220, 220)
	devInfo.Text = "My name is Zeedanzo!\n\nI love making art and sharing it with others.\n\nIf you find any bugs, please report them :-)"
	devInfo.Font = Enum.Font.Gotham
	devInfo.TextSize = 14
	devInfo.TextWrapped = true
	devInfo.TextYAlignment = Enum.TextYAlignment.Top
	devInfo.Parent = InfoPanel

	local devCorner = Instance.new("UICorner")
	devCorner.CornerRadius = UDim.new(0, 6)
	devCorner.Parent = devInfo

	local devPadding = Instance.new("UIPadding")
	devPadding.PaddingTop = UDim.new(0, 8)
	devPadding.PaddingBottom = UDim.new(0, 8)
	devPadding.PaddingLeft = UDim.new(0, 8)
	devPadding.PaddingRight = UDim.new(0, 8)
	devPadding.Parent = devInfo

	-- Invite Button
	local inviteBtn = Instance.new("TextButton")
	inviteBtn.Name = "InviteButton"
	inviteBtn.Size = UDim2.new(1, 0, 0, 40)
	inviteBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
	inviteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	inviteBtn.Text = "📨 Invite Friends"
	inviteBtn.Font = Enum.Font.GothamBold
	inviteBtn.TextSize = 16
	inviteBtn.Parent = InfoPanel

	local inviteCorner = Instance.new("UICorner")
	inviteCorner.CornerRadius = UDim.new(0, 8)
	inviteCorner.Parent = inviteBtn

	inviteBtn.MouseButton1Click:Connect(function()
		pcall(function()
			SocialService:PromptGameInvite(Players.LocalPlayer)
		end)
	end)

	-- Donation Section Label
	local donateLabel = Instance.new("TextLabel")
	donateLabel.Name = "DonateLabel"
	donateLabel.Size = UDim2.new(1, 0, 0, 25)
	donateLabel.BackgroundTransparency = 1
	donateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	donateLabel.Text = "Support Development"
	donateLabel.Font = Enum.Font.GothamBold
	donateLabel.TextSize = 16
	donateLabel.Parent = InfoPanel

	-- Donation Buttons Container
	local donateContainer = Instance.new("Frame")
	donateContainer.Name = "DonateContainer"
	donateContainer.Size = UDim2.new(1, 0, 0, 50)
	donateContainer.BackgroundTransparency = 1
	donateContainer.Parent = InfoPanel

	local donateGrid = Instance.new("UIGridLayout")
	donateGrid.CellSize = UDim2.new(0.31, 0, 0, 45)
	donateGrid.CellPadding = UDim2.new(0.035, 0, 0, 10)
	donateGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	donateGrid.Parent = donateContainer

	-- Create donation buttons
	for _, option in ipairs(DONATION_OPTIONS) do
		local donateBtn = Instance.new("TextButton")
		donateBtn.Name = "Donate" .. option.amount
		donateBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
		donateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		donateBtn.Text = "R$" .. option.amount
		donateBtn.Font = Enum.Font.GothamBold
		donateBtn.TextSize = 16
		donateBtn.Parent = donateContainer

		local donateCorner = Instance.new("UICorner")
		donateCorner.CornerRadius = UDim.new(0, 8)
		donateCorner.Parent = donateBtn

		-- Prompt product purchase
		donateBtn.MouseButton1Click:Connect(function()
			pcall(function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, option.productId)
			end)
		end)

		-- Hover effect
		donateBtn.MouseEnter:Connect(function()
			TweenService:Create(donateBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 200, 120)}):Play()
		end)
		donateBtn.MouseLeave:Connect(function()
			TweenService:Create(donateBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 180, 100)}):Play()
		end)
	end

	-- Toggle panel function
	local function toggleInfoPanel()
		isInfoPanelOpen = not isInfoPanelOpen
		
		if isInfoPanelOpen then
			InfoPanel.Visible = true
			InfoPanel.Size = UDim2.new(0, 320, 0, 0)
			TweenService:Create(InfoPanel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
				{Size = UDim2.new(0, 320, 0, 380)}):Play()
		else
			TweenService:Create(InfoPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), 
				{Size = UDim2.new(0, 320, 0, 0)}):Play()
			task.wait(0.2)
			InfoPanel.Visible = false
		end
	end

	-- Click to toggle panel
	InviteButton.MouseButton1Click:Connect(function()
		toggleInfoPanel()
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
