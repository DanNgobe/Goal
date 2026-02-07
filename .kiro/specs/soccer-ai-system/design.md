# Design Document: Soccer AI System

## Overview

The Soccer AI System provides intelligent, tactical control for NPCs in a 5v5 Roblox soccer game. The system is designed with a modular architecture that separates decision-making from action execution, enabling maintainable and testable AI behavior.

The AI operates on a perception-decision-action cycle:
1. **Perception**: Gather game state (ball position, NPC positions, possession, formation)
2. **Decision**: Evaluate tactical options and select optimal action
3. **Action**: Execute the chosen behavior through existing game systems

The system integrates with existing managers (BallManager, TeamManager, NPCManager, FormationData) and handles all 10 NPCs simultaneously while maintaining performance above 30 FPS.

## Architecture

### High-Level Structure

```
ServerModules/AI/
├── AIController.lua          -- Main coordinator, manages AI lifecycle
├── DecisionEngine.lua        -- Base decision-making logic for all NPCs
├── GoalkeeperDecisionEngine.lua  -- Specialized GK decision logic (inherits from DecisionEngine)
├── BehaviorController.lua    -- Action execution (movement, passing, shooting)
├── PositionCalculator.lua    -- Formation-based position calculation
├── BallPredictor.lua         -- Ball trajectory and landing prediction
├── TeamCoordinator.lua       -- Multi-NPC coordination logic
└── AIConfig.lua              -- Tunable parameters and constants
```

**Note**: Goalkeepers use a specialized decision engine that inherits from the base DecisionEngine. This allows GKs to share common logic (movement, ball awareness) while overriding specific behaviors (positioning, shot reactions, distribution preferences).


### Component Responsibilities

**AIController**
- Manages AI activation/deactivation for each NPC based on possession state
- Coordinates update cycles across all AI-controlled NPCs
- Provides interface for formation switching
- Staggers decision updates to distribute computational load

**DecisionEngine**
- Base decision-making logic for all NPCs (outfield players and goalkeepers)
- Evaluates current game state for a single NPC
- Maintains decision state machine (Idle, Positioning, Pursuing, Attacking, Defending)
- Selects optimal action based on role, position, and tactical state
- Scores potential actions (pass, shoot, dribble, defend) and selects highest-scoring option

**GoalkeeperDecisionEngine**
- Inherits from DecisionEngine, specializes behavior for goalkeepers
- Overrides positioning logic to stay near goal
- Overrides pursuit logic to be more conservative
- Adds shot reaction and ball collection behaviors
- Prioritizes distribution (passing to defenders) over dribbling

**BehaviorController**
- Executes movement commands using NPC_Manager
- Executes ball actions (pass, shoot, kick) using Ball_Manager
- Handles pathfinding and obstacle avoidance
- Implements position-holding behavior when at target location

**PositionCalculator**
- Calculates target positions based on formation and tactical state
- Adjusts positions dynamically based on ball location
- Implements role-specific positioning logic (GK, DF, LW, RW, ST)
- Provides smooth position transitions when formation changes

**BallPredictor**
- Predicts ball position N seconds ahead based on velocity
- Calculates landing position for airborne balls
- Identifies interception opportunities
- Estimates pass arrival times and locations

**TeamCoordinator**
- Prevents multiple NPCs from pursuing the same ball
- Ensures proper spacing between teammates
- Coordinates attacking runs and defensive coverage
- Manages role assignments during transitions



### Update Cycle

The AI operates on a staggered update cycle to maintain performance:

```
Frame N:
  - AIController checks for possession changes
  - Update NPCs 1, 3, 5, 7, 9 (odd indices)
  
Frame N+15 (0.5 seconds at 30 FPS):
  - Update NPCs 2, 4, 6, 8, 10 (even indices)
  
For each NPC update:
  1. Gather perception data (ball state, nearby players, own position)
  2. DecisionEngine evaluates and selects action
  3. BehaviorController executes action
  4. Update decision state for debugging
```

This staggered approach ensures:
- Maximum 5 NPCs updated per frame
- Each NPC updated every 0.5 seconds
- Consistent frame time distribution

### State Machine

Each NPC maintains a decision state:

```
States:
- Idle: No specific action, maintaining formation position
- Positioning: Moving to target formation position
- Pursuing: Chasing loose ball or moving to intercept
- Attacking: Has possession, evaluating pass/shoot/dribble
- Defending: Pressuring opponent or marking space

Transitions:
- Any → Attacking: NPC gains possession
- Attacking → Positioning: NPC loses possession
- Positioning → Pursuing: Ball becomes loose nearby
- Pursuing → Defending: Opponent gains possession
- Defending → Pursuing: Ball becomes loose
- Any → Idle: No immediate action required
```



## Components and Interfaces

### AIController

**Purpose**: Main coordinator managing AI lifecycle and update scheduling

