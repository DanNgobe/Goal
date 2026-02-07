--[[
  AICore.lua
  
  Main coordinator for the Soccer AI System.
  Manages AI lifecycle, update scheduling, and decision state for all NPCs.
  
  Responsibilities:
  - Activate/deactivate AI control based on possession state
  - Coordinate staggered update cycles across all AI-controlled NPCs
  - Provide interface for formation switching
  - Maintain decision state machine for each NPC
  - Integrate all AI sub-modules (DecisionEngine, BehaviorController, etc.)
  
  Replaces the old AIController reference in GameManager.
]]

local AICore = {}

-- Services
local RunService = game:GetService("RunService")

-- AI Modules
local AIConfig = require(script.Parent.AIConfig)
local DecisionEngine = require(script.Parent.DecisionEngine)
local GoalkeeperDecisionEngine = require(script.Parent.GoalkeeperDecisionEngine)
local BehaviorController = require(script.Parent.BehaviorController)
local PositionCalculator = require(script.Parent.PositionCalculator)
local BallPredictor = require(script.Parent.BallPredictor)
local TeamCoordinator = require(script.Parent.TeamCoordinator)
local SafeMath = require(script.Parent.SafeMath)

-- Private state
local TeamManager = nil
local NPCManager = nil
local BallManager = nil
local FormationData = nil

-- AI-controlled NPCs and their decision states
local ControlledNPCs = {}  -- Array of NPCs currently under AI control
local DecisionStates = {}  -- Map of NPC -> DecisionState

-- Update scheduling
local FrameCounter = 0
local LastUpdateTime = {}  -- Map of NPC -> last update timestamp

-- Decision engines (base and goalkeeper)
local BaseDecisionEngine = nil
local GKDecisionEngine = nil

-- Behavior controller instance
local BehaviorControllerInstance = nil

-- Position calculator instance
local PositionCalculatorInstance = nil

-- Ball predictor instance
local BallPredictorInstance = nil

-- Team coordinator instance
local TeamCoordinatorInstance = nil

-- Heartbeat connection
local HeartbeatConnection = nil

-- Valid decision states
local ValidStates = {
  Idle = true,
  Positioning = true,
  Pursuing = true,
  Attacking = true,
  Defending = true
}

--[[
  DecisionState structure:
  {
    npc = NPC Model,
    state = "Idle"|"Positioning"|"Pursuing"|"Attacking"|"Defending",
    action = "Position"|"Pass"|"Shoot"|"Dribble"|"Pursue"|"Defend",
    target = Vector3 or NPC or nil,
    priority = number (0-100),
    lastUpdate = tick(),
    transitionReason = string
  }
]]

--[[
  Get field dimensions for position calculator.
  
  Returns:
    Vector3 - Field center position
    Vector3 - Field size (X, Y, Z dimensions)
]]
function AICore._GetFieldDimensions()
  local fieldCenter = Vector3.new(0, 0, 0)
  local fieldSize = Vector3.new(50, 0, 30)
  
  -- Try to get from NPCManager if available
  if NPCManager and NPCManager.GetFieldBounds then
    local bounds = NPCManager.GetFieldBounds()
    if bounds then
      fieldCenter = Vector3.new(
        (bounds.minX + bounds.maxX) / 2,
        0,
        (bounds.minZ + bounds.maxZ) / 2
      )
      fieldSize = Vector3.new(
        (bounds.maxX - bounds.minX) / 2,
        0,
        (bounds.maxZ - bounds.minZ) / 2
      )
    end
  else
    -- Fallback: try to find Ground part in workspace
    local pitch = workspace:FindFirstChild("Pitch")
    if pitch then
      local ground = pitch:FindFirstChild("Ground")
      if ground and ground:IsA("BasePart") then
        fieldCenter = ground.Position
        fieldSize = ground.Size / 2
      end
    end
  end
  
  return fieldCenter, fieldSize
end

