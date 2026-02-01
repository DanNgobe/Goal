--[[
	AIUtils.lua
	Shared utilities for AI system
	- Opponent awareness and path blocking
	- Team/character utilities
	- Position calculations
	- Animation playback
]]

local AIUtils = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))

-- Dependencies (injected)
local TeamManager = nil
local NPCManager = nil

-- Configuration
local Config = {
	OpponentCheck = 25,   -- Radius to check for nearby opponents
	BlockingWidth = 8     -- Width of blocking zone for passes/shots
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIUtils.Initialize(teamManager, npcManager)
	TeamManager = teamManager
	NPCManager = npcManager
	return TeamManager ~= nil and NPCManager ~= nil
end

--------------------------------------------------------------------------------
-- OPPONENT AWARENESS
--------------------------------------------------------------------------------

-- Check if path is blocked by opponents
function AIUtils.IsPathBlocked(fromPos, toPos, teamName)
	local oppositeTeam = AIUtils.GetOppositeTeam(teamName)
	local opponents = AIUtils.GetNearbyPlayers(fromPos, oppositeTeam, Config.OpponentCheck)

	local pathDir = (toPos - fromPos).Unit
	local pathLength = (toPos - fromPos).Magnitude

	for _, opponent in ipairs(opponents) do
		local toOpponent = opponent.Position - fromPos
		local projection = toOpponent:Dot(pathDir)

		-- Check if opponent is along the path
		if projection > 0 and projection < pathLength then
			local perpDist = (toOpponent - (pathDir * projection)).Magnitude

			-- If opponent is within blocking width, path is blocked
			if perpDist < Config.BlockingWidth then
				return true
			end
		end
	end

	return false
end

-- Get nearby players from a team
function AIUtils.GetNearbyPlayers(position, teamName, radius)
	local players = {}
	if not TeamManager then return players end

	local slots = TeamManager.GetTeamSlots(teamName)

	for _, slot in ipairs(slots) do
		if slot.NPC and slot.NPC.Parent then
			local root = slot.NPC:FindFirstChild("HumanoidRootPart")
			local humanoid = slot.NPC:FindFirstChildOfClass("Humanoid")

			if root and humanoid and humanoid.Health > 0 then
				local dist = (root.Position - position).Magnitude
				if dist <= radius then
					table.insert(players, {
						Position = root.Position, 
						Distance = dist,
						Character = slot.NPC
					})
				end
			end
		end
	end

	return players
end

--------------------------------------------------------------------------------
-- POSITION CALCULATIONS
--------------------------------------------------------------------------------

-- Blend two positions based on weight
function AIUtils.CalculateBlendedPosition(currentPos, formationPos, ballPos, formationWeight)
	local ballWeight = 1 - formationWeight
	return formationPos * formationWeight + ballPos * ballWeight
end

-- Calculate intercept position for defensive support
function AIUtils.CalculateInterceptPosition(currentPos, homePos, target)
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return homePos end

	local targetPos = targetRoot.Position
	return homePos * 0.3 + targetPos * 0.7
end

--------------------------------------------------------------------------------
-- TEAM UTILITIES
--------------------------------------------------------------------------------

-- Find which team a character belongs to
function AIUtils.FindCharacterTeam(character)
	if not NPCManager or not TeamManager then return nil end

	for _, teamName in ipairs({"Blue", "Red"}) do
		local npcs = NPCManager.GetTeamNPCs(teamName)
		for _, npcData in ipairs(npcs) do
			if npcData.Model == character then return teamName end
		end

		local slots = TeamManager.GetTeamSlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.NPC == character then return teamName end
		end
	end
	return nil
end

-- Check if character is a teammate
function AIUtils.IsTeammate(character, teamName)
	return AIUtils.FindCharacterTeam(character) == teamName
end

-- Get opposite team
function AIUtils.GetOppositeTeam(teamName)
	return teamName == "Blue" and "Red" or "Blue"
end

-- Get opponent goal position
function AIUtils.GetOpponentGoalPosition(teamName)
	if not TeamManager then return nil end

	local oppositeTeam = AIUtils.GetOppositeTeam(teamName)
	local teamData = TeamManager.GetTeam(oppositeTeam)
	return teamData and teamData.GoalPart and teamData.GoalPart.Position
end

-- Get own goal position
function AIUtils.GetOwnGoalPosition(teamName)
	if not TeamManager then return nil end

	local teamData = TeamManager.GetTeam(teamName)
	return teamData and teamData.GoalPart and teamData.GoalPart.Position
end

-- Get goal direction (which way the goal faces)
function AIUtils.GetGoalDirection(teamName, isOpponent)
	if not TeamManager then return nil end

	local targetTeam = isOpponent and AIUtils.GetOppositeTeam(teamName) or teamName
	local teamData = TeamManager.GetTeam(targetTeam)

	if teamData and teamData.GoalPart then
		-- Goal faces outward from the goal line
		-- Typically goals face along the Z axis
		return teamData.GoalPart.CFrame.LookVector
	end

	return nil
end

--------------------------------------------------------------------------------
-- ANIMATION
--------------------------------------------------------------------------------

-- Play kick animation for NPC
function AIUtils.PlayNPCKickAnimation(npc, root, direction, power, kickType)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animId = AnimationData.ChooseKickAnimation(root, direction, power, kickType)
	local originalWalkSpeed = humanoid.WalkSpeed

	humanoid.WalkSpeed = 0
	root.Anchored = true

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local kickAnimation = Instance.new("Animation")
	kickAnimation.AnimationId = animId
	local animTrack = animator:LoadAnimation(kickAnimation)
	animTrack:Play()

	task.spawn(function()
		-- Wait for animation to complete (max 0.5s to be safe)
		local waitTime = math.min(animTrack.Length, 0.45)
		task.wait(waitTime)

		if root and root.Parent and humanoid and humanoid.Parent then
			-- Stop animation first
			animTrack:Stop()

			-- Force unanchor and restore movement
			root.Anchored = false
			humanoid.WalkSpeed = originalWalkSpeed

			-- Reset humanoid state to ensure animations restart
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
end

return AIUtils