**Interface**:
```lua
AIController = {}

-- Initialize the AI system
function AIController:Initialize(npcManager, ballManager, teamManager, formationSystem)
  -- Store references to game systems
  -- Set up update scheduling
  -- Initialize sub-components
end

-- Called every frame by GameManager
function AIController:Update(deltaTime)
  -- Check for possession changes
  -- Update scheduled NPCs this frame
  -- Handle formation transitions
end

-- Enable AI control for specific NPC
function AIController:EnableAI(npc)
  -- Add NPC to controlled list
  -- Initialize decision state
end

-- Disable AI control (human takes over)
function AIController:DisableAI(npc)
  -- Remove from controlled list
  -- Clear decision state
end

-- Change tactical formation
function AIController:SetFormation(teamName, formationType)
  -- Update formation state
  -- Trigger position recalculation
end

-- Get current decision state for debugging
function AIController:GetDecisionState(npc)
  -- Return current state, action, target
end
```

**Internal State**:
- `controlledNPCs`: Array of NPCs currently under AI control
- `updateSchedule`: Which NPCs to update this frame
- `frameCounter`: Used for staggered updates
- `decisionStates`: Map of NPC → current decision state



### DecisionEngine

**Purpose**: Base decision-making logic for all NPCs (outfield players and goalkeepers)

**Interface**:
```lua
DecisionEngine = {}

-- Create new decision engine instance
function DecisionEngine.new()
  local self = setmetatable({}, {__index = DecisionEngine})
  return self
end

-- Evaluate and return best action for NPC (can be overridden by subclasses)
function DecisionEngine:Decide(npc, gameState, decisionState)
  -- Returns: { action = "Pass"|"Shoot"|"Dribble"|"Pursue"|"Defend"|"Position", 
  --           target = Vector3 or NPC,
  --           priority = number }
end

-- Score a potential pass to teammate
function DecisionEngine:ScorePass(npc, teammate, gameState)
  -- Returns: score (0-100)
end

-- Score a potential shot on goal
function DecisionEngine:ScoreShot(npc, gameState)
  -- Returns: score (0-100)
end

-- Determine if NPC should pursue ball
function DecisionEngine:ShouldPursue(npc, gameState, teamCoordinator)
  -- Returns: boolean
end

-- Select defensive target (opponent to mark or space to cover)
function DecisionEngine:SelectDefensiveTarget(npc, gameState)
  -- Returns: target (NPC or Vector3)
end
```

### GoalkeeperDecisionEngine

**Purpose**: Specialized decision-making for goalkeepers, inherits from DecisionEngine

**Interface**:
```lua
GoalkeeperDecisionEngine = {}
setmetatable(GoalkeeperDecisionEngine, {__index = DecisionEngine})

-- Create new goalkeeper decision engine
function GoalkeeperDecisionEngine.new()
  local self = DecisionEngine.new()
  setmetatable(self, {__index = GoalkeeperDecisionEngine})
  return self
end

-- Override: GK-specific decision logic
function GoalkeeperDecisionEngine:Decide(npc, gameState, decisionState)
  -- Check for shot reactions first
  if self:IsShotIncoming(gameState) then
    return self:ReactToShot(npc, gameState)
  end
  
  -- Check for ball collection opportunities
  if self:CanCollectBall(npc, gameState) then
    return {action = "Pursue", target = gameState.ball.position, priority = 90}
  end
  
  -- Default to positioning between ball and goal
  return {action = "Position", target = self:GetGoalkeeperPosition(npc, gameState), priority = 50}
end

-- Override: GK should be more conservative about pursuing
function GoalkeeperDecisionEngine:ShouldPursue(npc, gameState, teamCoordinator)
  local ballDistance = (gameState.ball.position - npc.Position).Magnitude
  -- Only pursue if very close and no opponents nearby
  return ballDistance < 10 and not self:AreOpponentsNearby(npc, gameState, 15)
end

-- Override: GK prioritizes passing to defenders
function GoalkeeperDecisionEngine:ScorePass(npc, teammate, gameState)
  local baseScore = DecisionEngine.ScorePass(self, npc, teammate, gameState)
  
  -- Boost score for passes to defenders
  if teammate.Role == "DF" then
    baseScore = baseScore * 1.5
  end
  
  return math.min(baseScore, 100)
end

-- GK-specific: Check if shot is incoming
function GoalkeeperDecisionEngine:IsShotIncoming(gameState)
  -- Check ball velocity toward goal
end

-- GK-specific: React to incoming shot
function GoalkeeperDecisionEngine:ReactToShot(npc, gameState)
  -- Calculate interception point
end

-- GK-specific: Calculate GK position between ball and goal
function GoalkeeperDecisionEngine:GetGoalkeeperPosition(npc, gameState)
  -- Position between ball and goal center
end
```

**Inheritance Benefits**:
- Goalkeepers share common logic: ball awareness, movement, basic decision-making
- GK-specific behaviors override base methods: positioning, pursuit, distribution
- Reduces code duplication while allowing specialization
- Easy to add more specialized roles in the future (e.g., specialized striker AI)

