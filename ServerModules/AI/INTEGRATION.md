# AI System Integration Guide

This document describes how to integrate the Soccer AI System with existing game systems.

## Overview

The AI System is implemented as a modular architecture with `AICore` as the main coordinator. It integrates with existing game managers (TeamManager, NPCManager, BallManager, FormationData) to provide intelligent NPC behavior.

## Integration Points

### 1. GameManager Integration

The AI System is loaded and initialized by GameManager during game setup.

**Loading AICore:**

```lua
-- In GameManager._LoadManagers()
local aiCoreModule = ServerModules:FindFirstChild("AI")
if aiCoreModule then
    aiCoreModule = aiCoreModule:FindFirstChild("AICore")
end

local success, aiCore = pcall(require, aiCoreModule)
Managers.AIController = aiCore  -- Stored as AIController for compatibility
```

**Initialization:**

```lua
-- In GameManager.Initialize()
-- Initialize after TeamManager, NPCManager, BallManager, and FormationData
local aiSuccess = Managers.AIController.Initialize(
    Managers.TeamManager,
    Managers.NPCManager,
    Managers.BallManager,
    Managers.FormationData
)
```

**Cleanup:**

```lua
-- In GameManager.Cleanup()
if Managers.AIController then
    Managers.AIController.Cleanup()
end
```

### 2. AICore Public Interface

AICore exposes the following methods for integration:

#### Initialize(teamManager, npcManager, ballManager, formationData)

Initializes the AI system with references to game managers.

**Parameters:**
- `teamManager` - TeamManager module reference
- `npcManager` - NPCManager module reference
- `ballManager` - BallManager module reference
- `formationData` - FormationData module reference

**Returns:**
- `boolean` - Success status (true if initialized successfully)

**Example:**
```lua
local success = AICore.Initialize(
    TeamManager,
    NPCManager,
    BallManager,
    FormationData
)

if not success then
    warn("Failed to initialize AI system")
end
```

#### Update(deltaTime)

Main update loop called every frame. Implements staggered updates to distribute computational load.

**Parameters:**
- `deltaTime` - Time since last frame in seconds

**Note:** This is automatically called via RunService.Heartbeat connection established during Initialize(). You do not need to call this manually unless you've disabled the automatic update loop.

**Example (manual call if needed):**
```lua
RunService.Heartbeat:Connect(function(deltaTime)
    AICore.Update(deltaTime)
end)
```

#### EnableAI(npc)

Enables AI control for a specific NPC. Adds the NPC to the controlled list and initializes decision state.

**Parameters:**
- `npc` - The NPC Model to control

**Example:**
```lua
-- Enable AI when player releases control
local npc = slot.NPC
AICore.EnableAI(npc)
```

#### DisableAI(npc)

Disables AI control for a specific NPC. Removes the NPC from the controlled list and clears decision state.

**Parameters:**
- `npc` - The NPC Model to stop controlling

**Example:**
```lua
-- Disable AI when player takes control
local npc = slot.NPC
AICore.DisableAI(npc)
```

#### SetFormation(teamName, formationType)

Changes tactical formation for a team. Triggers position recalculation for all NPCs on that team.

**Parameters:**
- `teamName` - "Blue" or "Red"
- `formationType` - "Neutral", "Attacking", or "Defensive"

**Example:**
```lua
-- Switch to attacking formation when team has possession
AICore.SetFormation("Blue", "Attacking")

-- Switch to defensive formation when opponent has possession
AICore.SetFormation("Blue", "Defensive")

-- Return to neutral formation
AICore.SetFormation("Blue", "Neutral")
```

#### GetDecisionState(npc)

Gets the current decision state for an NPC (for debugging).

**Parameters:**
- `npc` - The NPC Model

**Returns:**
- `DecisionState` table or nil

**DecisionState Structure:**
```lua
{
    npc = NPC Model,
    state = "Idle"|"Positioning"|"Pursuing"|"Attacking"|"Defending",
    action = "Position"|"Pass"|"Shoot"|"Dribble"|"Pursue"|"Defend",
    target = Vector3 or NPC or nil,
    priority = number (0-100),
    lastUpdate = tick(),
    transitionReason = string
}
```