--[[
  Initialize the AI system with references to game managers.
  
  Parameters:
    teamManager - TeamManager module
    npcManager - NPCManager module
    ballManager - BallManager module
    formationData - FormationData module
    
  Returns:
    boolean - Success status
]]
function AICore.Initialize(teamManager, npcManager, ballManager, formationData)
  if not teamManager or not npcManager or not ballManager or not formationData then
    warn("[AICore] Missing required manager references")
    return false
  end
  
  -- Store manager references
  TeamManager = teamManager
  NPCManager = npcManager
  BallManager = ballManager
  FormationData = formationData
  
  -- Initialize decision engines
  BaseDecisionEngine = DecisionEngine.new()
  GKDecisionEngine = GoalkeeperDecisionEngine.new()
  
  -- Initialize behavior controller
  local behaviorSuccess = BehaviorController.Initialize(npcManager, ballManager, AIConfig)
  if not behaviorSuccess then
    warn("[AICore] Failed to initialize BehaviorController")
    return false
  end
  BehaviorControllerInstance = BehaviorController
  
  -- Initialize position calculator
  local fieldCenter, fieldSize = AICore._GetFieldDimensions()
  local positionSuccess = PositionCalculator.Initialize(formationData, fieldCenter, fieldSize)
  if not positionSuccess then
    warn("[AICore] Failed to initialize PositionCalculator")
    return false
  end
  PositionCalculatorInstance = PositionCalculator
  
  -- Initialize ball predictor (stateless, just store reference)
  BallPredictorInstance = BallPredictor
  
  -- Initialize team coordinator (stateless, just store reference)
  TeamCoordinatorInstance = TeamCoordinator
  
  -- Clear state
  ControlledNPCs = {}
  DecisionStates = {}
  LastUpdateTime = {}
  FrameCounter = 0
  
  -- Connect to Heartbeat for update loop
  if HeartbeatConnection then
    HeartbeatConnection:Disconnect()
  end
  
  HeartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
    AICore.Update(deltaTime)
  end)
  
  if AIConfig.DEBUG_MODE then
    print("[AICore] Initialized successfully")
  end
  
  return true
end


--[[
  Main update loop called every frame.
  Implements staggered updates to distribute computational load.
  
  Parameters:
    deltaTime - Time since last frame (seconds)
]]
function AICore.Update(deltaTime)
  FrameCounter = FrameCounter + 1
  
  -- Determine which NPCs to update this frame (odd or even indices)
  local updateOddIndices = (FrameCounter % AIConfig.STAGGER_OFFSET) == 0
  
  for i, npc in ipairs(ControlledNPCs) do
    -- Stagger updates: odd indices on one frame, even on another
    local shouldUpdate = (i % 2 == 1) == updateOddIndices
    
    if shouldUpdate then
      -- Check if enough time has passed since last update
      local lastUpdate = LastUpdateTime[npc] or 0
      local currentTime = tick()
      
      if currentTime - lastUpdate >= AIConfig.UPDATE_INTERVAL then
        AICore._UpdateNPC(npc, deltaTime)
        LastUpdateTime[npc] = currentTime
      end
    end
  end
end

--[[
  Update a single NPC's AI decision and behavior.
  
  Parameters:
    npc - The NPC Model to update
    deltaTime - Time since last frame
]]
function AICore._UpdateNPC(npc, deltaTime)
  -- Wrap entire update in pcall for error catching
  local success, err = pcall(function()
    -- Validate NPC
    if not AICore._IsValidNPC(npc) then
      AICore.DisableAI(npc)
      return
    end
    
    -- Get or create decision state
    local decisionState = DecisionStates[npc]
    if not decisionState then
      decisionState = AICore._CreateDecisionState(npc)
      DecisionStates[npc] = decisionState
    end
    
    -- Gather game state with validation
    local gameState = AICore._GatherGameState(npc)
    if not gameState then
      if AIConfig.DEBUG_MODE then
        warn("[AICore] Invalid game state, skipping update for NPC")
      end
      -- Fallback: try to position NPC at safe location
      AICore._ExecuteFallbackBehavior(npc)
      return
    end
    
    -- Validate game state components
    if not AICore._ValidateGameState(gameState) then
      if AIConfig.DEBUG_MODE then
        warn("[AICore] Game state validation failed, using fallback")
      end
      AICore._ExecuteFallbackBehavior(npc)
      return
    end
    
    -- Enhance game state with sub-module references
    gameState.ballPredictor = BallPredictorInstance
    gameState.positionCalculator = PositionCalculatorInstance
    gameState.teamCoordinator = TeamCoordinatorInstance
    
    -- Select appropriate decision engine based on role
    local decisionEngine = AICore._GetDecisionEngine(npc)
    
    -- Make decision with error handling
    local decisionSuccess, decision = pcall(function()
      return decisionEngine:Decide(npc, gameState, decisionState)
    end)
    
    if not decisionSuccess then
      warn("[AICore] Decision engine failed:", decision)
      -- Fallback to positioning behavior
      decision = {
        action = "Position",
        target = npc.Position,
        priority = 30,
        reasoning = "Fallback after decision error"
      }
    end
    
    -- Update decision state
    if decision then
      AICore._UpdateDecisionState(npc, decision, decisionState)
    end
    
    -- Execute behavior with error handling
    AICore._ExecuteBehavior(npc, decisionState, gameState)
  end)
  
  if not success then
    warn("[AICore] Critical error in NPC update:", err)
    -- Attempt to disable AI for this NPC to prevent repeated errors
    AICore.DisableAI(npc)
  end
