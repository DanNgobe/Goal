--[[
	BallEffects.lua
	Handles visual effects for the ball (trail, impact particles)
]]

local BallEffects = {}

-- Services
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- Private variables
local Ball = nil
local TrailAttachment0 = nil
local TrailAttachment1 = nil
local BallTrail = nil
local LastBallPosition = nil
local LastBallVelocity = Vector3.new(0, 0, 0)
local UpdateConnection = nil

-- Settings
local Settings = {
	TrailMinSpeed = 30, -- Minimum speed to show trail
	TrailLifetime = 0.4,
	ImpactMinSpeed = 20, -- Minimum speed for impact particles
	ImpactCooldown = 0.1,
}

local LastImpactTime = 0

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function BallEffects.Initialize()
	Ball = workspace:WaitForChild("Ball", 10)
	if not Ball then
		warn("[BallEffects] Ball not found in workspace!")
		return false
	end
	
	-- Create trail attachments
	CreateTrail()
	
	-- Start update loop
	StartUpdateLoop()
	
	return true
end

--------------------------------------------------------------------------------
-- TRAIL EFFECT
--------------------------------------------------------------------------------

function CreateTrail()
	-- Create attachments for trail
	TrailAttachment0 = Instance.new("Attachment")
	TrailAttachment0.Name = "TrailAttachment0"
	TrailAttachment0.Parent = Ball
	
	TrailAttachment1 = Instance.new("Attachment")
	TrailAttachment1.Name = "TrailAttachment1"
	TrailAttachment1.Parent = Ball
	
	-- Create trail
	BallTrail = Instance.new("Trail")
	BallTrail.Name = "BallTrail"
	BallTrail.Attachment0 = TrailAttachment0
	BallTrail.Attachment1 = TrailAttachment1
	BallTrail.Lifetime = Settings.TrailLifetime
	BallTrail.MinLength = 0.1
	BallTrail.FaceCamera = true
	BallTrail.Enabled = false
	
	-- Trail appearance
	BallTrail.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 255))
	}
	BallTrail.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	}
	BallTrail.WidthScale = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2)
	}
	BallTrail.LightEmission = 0.5
	BallTrail.Texture = "rbxasset://textures/particles/smoke_main.dds"
	
	BallTrail.Parent = Ball
end

function UpdateTrail()
	if not Ball or not Ball.Parent then return end
	
	local velocity = Ball.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	
	-- Enable trail if ball is moving fast enough
	if speed >= Settings.TrailMinSpeed then
		if not BallTrail.Enabled then
			BallTrail.Enabled = true
		end
		
		-- Adjust trail width based on speed (faster = wider trail)
		local widthMultiplier = math.clamp(speed / 100, 0.5, 2)
		BallTrail.WidthScale = NumberSequence.new{
			NumberSequenceKeypoint.new(0, widthMultiplier),
			NumberSequenceKeypoint.new(1, widthMultiplier * 0.2)
		}
	else
		if BallTrail.Enabled then
			BallTrail.Enabled = false
		end
	end
end

--------------------------------------------------------------------------------
-- IMPACT PARTICLES
--------------------------------------------------------------------------------

function CheckForImpact()
	if not Ball or not Ball.Parent then return end
	
	local currentPos = Ball.Position
	local currentVelocity = Ball.AssemblyLinearVelocity
	local speed = currentVelocity.Magnitude
	
	-- Check if ball hit something (sudden velocity change)
	if LastBallPosition and LastBallVelocity then
		local velocityChange = (currentVelocity - LastBallVelocity).Magnitude
		
		-- Impact detected if velocity changed significantly and moving fast enough
		if velocityChange > 20 and speed >= Settings.ImpactMinSpeed then
			local currentTime = tick()
			if currentTime - LastImpactTime >= Settings.ImpactCooldown then
				CreateImpactEffect(currentPos, currentVelocity)
				LastImpactTime = currentTime
			end
		end
	end
	
	LastBallPosition = currentPos
	LastBallVelocity = currentVelocity
end

function CreateImpactEffect(position, velocity)
	-- Create impact particle emitter
	local impactPart = Instance.new("Part")
	impactPart.Size = Vector3.new(0.1, 0.1, 0.1)
	impactPart.Position = position
	impactPart.Anchored = true
	impactPart.CanCollide = false
	impactPart.Transparency = 1
	impactPart.Parent = workspace
	
	-- Particle emitter
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "ImpactParticles"
	
	-- Particle properties
	particles.Lifetime = NumberRange.new(0.2, 0.4)
	particles.Rate = 0
	particles.Speed = NumberRange.new(10, 20)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rotation = NumberRange.new(0, 360)
	particles.RotSpeed = NumberRange.new(-200, 200)
	
	particles.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	}
	
	particles.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	}
	
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	particles.LightEmission = 0.3
	particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
	
	particles.Parent = impactPart
	
	-- Emit burst
	particles:Emit(15)
	
	-- Cleanup
	Debris:AddItem(impactPart, 1)
end

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function StartUpdateLoop()
	if UpdateConnection then
		UpdateConnection:Disconnect()
	end
	
	UpdateConnection = RunService.RenderStepped:Connect(function()
		UpdateTrail()
		CheckForImpact()
	end)
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function BallEffects.Cleanup()
	if UpdateConnection then
		UpdateConnection:Disconnect()
		UpdateConnection = nil
	end
	
	if BallTrail then
		BallTrail:Destroy()
	end
	
	if TrailAttachment0 then
		TrailAttachment0:Destroy()
	end
	
	if TrailAttachment1 then
		TrailAttachment1:Destroy()
	end
end

return BallEffects
