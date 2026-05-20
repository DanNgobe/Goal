--[[
	TeamJoinUI.lua
	Creates and manages the team selection panel.

	Hover technique (no BackgroundColor3 animation):
	- White overlay Frame toggled instantly on hover = 1 property write, not 12
	- UIScale tween for a subtle grow effect = GPU transform, no re-batching
	- Result: SceneUpdater spike eliminated while looking premium
]]

local TeamJoinUI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

-- Dependencies
local TeamHelper      = require(script.Parent.Parent:WaitForChild("Utils"):WaitForChild("TeamHelper"))
local SoundController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("SoundController"))

-- UI Elements
local JoinPanel  = nil
local BlueButton = nil
local RedButton  = nil

	local function SetupHover(button)
		local baseColor = button.BackgroundColor3
		local hoverColor = baseColor:Lerp(Color3.new(1, 1, 1), 0.2)
		
		-- Create white overlay for "premium" flash effect (1 property write vs tweening color)
		local overlay = Instance.new("Frame")
		overlay.Name = "HoverOverlay"
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.new(1, 1, 1)
		overlay.BackgroundTransparency = 0.9 -- Subtle
		overlay.BorderSizePixel = 0
		overlay.Visible = false
		overlay.Parent = button
		Instance.new("UICorner").Parent = overlay

		-- Add UIScale for the grow effect mentioned in the header
		local scale = button:FindFirstChild("HoverScale") or Instance.new("UIScale")
		scale.Name = "HoverScale"
		scale.Scale = 1
		scale.Parent = button

		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		button.MouseEnter:Connect(function()
			overlay.Visible = true
			TweenService:Create(scale, tweenInfo, {Scale = 1.05}):Play()
			SoundController.PlaySFX("UI_Hover")
		end)

		button.MouseLeave:Connect(function()
			overlay.Visible = false
			TweenService:Create(scale, tweenInfo, {Scale = 1}):Play()
		end)
	end

-- ── Create ────────────────────────────────────────────────────────────────────

function TeamJoinUI.Create(parent)
	JoinPanel                        = Instance.new("Frame")
	JoinPanel.Name                   = "TeamJoinPanel"
	JoinPanel.Size                   = UDim2.new(0.3, 0, 0.15, 0)
	JoinPanel.Position               = UDim2.new(0.35, 0, 0.8, 0)
	JoinPanel.BackgroundColor3       = Color3.fromRGB(20, 20, 30)
	JoinPanel.BackgroundTransparency = 0.1
	JoinPanel.BorderSizePixel        = 0
	JoinPanel.Parent                 = parent

	local corner             = Instance.new("UICorner")
	corner.CornerRadius      = UDim.new(0.1, 0)
	corner.Parent            = JoinPanel

	local stroke             = Instance.new("UIStroke")
	stroke.Color             = Color3.fromRGB(255, 215, 0)
	stroke.Thickness         = 2
	stroke.Parent            = JoinPanel

	-- Title
	local title              = Instance.new("TextLabel")
	title.Name               = "Title"
	title.Size               = UDim2.new(0.9, 0, 0.25, 0)
	title.Position           = UDim2.new(0.05, 0, 0.05, 0)
	title.BackgroundTransparency = 1
	title.Font               = Enum.Font.GothamBold
	title.TextScaled         = true
	title.TextColor3         = Color3.fromRGB(255, 255, 255)
	title.Text               = "SELECT TEAM"
	title.Parent             = JoinPanel

	-- Home Button
	BlueButton               = Instance.new("TextButton")
	BlueButton.Name          = "HomeButton"
	BlueButton.Size          = UDim2.new(0.42, 0, 0.55, 0)
	BlueButton.Position      = UDim2.new(0.05, 0, 0.38, 0)
	BlueButton.BackgroundColor3 = TeamHelper.GetTeamColor("HomeTeam")
	BlueButton.Font          = Enum.Font.GothamBold
	BlueButton.TextScaled    = true
	BlueButton.TextColor3    = TeamHelper.GetContrastColor(BlueButton.BackgroundColor3)
	BlueButton.Text          = TeamHelper.GetTeamName("HomeTeam")
	BlueButton.Parent        = JoinPanel
	Instance.new("UICorner").Parent = BlueButton

	-- Away Button
	RedButton                = Instance.new("TextButton")
	RedButton.Name           = "AwayButton"
	RedButton.Size           = UDim2.new(0.42, 0, 0.55, 0)
	RedButton.Position       = UDim2.new(0.53, 0, 0.38, 0)
	RedButton.BackgroundColor3 = TeamHelper.GetTeamColor("AwayTeam")
	RedButton.Font           = Enum.Font.GothamBold
	RedButton.TextScaled     = true
	RedButton.TextColor3     = TeamHelper.GetContrastColor(RedButton.BackgroundColor3)
	RedButton.Text           = TeamHelper.GetTeamName("AwayTeam")
	RedButton.Parent         = JoinPanel
	Instance.new("UICorner").Parent = RedButton

	-- Remotes
	local events          = ReplicatedStorage:WaitForChild("Events")
	local playerRemotes   = events:WaitForChild("PlayerRemotes")
	local joinTeamRequest = playerRemotes:WaitForChild("JoinTeamRequest")
	local playerJoined    = playerRemotes:WaitForChild("PlayerJoined")

	BlueButton.MouseButton1Click:Connect(function()
		SoundController.PlaySFX("VS_Slam")
		joinTeamRequest:FireServer("HomeTeam")
	end)

	RedButton.MouseButton1Click:Connect(function()
		SoundController.PlaySFX("VS_Slam")
		joinTeamRequest:FireServer("AwayTeam")
	end)

	playerJoined.OnClientEvent:Connect(function()
		TeamJoinUI.Hide()
	end)

	-- Hover: overlay flash + scale grow (no color tween)
	SetupHover(BlueButton)
	SetupHover(RedButton)

	return JoinPanel
end

-- ── Show / Hide ───────────────────────────────────────────────────────────────

function TeamJoinUI.Show()
	if JoinPanel then JoinPanel.Visible = true end
end

function TeamJoinUI.Hide()
	if JoinPanel then JoinPanel.Visible = false end
end

return TeamJoinUI
