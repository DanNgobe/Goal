--[[
	TestFormation.lua
	
	Test script to visualize NPC spawn positions on the field.
	Place this in ServerScriptService and run to see where NPCs will spawn.
	
	This creates colored parts at each position to verify the formation layout.
	DELETE THIS FILE after testing is complete.
]]

-- Wait for workspace to load
wait(1)

-- Require the modules
local ServerModules = script.Parent:WaitForChild("ServerModules")
local FormationData = require(ServerModules:WaitForChild("FormationData"))
local NPCManager = require(ServerModules:WaitForChild("NPCManager"))

-- Get references
local Ground = workspace:WaitForChild("Pitch"):WaitForChild("Ground")

print("=== FORMATION TEST STARTED ===")

-- Initialize NPCManager
local success = NPCManager.Initialize(Ground, FormationData)
if not success then
	warn("Failed to initialize NPCManager!")
	return
end

-- Get field info
local center = NPCManager.GetFieldCenter()
local bounds = NPCManager.GetFieldBounds()
print(string.format("Field Center: %s", tostring(center)))
print(string.format("Field Bounds: %.1f x %.1f", bounds.Width, bounds.Length))

-- Function to create a visualization part
local function CreateMarker(position, color, label)
	local part = Instance.new("Part")
	part.Size = Vector3.new(2, 6, 2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Name = label
	
	-- Add label billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = label
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = billboard
	
	part.Parent = workspace
	return part
end

-- Test HomeTeam Team positions
print("\n=== TESTING HomeTeam TEAM POSITIONS ===")
local formation = FormationData.GetFormation()
local blueColor = Color3.fromRGB(0, 100, 255)

for _, posData in ipairs(formation) do
	local worldPos = NPCManager.CalculateWorldPosition("HomeTeam", posData.Position)
	CreateMarker(worldPos, blueColor, "Blue_" .. posData.Role)
	print(string.format("  %s: %s", posData.Role, tostring(worldPos)))
end

-- Test AwayTeam Team positions
print("\n=== TESTING AwayTeam TEAM POSITIONS ===")
local redColor = Color3.fromRGB(255, 50, 50)

for _, posData in ipairs(formation) do
	local worldPos = NPCManager.CalculateWorldPosition("AwayTeam", posData.Position)
	CreateMarker(worldPos, redColor, "Red_" .. posData.Role)
	print(string.format("  %s: %s", posData.Role, tostring(worldPos)))
end

-- Create a center marker
CreateMarker(center + Vector3.new(0, 3, 0), Color3.fromRGB(255, 255, 0), "CENTER")

print("\n=== FORMATION TEST COMPLETE ===")
print("Check the workspace for colored markers showing NPC positions.")
print("HomeTeam team on one side, AwayTeam team on the other.")
print("DELETE this script after verifying positions look correct!")
