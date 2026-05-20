# NPC & Player Character Customization System

## Overview
All NPCs use the **Male** template from `ServerStorage/NPCs/Male` with **country-based team colors** dynamically applied through SurfaceAppearance.

## Country Teams System

The game features **16 international teams** with authentic colors:

### Teams Available:
- 🇧🇷 **BRA** - Brazil (Yellow/Green)
- 🇦🇷 **ARG** - Argentina (Light Blue/White)
- 🇺🇾 **URU** - Uruguay (Sky Blue)
- 🏴󠁧󠁢󠁥󠁮󠁧󠁿 **ENG** - England (White/Red)
- 🇫🇷 **FRA** - France (Navy Blue/Red)
- 🇪🇸 **ESP** - Spain (Red/Gold)
- 🇩🇪 **GER** - Germany (White/Black)
- 🇮🇹 **ITA** - Italy (Blue)
- 🇳🇱 **NED** - Netherlands (Orange)
- 🇵🇹 **POR** - Portugal (Red/Green)
- 🇿🇦 **RSA** - South Africa (Gold/Green)
- 🇳🇬 **NGA** - Nigeria (Green/White)
- 🇺🇸 **USA** - United States (White/Red/Blue)
- 🇲🇽 **MEX** - Mexico (Green/Red)
- 🇯🇵 **JPN** - Japan (Blue)
- 🇰🇷 **KOR** - South Korea (Red)

## Structure Required
```
ServerStorage
└── NPCs
    └── Male (Character Model)
        ├── HumanoidRootPart
        ├── Humanoid
        ├── Body (BasePart with SurfaceAppearance)
        ├── Shirt (BasePart with SurfaceAppearance)
        ├── Shorts (BasePart with SurfaceAppearance)
        ├── Socks (BasePart with SurfaceAppearance)
        └── ... (other parts)
```

## How It Works

### Random Match Selection
Each match randomly selects two different countries:
- **HomeTeam** gets one random country
- **AwayTeam** gets a different random country
- Team colors are applied to NPCs automatically
- UI displays country names and colors dynamically

### Team Colors
Team colors are defined in `ReplicatedStorage/TeamData.lua`:

```lua
BRA = {
    Name = "Brazil",
    Code = "BRA",
    PrimaryColor = Color3.fromRGB(255, 220, 0),  -- Yellow (Shirt)
    SecondaryColor = Color3.fromRGB(0, 100, 40),  -- Green
    ShortsColor = Color3.fromRGB(30, 70, 200),    -- Blue
    SocksColor = Color3.fromRGB(255, 255, 255)    -- White
}
```

### Color Application
Colors are applied to **SurfaceAppearance** components:
- **Shirt** - PrimaryColor (main jersey color)
- **Shorts** - ShortsColor
- **Socks** - SocksColor
- **Body** - Standard skin tone (consistent across all teams)

### For NPCs
When NPCs spawn via `NPCManager.SpawnNPC()`:
1. Male template is cloned
2. Team colors are automatically applied
3. NPC is positioned and added to workspace

### For Players
Players use their **default Roblox character**. When they join a team:
1. Player joins team via **TeamJoinUI**
2. **PlayerController** calls `NPCManager.ApplyTeamColors()` on player's character
3. If player's character has matching parts (Shirt, Shorts, Socks, Body), colors are applied

**Note:** Players need to have the same Male template or at least parts named Shirt, Shorts, Socks, and Body with SurfaceAppearance for colors to work.

## Customizing Teams

### Add New Countries
Edit `ReplicatedStorage/TeamData.lua` and add new country definitions to the `Countries` table.

### Set Specific Match Teams
In `ServerModules/GameManager.lua`, replace `SetRandomMatchTeams()` with:
```lua
NPCManager.SetMatchTeams("BRA", "ARG")  -- Brazil vs Argentina
```

## Files Modified
- ✅ **ReplicatedStorage/TeamData.lua** (NEW) - Country team definitions
- ✅ **ServerModules/NPCManager.lua** - Uses TeamData for colors, random match setup
- ✅ **ServerModules/GameManager.lua** - Sets random match on initialization
- ✅ **ServerModules/PlayerController.lua** - Applies team colors to players on join
- ✅ **ClientModules/TeamColorHelper.lua** (NEW) - Client helper for team colors
- ✅ **ClientModules/UIController.lua** - Initializes TeamColorHelper
- ✅ **ClientModules/UI/ScoreboardUI.lua** - Dynamic team colors
- ✅ **ClientModules/UI/TeamJoinUI.lua** - Shows country names and colors
- ✅ **ClientModules/UI/IntermissionUI.lua** - Uses team colors for celebrations

## Setup Instructions
1. ✅ Ensure `ServerStorage/NPCs/Male` exists with the proper structure
2. ✅ Each clothing part (Shirt, Shorts, Socks, Body) should have a **SurfaceAppearance** child
3. ✅ `ReplicatedStorage/TeamData.lua` contains all country definitions
4. ✅ The system is ready - each match will have random countries!

## How Random Matches Work
1. **Game starts** → `GameManager` calls `NPCManager.SetRandomMatchTeams()`
2. **Two different countries are randomly selected** from the 16 available
3. **HomeTeam gets one country**, **AwayTeam gets another**
4. **Team colors replicate to clients** via `ReplicatedStorage/MatchTeams`
5. **All NPCs spawn with their country's colors**
6. **UI displays country names** instead of "HomeTeam/AwayTeam"
7. **Players get their team's colors** when they join
8. **🎉 When match ends:**
   - **New random countries are selected**
   - **All NPCs are despawned and respawned with new colors**
   - **UI automatically updates** with new team names and colors
   - **Clients detect the change** and refresh scoreboard/team join UI
   - **Next match begins** with completely different teams!

## Notes
- All NPCs share the same base Male model
- Customization is purely color-based through SurfaceAppearance
- Players spawn with default Roblox character
- When players join a team, their character gets team colors applied (if they have matching parts)
- **Each match features two random countries for variety**
- **Teams automatically change when a match ends** - the game never repeats the same matchup twice in a row
- **Client UI dynamically updates** when teams change (no refresh needed)
- To add more countries, just edit TeamData.lua
- Country codes are 3 letters (ISO-style)
