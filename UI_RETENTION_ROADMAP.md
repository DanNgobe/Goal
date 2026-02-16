# 🏆 UI & User Retention Roadmap

This document outlines the planned improvements for player experience, visual Polish, and long-term progression.

---

## 📺 Phase 1: Visual Hype & Onboarding
### 1.1 Match Intro (VS Screen) [COMPLETED]
- **Goal:** Build excitement before the whistle blows.
- **Features:**
    - Full-screen overlay showing Team A vs Team B.
    - Display country names and flags (or stylized icons).
    - Camera pan across the field or the starting lineups.
    - Delayed match start until intro finishes.

### 1.2 Onboarding / Controls Overlay
- **Goal:** Reduce friction for new players.
- **Features:**
    - Clean UI element in the bottom-left corner.
    - Toggleable with a key (e.g., `H` for Help).
    - Context-sensitive: Shows "Q - Tackle" when defending, "Space - Air Kick" when attacking, "M to...", "C to..."

---

## ⚽ Phase 2: In-Game Feedback
### 2.1 Goal & Assist Feed
- **Goal:** Recognize individual player performance.
- **Features:**
    - Small notification on the side of the screen.
    - Format: `[Scorer] SCORED! (Assist: [Teammate])`
    - Integration with `TeamManager` to track who last touched the ball before the scorer.

### 2.2 Live Match Stats
- **Goal:** Provide tactical feedback.
- **Features:**
    - Track **Possession %**, **Shots on Goal**, and **Pass Accuracy**.
    - Small "Stat Popups" during breaks (e.g., after a goal).

---

## 📊 Phase 3: Match End & Persistence
### 3.1 Advanced Match Summary
- **Goal:** Make the end of the game feel rewarding.
- **Features:**
    - Vertical table showing final stats for both teams.
    - MVP (Man of the Match) highlight with their character model.

### 3.2 World Cup Tournament Mode (Core Retention)
- **Goal:** Give players a reason to keep playing match after match.
- **System:**
    - **Pick Your Path:** At start, choose a national team just as you do right now. and ideally you must keep on choosing this team
    - **The Path:** Quarter-finals → Semi-finals → Final.
    - **Persistence:** If your team wins, you progress to the next...
    - **Permadeath:** If you lose or switch teams, you are knocked out and must restart from the beginning.
    - **Reward:** Trophies and unique cosmetics for winning the "World Cup".
    - We need great looking ui for this with brackets...

---

## 🛠️ Technical Implementation Checklist
- [ ] **Assist System:** Update `BallManager` to track `LastOwnerCharacter` (the person who passed the ball) in addition to `LastKickerCharacter`.
- [ ] **Stat Tracker:** Create a `StatTracker.lua` module to record:
    - Shots on goal (ball enters a "threat zone" or is kicked toward goal).
    - Possession time per team.
    - Pass completion rates.
- [ ] **Match Intro System:** Refactor `IntermissionUI` to handle "Intro" vs "Goal" vs "Match End" states.
- [ ] **World Cup Logic:** Build a `TournamentManager.lua` that saves player's progress and manages the "path" to the final.
- [ ] **Controls Overlay:** Add a toggleable UI layer in `UIController.lua`.
