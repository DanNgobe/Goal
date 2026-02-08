--[[
	TeamJoinUI.lua
	Creates and manages the team selection panel.
]]

local TeamJoinUI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- UI Elements
local JoinPanel = nil

-- Callbacks
local OnTeamSelected = nil

-- Create the team join panel
function TeamJoinUI.Create(parent, cameraController)
	JoinPanel = Instance.new("Frame")
	JoinPanel.Name = "TeamJoinPanel"
	JoinPanel.Size = UDim2.new(0.25, 0, 0.12, 0)
	JoinPanel.Position = UDim2.new(0.375, 0, 0.85, 0)
	JoinPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	JoinPanel.BackgroundTransparency = 0.15
	JoinPanel.BorderSizePixel = 0
	JoinPanel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = JoinPanel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 150, 150)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = JoinPanel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.9, 0, 0.25, 0)
	title.Position = UDim2.new(0.05, 0, 0.05, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "JOIN TEAM"
	title.Parent = JoinPanel

	-- Blue Team Button
	local blueButton = Instance.new("TextButton")
	blueButton.Name = "BlueButton"
	blueButton.Size = UDim2.new(0.42, 0, 0.55, 0)
	blueButton.Position = UDim2.new(0.05, 0, 0.38, 0)
	blueButton.BackgroundColor3 = Color3.fromRGB(30, 130, 255)
	blueButton.BorderSizePixel = 0
	blueButton.Font = Enum.Font.GothamBold
	blueButton.TextScaled = true
	blueButton.TextColor3 = Color3.new(1, 1, 1)
	blueButton.Text = "BLUE"
	blueButton.Parent = JoinPanel

	local blueCorner = Instance.new("UICorner")
	blueCorner.CornerRadius = UDim.new(0.2, 0)
	blueCorner.Parent = blueButton

	local blueStroke = Instance.new("UIStroke")
	blueStroke.Color = Color3.fromRGB(100, 180, 255)
	blueStroke.Thickness = 2
	blueStroke.Parent = blueButton

	-- Red Team Button
	local redButton = Instance.new("TextButton")
	redButton.Name = "RedButton"
	redButton.Size = UDim2.new(0.42, 0, 0.55, 0)
	redButton.Position = UDim2.new(0.53, 0, 0.38, 0)
	redButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	redButton.BorderSizePixel = 0
	redButton.Font = Enum.Font.GothamBold
	redButton.TextScaled = true
	redButton.TextColor3 = Color3.new(1, 1, 1)
	redButton.Text = "RED"
	redButton.Parent = JoinPanel

	local redCorner = Instance.new("UICorner")
	redCorner.CornerRadius = UDim.new(0.2, 0)
	redCorner.Parent = redButton

	local redStroke = Instance.new("UIStroke")
	redStroke.Color = Color3.fromRGB(255, 130, 130)
	redStroke.Thickness = 2
	redStroke.Parent = redButton

	-- Button events
	local playerRemotes = ReplicatedStorage:WaitForChild("PlayerRemotes")
	local joinTeamRequest = playerRemotes:WaitForChild("JoinTeamRequest")

	blueButton.MouseButton1Click:Connect(function()
		joinTeamRequest:FireServer("Blue")
		JoinPanel.Visible = false

		-- Lock mouse when team is selected
		if cameraController then
			cameraController.LockMouse()
		end
	end)

	redButton.MouseButton1Click:Connect(function()
		joinTeamRequest:FireServer("Red")
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

return TeamJoinUI
