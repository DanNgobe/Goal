--[[
	TestGoalkeeper.lua
	Simple script to initialize and test the AIGoalkeeper.
	
	Place this in ServerScriptService.
	Make sure you have:
	- workspace.Player (R15 character model)
	- workspace.Goal (Part)
	- workspace.Ball (Part)
]]

-- Wait for game to load
task.wait(1)

print("========================================")
print("    GOALKEEPER TEST - INITIALIZING")
print("========================================")

-- Get references to workspace objects
local Player = workspace:WaitForChild("Player")
local Goal = workspace:WaitForChild("Goal")
local Ball = workspace:WaitForChild("Ball")

-- Load the AIGoalkeeper module
local AIGoalkeeper = require(script.Parent:WaitForChild("AIGoalkeeper"))

-- Initialize the goalkeeper
local success = AIGoalkeeper.Initialize(Player, Ball, Goal)

if success then
	print("✓ Goalkeeper AI initialized successfully!")
	print("========================================")
	print("TEST CONTROLS:")
	print("- Move the ball toward the goal to test")
	print("- Goalkeeper will track and dive")
	print("========================================")
else
	warn("✗ Failed to initialize goalkeeper AI!")
end

-- Optional: Add some test commands
local function CreateTestBall()
	-- Create a test ball that shoots toward goal
	local testBall = Instance.new("Part")
	testBall.Name = "TestBall"
	testBall.Shape = Enum.PartType.Ball
	testBall.Size = Vector3.new(2, 2, 2)
	testBall.Position = Goal.Position + Vector3.new(0, 5, -20)
	testBall.BrickColor = BrickColor.new("Bright orange")
	testBall.Material = Enum.Material.Neon
	testBall.Parent = workspace
	
	-- Shoot toward goal
	local direction = (Goal.Position - testBall.Position).Unit
	testBall.AssemblyLinearVelocity = direction * 40 + Vector3.new(0, 5, 0)
	
	print("[Test] Test ball created and shot toward goal!")
end

-- Cleanup on server shutdown
game:BindToClose(function()
	AIGoalkeeper.Cleanup()
end)