**Decision Scoring Logic**:

Pass scoring considers:
- Distance to teammate (closer = better, up to optimal range)
- Teammate's position relative to goal (forward progress)
- Opponent proximity to passing lane (clear lane = better)
- Teammate's readiness to receive (facing ball, not marked)

Shot scoring considers:
- Distance to goal (closer = better, optimal 10-20 studs)
- Angle to goal (wider angle = better)
- Goalkeeper position (shot away from GK = better)
- Clear line of sight (no defenders blocking)

Pursuit decision considers:
- Distance to ball (closer = more likely)
- Current role (attackers more aggressive)
- Team coordination (only one pursuer)
- Ball trajectory (moving toward or away)



### BehaviorController

**Purpose**: Executes actions determined by DecisionEngine

**Interface**:
```lua
BehaviorController = {}

-- Move NPC to target position
function BehaviorController:MoveTo(npc, targetPosition, urgency)
  -- Use NPC_Manager to set movement
  -- Apply pathfinding if obstacles present
  -- Adjust speed based on urgency
end

-- Execute a pass to teammate
function BehaviorController:Pass(npc, targetNPC, gameState)
  -- Calculate pass power and direction
  -- Use Ball_Manager kick system
  -- Aim slightly ahead of moving target
end

-- Execute a shot on goal
function BehaviorController:Shoot(npc, gameState)
  -- Calculate shot power and aim point
  -- Consider goalkeeper position
  -- Use Ball_Manager kick system
end

-- Dribble ball forward
function BehaviorController:Dribble(npc, direction, gameState)
  -- Move toward direction while maintaining ball control
  -- Keep within 3 studs of ball
  -- Adjust for obstacles
end

-- Apply defensive pressure to opponent
function BehaviorController:Pressure(npc, targetNPC)
  -- Move to within 3 studs of target
  -- Position between target and goal
end

-- Maintain position (small adjustments)
function BehaviorController:HoldPosition(npc, targetPosition)
  -- Reduce speed when within 3 studs
  -- Make small corrective movements
end
```

**Pathfinding**:
- Use simplified raycasting to detect obstacles
- Generate waypoints around obstacles (max 5 waypoints)
- Prefer direct paths when clear
- Avoid other NPCs by steering around them



### PositionCalculator

**Purpose**: Calculates target positions based on formation and game state

**Interface**:
```lua
PositionCalculator = {}

-- Calculate target position for NPC based on formation
function PositionCalculator:GetTargetPosition(npc, formation, tacticalState, ballPosition)
  -- Returns: Vector3 target position
end

-- Get base formation position for role
function PositionCalculator:GetFormationPosition(role, formation, teamSide)
  -- Returns: Vector3 base position from FormationData
end

-- Adjust position based on ball location
function PositionCalculator:AdjustForBall(basePosition, ballPosition, role, tacticalState)
  -- Returns: Vector3 adjusted position
end

-- Calculate goalkeeper position
function PositionCalculator:GetGoalkeeperPosition(goalCenter, ballPosition)
  -- Returns: Vector3 position between ball and goal
end
```

**Position Calculation Logic**:

Base positions come from FormationData (Neutral, Attacking, Defensive).

Dynamic adjustments:
- **Ball in defensive third**: Pull all players back slightly (except when Attacking formation)
- **Ball in attacking third**: Push forwards up (LW, RW, ST)
- **Ball on left side**: LW pushes up, RW holds width
- **Ball on right side**: RW pushes up, LW holds width

Role-specific adjustments:
- **GK**: Always between ball and goal center when ball in defensive half
- **DF**: Maintain defensive line, shift with ball laterally
- **LW/RW**: Maintain width (stay near sidelines), push up when ball advances
- **ST**: Most aggressive forward positioning, lead attacks

Tactical state modifiers:
- **Attacking**: +10 studs forward for LW, RW, ST
- **Defensive**: -15 studs back for all non-GK players
- **Neutral**: Use base formation positions



### BallPredictor

**Purpose**: Predicts ball movement for interception and positioning

**Interface**:
```lua
BallPredictor = {}

-- Predict ball position after time interval
function BallPredictor:PredictPosition(ball, timeAhead)
  -- Returns: Vector3 predicted position
end

-- Calculate where airborne ball will land
function BallPredictor:PredictLanding(ball)
  -- Returns: Vector3 landing position, number timeToLand
end

-- Check if NPC can intercept ball trajectory
function BallPredictor:CanIntercept(npc, ball, timeWindow)
  -- Returns: boolean, Vector3 interceptionPoint
end

-- Estimate when/where pass will arrive
function BallPredictor:PredictPassArrival(fromPosition, toPosition, passSpeed)
  -- Returns: Vector3 arrivalPosition, number arrivalTime
end
```

**Prediction Algorithm**:

