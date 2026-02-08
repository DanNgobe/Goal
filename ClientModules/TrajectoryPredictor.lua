--[[
	TrajectoryPredictor.lua
	Visualizes the predicted trajectory of the ball when aiming
]]

local TrajectoryPredictor = {}

-- Services
local Workspace = game:GetService("Workspace")

-- Settings (must match BallControlClient and server physics!)
local Settings = {
	GroundKickSpeed = 100,
	AirKickSpeed = 90,
	AirKickUpwardForce = 60, -- Increased from 40 for higher arc
	
	-- Visual settings
	PointCount = 35, -- Increased from 20 for longer trajectory
	PointSize = 0.6, -- Increased from 0.3 for better visibility
	PointSpacing = 0.12, -- Increased from 0.1 for longer span
	MaxDistance = 150, -- Increased from 100 for longer range
	
	-- Colors
	GroundKickColor = Color3.fromRGB(100, 200, 255),
	AirKickColor = Color3.fromRGB(255, 150, 50),
	Transparency = 0.2, -- Slightly less transparent
}

-- Private variables
local TrajectoryFolder = nil
local TrajectoryPoints = {}
local IsVisible = false

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function TrajectoryPredictor.Initialize()
	-- Create folder for trajectory points
	TrajectoryFolder = Instance.new("Folder")
	TrajectoryFolder.Name = "TrajectoryPreview"
	TrajectoryFolder.Parent = Workspace
	
	-- Pre-create trajectory points
	for i = 1, Settings.PointCount do
		local point = Instance.new("Part")
		point.Name = "TrajectoryPoint" .. i
		point.Size = Vector3.new(Settings.PointSize, Settings.PointSize, Settings.PointSize)
		point.Shape = Enum.PartType.Ball
		point.Material = Enum.Material.Neon
		point.Anchored = true
		point.CanCollide = false
		point.CastShadow = false
		point.Transparency = Settings.Transparency
		point.Parent = TrajectoryFolder
		
		TrajectoryPoints[i] = point
	end
	
	TrajectoryPredictor.Hide()
end

--------------------------------------------------------------------------------
-- TRAJECTORY CALCULATION
--------------------------------------------------------------------------------

-- Calculate ground kick trajectory (straight line with slight drop)
local function CalculateGroundTrajectory(startPos, direction, power)
	local positions = {}
	local speed = Settings.GroundKickSpeed * power
	local gravity = Vector3.new(0, -Workspace.Gravity, 0)
	
	for i = 1, Settings.PointCount do
		local t = i * Settings.PointSpacing
		local horizontalOffset = direction * speed * t
		local verticalOffset = 0.5 * gravity * t * t
		local pos = startPos + horizontalOffset + verticalOffset
		
		-- Stop if hit ground
		if pos.Y < startPos.Y - 5 then
			break
		end
		
		-- Stop if too far
		if (pos - startPos).Magnitude > Settings.MaxDistance then
			break
		end
		
		table.insert(positions, pos)
	end
	
	return positions
end

-- Calculate air kick trajectory (arc with gravity)
local function CalculateAirTrajectory(startPos, direction, power)
	local positions = {}
	local horizontalSpeed = Settings.AirKickSpeed * power
	local upwardSpeed = Settings.AirKickUpwardForce * power
	local gravity = Vector3.new(0, -Workspace.Gravity, 0)
	
	for i = 1, Settings.PointCount do
		local t = i * Settings.PointSpacing
		local horizontalOffset = direction * horizontalSpeed * t
		local verticalOffset = Vector3.new(0, upwardSpeed * t, 0) + 0.5 * gravity * t * t
		local pos = startPos + horizontalOffset + verticalOffset
		
		-- Stop if hit ground
		if pos.Y < 1 then
			table.insert(positions, Vector3.new(pos.X, 1, pos.Z))
			break
		end
		
		-- Stop if too far
		if (pos - startPos).Magnitude > Settings.MaxDistance then
			break
		end
		
		table.insert(positions, pos)
	end
	
	return positions
end

--------------------------------------------------------------------------------
-- VISUALIZATION
--------------------------------------------------------------------------------

function TrajectoryPredictor.Update(kickType, startPos, direction, power)
	if not IsVisible then return end
	
	-- Calculate trajectory based on kick type
	local positions
	if kickType == "Ground" then
		positions = CalculateGroundTrajectory(startPos, direction, power)
	elseif kickType == "Air" then
		positions = CalculateAirTrajectory(startPos, direction, power)
	else
		return
	end
	
	-- Update point positions and visibility
	for i = 1, Settings.PointCount do
		local point = TrajectoryPoints[i]
		if positions[i] then
			point.Position = positions[i]
			point.Visible = true
			
			-- Set color based on kick type
			if kickType == "Ground" then
				point.Color = Settings.GroundKickColor
			else
				point.Color = Settings.AirKickColor
			end
			
			-- Fade out points further along the trajectory
			local fadeAmount = (i / #positions) * 0.5
			point.Transparency = Settings.Transparency + fadeAmount
		else
			point.Visible = false
		end
	end
end

function TrajectoryPredictor.Show()
	IsVisible = true
	if TrajectoryFolder then
		TrajectoryFolder.Parent = Workspace
	end
end

function TrajectoryPredictor.Hide()
	IsVisible = false
	if TrajectoryFolder then
		-- Hide all points
		for _, point in ipairs(TrajectoryPoints) do
			point.Visible = false
		end
	end
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function TrajectoryPredictor.Cleanup()
	if TrajectoryFolder then
		TrajectoryFolder:Destroy()
		TrajectoryFolder = nil
	end
	TrajectoryPoints = {}
	IsVisible = false
end

return TrajectoryPredictor
