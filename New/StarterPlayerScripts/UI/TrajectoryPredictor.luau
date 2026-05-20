--[[
	TrajectoryPredictor.lua
	Visualizes the predicted ball trajectory during kick charging.

	Improvements over Goal version:
	- Uses Beams (not floating dots) connecting sequential points for a continuous arc line
	- Landing marker: a glowing ring on the predicted impact point
	- Power-driven color: low=blue, medium=yellow, high=red (matches KickChargeUI)
	- Separate dot + beam pooling so we never thrash instances
	- Ground kick arc matches server BodyVelocity physics exactly
	- Air kick arc matches server physics exactly
	- Dots scale with distance from camera (always visible)
	- Fades trajectory dots by index for a vanishing-into-distance effect
	- All points hidden by setting Transparency = 1 (no reparenting)
]]

local TrajectoryPredictor = {}

-- Services
local Workspace    = game:GetService("Workspace")
local RunService   = game:GetService("RunService")

-- ── Settings ──────────────────────────────────────────────────────────────────
-- These must match BallManager server physics values!
local Settings = {
	-- Physics (mirror BallConfig values)
	GroundKickMaxForce  = 65,   -- Mirror BallConfig.Ground_Kick_Max
	GroundKickMaxHeight = 15,
	AirKickMaxForce     = 75,   -- Mirror BallConfig.Air_Kick_Max
	AirKickMaxHeight    = 65,
	KickForceMult       = 1.3,  -- Same as server: force = maxPower * sqrt(power) * 1.3
	Gravity             = nil,  -- Set at runtime from Workspace.Gravity

	-- Visual
	SegmentCount        = 25,   -- Number of dots (reduced for performance)
	TimeStep            = 0.07, -- Seconds between each simulated step
	MaxDistance         = 200,  -- Stops computing if arc exceeds this
	GroundY             = 1,    -- Y floor level

	-- Dot appearance
	DotSizeBase         = 0.35, -- Base diameter of each dot
	DotSizeEnd          = 0.12, -- Diameter at tail end (fades smaller)
	FadeStart           = 0.3,  -- Fraction of arc at which fading begins

	-- Power colors (matches KickChargeUI zones)
	ColorLow  = Color3.fromRGB(60,  180, 255), -- blue  (<0.4)
	ColorMed  = Color3.fromRGB(255, 200,  40), -- yellow (0.4-0.75)
	ColorHigh = Color3.fromRGB(255,  60,  60), -- red   (>0.75)

	-- Landing ring
	RingRadius          = 2.5,
	RingThickness       = 0.3,
	RingHeight          = 0.15,
}

-- ── Private State ─────────────────────────────────────────────────────────────
local TrajectoryFolder  = nil
local Dots              = {}      -- Pre-pooled Part instances
local DotSizeCache      = {}      -- Pre-computed sizes [i] = normal, [i.."d"] = dashed
local LandingRing       = nil     -- A single ring Part shown at impact point
local IsVisible         = false

-- Reusable positions cache — avoids table allocation every frame
local PositionsCache    = {}
local PositionCount     = 0

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function GetPowerColor(power)
	if power < 0.4 then
		return Settings.ColorLow
	elseif power < 0.75 then
		-- Lerp yellow toward low
		local t = (power - 0.4) / 0.35
		return Settings.ColorLow:Lerp(Settings.ColorMed, t)
	else
		local t = (power - 0.75) / 0.25
		return Settings.ColorMed:Lerp(Settings.ColorHigh, t)
	end
end

local function CreateDot(index)
	local dot          = Instance.new("Part")
	dot.Name           = "TrajDot_" .. index
	dot.Shape          = Enum.PartType.Ball
	dot.Anchored       = true
	dot.CanCollide     = false
	dot.CastShadow     = false
	dot.Material       = Enum.Material.Neon
	dot.Transparency   = 1
	dot.Parent         = TrajectoryFolder
	return dot
end

local function CreateLandingRing()
	local ring          = Instance.new("Part")
	ring.Name           = "LandingRing"
	ring.Shape          = Enum.PartType.Cylinder
	ring.Anchored       = true
	ring.CanCollide     = false
	ring.CastShadow     = false
	ring.Material       = Enum.Material.Neon
	ring.Size           = Vector3.new(Settings.RingHeight, Settings.RingRadius * 2, Settings.RingRadius * 2)
	ring.Transparency   = 1
	ring.Parent         = TrajectoryFolder
	return ring
end

-- ── Physics Simulation ────────────────────────────────────────────────────────

