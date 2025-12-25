# ⚽ Roblox 5v5 Soccer Game - Architecture Documentation

## 📋 Project Overview

A simplified tactical soccer game where NPCs are the primary players and human players "possess" and control NPCs on their team. The game features formation-based positioning, tactical AI, and player switching mechanics.

---

## 🎮 Core Concepts

- **NPCs are the "real" players** - 10 NPCs (5 per team) play soccer
- **Players control NPCs** - Human players possess and switch between NPCs on their team
- **Formation-based** - Each NPC has a designated position (GK, defenders, midfielders, forwards)
- **Tactical AI** - When not controlled by players, NPCs follow simple tactical rules
- **5v5 gameplay** - Blue team vs Red team

---

## 🏗️ Architecture Structure

### Server-Side Structure
```
ServerScriptService/
├── Main.lua (Script) - Entry point
└── Modules/ (Folder)
    ├── GameManager.lua - Core game orchestrator
    ├── TeamManager.lua - Team organization & slot management
    ├── NPCManager.lua - NPC spawning & field positioning
    ├── BallManager.lua - Ball physics & possession system
    ├── AIController.lua - NPC AI behavior
    ├── PlayerController.lua - Player-NPC binding
    ├── GoalManager.lua - Goal detection & scoring
    └── FormationData.lua - 5v5 formation definitions
```

### Client-Side Structure
```
StarterPlayer/StarterPlayerScripts/
├── ClientMain.lua - Client entry point
└── ClientModules/ (Folder)
    ├── NPCControlClient.lua - NPC possession & control
    ├── BallControlClient.lua - Ball kick mechanics
    ├── CameraController.lua - Camera follow system
    ├── InputHandler.lua - Input management
    └── UIController.lua - UI & scoreboard
```

---

## 📦 Module Responsibilities

### **FormationData.lua**
- Defines 5v5 formation positions (relative coordinates)
- Stores role names (GK, LB, RB, CM, LW, RW, ST)
- Provides formation data to other systems

### **NPCManager.lua**
- Reads Ground part size to calculate field dimensions
- Converts formation data to world positions
- Spawns NPCs from ServerStorage
- Positions NPCs on field according to formation
- Handles NPC respawning if needed

### **TeamManager.lua**
- Manages Blue and Red team data structures
- Tracks which slots are AI vs Player-controlled
- Handles team assignment and auto-balancing
- Stores team scores and goal references

### **BallManager.lua**
- Handles ball possession for both players AND NPCs
- Ball attachment/detachment logic
- Kick handling (ground and air kicks)
- Touch detection and cooldowns
- Ball physics and damping

### **PlayerController.lua**
- Manages player joining (spectator → active)
- Handles NPC possession switching
- Tracks player → NPC mapping
- Hides/freezes real player characters
- Enables/disables AI when switching

### **AIController.lua**
- Controls all NPCs not possessed by players
- **With Ball:** Pass to teammate ahead or shoot at goal
- **Without Ball:** Return to formation position
- Triggers ball touches and kicks programmatically

### **GoalManager.lua**
- Detects ball entering goal zones
- Awards points to correct team
- Resets ball to center after goal
- Broadcasts goal events to clients

### **GameManager.lua**
- Initializes all systems in correct order
- Manages game state (Waiting, Playing, Ended)
- Handles match timer and round resets
- Coordinates events between systems

---

## 🎯 Gameplay Features

### Player Controls
- **T Key** - Join team (auto-balanced)
- **Q Key** - Switch to closest NPC on your team
- **Mouse + WASD** - Control possessed NPC
- **Left Click (Hold)** - Charge ground kick
- **Right Click (Hold)** - Charge air kick

### NPC AI Behavior
When not controlled by players:
1. **Has Ball:**
   - Check for teammate ahead → Pass
   - If frontmost player → Move toward goal
   - If close to goal → Shoot

2. **No Ball:**
   - Return to formation position
   - Chase ball if very close

---

## 🔄 Implementation Batches

### **BATCH 1: Foundation & Data** ✅
- FormationData.lua - Formation definitions
- NPCManager.lua - Position calculation & spawning
- Test: Visualize positions on field

### **BATCH 2: Ball System Refactor**
- Refactor BallServerScript.lua → BallManager.lua
- Make ball system work with any character (player or NPC)
- Test: Ball system still works for players

### **BATCH 3: Team Management & NPC Spawning**
- TeamManager.lua - Team structure
- GameManager.lua - Initialization orchestrator
- Main.lua - Entry point
- Test: 10 NPCs spawn in formation

### **BATCH 4: Player Control & Spectator System**
- PlayerController.lua (server)
- ClientMain.lua + client modules
- Camera, input, and NPC control
- Test: Players can join and control NPCs

### **BATCH 5: Basic AI Behavior**
- AIController.lua - Basic AI
- Return to position behavior
- Test: AI NPCs walk to positions

### **BATCH 6: Advanced AI (Passing & Shooting)**
- Expand AIController.lua
- Pass and shoot logic
- Test: NPCs play soccer tactically

### **BATCH 7: Goal Detection & Scoring**
- GoalManager.lua
- UIController.lua (client)
- Test: Complete game loop

---

## 📐 Workspace Setup Required

### Workspace Structure
```
Workspace/
├── Pitch (Model)
│   ├── BlueGoal (Part) - Left side goal
│   ├── RedGoal (Part) - Right side goal
│   └── Ground (Part) - Field surface
└── Ball (Part) - Soccer ball
```

### ServerStorage Structure
```
ServerStorage/
└── NPCs (Folder)
    ├── Blue (R15 Character Model)
    └── Red (R15 Character Model)
```

---

## 🎨 Formation Layout (5v5)

```
                    [BLUE GOAL]
                        GK
            LB                      RB
                 LCM         RCM
            LW                      RW
                       ST
         ──────────── CENTER ────────────
                       ST
            LW                      RW
                 LCM         RCM
            LB                      RB
                        GK
                    [RED GOAL]
```

**Roles:**
- **GK** - Goalkeeper
- **LB/RB** - Left/Right Back (Defenders)
- **LCM/RCM** - Left/Right Center Midfielder
- **LW/RW** - Left/Right Winger
- **ST** - Striker (Forward)

---

## 🔑 Key Design Decisions

1. **Player characters are hidden** - Players only see/control NPCs
2. **Formation-based positioning** - NPCs have home positions
3. **AI uses same ball system** - NPCs trigger touch/kick events like players
4. **Auto-team balancing** - Players join smaller team automatically
5. **Closest NPC switching** - Q key switches to nearest teammate
6. **Modular architecture** - Each system is independent and testable

---

## 🚀 Current Status

**Completed:**
- Planning and architecture design
- Ball control system (existing BallServerScript.lua & BallClientScript.lua)

**In Progress:**
- BATCH 1: Foundation & Data (FormationData, NPCManager)

**Next Steps:**
- Complete BATCH 1 testing
- Begin BATCH 2: Ball system refactor

---

## 📝 Notes

- Field dimensions calculated dynamically from Ground part size
- All positions are calculated at runtime (flexible field sizes)
- NPC spawning handled by NPCManager using formation data
- Player real character stays in workspace but hidden/frozen
- Camera smoothly follows controlled NPC

---

*Last Updated: December 25, 2025*