For moving ball:
```
predictedPosition = currentPosition + (velocity * timeAhead)
-- Apply simple drag factor
dragFactor = 0.95 ^ timeAhead
predictedPosition = currentPosition + (velocity * timeAhead * dragFactor)
```

For airborne ball:
```
-- Use kinematic equation with gravity
gravity = workspace.Gravity
timeToLand = (velocity.Y + sqrt(velocity.Y^2 + 2 * gravity * height)) / gravity
landingX = currentX + velocityX * timeToLand
landingZ = currentZ + velocityZ * timeToLand
```

For interception:
```
-- Check if NPC can reach predicted position before ball
npcSpeed = 16 -- studs/second (Humanoid WalkSpeed)
distanceToIntercept = (npcPosition - predictedBallPosition).Magnitude
timeToReach = distanceToIntercept / npcSpeed
canIntercept = timeToReach < timeForBallToReach
```



### TeamCoordinator

**Purpose**: Manages multi-NPC coordination to prevent conflicts

**Interface**:
```lua
TeamCoordinator = {}

-- Designate which NPC should pursue ball
function TeamCoordinator:AssignBallPursuer(team, ballPosition)
  -- Returns: NPC that should pursue, or nil
end

-- Check if too many NPCs are clustered
function TeamCoordinator:CheckClustering(team, position, radius)
  -- Returns: number of NPCs in radius
end

-- Get NPCs available for passing
function TeamCoordinator:GetPassingOptions(npc, team, gameState)
  -- Returns: array of {npc, score} sorted by score
end

-- Ensure defensive coverage
function TeamCoordinator:AssignDefensiveRoles(team, opponentPositions)
  -- Returns: map of NPC → defensive assignment
end

-- Position support players for attack
function TeamCoordinator:PositionSupportPlayers(attackerNPC, team)
  -- Returns: map of NPC → support position
end
```

**Coordination Rules**:

Ball pursuit:
- Only one NPC per team pursues loose ball
- Closest NPC to ball gets priority
- If pursuer is GK, next closest field player also pursues
- Re-evaluate every 1 second or when ball changes direction

Spacing:
- Prevent more than 3 NPCs within 10 studs
- If clustering detected, push excess NPCs to formation positions
- Maintain minimum 8 studs between LW and RW

Defensive coverage:
- Always keep one DF between ball and goal
- Assign closest DF to pressure ball carrier
- Other DFs mark dangerous opponents or cover space
- GK never leaves goal area to pursue unless ball very close

Attacking support:
- When ST has ball, LW and RW position wide
- When LW has ball, ST and RW move to receive
- When DF has ball, at least one midfielder shows for pass



### AIConfig

**Purpose**: Centralized configuration for tunable AI parameters

**Structure**:
```lua
AIConfig = {
  -- Update timing
  UPDATE_INTERVAL = 0.5,  -- seconds between decision updates
  STAGGER_OFFSET = 15,    -- frames between odd/even updates
  
  -- Distance thresholds
  BALL_PURSUIT_RANGE = 20,      -- studs
  PRESSURE_RANGE = 10,           -- studs
  BALL_CONTROL_RANGE = 3,        -- studs
  POSITION_ARRIVAL_THRESHOLD = 3, -- studs
  CLUSTERING_RADIUS = 10,        -- studs
  
  -- Shooting parameters
  MAX_SHOT_DISTANCE = 30,        -- studs
  OPTIMAL_SHOT_DISTANCE = 15,    -- studs
  MIN_SHOT_ANGLE = 15,           -- degrees
  
  -- Passing parameters
  MAX_PASS_DISTANCE = 40,        -- studs
  OPTIMAL_PASS_DISTANCE = 20,    -- studs
  PASS_LANE_WIDTH = 3,           -- studs
  
  -- Movement speeds
  SPRINT_SPEED = 20,             -- studs/second
  JOG_SPEED = 16,                -- studs/second
  WALK_SPEED = 10,               -- studs/second
  
  -- Goalkeeper specific
  GK_MAX_RANGE = 15,             -- studs from goal
  GK_REACTION_DISTANCE = 40,     -- studs to react to ball
  
  -- Formation adjustments
  ATTACKING_FORWARD_OFFSET = 10,  -- studs
  DEFENSIVE_BACK_OFFSET = 15,     -- studs
  
  -- Performance
  MAX_PATHFINDING_WAYPOINTS = 5,
  PREDICTION_TIME_AHEAD = 1.0,    -- seconds
  
  -- Debugging
  DEBUG_MODE = false,
  LOG_DECISIONS = false,
}
```

These values can be tuned during playtesting to adjust AI difficulty and behavior.



## Data Models

### DecisionState

Represents the current decision state of an AI-controlled NPC.

```lua
DecisionState = {
  npc = NPC,                    -- Reference to the NPC
  state = "Idle",               -- Current state: Idle, Positioning, Pursuing, Attacking, Defending
  action = "Position",          -- Current action: Pass, Shoot, Dribble, Pursue, Defend, Position
  target = Vector3 or NPC,      -- Target of current action
  priority = 50,                -- Priority score (0-100)
  lastUpdate = tick(),          -- Timestamp of last decision update
  transitionReason = "",        -- Why state changed (for debugging)
}
```

