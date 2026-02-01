--[[
	PlayerSetup.lua
	Handles player character setup including collision groups.
	
	Place in ServerScriptService
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

-- Set up collision group for player character
local function SetupPlayerCollisions(character)
	task.wait(0.1)  -- Wait for character to fully load

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = "Players"
			end)
		end
	end
end

-- Connect to all players
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		SetupPlayerCollisions(character)
	end)

	-- Handle if character already exists
	if player.Character then
		SetupPlayerCollisions(player.Character)
	end
end)

-- Handle existing players
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		SetupPlayerCollisions(player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		SetupPlayerCollisions(character)
	end)
end