**Example:**
```lua
local state = AICore.GetDecisionState(npc)
if state then
    print("NPC State:", state.state)
    print("Current Action:", state.action)
    print("Priority:", state.priority)
    print("Reason:", state.transitionReason)
end
```

#### GetControlledNPCs()

Gets all NPCs currently under AI control (for debugging).

**Returns:**
- Array of NPC Models

**Example:**
```lua
local controlledNPCs = AICore.GetControlledNPCs()
print("AI controlling", #controlledNPCs, "NPCs")
```

#### IsControlling(npc)

Checks if an NPC is currently under AI control.

**Parameters:**
- `npc` - The NPC Model

**Returns:**
- `boolean` - Is controlled

**Example:**
```lua
if AICore.IsControlling(npc) then
    print("NPC is under AI control")
else
    print("NPC is player-controlled or not controlled")
end
```

#### Cleanup()

Cleans up the AI system (for testing). Disconnects update loop and clears all state.

**Example:**
```lua
AICore.Cleanup()
```

## Usage Patterns

### Pattern 1: Enabling/Disabling AI Based on Player Possession

When a player possesses an NPC, disable AI. When they release it, enable AI.

```lua
-- In PlayerController or similar system

-- When player takes control
function OnPlayerPossessNPC(player, npc)
    AICore.DisableAI(npc)
    -- ... other possession logic
end

-- When player releases control
function OnPlayerReleaseNPC(player, npc)
    AICore.EnableAI(npc)
    -- ... other release logic
end
```

### Pattern 2: Formation Switching Based on Ball Possession

Automatically switch formations based on which team has the ball.

```lua
-- In BallManager or TeamManager

function OnPossessionChange(newOwner)
    if not newOwner then
        -- Ball is loose, return to neutral
        AICore.SetFormation("Blue", "Neutral")
        AICore.SetFormation("Red", "Neutral")
        return
    end
    
    local ownerTeam = TeamManager.GetNPCTeam(newOwner)
    
    if ownerTeam == "Blue" then
        AICore.SetFormation("Blue", "Attacking")
        AICore.SetFormation("Red", "Defensive")
    elseif ownerTeam == "Red" then
        AICore.SetFormation("Red", "Attacking")
        AICore.SetFormation("Blue", "Defensive")
    end
end
```

### Pattern 3: Debugging AI Decisions

Query decision states to understand what the AI is doing.

```lua
-- Debug command or admin tool

function DebugNPCAI(npc)
    local state = AICore.GetDecisionState(npc)
    
    if not state then
        print("NPC is not under AI control")
        return
    end
    
    print("=== AI Debug Info ===")
    print("NPC:", npc.Name)
    print("State:", state.state)
    print("Action:", state.action)
    print("Priority:", state.priority)
    print("Last Update:", tick() - state.lastUpdate, "seconds ago")
    print("Transition Reason:", state.transitionReason)
    
    if state.target then
        if typeof(state.target) == "Vector3" then
            print("Target Position:", state.target)
        elseif typeof(state.target) == "Instance" then
            print("Target NPC:", state.target.Name)
        end
    end
end
```

### Pattern 4: Initializing AI for All NPCs at Game Start

Enable AI for all NPCs when the game starts.

```lua
-- In GameManager.Initialize() or similar

function InitializeAllNPCAI()
    local teams = {"Blue", "Red"}
    
    for _, teamName in ipairs(teams) do
        local slots = TeamManager.GetTeamSlots(teamName)
        
        for _, slot in ipairs(slots) do
            if slot.NPC and not slot.Controller then
                -- NPC exists and has no player controller
                AICore.EnableAI(slot.NPC)
            end
        end
    end
    
    print("AI enabled for all uncontrolled NPCs")
end
```

## Configuration

AI behavior can be tuned by modifying `AIConfig.lua`. Key parameters include:

- `UPDATE_INTERVAL` - Seconds between decision updates (default: 0.5)
- `STAGGER_OFFSET` - Frames between odd/even updates (default: 15)
- `BALL_PURSUIT_RANGE` - Distance to pursue ball (default: 20 studs)
- `PRESSURE_RANGE` - Distance to pressure opponent (default: 10 studs)
- `MAX_SHOT_DISTANCE` - Maximum shooting distance (default: 30 studs)
- `DEBUG_MODE` - Enable debug logging (default: false)
- `LOG_DECISIONS` - Log decision changes (default: false)