### GameState

Snapshot of relevant game state for decision-making.

```lua
GameState = {
  ball = {
    position = Vector3,
    velocity = Vector3,
    isLoose = boolean,
    possessor = NPC or nil,
  },
  
  ownTeam = {
    name = "Blue" or "Red",
    npcs = {NPC},
    formation = "Neutral" or "Attacking" or "Defensive",
    goalPosition = Vector3,
  },
  
  opponentTeam = {
    name = "Blue" or "Red",
    npcs = {NPC},
    formation = "Neutral" or "Attacking" or "Defensive",
    goalPosition = Vector3,
  },
  
  fieldBounds = {
    minX = number,
    maxX = number,
    minZ = number,
    maxZ = number,
  },
  
  timestamp = tick(),
}
```

### ActionScore

Represents a scored potential action.

```lua
ActionScore = {
  action = "Pass" or "Shoot" or "Dribble" or "Pursue" or "Defend" or "Position",
  target = Vector3 or NPC or nil,
  score = number,              -- 0-100
  reasoning = string,          -- Why this score (for debugging)
}
```



### PositionData

Represents a calculated target position with metadata.

```lua
PositionData = {
  position = Vector3,
  role = "GK" or "DF" or "LW" or "RW" or "ST",
  formation = "Neutral" or "Attacking" or "Defensive",
  adjustedForBall = boolean,
  priority = number,           -- How important to reach this position
}
```

### InterceptionData

Represents a potential ball interception opportunity.

```lua
InterceptionData = {
  canIntercept = boolean,
  interceptionPoint = Vector3,
  timeToIntercept = number,    -- seconds
  ballArrivalTime = number,    -- seconds
  confidence = number,         -- 0-100, how likely interception succeeds
}
```



## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: AI Control State Transitions

*For any* NPC, when possession state changes (human takes control or releases control), the AI control state should transition correctly within the specified time window: AI disabled when possessed, AI enabled when released.

**Validates: Requirements 1.1, 1.2, 1.3**

### Property 2: Movement Toward Target Position

*For any* AI-controlled NPC without possession, the NPC's movement direction should be toward its calculated Target_Position, and movement speed should decrease when within the arrival threshold.

**Validates: Requirements 2.1, 2.3**

### Property 3: Formation-Based Position Calculation

*For any* tactical state (Neutral, Attacking, Defensive) and role (GK, DF, LW, RW, ST), the calculated Target_Position should reflect the formation's tactical intent: Attacking pushes forwards up, Defensive pulls players back, Neutral uses base formation.

**Validates: Requirements 9.1, 9.2, 9.3, 9.4**


### Property 4: Pathfinding Obstacle Avoidance

*For any* NPC moving to a target position with obstacles in the direct path, the generated path should route around obstacles and contain at most the maximum allowed waypoints.

**Validates: Requirements 2.4, 10.3**

### Property 5: Goalkeeper Positioning Between Ball and Goal

*For any* ball position within reaction distance of the goal, the goalkeeper's target position should be between the ball and the goal center, and the goalkeeper should remain within maximum range of the goal.

**Validates: Requirements 2.5, 8.1, 8.3**

### Property 6: Single Ball Pursuer Coordination

*For any* loose ball situation with multiple NPCs on the same team within pursuit range, only one NPC should be designated as the pursuer while others maintain formation or support positions.

**Validates: Requirements 3.3, 14.1**

### Property 7: Ball Prediction for Interception

*For any* moving ball, the AI system should calculate predicted positions ahead in time, and interception decisions should use predicted positions rather than current positions.

**Validates: Requirements 13.1, 13.2, 13.5**

### Property 8: Airborne Ball Landing Prediction

*For any* airborne ball with upward or downward velocity, the system should calculate a landing position that accounts for gravity and horizontal velocity.

**Validates: Requirements 13.3**


### Property 9: Pass Scoring Factors

*For any* NPC with possession and potential passing targets, pass scores should increase with better positioning (clear passing lane, forward progress, optimal distance) and decrease with worse positioning (opponents blocking, poor angle, too far).

**Validates: Requirements 4.2, 4.4, 4.5**

### Property 10: Passing Under Pressure

*For any* NPC with possession and opponents within pressure range, passing actions should be prioritized over dribbling actions (higher scores).

**Validates: Requirements 4.5**

### Property 11: Shot Scoring Based on Position

*For any* NPC with possession in shooting range, shot scores should be higher when closer to goal (within optimal range), with wider shooting angles, and with clear lines to goal, and lower for narrow angles or distant positions.

**Validates: Requirements 5.2, 5.4**

### Property 12: Attacker Role Shooting Priority