end

--[[
  Validate that an NPC is still valid and can be controlled.
  
  Parameters:
    npc - The NPC Model to validate
    
  Returns:
    boolean - Is valid
]]
function AICore._IsValidNPC(npc)
  if not npc or not npc.Parent then
    return false
  end
  
  -- Check if NPC is a Model
  if not npc:IsA("Model") then
    return false
  end
  
  local humanoid = npc:FindFirstChildOfClass("Humanoid")
  if not humanoid or humanoid.Health <= 0 then
    return false
  end
  
  local rootPart = npc:FindFirstChild("HumanoidRootPart")
  if not rootPart or not rootPart:IsA("BasePart") then
    return false
  end
  
  return true
end

--[[
  Validate game state has all required components.
  
  Parameters:
    gameState - GameState table
    
  Returns:
    boolean - Is valid
]]
function AICore._ValidateGameState(gameState)
  if not gameState then
    return false
  end
  
  -- Validate ball state
  if not gameState.ball or not gameState.ball.position then
    return false
  end
  
  -- Validate team data
  if not gameState.ownTeam or not gameState.opponentTeam then
    return false
  end
  
  -- Validate field bounds
  if not gameState.fieldBounds then
    return false
  end
  
  -- Validate positions are valid Vector3s
  if typeof(gameState.ball.position) ~= "Vector3" then
    return false
  end
  
  return true
end

--[[
  Execute fallback behavior when normal decision-making fails.
  Attempts to move NPC to a safe position.
  
  Parameters:
    npc - The NPC Model
]]
function AICore._ExecuteFallbackBehavior(npc)
  if not npc or not npc:FindFirstChild("HumanoidRootPart") then
    return
  end
  
  local success, err = pcall(function()
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    if humanoid then
      -- Try to move to field center as fallback
      local fieldCenter = Vector3.new(0, 3, 0)
      
      -- Try to get actual field center
      if NPCManager and NPCManager.GetFieldCenter then
        local center = NPCManager.GetFieldCenter()
        if center then
          fieldCenter = center
        end
      end
      
      humanoid.WalkSpeed = AIConfig.WALK_SPEED
      humanoid:MoveTo(fieldCenter)
    end
  end)
  
  if not success then
    warn("[AICore] Fallback behavior failed:", err)
  end
end

--[[
  Create a new decision state for an NPC.
  
  Parameters:
    npc - The NPC Model
    
  Returns:
    DecisionState table
]]
function AICore._CreateDecisionState(npc)
  return {
    npc = npc,
    state = "Idle",
    action = "Position",
    target = nil,
    priority = 0,
    lastUpdate = tick(),
    transitionReason = "Initial state"
  }
end

