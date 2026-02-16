--[[
	InputHandler.lua
	Handles client-side input for slot switching.
	
	Key Features:
	- C key: Switch to NPC closest to ball on your team
]]

local InputHandler = {}

-- Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Private variables
local IsProcessing = false
local BallControlClient = nil
local UIController = nil

-- Initialize
function InputHandler.Initialize(ballControlClient)
	-- Store reference modules
	BallControlClient = ballControlClient
	UIController = require(script.Parent.UIController)

	-- Connect to input
	UserInputService.InputBegan:Connect(OnInputBegan)

	print("[InputHandler] Initialized")
	return true
end

-- Private: Handle input
function OnInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.C then
		-- Request slot switch
		RequestSlotSwitch()
	elseif input.KeyCode == Enum.KeyCode.Q then
		-- Request tackle
		if BallControlClient then
			BallControlClient.Tackle()
		end
	elseif input.KeyCode == Enum.KeyCode.H then
		-- Toggle Help UI
		if UIController then
			UIController.ToggleHelp()
		end
	end
end

-- Private: Request slot switch from server
function RequestSlotSwitch()
	if IsProcessing then return end

	-- Don't allow switching if player has the ball
	if BallControlClient and BallControlClient.HasBall() then
		print("[InputHandler] Cannot switch - you have the ball!")
		return
	end

	IsProcessing = true

	local playerRemotes = ReplicatedStorage:FindFirstChild("PlayerRemotes")
	if playerRemotes then
		local switchSlotRequest = playerRemotes:FindFirstChild("SwitchSlotRequest")
		if switchSlotRequest then
			switchSlotRequest:FireServer()
		end
	end

	-- Cooldown
	task.wait(0.5)
	IsProcessing = false
end

return InputHandler
