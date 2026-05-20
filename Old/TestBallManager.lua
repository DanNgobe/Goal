--[[
	TestBallManager.lua
	
	Test script to verify the BallManager works correctly.
	Place this in ServerScriptService and run to test ball system.
	
	This replaces the old BallServerScript.lua
	DELETE THIS FILE after testing is complete and ball system works.
]]

-- Wait for workspace to load
wait(1)

-- Require the BallManager module
local ServerModules = script.Parent:WaitForChild("ServerModules")
local BallManager = require(ServerModules:WaitForChild("BallManager"))

-- Get the ball
local Ball = workspace:WaitForChild("Ball")

print("=== BALL MANAGER TEST STARTED ===")

-- Initialize the BallManager
local success = BallManager.Initialize(Ball)
if not success then
	warn("Failed to initialize BallManager!")
	return
end

print("[BallManager] Successfully initialized")
print("[BallManager] Players can now pick up and kick the ball")
print("[BallManager] Test by:")
print("  1. Running around and touching ball with feet")
print("  2. Ball should attach in front of you")
print("  3. Left click (hold) for ground kick")
print("  4. Right click (hold) for air kick")
print("")
print("=== BALL MANAGER TEST RUNNING ===")
print("Make sure BallClientScript.lua is in StarterPlayer/StarterCharacterScripts")
print("DELETE this script after verifying everything works!")

-- Optional: Set up a callback to log possession changes
BallManager.OnPossessionChanged(function(character, hasPossession)
	if hasPossession then
		print(string.format("[BallManager] %s gained possession", character.Name))
	else
		print(string.format("[BallManager] %s lost possession", character.Name))
	end
end)