--[[
  Gather current game state for decision-making.
  
  Parameters:
    npc - The NPC making the decision
    
  Returns:
    GameState table or nil if invalid
]]
function AICore._GatherGameState(npc)
  -- Validate managers
  if not BallManager or not TeamManager or not NPCManager then
    return nil
  end
  
  -- Get ball state
  local ball = BallManager.GetBall and BallManager.GetBall() or workspace:FindFirstChild("Ball")
  if not ball then
    return nil
  end
  
  local ballPosition = ball.Position
  local ballVelocity = ball.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
  local ballPossessor = BallManager.GetCurrentOwner and BallManager.GetCurrentOwner() or nil
  local isLoose = ballPossessor == nil
  
  -- Get NPC's team and role
  local npcTeam = AICore._GetNPCTeam(npc)
  if not npcTeam then
    return nil
  end
  
  local npcRole = AICore._GetNPCRole(npc)
  
  local opponentTeam = npcTeam == "Blue" and "Red" or "Blue"
  
  -- Get team NPCs
  local ownTeamNPCs = AICore._GetTeamNPCs(npcTeam)
  local opponentNPCs = AICore._GetTeamNPCs(opponentTeam)
  
  -- Get formations
  local ownFormation = TeamManager.GetFormation and TeamManager.GetFormation(npcTeam) or "Neutral"
  local opponentFormation = TeamManager.GetFormation and TeamManager.GetFormation(opponentTeam) or "Neutral"
  
  -- Get goal positions
  local ownGoal = AICore._GetGoalPosition(npcTeam)
  local opponentGoal = AICore._GetGoalPosition(opponentTeam)
  
  -- Get field bounds
  local fieldBounds = NPCManager.GetFieldBounds and NPCManager.GetFieldBounds() or {
    minX = -50, maxX = 50, minZ = -30, maxZ = 30
  }
  
  -- Store NPC role and team on the NPC for easy access
  npc.Role = npcRole
  npc.Team = npcTeam
  
  return {
    ball = {
      position = ballPosition,
      velocity = ballVelocity,
      isLoose = isLoose,
      possessor = ballPossessor,
      object = ball
    },
    ownTeam = {
      name = npcTeam,
      npcs = ownTeamNPCs,
      formation = ownFormation,
      goalPosition = ownGoal
    },
    opponentTeam = {
      name = opponentTeam,
      npcs = opponentNPCs,
      formation = opponentFormation,
      goalPosition = opponentGoal
    },
    fieldBounds = fieldBounds,
    timestamp = tick(),
    npcRole = npcRole
  }
end


--[[
  Get the team name for an NPC.
  
  Parameters:
    npc - The NPC Model
    
  Returns:
    string - Team name ("Blue" or "Red") or nil
]]
function AICore._GetNPCTeam(npc)
  if not TeamManager or not TeamManager.GetNPCTeam then
    -- Fallback: check NPC name
    if npc.Name:find("Blue") then
      return "Blue"
    elseif npc.Name:find("Red") then
      return "Red"
    end
    return nil
  end
  
  return TeamManager.GetNPCTeam(npc)
end

--[[
  Get all NPCs for a team.
  
  Parameters:
    teamName - "Blue" or "Red"
    
  Returns:
    Array of NPC Models
]]
function AICore._GetTeamNPCs(teamName)
  if not TeamManager or not TeamManager.GetTeamSlots then
    return {}
  end
  
  local slots = TeamManager.GetTeamSlots(teamName)
  local npcs = {}
  
  for _, slot in ipairs(slots) do
    if slot.NPC then
      table.insert(npcs, slot.NPC)
    end
  end
  
  return npcs
end

--[[
  Get goal position for a team.
  
  Parameters:
    teamName - "Blue" or "Red"
    
  Returns:
    Vector3 - Goal position
]]
function AICore._GetGoalPosition(teamName)
  if not TeamManager or not TeamManager.GetGoalPosition then
    -- Fallback positions
    if teamName == "Blue" then
      return Vector3.new(-50, 0, 0)
    else
      return Vector3.new(50, 0, 0)
    end
  end
  
  return TeamManager.GetGoalPosition(teamName)
end

--[[
  Get the appropriate decision engine for an NPC based on role.
  
  Parameters:
    npc - The NPC Model
    
  Returns:
    DecisionEngine instance
]]
function AICore._GetDecisionEngine(npc)
  local role = AICore._GetNPCRole(npc)
  
  if role == "GK" then
    return GKDecisionEngine
  else
    return BaseDecisionEngine
  end
end

