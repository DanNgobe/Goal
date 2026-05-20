--[[
	AIUtils.lua
	Shared utilities for AI system in Football_Game
	- Adapted for SlotManager and modern Logger
]]

local AIUtils = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = ReplicatedStorage:WaitForChild("Utils")
local Logger = require(Utils:WaitForChild("Logger")).new("AIUtils")

-- Modules
local AnimationData = require(ReplicatedStorage:WaitForChild("AnimationData"))

-- Dependencies (injected)
local SlotManager = nil

-- Configuration
local Config = {
	OpponentCheck = 25,   -- Radius to check for nearby opponents
	BlockingWidth = 8     -- Width of blocking zone for passes/shots
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function AIUtils.Initialize(slotManager)
	SlotManager = slotManager
	if not SlotManager then
		Logger:error("SlotManager missing during initialization!")
		return false
	end
	return true
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
	if not SlotManager then return players end

	local slots = SlotManager.GetTeamSlots(teamName)

	for _, slot in ipairs(slots) do
		local model = slot.Model -- This can be an NPC or Player character
		if model and model.Parent then
			local root = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")

			if root and humanoid and humanoid.Health > 0 then
				local dist = (root.Position - position).Magnitude
				if dist <= radius then
					table.insert(players, {
						Position = root.Position, 
						Distance = dist,
						Character = model
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
	if not SlotManager then return nil end
	local slot, teamName = SlotManager.GetSlotByModel(character)
	return teamName
end

-- Check if character is a teammate
function AIUtils.IsTeammate(character, teamName)
	return AIUtils.FindCharacterTeam(character) == teamName
end

-- Get opposite team
function AIUtils.GetOppositeTeam(teamName)
	return teamName == "HomeTeam" and "AwayTeam" or "HomeTeam"
end

-- Get opponent goal position
function AIUtils.GetOpponentGoalPosition(teamName)
	local oppositeTeam = AIUtils.GetOppositeTeam(teamName)
	return AIUtils.GetOwnGoalPosition(oppositeTeam)
end

-- Get own goal position
function AIUtils.GetOwnGoalPosition(teamName)
	local Stadium = workspace:FindFirstChild("Stadium")
	if not Stadium then return nil end
	
	local goalName = (teamName == "HomeTeam") and "HomeGoal" or "AwayGoal"
	local goal = Stadium:FindFirstChild(goalName)
	
	if not goal then
		Logger:warn(string.format("Goal '%s' not found in workspace.Stadium!", goalName))
	end
	
	return goal and goal.Position
end

return AIUtils
