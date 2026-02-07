# Technology Stack

## Platform

- **Roblox Studio** - Development environment
- **Luau** - Programming language (Roblox's typed Lua variant)

## Architecture

- **Client-Server Model**: Server-authoritative game logic with client-side input/UI
- **Modular Design**: Separate manager modules for each system
- **RemoteEvents**: Client-server communication for player actions and game events

## Key Libraries & Services

- `RunService` - Heartbeat loop for continuous updates
- `PhysicsService` - Collision group management
- `ReplicatedStorage` - Shared data and RemoteEvents
- `UserInputService` - Client input handling
- `Debris` - Automatic cleanup of temporary objects

## Project Structure

```
ServerScriptService/
├── Main.lua - Entry point, initializes GameManager
└── ServerModules/ - All server-side logic modules
    ├── GameManager.lua - Core orchestrator
    ├── TeamManager.lua - Team/slot management
    ├── NPCManager.lua - NPC spawning/positioning
    ├── BallManager.lua - Ball physics/possession
    ├── PlayerController.lua - Player-NPC binding
    ├── FormationData.lua - Formation definitions
    ├── MatchTimer.lua - Match timing
    └── AI/ - AI system modules

StarterPlayer/StarterPlayerScripts/
├── ClientMain.lua - Client entry point
└── ClientModules/ - Client-side modules
    ├── BallControlClient.lua - Ball kick mechanics
    ├── CameraController.lua - Camera follow system
    ├── InputHandler.lua - Input management
    └── UIController.lua - UI and scoreboard

ReplicatedStorage/
└── AnimationData.lua - Centralized animation IDs
```

## Common Patterns

### Module Structure
```lua
local ModuleName = {}

local PrivateVar = nil

function ModuleName.Initialize(dependencies)
    return true
end

function ModuleName.PublicMethod()
end

return ModuleName
```

### RemoteEvent Communication
- Server creates RemoteEvents in ReplicatedStorage folders
- Client fires to server: `RemoteEvent:FireServer(args)`
- Server fires to client: `RemoteEvent:FireClient(player, args)`
- Server fires to all: `RemoteEvent:FireAllClients(args)`

## Testing

- **Do not write tests automatically** - only create tests when explicitly requested
- Manual testing in Roblox Studio is primary testing method
- Test scripts can be created in workspace for specific systems when needed
- Property-based testing available for AI system (see `.kiro/specs/soccer-ai-system/`)

## Development Workflow

1. Edit code in Roblox Studio or external editor
2. Test in Studio's Play mode (F5)
3. Use output console for debug prints
4. Test multiplayer with Studio's multi-client testing

## Performance Considerations

- AI updates staggered (odd/even frame updates) to reduce load
- Collision groups prevent player/NPC collisions
- BodyVelocity objects cleaned up with Debris service
- Ball damping applied via Heartbeat for smooth physics