--[[
  Get the role of an NPC.
  
  Parameters:
    npc - The NPC Model
    
  Returns:
    string - Role ("GK", "DF", "LW", "RW", "ST") or nil
]]
function AICore._GetNPCRole(npc)
  if not TeamManager or not TeamManager.GetNPCRole then
    -- Fallback: check for Role attribute or value
    local roleValue = npc:FindFirstChild("Role")
    if roleValue and roleValue:IsA("StringValue") then
      return roleValue.Value
    end
    return nil
  end
  
  return TeamManager.GetNPCRole(npc)
end

--[[
  Update the decision state based on a new decision.
  
  Parameters:
    npc - The NPC Model
    decision - Decision table from DecisionEngine
    decisionState - Current DecisionState
]]
function AICore._UpdateDecisionState(npc, decision, decisionState)
  local oldState = decisionState.state
  local newState = AICore._DetermineState(decision.action, npc, decision)
  
  -- Update state
  decisionState.action = decision.action
  decisionState.target = decision.target
  decisionState.priority = decision.priority or 50
  decisionState.lastUpdate = tick()
  
  -- Handle state transition
  if newState ~= oldState then
    decisionState.state = newState
    decisionState.transitionReason = decision.reasoning or "State changed"
    
    if AIConfig.LOG_DECISIONS then
      print(string.format("[AICore] NPC %s: %s -> %s (%s)", 
        npc.Name, oldState, newState, decisionState.transitionReason))
    end
  end
end

--[[
  Determine the state based on the action.
  
  Parameters:
    action - Action string
    npc - The NPC Model
    decision - Decision table
    
  Returns:
    string - State name
]]
function AICore._DetermineState(action, npc, decision)
  if action == "Pass" or action == "Shoot" or action == "Dribble" then
    return "Attacking"
  elseif action == "Pursue" then
    return "Pursuing"
  elseif action == "Defend" or action == "Pressure" then
    return "Defending"
  elseif action == "Position" then
    return "Positioning"
  else
    return "Idle"
  end
end

--[[
  Execute the behavior based on current decision state.
  
  Parameters:
    npc - The NPC Model
    decisionState - Current DecisionState
    gameState - Current GameState
]]
function AICore._ExecuteBehavior(npc, decisionState, gameState)
  if not BehaviorControllerInstance then
    return
  end
  
  local action = decisionState.action
  local target = decisionState.target
  
  -- Wrap in pcall for error handling
  local success, err = pcall(function()
    if action == "Position" then
      if target and typeof(target) == "Vector3" then
        BehaviorControllerInstance:MoveTo(npc, target, "normal")
      end
      
    elseif action == "Pursue" then
      if target and typeof(target) == "Vector3" then
        BehaviorControllerInstance:MoveTo(npc, target, "sprint")
      end
      
    elseif action == "Pass" then
      if target and typeof(target) == "Instance" and target:IsA("Model") then
        BehaviorControllerInstance:Pass(npc, target, gameState)
      end
      
    elseif action == "Shoot" then
      BehaviorControllerInstance:Shoot(npc, gameState)
      
    elseif action == "Dribble" then
      if target and typeof(target) == "Vector3" then
        local rootPart = npc:FindFirstChild("HumanoidRootPart")
        if rootPart then
          local direction = SafeMath.SafeNormalize(target - rootPart.Position, Vector3.new(0, 0, 1))
          BehaviorControllerInstance:Dribble(npc, direction, gameState)
        end
      end
      
    elseif action == "Defend" or action == "Pressure" then
      if target then
        if typeof(target) == "Instance" and target:IsA("Model") then
          BehaviorControllerInstance:Pressure(npc, target)
        elseif typeof(target) == "Vector3" then
          BehaviorControllerInstance:MoveTo(npc, target, "sprint")
        end
      end
      
    end
  end)
  
  if not success then
    warn("[AICore] Behavior execution failed:", err)
    -- Fallback to safe positioning
    AICore._ExecuteFallbackBehavior(npc)
  end
end


