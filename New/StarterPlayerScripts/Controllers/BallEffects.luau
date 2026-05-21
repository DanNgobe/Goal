--[[
	BallEffects.luau
	Handles visual effects for the ball: trail when moving fast, and
	impact particle burst on sharp velocity changes.

	Public API:
	- Initialize()
]]

local BallEffects = {}

-- Services
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Logger
local Utils  = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("BallEffects")

-- ── Constants ──────────────────────────────────────────────────────────────────
local TRAIL_MIN_SPEED  = 30   -- studs/s: threshold to enable trail
local TRAIL_LIFETIME   = 0.4
local IMPACT_MIN_SPEED = 20   -- studs/s: minimum speed to register an impact
local IMPACT_DELTA     = 20   -- studs/s: minimum speed delta to trigger burst

-- ── Private State ──────────────────────────────────────────────────────────────
local Ball              = nil
local BallTrail         = nil
local RenderConnection  = nil
local PrevSpeed         = 0   -- Speed recorded on previous frame

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function CreateTrail()
	-- Attachment endpoints placed on the ball
	local att0 = Instance.new("Attachment")
	att0.Name   = "TrailAttachment0"
	att0.Parent = Ball

	local att1 = Instance.new("Attachment")
	att1.Name   = "TrailAttachment1"
	att1.Parent = Ball

	-- Trail instance
	local trail = Instance.new("Trail")
	trail.Name        = "BallTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1

	-- Timing / rendering
	trail.Lifetime    = TRAIL_LIFETIME
	trail.FaceCamera  = true
	trail.MinLength   = 0.05

	-- Appearance: white → light blue
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 220, 255)),
	})

	-- Transparency: fully opaque at head → fully transparent at tail
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- Neon-like emission
	trail.LightEmission  = 0.5
	trail.LightInfluence = 0.5

	-- Starts disabled; enabled dynamically in the update loop
	trail.Enabled = false
	trail.Parent  = Ball

	return trail
end

local function EmitImpactBurst(position)
	-- Temporary invisible anchored part at the impact location
	local tempPart           = Instance.new("Part")
	tempPart.Size            = Vector3.new(0.1, 0.1, 0.1)
	tempPart.Position        = position
	tempPart.Anchored        = true
	tempPart.CanCollide      = false
	tempPart.Transparency    = 1
	tempPart.Parent          = workspace

	-- Particle emitter: white neon burst
	local emitter              = Instance.new("ParticleEmitter")
	emitter.Lifetime           = NumberRange.new(0.1, 0.3)
	emitter.Rate               = 0   -- burst-only, driven by Emit()
	emitter.Color              = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.LightEmission      = 1
	emitter.SpreadAngle        = Vector2.new(180, 180)
	emitter.Size               = NumberSequence.new(0.3)
	emitter.Speed              = NumberRange.new(8, 20)
	emitter.Parent             = tempPart

	-- Fire burst of 15 particles immediately
	emitter:Emit(15)

	-- Auto-destroy after 1 second
	Debris:AddItem(tempPart, 1)
end

-- ── RenderStepped Update ───────────────────────────────────────────────────────

local function OnRenderStepped()
	if not Ball or not Ball.Parent then return end

	local velocity  = Ball.AssemblyLinearVelocity
	local speed     = velocity.Magnitude

	-- ── Trail toggling ──────────────────────────────────────────────────────
	BallTrail.Enabled = speed >= TRAIL_MIN_SPEED

	-- ── Impact detection ────────────────────────────────────────────────────
	-- Sharp velocity change while moving fast enough → emit burst
	if speed >= IMPACT_MIN_SPEED and math.abs(speed - PrevSpeed) > IMPACT_DELTA then
		EmitImpactBurst(Ball.Position)
	end

	PrevSpeed = speed
end

-- ── Public API ─────────────────────────────────────────────────────────────────

function BallEffects.Initialize()
	Logger:info("Initializing BallEffects...")

	-- Wait up to 10 s for the ball to appear in workspace
	Ball = workspace:WaitForChild("Ball", 10)
	if not Ball then
		Logger:warn("Ball not found in workspace — BallEffects disabled.")
		return false
	end

	-- Build trail
	BallTrail = CreateTrail()

	-- Start per-frame update loop
	if RenderConnection then
		RenderConnection:Disconnect()
	end
	RenderConnection = RunService.RenderStepped:Connect(OnRenderStepped)

	Logger:info("BallEffects initialized.")
	return true
end

return BallEffects
