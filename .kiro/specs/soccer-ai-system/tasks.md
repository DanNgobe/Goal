# Implementation Plan: Soccer AI System

## Overview

This implementation plan breaks down the Soccer AI System into discrete, incremental coding tasks. Each task builds on previous work, with testing integrated throughout to validate functionality early. The implementation follows a bottom-up approach: building utility modules first, then core decision-making, then coordination, and finally integration.

## Tasks

- [x] 1. Set up AI module structure and configuration
  - Create the ServerModules/AI folder structure
  - Create AIConfig.lua with all tunable parameters
  - _Requirements: 15.1, 15.2, 15.3, 15.4_

- [x] 2. Implement BallPredictor utility module
  - Create BallPredictor.lua with prediction functions
  - Implement PredictPosition for moving balls with drag
  - Implement PredictLanding for airborne balls with gravity
  - Implement CanIntercept for interception opportunity detection
  - Implement PredictPassArrival for pass timing
  - _Requirements: 13.1, 13.3_

- [x] 3. Implement PositionCalculator module
  - Create PositionCalculator.lua with position calculation functions
  - Implement GetFormationPosition to retrieve base positions from FormationData
  - Implement AdjustForBall to dynamically adjust positions based on ball location
  - Implement GetGoalkeeperPosition for GK-specific positioning
  - Implement GetTargetPosition as main entry point combining all logic
  - _Requirements: 2.1, 2.2, 2.5, 9.1, 9.2, 9.3_

- [x] 4. Implement base DecisionEngine
  - Create DecisionEngine.lua with core decision logic
  - Implement DecisionEngine.new() constructor
  - Implement Decide() method with action scoring and selection
  - Implement ScorePass() with teammate evaluation
  - Implement ScoreShot() with distance and angle scoring
  - Implement ShouldPursue() with distance and role checks
  - Implement SelectDefensiveTarget() for marking logic
  - _Requirements: 4.1, 4.2, 5.1, 5.2, 5.4, 6.1, 7.1_

- [x] 5. Implement GoalkeeperDecisionEngine
  - Create GoalkeeperDecisionEngine.lua inheriting from DecisionEngine
  - Implement GoalkeeperDecisionEngine.new() with inheritance setup
  - Override Decide() with GK-specific logic (shot reactions, ball collection)
  - Override ShouldPursue() to be more conservative
  - Override ScorePass() to prioritize defenders
  - Implement IsShotIncoming() to detect incoming shots
  - Implement ReactToShot() for shot interception
  - Implement GetGoalkeeperPosition() for positioning logic
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 6. Implement BehaviorController for action execution
  - Create BehaviorController.lua with action execution methods
  - Implement MoveTo() using NPC_Manager for movement
  - Implement Pass() using Ball_Manager kick system
  - Implement Shoot() with aim calculation and Ball_Manager integration
  - Implement Dribble() for ball control while moving
  - Implement Pressure() for defensive positioning
  - Implement HoldPosition() for small positional adjustments
  - Add simple pathfinding with obstacle avoidance (max 5 waypoints)
  - _Requirements: 2.1, 2.3, 2.4, 4.3, 5.3, 6.2, 7.2, 11.1, 11.2_

- [x] 7. Implement TeamCoordinator for multi-NPC coordination
  - Create TeamCoordinator.lua with coordination functions
  - Implement AssignBallPursuer() to designate single pursuer
  - Implement CheckClustering() to detect NPC clustering
  - Implement GetPassingOptions() to find available receivers
  - Implement AssignDefensiveRoles() for defensive coverage
  - Implement PositionSupportPlayers() for attacking support
  - _Requirements: 3.3, 14.1, 14.2, 14.3, 14.4, 14.5_

- [x] 8. Implement AICore main coordinator
  - Create AICore.lua with lifecycle management (replaces AIController)
  - Implement Initialize() to set up references to game systems
  - Implement Update() with staggered update scheduling
  - Implement EnableAI() to add NPC to controlled list
  - Implement DisableAI() to remove NPC from controlled list
  - Implement SetFormation() to trigger formation changes
  - Implement GetDecisionState() for debugging queries
  - Create decision state storage and management
  - Implement state machine transitions (Idle, Positioning, Pursuing, Attacking, Defending)
  - _Requirements: 1.1, 1.2, 1.3, 10.1, 10.2, 11.5, 12.1, 12.3, 12.4, 12.5_