*For any* NPC with an attacking role (ST, LW, RW) in possession within shooting range with a clear opportunity, shooting should be evaluated and prioritized appropriately.

**Validates: Requirements 5.1, 5.5**

### Property 13: Shot Aiming Considers Goalkeeper

*For any* shot execution, the aim direction should account for goalkeeper position, aiming away from the goalkeeper when possible.

**Validates: Requirements 5.3**


### Property 14: Dribbling as Fallback Action

*For any* NPC with possession when passing and shooting options score low, dribbling toward the opponent's goal should be selected as the action.

**Validates: Requirements 6.1**

### Property 15: Ball Control During Dribbling

*For any* NPC executing a dribble action, the NPC should maintain proximity to the ball (within control range) while moving toward the target direction.

**Validates: Requirements 6.2**

### Property 16: Boundary Awareness During Dribbling

*For any* NPC dribbling near field boundaries, the NPC should change direction or select an alternative action (pass) before going out of bounds.

**Validates: Requirements 6.4**

### Property 17: Role-Based Decision Priorities

*For any* defender (DF) with possession in the defensive third, passing actions should score higher than dribbling forward actions. For any goalkeeper with possession, passing to defenders should score higher than dribbling.

**Validates: Requirements 6.5, 8.4**

### Property 18: Defensive Pressure Assignment

*For any* opponent with possession, the closest defensive NPC should be assigned to apply pressure, and that NPC should move to within pressure range of the opponent.

**Validates: Requirements 7.1, 7.2**


### Property 19: Marking Positioning Between Threat and Goal

*For any* opponent without possession moving toward goal, defensive NPCs should position themselves between the opponent and the goal.

**Validates: Requirements 7.3**

### Property 20: Defensive Positioning Priority in Defensive Third

*For any* game state where the ball is in the defensive third, defenders (DF) and goalkeeper (GK) should prioritize defensive positioning over attacking positioning.

**Validates: Requirements 7.4**

### Property 21: Shot Blocking Positioning

*For any* opponent preparing to shoot (in shooting range with clear angle), nearby defenders should position themselves between the ball and goal to block the shot.

**Validates: Requirements 7.5**

### Property 22: Goalkeeper Shot Interception

*For any* shot trajectory toward goal, the goalkeeper should move toward the predicted ball trajectory to attempt interception.

**Validates: Requirements 8.2**

### Property 23: Goalkeeper Ball Collection in Goal Area

*For any* ball in the goal area with no nearby opponents, the goalkeeper should move to collect the ball.

**Validates: Requirements 8.5**


### Property 24: Tactical State Influences Decision Priorities

*For any* NPC in an Attacking tactical state, shooting and forward passing actions should receive higher priority scores compared to the same actions in Neutral or Defensive states.

**Validates: Requirements 9.5**

### Property 25: Decision State Storage and Retrieval

*For any* NPC making a decision, the decision state (action type, target, reasoning) should be stored and retrievable through the query interface.

**Validates: Requirements 12.1, 12.3**

### Property 26: State Machine Valid States

*For any* NPC's decision state, the state value should be one of the valid states: Idle, Positioning, Pursuing, Attacking, or Defending.

**Validates: Requirements 12.5**

### Property 27: Transition Reason Recording

*For any* NPC transitioning between decision states, the transition reason should be recorded in the decision state.

**Validates: Requirements 12.4**

### Property 28: Pass Reception Movement

*For any* pass executed to a receiving NPC, the receiving NPC should move toward the predicted ball arrival position rather than the current ball position.

**Validates: Requirements 13.4**


### Property 29: Offensive Support Positioning

*For any* NPC with possession, at least two teammates should position themselves in viable passing lanes (not blocked by opponents, within passing range).

**Validates: Requirements 14.2**

### Property 30: Defensive Coverage Guarantee

*For any* game state when defending, at least one defender (DF) should be positioned between the ball and the goal.

**Validates: Requirements 14.3**

### Property 31: Attacking Width Maintenance

*For any* game state when attacking, the left wing (LW) and right wing (RW) should be positioned on opposite sides of the field to maintain attacking width.

**Validates: Requirements 14.4**

### Property 32: Anti-Clustering Spacing

*For any* team, no more than 3 NPCs should be clustered within the clustering radius of each other.

**Validates: Requirements 14.5**



## Error Handling

### Invalid Game State

**Scenario**: Game state data is incomplete or invalid (nil references, missing NPCs, invalid positions)

**Handling**:
- Validate game state before decision-making
- Use default/safe values for missing data
- Log warnings for invalid state
- Skip decision update for affected NPC until next cycle

**Example**:
```lua
if not gameState.ball or not gameState.ball.position then
  warn("Invalid ball state, skipping AI update")
  return
end
```

### NPC Reference Errors

**Scenario**: NPC reference becomes invalid (character destroyed, removed from game)

**Handling**:
- Check NPC validity before operations
- Remove invalid NPCs from controlled list
- Clean up associated decision states
- Gracefully handle mid-update invalidation

