--[[
	BallConfig.lua
	Shared constants for ball physics and kick mechanics.
	Used by BallManager (server) and BallController + TrajectoryPredictor (client).
	
	NOTE: Player speed / stamina constants live in StaminaController.lua on the client.
	      Only ball-related values belong here.
]]

return {
	-- Possession
	Touch_Cooldown         = 0.5,    -- Seconds between re-possession attempts per character
	Possession_Timeout     = 0.5,    -- Seconds another player must wait before stealing
	Max_Possession_Speed   = 50,     -- Ball moving faster than this cannot be possessed

	-- Attachment / Dribble
	Dribble_ForwardOffset  = 3.25,   -- Studs in front of HumanoidRootPart
	Dribble_VerticalOffset = -5,     -- Drop below root so ball sits at foot level
	Axle_SpinRate          = 2,      -- Multiplier: speed * rate = HingeConstraint.AngularVelocity

	-- Kick – Ground
	Ground_Kick_Max        = 65,     -- Max horizontal force (bumped from 55)
	Ground_Kick_Height     = 15,     -- Max upward force

	-- Kick – Air (RMB)
	Air_Kick_Max           = 75,     -- Max horizontal force (bumped from 65)
	Air_Kick_Height        = 65,     -- Max upward force

	-- BodyVelocity kick duration
	Kick_Velocity_Duration = 0.2,    -- Seconds the BodyVelocity lasts
	Kick_Touch_Block       = 0.3,    -- Seconds CanTouch is disabled after kick
	Kick_Freeze_Duration   = 0.2,    -- Seconds to freeze the kicker's RootPart

	-- Physics
	Damping                = 0.98,   -- Applied per Heartbeat when ball is loose
	Reset_Height           = -10,    -- Y below which ball is reset to center
}