- [x] 9. Wire AICore to use all sub-modules
  - Integrate BallPredictor for ball state predictions
  - Integrate PositionCalculator for target position calculation
  - Integrate DecisionEngine (base and GK) for decision-making
  - Integrate BehaviorController for action execution
  - Integrate TeamCoordinator for multi-NPC coordination
  - Handle decision engine selection based on NPC role (GK vs outfield)
  - _Requirements: 15.1, 15.4, 15.5_

- [x] 10. Implement error handling and robustness
  - Add error handling to AICore
  - Add game state validation before decision updates
  - Add NPC validity checks before operations
  - Wrap manager calls in pcall for error catching
  - Add fallback behaviors for failed operations
  - Add error handling to BehaviorController
  - Add pathfinding failure fallbacks
  - Add safe math utilities (division by zero, normalization)
  - Add boundary checks for field positions
  - _Requirements: Error Handling section_

- [ ] 11. Implement additional decision behaviors
  - Add tactical state influence on decisions
  - Modify DecisionEngine to adjust action scores based on tactical state
  - Increase shooting/forward passing priority in Attacking formation
  - Increase defensive positioning priority in Defensive formation
  - Add pressure-based decision adjustments
  - Prioritize quick passing when under pressure
  - Re-evaluate decisions when opponents approach during dribbling
  - Add boundary awareness to BehaviorController
  - Detect when dribbling near field boundaries
  - Trigger direction change or pass when out of bounds imminent
  - _Requirements: 9.5, 4.5, 6.3, 6.4_

- [ ] 12. Implement remaining coordination and positioning
  - Add offensive support positioning to TeamCoordinator
  - Ensure at least two teammates position in passing lanes when NPC has possession
  - Calculate viable passing lane positions
  - Add pass reception movement to BehaviorController
  - When receiving a pass, move toward predicted arrival position
  - Use BallPredictor to calculate arrival position
  - Add defensive behaviors to DecisionEngine
  - Implement marking positioning (between opponent and goal)
  - Implement shot blocking positioning
  - Implement defensive positioning priority in defensive third
  - _Requirements: 14.2, 13.4, 7.3, 7.4, 7.5_

- [ ] 13. Add debugging and transparency features
  - Add debug logging to AICore
  - Implement conditional logging based on AIConfig.DEBUG_MODE
  - Log decision changes when AIConfig.LOG_DECISIONS is true
  - Add transition reason recording for state changes
  - Add visual debugging helpers (optional)
  - Create debug visualization for target positions
  - Create debug visualization for decision states
  - Create debug visualization for ball predictions
  - Only active when DEBUG_MODE is true
  - _Requirements: 12.2, 12.4_

- [ ] 14. Integration with existing game systems
  - Create integration interface for GameManager
  - Expose AICore.Initialize() for game setup
  - Expose AICore.Update() for frame updates
  - Expose AICore.SetFormation() for tactical changes
  - Ensure compatibility with existing AIController reference in GameManager
  - Update GameManager to load AI/AICore instead of AIController
  - Document integration points
  - Document how to initialize AI system with game managers
  - Document how to enable/disable AI for specific NPCs
  - Document how to change formations
  - Document how to query decision states for debugging
  - _Requirements: 11.5_

- [ ] 15. Performance optimization and tuning
  - Implement performance monitoring
  - Add frame time tracking to AICore
  - Add decision update timing measurements
  - Add adaptive update frequency based on performance
  - Optimize hot paths
  - Cache frequently calculated values (distances, angles) within decision cycle
  - Optimize pathfinding to use simplified paths
  - Ensure staggered updates distribute load evenly
  - Tune AIConfig parameters
  - Test with 10 AI-controlled NPCs
  - Adjust update intervals for performance
  - Adjust distance thresholds for behavior quality
  - Adjust scoring weights for tactical balance
  - _Requirements: 10.5, 10.2, 10.3, 10.4, 1.4, 10.1_

- [ ] 16. Final integration testing and validation
  - Test AI activation/deactivation with player possession
  - Test formation switching during gameplay
  - Test all 5 positions (GK, DF, LW, RW, ST) exhibit correct behaviors
  - Test both teams (Blue and Red) work correctly
  - Verify 30+ FPS maintained with 10 AI NPCs
  - Review all code for clarity and maintainability
  - Ensure all integration points are documented
  - Ensure AIConfig parameters are well-commented

## Notes

- Each task references specific requirements for traceability
- The implementation follows a bottom-up approach: utilities → decision-making → coordination → integration
- Goalkeeper logic inherits from base DecisionEngine while overriding specific behaviors
- AICore is the main module that GameManager will load (replaces the old AIController reference)