See `AIConfig.lua` for the complete list of tunable parameters.

## Performance Considerations

The AI system is designed to handle 10 NPCs simultaneously while maintaining 30+ FPS:

1. **Staggered Updates**: NPCs are updated in two groups (odd/even indices) on alternating frames
2. **Update Interval**: Each NPC is updated at most once per 0.5 seconds
3. **Error Handling**: All critical operations are wrapped in pcall to prevent crashes
4. **Fallback Behaviors**: If decision-making fails, NPCs fall back to safe positioning
5. **Validation**: Game state and NPC validity are checked before processing

## Troubleshooting

### AI Not Responding

**Symptoms:** NPCs stand still or don't react to game events

**Possible Causes:**
1. AI not enabled for the NPC - Call `AICore.EnableAI(npc)`
2. NPC is invalid (no Humanoid or HumanoidRootPart) - Check NPC structure
3. Game managers not initialized - Ensure Initialize() was called successfully
4. Update loop not running - Check if Heartbeat connection is active

**Debug:**
```lua
print("Is AI controlling NPC?", AICore.IsControlling(npc))
print("Decision state:", AICore.GetDecisionState(npc))
print("Controlled NPCs:", #AICore.GetControlledNPCs())
```

### AI Making Poor Decisions

**Symptoms:** NPCs make tactically bad choices

**Possible Causes:**
1. AIConfig parameters need tuning - Adjust scoring weights and thresholds
2. Formation data incorrect - Verify FormationData positions
3. Game state data invalid - Check ball position, team data, etc.

**Debug:**
```lua
-- Enable debug logging in AIConfig.lua
AIConfig.DEBUG_MODE = true
AIConfig.LOG_DECISIONS = true
```

### Performance Issues

**Symptoms:** Game FPS drops below 30 with AI active

**Possible Causes:**
1. Too many NPCs updated per frame - Increase STAGGER_OFFSET
2. Update interval too short - Increase UPDATE_INTERVAL
3. Pathfinding too complex - Reduce MAX_PATHFINDING_WAYPOINTS

**Debug:**
```lua
-- Monitor update frequency
local lastCheck = tick()
RunService.Heartbeat:Connect(function()
    if tick() - lastCheck > 1 then
        print("Controlled NPCs:", #AICore.GetControlledNPCs())
        lastCheck = tick()
    end
end)
```

## Architecture Overview

The AI System consists of these modules:

- **AICore** - Main coordinator, manages lifecycle and update scheduling
- **DecisionEngine** - Base decision-making logic for outfield players
- **GoalkeeperDecisionEngine** - Specialized decision logic for goalkeepers
- **BehaviorController** - Executes actions (movement, passing, shooting)
- **PositionCalculator** - Calculates formation-based target positions
- **BallPredictor** - Predicts ball trajectory and landing positions
- **TeamCoordinator** - Manages multi-NPC coordination
- **AIConfig** - Centralized configuration parameters
- **SafeMath** - Safe mathematical operations (division, normalization)

All modules are located in `ServerModules/AI/`.

## Migration from Old AIController

If you have an existing AIController, the new AICore is designed to be a drop-in replacement:

1. GameManager already loads AICore as `Managers.AIController`
2. The public interface is compatible with common AIController patterns
3. Formation switching uses the same method signature
4. Enable/Disable AI methods work the same way

**Old Code:**
```lua
AIController.Initialize(teamManager, npcManager, ballManager, formationData)
AIController.EnableAI(npc)
AIController.SetFormation("Blue", "Attacking")
```

**New Code (same):**
```lua
AICore.Initialize(teamManager, npcManager, ballManager, formationData)
AICore.EnableAI(npc)
AICore.SetFormation("Blue", "Attacking")
```

The main difference is that AICore uses a more sophisticated decision-making system with multiple specialized modules, but the integration interface remains consistent.

## Summary

The AI System integrates seamlessly with existing game systems through:

1. **Initialization** via GameManager with manager references
2. **Automatic updates** via RunService.Heartbeat
3. **Enable/Disable** methods for player possession control
4. **Formation switching** for tactical behavior changes
5. **Debug queries** for decision state inspection

For most use cases, you only need to call `EnableAI()` and `DisableAI()` when players possess/release NPCs, and optionally call `SetFormation()` to change tactical behavior.