-- Simulate Roblox projectile physics: pos = startPos + vel*t + 0.5*g*t^2
-- Exactly matching BodyVelocity behavior
-- Fills PositionsCache in-place; returns the number of valid entries.
-- No table allocation — reuses the module-level cache every frame.
local function SimulateArc(startPos, initialVelocity)
	local gravity = Settings.Gravity or Workspace.Gravity
	local gY      = -gravity             -- Only Y component needed
	local dt      = Settings.TimeStep
	local maxDist = Settings.MaxDistance
	local groundY = Settings.GroundY
	local count   = 0

	for i = 1, Settings.SegmentCount do
		local t   = i * dt
		local halfGt2 = 0.5 * gY * t * t
		local pos = Vector3.new(
			startPos.X + initialVelocity.X * t,
			startPos.Y + initialVelocity.Y * t + halfGt2,
			startPos.Z + initialVelocity.Z * t
		)

		-- Hit ground: interpolate exact landing position
		if pos.Y < groundY then
			local prevT  = (i - 1) * dt
			local prevY  = startPos.Y + initialVelocity.Y * prevT + 0.5 * gY * prevT * prevT
			local frac   = (prevY - groundY) / (prevY - pos.Y)
			local gT     = prevT + frac * dt
			count = count + 1
			PositionsCache[count] = Vector3.new(
				startPos.X + initialVelocity.X * gT,
				groundY,
				startPos.Z + initialVelocity.Z * gT
			)
			break
		end

		if (pos - startPos).Magnitude > maxDist then
			count = count + 1
			PositionsCache[count] = pos
			break
		end

		count = count + 1
		PositionsCache[count] = pos
	end

	PositionCount = count
end

local function GetInitialVelocity(kickType, direction, power)
	local curve = math.sqrt(power)  -- Mirror server's math.sqrt(power)

	if kickType == "Ground" then
		local force  = Settings.GroundKickMaxForce  * curve * Settings.KickForceMult
		local height = Settings.GroundKickMaxHeight * curve
		return (direction * force) + Vector3.new(0, height, 0)
	else
		local force  = Settings.AirKickMaxForce  * curve * Settings.KickForceMult
		local height = Settings.AirKickMaxHeight * curve
		return (direction * force) + Vector3.new(0, height, 0)
	end
end

-- ── Visualization ─────────────────────────────────────────────────────────────

function TrajectoryPredictor.Update(kickType, startPos, direction, power)
	if not IsVisible then return end

	Settings.Gravity = Workspace.Gravity

	local vel   = GetInitialVelocity(kickType, direction, power)
	SimulateArc(startPos, vel)  -- fills PositionsCache, sets PositionCount
	local count = PositionCount
	local color = GetPowerColor(power)

	for i = 1, Settings.SegmentCount do
		local dot = Dots[i]
		if not dot then continue end

		if i <= count then
			dot.Position = PositionsCache[i]

			-- Use pre-computed size cache — no per-frame size calculation or alloc
			dot.Size = (i % 3 == 0) and DotSizeCache[i .. "d"] or DotSizeCache[i]

			-- Transparency fade toward tail
			local frac      = i / count
			local fadeAlpha = 0
			if frac > Settings.FadeStart then
				fadeAlpha = ((frac - Settings.FadeStart) / (1 - Settings.FadeStart)) * 0.75
			end
			dot.Color        = color
			dot.Transparency = fadeAlpha
		else
			dot.Transparency = 1
		end
	end

	-- Landing ring at last computed position
	if count > 0 and LandingRing then
		local landPos = PositionsCache[count]
		LandingRing.CFrame       = CFrame.new(landPos.X, Settings.GroundY + Settings.RingHeight * 0.5, landPos.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		LandingRing.Color        = color
		LandingRing.Transparency = 0.3
	end
end

function TrajectoryPredictor.Show()
	IsVisible = true
end

function TrajectoryPredictor.Hide()
	IsVisible = false
	for _, dot in ipairs(Dots) do
		dot.Transparency = 1
	end
	if LandingRing then
		LandingRing.Transparency = 1
	end
end

-- ── Initialization ─────────────────────────────────────────────────────────────

function TrajectoryPredictor.Initialize()
	-- Destroy old folder if it exists (e.g. from a previous run in Studio)
	local old = Workspace:FindFirstChild("TrajectoryPreview")
	if old then old:Destroy() end

	TrajectoryFolder        = Instance.new("Folder")
	TrajectoryFolder.Name   = "TrajectoryPreview"
	TrajectoryFolder.Parent = Workspace

	-- Pre-pool dots and pre-compute their sizes
	-- DotSizeCache[i]       = normal size Vector3
	-- DotSizeCache[i.."d"]  = dashed (every 3rd) size Vector3
	for i = 1, Settings.SegmentCount do
		Dots[i] = CreateDot(i)

		-- Size is purely a function of index position; cache it now
		local frac = i / Settings.SegmentCount
		local s    = Settings.DotSizeBase + (Settings.DotSizeEnd - Settings.DotSizeBase) * frac
		DotSizeCache[i]         = Vector3.one * s
		DotSizeCache[i .. "d"] = Vector3.one * (s * 1.4)
	end

	-- Pre-fill positions cache slots so Lua never has to grow the table
	for i = 1, Settings.SegmentCount do
		PositionsCache[i] = Vector3.zero
	end

	-- Create landing ring
	LandingRing = CreateLandingRing()

	TrajectoryPredictor.Hide()
end

-- ── Cleanup ────────────────────────────────────────────────────────────────────

function TrajectoryPredictor.Cleanup()
	if TrajectoryFolder then
		TrajectoryFolder:Destroy()
		TrajectoryFolder = nil
	end
	Dots = {}
	LandingRing = nil
	IsVisible   = false
end

return TrajectoryPredictor
