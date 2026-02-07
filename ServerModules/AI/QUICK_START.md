# AI System Quick Start Guide

This is a quick reference for integrating and using the Soccer AI System.

## TL;DR

The AI system is already integrated with GameManager. It automatically:
- Initializes when the game starts
- Enables AI for all NPCs at startup
- Disables AI when players possess NPCs
- Re-enables AI when NPCs are spawned back

**You don't need to do anything for basic functionality!**

## Common Tasks

### Check if AI is Controlling an NPC

```lua
local AICore = require(game.ServerScriptService.ServerModules.AI.AICore)

if AICore.IsControlling(npc) then
    print("AI is controlling this NPC")
end
```

### Manually Enable/Disable AI

```lua
local AICore = require(game.ServerScriptService.ServerModules.AI.AICore)

-- Enable AI
AICore.EnableAI(npc)

-- Disable AI
AICore.DisableAI(npc)
```

### Change Team Formation

```lua
local AICore = require(game.ServerScriptService.ServerModules.AI.AICore)

-- Switch to attacking formation
AICore.SetFormation("Blue", "Attacking")

-- Switch to defensive formation
AICore.SetFormation("Red", "Defensive")

-- Return to neutral
AICore.SetFormation("Blue", "Neutral")
```

### Debug AI Decisions

```lua
local AICore = require(game.ServerScriptService.ServerModules.AI.AICore)

local state = AICore.GetDecisionState(npc)
if state then
    print("State:", state.state)
    print("Action:", state.action)
    print("Priority:", state.priority)
    print("Reason:", state.transitionReason)
end
```

### Enable Debug Logging

Edit `ServerModules/AI/AIConfig.lua`:

```lua
AIConfig.DEBUG_MODE = true
AIConfig.LOG_DECISIONS = true
```

## Integration Points

### GameManager
- Loads AICore as `Managers.AIController`
- Initializes AI system with manager references
- Enables AI for all NPCs at game start

### PlayerController
- Disables AI when player possesses NPC
- Enables AI when NPC is spawned back
- Receives AICore reference during initialization

### TeamManager
- Provides team data to AI system
- Manages formations that AI uses for positioning

### NPCManager
- Provides field bounds and NPC data
- Used by AI for movement commands

### BallManager
- Provides ball state to AI system
- Used by AI for kick/pass/shoot actions

## File Structure

```
ServerModules/AI/
├── AICore.lua                    -- Main coordinator (use this!)
├── DecisionEngine.lua            -- Base decision logic
├── GoalkeeperDecisionEngine.lua  -- GK-specific decisions
├── BehaviorController.lua        -- Action execution
├── PositionCalculator.lua        -- Formation positioning
├── BallPredictor.lua             -- Ball trajectory prediction
├── TeamCoordinator.lua           -- Multi-NPC coordination
├── AIConfig.lua                  -- Tunable parameters
├── SafeMath.lua                  -- Safe math utilities
├── INTEGRATION.md                -- Detailed integration guide
└── QUICK_START.md                -- This file
```

## Tuning AI Behavior

Edit `AIConfig.lua` to adjust:

- **UPDATE_INTERVAL** - How often NPCs make decisions (default: 0.5s)
- **BALL_PURSUIT_RANGE** - How far NPCs chase the ball (default: 20 studs)
- **MAX_SHOT_DISTANCE** - Maximum shooting distance (default: 30 studs)
- **SPRINT_SPEED** - NPC sprint speed (default: 20 studs/s)
- And many more...

## Troubleshooting

### NPCs Not Moving
1. Check if AI is enabled: `AICore.IsControlling(npc)`
2. Check if NPC is valid (has Humanoid and HumanoidRootPart)
3. Enable debug logging in AIConfig.lua

### Poor AI Decisions
1. Adjust scoring weights in AIConfig.lua
2. Check formation data in FormationData.lua
3. Enable decision logging: `AIConfig.LOG_DECISIONS = true`

### Performance Issues
1. Increase UPDATE_INTERVAL in AIConfig.lua
2. Increase STAGGER_OFFSET to spread updates more
3. Check that only 10 NPCs are being controlled

## Need More Details?

See `INTEGRATION.md` for comprehensive documentation including:
- Complete API reference
- Usage patterns and examples
- Architecture overview
- Performance considerations
- Advanced debugging techniques
