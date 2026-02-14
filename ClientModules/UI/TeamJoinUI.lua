--[[
	TeamJoinUI.lua
	Creates and manages the team selection panel.
]]

local TeamJoinUI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load TeamColorHelper
local TeamColorHelper = require(script.Parent.Parent:WaitForChild("TeamColorHelper"))

-- UI Elements
local JoinPanel = nil
local BlueButton = nil
local RedButton = nil

-- Callbacks
local OnTeamSelected = nil

-- Create the team join panel
function TeamJoinUI.Create(parent, cameraController)
	local TweenService = game:GetService("TweenService")
	
	JoinPanel = Instance.new("Frame")
	JoinPanel.Name = "TeamJoinPanel"
	JoinPanel.Size = UDim2.new(0.3, 0, 0.15, 0)
	JoinPanel.Position = UDim2.new(0.35, 0, 0.8, 0)
	JoinPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	JoinPanel.BackgroundTransparency = 0.1
	JoinPanel.BorderSizePixel = 0
	JoinPanel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = JoinPanel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 4
	stroke.Parent = JoinPanel

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
	}
	gradient.Rotation = 45
	gradient.Parent = JoinPanel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.9, 0, 0.25, 0)
	title.Position = UDim2.new(0.05, 0, 0.05, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "⚽ JOIN TEAM ⚽"
	title.Parent = JoinPanel

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.new(0, 0, 0)
	titleStroke.Thickness = 3
	titleStroke.Parent = title

	-- HomeTeam Team Button
	BlueButton = Instance.new("TextButton")
	BlueButton.Name = "BlueButton"
	BlueButton.Size = UDim2.new(0.42, 0, 0.55, 0)
	BlueButton.Position = UDim2.new(0.05, 0, 0.38, 0)
	BlueButton.BackgroundColor3 = TeamColorHelper.GetTeamColor("HomeTeam")
	BlueButton.BorderSizePixel = 0
	BlueButton.Font = Enum.Font.GothamBold
	BlueButton.TextScaled = true
	BlueButton.TextColor3 = Color3.new(1, 1, 1)
	BlueButton.Text = TeamColorHelper.GetTeamName("HomeTeam")
	BlueButton.Parent = JoinPanel

	local blueCorner = Instance.new("UICorner")
	blueCorner.CornerRadius = UDim.new(0.2, 0)
	blueCorner.Parent = BlueButton

	local blueStroke = Instance.new("UIStroke")
	blueStroke.Color = TeamColorHelper.GetLightTeamColor("HomeTeam")
	blueStroke.Thickness = 1
	blueStroke.Parent = BlueButton

	-- AwayTeam Team Button
	RedButton = Instance.new("TextButton")
	RedButton.Name = "RedButton"
	RedButton.Size = UDim2.new(0.42, 0, 0.55, 0)
	RedButton.Position = UDim2.new(0.53, 0, 0.38, 0)
	RedButton.BackgroundColor3 = TeamColorHelper.GetTeamColor("AwayTeam")
	RedButton.BorderSizePixel = 0
	RedButton.Font = Enum.Font.GothamBold
	RedButton.TextScaled = true
	RedButton.TextColor3 = Color3.new(1, 1, 1)
	RedButton.Text = TeamColorHelper.GetTeamName("AwayTeam")
	RedButton.Parent = JoinPanel

	local redCorner = Instance.new("UICorner")
	redCorner.CornerRadius = UDim.new(0.2, 0)
	redCorner.Parent = RedButton

	local redStroke = Instance.new("UIStroke")
	redStroke.Color = TeamColorHelper.GetLightTeamColor("AwayTeam")
	redStroke.Thickness = 1
	redStroke.Parent = RedButton

	-- Hover animations for buttons
	local function setupButtonAnimation(button)
		local originalSize = button.Size
		
		button.MouseEnter:Connect(function()
			local tween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(originalSize.X.Scale * 1.1, 0, originalSize.Y.Scale * 1.1, 0)
			})
			tween:Play()
		end)
		
		button.MouseLeave:Connect(function()
			local tween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = originalSize
			})
			tween:Play()
		end)
	end
	
	setupButtonAnimation(BlueButton)
	setupButtonAnimation(RedButton)

	-- Button events
	local playerRemotes = ReplicatedStorage:WaitForChild("PlayerRemotes")
	local joinTeamRequest = playerRemotes:WaitForChild("JoinTeamRequest")

	BlueButton.MouseButton1Click:Connect(function()
		joinTeamRequest:FireServer("HomeTeam")
		JoinPanel.Visible = false

		-- Lock mouse when team is selected
		if cameraController then
			cameraController.LockMouse()
		end
	end)

	RedButton.MouseButton1Click:Connect(function()
		joinTeamRequest:FireServer("AwayTeam")
		JoinPanel.Visible = false

		-- Lock mouse when team is selected
		if cameraController then
			cameraController.LockMouse()
		end
	end)

	-- Hide panel when player joins
	local playerJoined = playerRemotes:WaitForChild("PlayerJoined")
	playerJoined.OnClientEvent:Connect(function()
		JoinPanel.Visible = false
	end)

	return JoinPanel
end

-- Show the team join panel
function TeamJoinUI.Show()
	if JoinPanel then
		JoinPanel.Visible = true
	end
end

-- Hide the team join panel
function TeamJoinUI.Hide()
	if JoinPanel then
		JoinPanel.Visible = false
	end
end

-- Update team colors (called when teams change)
function TeamJoinUI.UpdateTeamColors()
	if BlueButton then
		BlueButton.BackgroundColor3 = TeamColorHelper.GetTeamColor("HomeTeam")
		BlueButton.Text = TeamColorHelper.GetTeamName("HomeTeam")
		local blueStroke = BlueButton:FindFirstChildOfClass("UIStroke")
		if blueStroke then
			blueStroke.Color = TeamColorHelper.GetLightTeamColor("HomeTeam")
		end
	end
	
	if RedButton then
		RedButton.BackgroundColor3 = TeamColorHelper.GetTeamColor("AwayTeam")
		RedButton.Text = TeamColorHelper.GetTeamName("AwayTeam")
		local redStroke = RedButton:FindFirstChildOfClass("UIStroke")
		if redStroke then
			redStroke.Color = TeamColorHelper.GetLightTeamColor("AwayTeam")
		end
	end
	
	print("[TeamJoinUI] Updated team colors")
end

return TeamJoinUI
