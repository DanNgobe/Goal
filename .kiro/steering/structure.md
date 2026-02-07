# Project Structure & Conventions

## Code Organization

### Server-Side (ServerScriptService)
- **Main.lua**: Single entry point script that initializes GameManager
- **ServerModules/**: All server logic as ModuleScripts
  - Manager modules handle specific systems (Team, NPC, Ball, Player, AI)
  - Each manager is self-contained with clear responsibilities
  - Dependencies passed via Initialize() methods

### Client-Side (StarterPlayer/StarterPlayerScripts)
- **ClientMain.lua**: Client entry point, initializes all client modules
- **ClientModules/**: Client-only logic
  - Input handling, camera control, UI, ball control client
  - No game logic - only presentation and input

### Shared (ReplicatedStorage)
- **AnimationData.lua**: Centralized animation asset IDs
- **RemoteEvent folders**: Communication channels (BallRemotes, PlayerRemotes, GoalRemotes, GameRemotes)

## Naming Conventions

### Files & Modules
- PascalCase for module names: `TeamManager.lua`, `BallControlClient.lua`
- Descriptive names indicating purpose: `FormationData`, `InputHandler`

### Variables
- PascalCase for services: `ReplicatedStorage`, `UserInputService`
- PascalCase for module references: `GameManager`, `NPCManager`
- camelCase for local variables: `currentOwner`, `ballAttachment`
- UPPER_SNAKE_CASE for constants: `MAX_SHOT_DISTANCE`, `UPDATE_INTERVAL`

### Functions
- PascalCase for public module functions: `TeamManager.Initialize()`, `GetTeamSlots()`
- Private functions use local or underscore prefix: `_FindWorkspaceObjects()`

### Teams & Roles
- Team names: "Blue", "Red" (capitalized strings)
- Roles: "GK", "DF", "LW", "RW", "ST" (uppercase abbreviations)

## Architecture Patterns

### Manager Pattern
Each system has a manager module with:
- Private state variables
- `Initialize()` function accepting dependencies
- Public API functions
- Optional `Cleanup()` for testing

### Dependency Injection
- Managers receive dependencies via Initialize()
- Example: `TeamManager.Initialize(blueGoal, redGoal, npcManager, formationData)`
- Avoids circular dependencies and improves testability

### Data Structures

**Team Slot Structure:**
```lua
{
    Index = number,
    Role = string,
    NPC = Model,
    HomePosition = Vector3,
    Controller = Player | nil,
    IsAI = boolean
}
```

**Formation Position:**
```lua
{
    Role = string,
    Name = string,
    Position = Vector3,
    ShortName = string
}
```

## Workspace Requirements

### Required Hierarchy
```
Workspace/
├── Pitch (Model)
│   ├── Ground (Part) - Field surface, used for dimension calculations
│   ├── BlueGoal (Part) - Left side goal
│   └── RedGoal (Part) - Right side goal
└── Ball (Part) - Soccer ball with Kick sound

ServerStorage/
└── NPCs (Folder)
    ├── Blue (R15 Character Model)
    └── Red (R15 Character Model)
```

## Collision Groups

- **Players**: Real player characters (hidden/frozen)
- **NPCs**: NPC characters
- **Default**: Ground, goals, walls
- Players and NPCs don't collide with each other, only with Default

## Formation System

Formations use relative coordinates (-1 to 1 scale):
- X axis: Left (-) to Right (+)
- Z axis: Back (-) to Forward (+) relative to own goal
- Converted to world positions by NPCManager based on Ground part size

Three formation types:
- **Neutral**: Default, balanced positioning
- **Attacking**: Pushed forward when team has ball
- **Defensive**: Pulled back when opponent has ball

## Event Flow Examples

**Goal Scored:**
1. BallManager detects ball in goal
2. TeamManager.OnGoalScored() updates score
3. Fire GoalScored RemoteEvent to clients
4. Reset positions, freeze teams
5. Wait intermission (5s)
6. Setup kickoff (defending team frozen)

**Player Joins:**
1. PlayerController receives join request
2. TeamManager.AssignPlayerToTeam() auto-balances
3. Hide/freeze player character
4. Bind player to NPC slot
5. Enable camera follow and input

## Code Style

### Self-Documenting Code
- **No comments in code** - code should be self-documenting
- Use descriptive variable and function names
- Structure code for clarity and readability
- Let the code explain what it does through clear naming and organization
- **Do not write tests automatically** - only create tests when explicitly requested

### Debug Practices
- Use descriptive print statements: `print("[ModuleName] Action description")`
- Prefix warnings: `warn("[ModuleName] Error description")`
- Success indicators: `✓` for success, `✗` for failure
- Log important state changes for debugging