**Example**:
```lua
if not npc or not npc.Parent or not npc:FindFirstChild("Humanoid") then
  AIController:DisableAI(npc)
  return
end
```


### Manager Integration Failures

**Scenario**: Calls to BallManager, NPCManager, or TeamManager fail or return unexpected results

**Handling**:
- Wrap manager calls in pcall for error catching
- Provide fallback behavior when manager calls fail
- Log errors with context for debugging
- Continue AI operation for other NPCs

**Example**:
```lua
local success, result = pcall(function()
  return BallManager:KickBall(npc, direction, power)
end)

if not success then
  warn("Ball kick failed:", result)
  -- Fallback: try again next update
  return
end
```

### Pathfinding Failures

**Scenario**: Pathfinding cannot find valid path to target (blocked, unreachable)

**Handling**:
- Fall back to direct movement when pathfinding fails
- Reduce target position complexity (fewer waypoints)
- Select alternative target if original is unreachable
- Timeout pathfinding attempts after reasonable duration

**Example**:
```lua
local path = calculatePath(npc.Position, targetPosition)
if not path or #path == 0 then
  -- Direct movement fallback
  path = {targetPosition}
end
```

### Division by Zero and Math Errors

**Scenario**: Mathematical operations produce invalid results (division by zero, NaN, infinity)

**Handling**:
- Check for zero before division operations
- Validate vector magnitudes before normalization
- Clamp values to reasonable ranges
- Use safe math utilities

**Example**:
```lua
local function safeNormalize(vector)
  local magnitude = vector.Magnitude
  if magnitude < 0.001 then
    return Vector3.new(0, 0, 1)  -- Default forward direction
  end
  return vector / magnitude
end
```

### Performance Degradation

**Scenario**: AI system causes frame rate drops or performance issues

**Handling**:
- Monitor frame time and adjust update frequency
- Reduce decision complexity when performance drops
- Skip non-critical calculations under load
- Provide performance metrics for tuning

**Example**:
```lua
if deltaTime > 0.05 then  -- Frame took longer than 50ms
  -- Reduce update frequency
  AIConfig.UPDATE_INTERVAL = AIConfig.UPDATE_INTERVAL * 1.2
end
```



## Testing Strategy

### Dual Testing Approach

The AI system will be validated using both unit tests and property-based tests:

- **Unit tests**: Verify specific examples, edge cases, and integration points
- **Property tests**: Verify universal properties across randomized inputs

Both approaches are complementary and necessary for comprehensive coverage. Unit tests catch concrete bugs in specific scenarios, while property tests verify general correctness across a wide input space.

### Unit Testing Focus

Unit tests should focus on:

1. **Integration Points**
   - Verify AIController correctly calls BallManager methods
   - Verify BehaviorController uses NPCManager movement interface
   - Verify PositionCalculator uses FormationData correctly
   - Verify TeamCoordinator queries TeamManager appropriately

2. **Edge Cases**
   - Ball exactly at field boundary
   - NPC exactly at target position
   - Multiple NPCs equidistant from ball
   - Formation change during active dribble
   - Goalkeeper at maximum range limit

3. **Error Conditions**
   - Invalid NPC reference handling
   - Missing game state data
   - Manager call failures
   - Pathfinding failures
   - Division by zero scenarios

4. **State Transitions**
   - Idle → Pursuing transition
   - Attacking → Defending transition
   - Possession gain/loss handling
   - Formation change transitions

**Example Unit Test**:
```lua
describe("BehaviorController", function()
  it("should call BallManager.KickBall when executing pass", function()
    local mockBallManager = createMockBallManager()
    local controller = BehaviorController.new(mockBallManager)
    
    controller:Pass(testNPC, targetNPC, gameState)
    
    expect(mockBallManager.KickBall).toHaveBeenCalled()
  end)
end)
```


### Property-Based Testing Focus

Property tests should verify universal correctness properties across randomized inputs. Each property test will:

- Run minimum 100 iterations with randomized inputs
- Reference the design document property number
- Use tag format: **Feature: soccer-ai-system, Property {N}: {property text}**

**Property Test Configuration**:

For Lua/Roblox, we'll use a property-based testing approach with custom generators:

```lua
-- Example property test structure
describe("Property Tests", function()
  it("Property 1: AI Control State Transitions", function()
    -- Feature: soccer-ai-system, Property 1: AI Control State Transitions
    
    for i = 1, 100 do
      local npc = generateRandomNPC()
      local initialPossessionState = math.random() > 0.5
      
      -- Test AI control activation
      if not initialPossessionState then
        expect(AIController:IsControlling(npc)).toBe(true)
      else
        expect(AIController:IsControlling(npc)).toBe(false)
      end
      
      -- Test transition
      setPossessionState(npc, not initialPossessionState)
      wait(0.15)  -- Allow transition time
      
      if not initialPossessionState then
        expect(AIController:IsControlling(npc)).toBe(false)
      else
        expect(AIController:IsControlling(npc)).toBe(true)
      end
    end
  end)
end)
```

