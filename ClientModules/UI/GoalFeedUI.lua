--[[
	GoalFeedUI.lua
	Displays goal and assist notifications on the side of the screen.
]]

local GoalFeedUI = {}

-- Services
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local TeamColorHelper = require(script.Parent.Parent.TeamColorHelper)

-- UI Elements
local ParentGui = nil
local FeedContainer = nil

-- Settings
local FeedSettings = {
	Position = UDim2.new(1, -20, 0.3, 0),
	Size = UDim2.new(0, 250, 0, 80),
	NotificationDuration = 5,
}

-- Create the Goal Feed UI
function GoalFeedUI.Create(screenGui)
	ParentGui = screenGui

	FeedContainer = Instance.new("Frame")
	FeedContainer.Name = "GoalFeed"
	FeedContainer.Size = UDim2.new(0, 300, 0.4, 0)
	FeedContainer.Position = UDim2.new(1, -320, 0.3, 0)
	FeedContainer.BackgroundTransparency = 1
	FeedContainer.Parent = ParentGui

	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = FeedContainer

	return FeedContainer
end

-- Show a goal notification
function GoalFeedUI.ShowGoal(scoringTeam, scorerName, assisterName)
	if not FeedContainer then return end

	local teamColor = TeamColorHelper.GetTeamColor(scoringTeam) or Color3.fromRGB(255, 255, 255)

	local notification = Instance.new("Frame")
	notification.Name = "GoalNotification"
	notification.Size = UDim2.new(1, 0, 0, 60)
	notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notification.BackgroundTransparency = 0.4
	notification.BorderSizePixel = 0
	notification.Position = UDim2.new(1.2, 0, 0, 0) -- Start off-screen
	notification.Parent = FeedContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification

	local teamStripe = Instance.new("Frame")
	teamStripe.Name = "TeamStripe"
	teamStripe.Size = UDim2.new(0, 6, 1, 0)
	teamStripe.Position = UDim2.new(1, -6, 0, 0)
	teamStripe.BackgroundColor3 = teamColor
	teamStripe.BorderSizePixel = 0
	teamStripe.Parent = notification
	
	local stripeCorner = Instance.new("UICorner")
	stripeCorner.CornerRadius = UDim.new(0, 8)
	stripeCorner.Parent = teamStripe

	local textContainer = Instance.new("Frame")
	textContainer.Size = UDim2.new(1, -20, 1, 0)
	textContainer.BackgroundTransparency = 1
	textContainer.Parent = notification

	local scorerLabel = Instance.new("TextLabel")
	scorerLabel.Size = UDim2.new(1, 0, 0.5, 0)
	scorerLabel.Position = UDim2.new(0, 10, 0.1, 0)
	scorerLabel.BackgroundTransparency = 1
	scorerLabel.Font = Enum.Font.GothamBold
	scorerLabel.Text = string.upper(scorerName) .. " SCORED!"
	scorerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	scorerLabel.TextSize = 18
	scorerLabel.TextXAlignment = Enum.TextXAlignment.Left
	scorerLabel.Parent = textContainer

	if assisterName then
		local assistLabel = Instance.new("TextLabel")
		assistLabel.Size = UDim2.new(1, 0, 0.4, 0)
		assistLabel.Position = UDim2.new(0, 10, 0.5, 0)
		assistLabel.BackgroundTransparency = 1
		assistLabel.Font = Enum.Font.GothamMedium
		assistLabel.Text = "(Assist: " .. assisterName .. ")"
		assistLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		assistLabel.TextSize = 14
		assistLabel.TextXAlignment = Enum.TextXAlignment.Left
		assistLabel.Parent = textContainer
	end

	-- Animate in
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tweenIn = TweenService:Create(notification, tweenInfo, {Position = UDim2.new(0, 0, 0, 0)})
	tweenIn:Play()

	-- Wait and animate out
	task.delay(FeedSettings.NotificationDuration, function()
		local tweenOut = TweenService:Create(notification, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1.2, 0, 0, 0)})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			notification:Destroy()
		end)
	end)
end

return GoalFeedUI