--[[
  Enable AI control for a specific NPC.
  Adds the NPC to the controlled list and initializes decision state.
  
  Parameters:
    npc - The NPC Model to control
]]
function AICore.EnableAI(npc)
  if not npc then
    warn("[AICore] Cannot enable AI for nil NPC")
    return
  end
  
  -- Check if already controlled
  for _, controlledNPC in ipairs(ControlledNPCs) do
    if controlledNPC == npc then
      return  -- Already controlled
    end
  end
  
  -- Validate NPC
  if not AICore._IsValidNPC(npc) then
    warn("[AICore] Cannot enable AI for invalid NPC")
    return
  end
  
  -- Add to controlled list
  table.insert(ControlledNPCs, npc)
  
  -- Initialize decision state
  DecisionStates[npc] = AICore._CreateDecisionState(npc)
  LastUpdateTime[npc] = 0  -- Force immediate update
  
  if AIConfig.DEBUG_MODE then
    print("[AICore] Enabled AI for", npc.Name)
  end
end

--[[
  Disable AI control for a specific NPC.
  Removes the NPC from the controlled list and clears decision state.
  
  Parameters:
    npc - The NPC Model to stop controlling
]]
function AICore.DisableAI(npc)
  if not npc then
    return
  end
  
  -- Remove from controlled list
  for i, controlledNPC in ipairs(ControlledNPCs) do
    if controlledNPC == npc then
      table.remove(ControlledNPCs, i)
      break
    end
  end
  
  -- Clear decision state
  DecisionStates[npc] = nil
  LastUpdateTime[npc] = nil
  
  if AIConfig.DEBUG_MODE then
    print("[AICore] Disabled AI for", npc.Name)
  end
end

--[[
  Change tactical formation for a team.
  Triggers position recalculation for all NPCs on that team.
  
  Parameters:
    teamName - "Blue" or "Red"
    formationType - "Neutral", "Attacking", or "Defensive"
]]
function AICore.SetFormation(teamName, formationType)
  if not teamName or not formationType then
    warn("[AICore] Invalid parameters for SetFormation")
    return
  end
  
  -- Validate formation type
  local validFormations = {Neutral = true, Attacking = true, Defensive = true}
  if not validFormations[formationType] then
    warn("[AICore] Invalid formation type:", formationType)
    return
  end
  
  -- Update formation in TeamManager
  if TeamManager and TeamManager.SetFormation then
    TeamManager.SetFormation(teamName, formationType)
  end
  
  -- Force immediate update for all NPCs on this team
  for _, npc in ipairs(ControlledNPCs) do
    local npcTeam = AICore._GetNPCTeam(npc)
    if npcTeam == teamName then
      LastUpdateTime[npc] = 0  -- Force update on next frame
    end
  end
  
  if AIConfig.DEBUG_MODE then
    print(string.format("[AICore] Set formation for %s to %s", teamName, formationType))
  end
end

--[[
  Get the current decision state for an NPC (for debugging).
  
  Parameters:
    npc - The NPC Model
    
  Returns:
    DecisionState table or nil
]]
function AICore.GetDecisionState(npc)
  if not npc then
    return nil
  end
  
  return DecisionStates[npc]
end

--[[
  Get all controlled NPCs (for debugging).
  
  Returns:
    Array of NPC Models
]]
function AICore.GetControlledNPCs()
  return ControlledNPCs
end

--[[
  Check if an NPC is currently under AI control.
  
  Parameters:
    npc - The NPC Model
    
  Returns:
    boolean - Is controlled
]]
function AICore.IsControlling(npc)
  if not npc then
    return false
  end
  
  for _, controlledNPC in ipairs(ControlledNPCs) do
    if controlledNPC == npc then
      return true
    end
  end
  
  return false
end

--[[
  Cleanup the AI system (for testing).
  Disconnects update loop and clears all state.
]]
function AICore.Cleanup()
  -- Disconnect heartbeat
  if HeartbeatConnection then
    HeartbeatConnection:Disconnect()
    HeartbeatConnection = nil
  end
  
  -- Clear all state
  ControlledNPCs = {}
  DecisionStates = {}
  LastUpdateTime = {}
  FrameCounter = 0
  
  -- Clear manager references
  TeamManager = nil
  NPCManager = nil
  BallManager = nil
  FormationData = nil
  
  -- Clear sub-module references
  BaseDecisionEngine = nil
  GKDecisionEngine = nil
  BehaviorControllerInstance = nil
  PositionCalculatorInstance = nil
  BallPredictorInstance = nil
  TeamCoordinatorInstance = nil
  
  if AIConfig.DEBUG_MODE then
    print("[AICore] Cleaned up")
  end
end

return AICore