**Generators for Randomized Testing**:

```lua
-- Generate random NPC with valid properties
function generateRandomNPC()
  local roles = {"GK", "DF", "LW", "RW", "ST"}
  local teams = {"Blue", "Red"}
  
  return {
    Position = generateRandomFieldPosition(),
    Role = roles[math.random(#roles)],
    Team = teams[math.random(#teams)],
    Humanoid = createMockHumanoid(),
  }
end

-- Generate random field position within bounds
function generateRandomFieldPosition()
  return Vector3.new(
    math.random(-50, 50),
    0,
    math.random(-30, 30)
  )
end

-- Generate random ball state
function generateRandomBallState()
  return {
    position = generateRandomFieldPosition(),
    velocity = Vector3.new(
      math.random(-20, 20),
      math.random(-10, 10),
      math.random(-20, 20)
    ),
    isLoose = math.random() > 0.5,
  }
end

-- Generate random game state
function generateRandomGameState()
  return {
    ball = generateRandomBallState(),
    ownTeam = generateRandomTeam("Blue"),
    opponentTeam = generateRandomTeam("Red"),
    fieldBounds = {minX = -50, maxX = 50, minZ = -30, maxZ = 30},
  }
end
```


**Key Properties to Test**:

1. **Position Calculation Properties** (Properties 3, 5)
   - Generate random formations, roles, ball positions
   - Verify calculated positions match tactical intent
   - Verify GK always between ball and goal

2. **Decision Scoring Properties** (Properties 9, 11, 17)
   - Generate random game states with varying conditions
   - Verify scores increase/decrease with expected factors
   - Verify role-based priorities are respected

3. **Coordination Properties** (Properties 6, 29, 30, 31, 32)
   - Generate random team configurations
   - Verify only one pursuer designated
   - Verify spacing and coverage rules maintained

4. **Prediction Properties** (Properties 7, 8, 28)
   - Generate random ball trajectories
   - Verify predictions are ahead of current position
   - Verify landing calculations for airborne balls

5. **State Machine Properties** (Properties 25, 26, 27)
   - Generate random state transitions
   - Verify only valid states used
   - Verify state storage and retrieval

**Example Property Test for Position Calculation**:
```lua
it("Property 3: Formation-Based Position Calculation", function()
  -- Feature: soccer-ai-system, Property 3: Formation-Based Position Calculation
  
  for i = 1, 100 do
    local role = generateRandomRole()
    local formation = generateRandomFormation()
    local ballPosition = generateRandomFieldPosition()
    
    local targetPos = PositionCalculator:GetTargetPosition(
      role, formation, ballPosition
    )
    
    -- Verify tactical intent
    if formation == "Attacking" and isAttackingRole(role) then
      -- Should be pushed forward
      expect(targetPos.Z).toBeGreaterThan(0)  -- Positive Z is attacking half
    elseif formation == "Defensive" then
      -- Should be pulled back
      expect(targetPos.Z).toBeLessThan(10)  -- Stay in defensive area
    end
    
    -- Verify position is within field bounds
    expect(targetPos.X).toBeGreaterThan(-50)
    expect(targetPos.X).toBeLessThan(50)
    expect(targetPos.Z).toBeGreaterThan(-30)
    expect(targetPos.Z).toBeLessThan(30)
  end
end)
```

### Testing Tools and Framework

**Framework**: Roblox TestEZ or similar Lua testing framework

**Mocking**: Create mock implementations of:
- BallManager (for kick operations)
- NPCManager (for movement commands)
- TeamManager (for team queries)
- FormationData (for formation positions)

**Test Organization**:
```
ServerModules/AI/
├── __tests__/
│   ├── AIController.spec.lua
│   ├── DecisionEngine.spec.lua
│   ├── BehaviorController.spec.lua
│   ├── PositionCalculator.spec.lua
│   ├── BallPredictor.spec.lua
│   ├── TeamCoordinator.spec.lua
│   ├── Properties.spec.lua          -- Property-based tests
│   └── TestHelpers.lua              -- Generators and utilities
```

### Performance Testing

In addition to functional testing, performance should be validated:

- Measure frame time with 10 AI-controlled NPCs
- Verify update frequency stays within configured limits
- Profile decision-making and pathfinding costs
- Test under various game state complexities

**Performance Benchmarks**:
- Single NPC decision update: < 2ms
- Full 10-NPC update cycle: < 10ms
- Pathfinding calculation: < 1ms
- Position calculation: < 0.5ms

### Integration Testing

Test the complete AI system integrated with actual game managers:

- Spawn 10 NPCs in test environment
- Verify AI activates and deactivates correctly
- Verify NPCs exhibit expected behaviors
- Verify formation changes propagate correctly
- Verify ball interactions work properly

This can be done through automated test scenarios or manual playtesting with debug visualization enabled.
