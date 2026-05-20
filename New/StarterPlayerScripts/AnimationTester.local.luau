--[[
	AnimationTester.local.lua
	Loops through all animations in AnimationData and plays them on the character.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Animator = Humanoid:WaitForChild("Animator")

print("--- ANIMATION TESTER STARTED ---")

local function PlayAnimation(name, id)
	print("Playing: " .. name .. " (" .. id .. ")")
	
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	
	local track = Animator:LoadAnimation(anim)
	track:Play()
	
	-- Wait for animation to finish or at least 3 seconds
	task.wait(3)
	track:Stop()
	track:Destroy()
end

task.wait(5) -- Wait for character to fully load and settle

for category, anims in pairs(AnimationData) do
	if type(anims) == "table" then
		print("Category: " .. category)
		for animName, animId in pairs(anims) do
			if type(animId) == "string" and animId:find("rbxassetid://") then
				PlayAnimation(category .. "." .. animName, animId)
			end
		end
	end
end

print("--- ANIMATION TESTER FINISHED ---")
