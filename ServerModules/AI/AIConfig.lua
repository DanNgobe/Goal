--[[
  AIConfig.lua
  
  Centralized configuration for tunable AI parameters.
  All constants and thresholds for the Soccer AI System.
  
  Adjust these values during playtesting to tune AI difficulty and behavior.
]]

local AIConfig = {
  -- Update Timing
  -- How often each NPC's decision state is updated
  UPDATE_INTERVAL = 0.5,  -- seconds between decision updates per NPC
  
  -- Frame offset between odd/even NPC updates for load distribution
  STAGGER_OFFSET = 15,    -- frames between odd/even updates (at 30 FPS = 0.5s)
  
  
  -- Distance Thresholds (in studs)
  -- Maximum distance for NPC to consider pursuing loose ball
  BALL_PURSUIT_RANGE = 20,
  
  -- Distance at which NPC applies pressure to opponent with ball
  PRESSURE_RANGE = 10,
  
  -- Distance NPC must maintain from ball while dribbling
  BALL_CONTROL_RANGE = 3,
  
  -- Distance threshold to consider NPC "arrived" at target position
  POSITION_ARRIVAL_THRESHOLD = 3,
  
  -- Radius to detect NPC clustering (too many NPCs too close)
  CLUSTERING_RADIUS = 10,
  
  
  -- Shooting Parameters
  -- Maximum distance from goal to consider shooting
  MAX_SHOT_DISTANCE = 30,
  
  -- Optimal distance for highest shot score
  OPTIMAL_SHOT_DISTANCE = 15,
  
  -- Minimum shooting angle (degrees) - narrower angles discouraged
  MIN_SHOT_ANGLE = 15,
  
  
  -- Passing Parameters
  -- Maximum distance for passing to teammate
  MAX_PASS_DISTANCE = 40,
  
  -- Optimal passing distance for highest pass score
  OPTIMAL_PASS_DISTANCE = 20,
  
  -- Width of passing lane to check for blocking opponents
  PASS_LANE_WIDTH = 3,
  
  
  -- Movement Speeds (studs per second)
  -- Speed when chasing ball or urgent movement
  SPRINT_SPEED = 20,
  
  -- Normal movement speed
  JOG_SPEED = 16,
  
  -- Slow movement for positioning adjustments
  WALK_SPEED = 10,
  
  
  -- Goalkeeper Specific
  -- Maximum distance GK can move from goal center
  GK_MAX_RANGE = 15,
  
  -- Distance from goal at which GK reacts to ball
  GK_REACTION_DISTANCE = 40,
  
  
  -- Formation Adjustments (in studs)
  -- How far forward to push attackers in Attacking formation
  ATTACKING_FORWARD_OFFSET = 10,
  
  -- How far back to pull players in Defensive formation
  DEFENSIVE_BACK_OFFSET = 15,
  
  
  -- Performance Optimization
  -- Maximum waypoints in pathfinding to limit computation
  MAX_PATHFINDING_WAYPOINTS = 5,
  
  -- How far ahead to predict ball position (seconds)
  PREDICTION_TIME_AHEAD = 1.0,
  
  
  -- Debugging
  -- Enable debug logging and visualization
  DEBUG_MODE = false,
  
  -- Log decision changes to console
  LOG_DECISIONS = false,
}

return AIConfig
