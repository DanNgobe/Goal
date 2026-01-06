--[[
	GoalManager.lua
	Handles goal detection, scoring, and round resets.
	
	Responsibilities:
	- Detect when ball enters goal zones
	- Award points to correct team
	- Reset ball to center after goal
	- Broadcast goal events to clients
	- Handle intermissions between goals
	
	Batch 7: Goal Detection & Scoring
]]

local GoalManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Private variables
local TeamManager = nil
local BallManager = nil
local Ball = nil
local BlueGoal = nil
local RedGoal = nil
local FieldCenter = nil

local GoalTouchConnections = {}
local IsProcessingGoal = false

-- Remote Events
local RemoteFolder = nil
local GoalScored = nil

-- Settings
local Settings = {
	IntermissionTime = 5,  -- Seconds between goals (increased)
	ResetBallHeight = 10,  -- Height to spawn ball at center
	KickoffFreezeDistance = 30  -- Distance defending team must stay back
}

-- Kickoff state
local IsKickoff = true
local KickoffTeam = "Blue"  -- Team that gets to kick off

-- Initialize the Goal Manager
function GoalManager.Initialize(teamManager, ballManager, ball, blueGoal, redGoal, fieldCenter)
	TeamManager = teamManager
	BallManager = ballManager
	Ball = ball
	BlueGoal = blueGoal
	RedGoal = redGoal
	FieldCenter = fieldCenter

	if not Ball then
		warn("[GoalManager] Ball not found!")
		return false
	end

	if not BlueGoal or not RedGoal then
		warn("[GoalManager] Goals not found!")
		return false
	end

	-- Create RemoteEvents
	RemoteFolder = ReplicatedStorage:FindFirstChild("GoalRemotes")
	if not RemoteFolder then
		RemoteFolder = Instance.new("Folder")
		RemoteFolder.Name = "GoalRemotes"
		RemoteFolder.Parent = ReplicatedStorage
	end

	GoalScored = Instance.new("RemoteEvent")
	GoalScored.Name = "GoalScored"
	GoalScored.Parent = RemoteFolder

	-- Setup goal detection
	GoalManager._SetupGoalDetection()

	-- Setup collision groups
	GoalManager._SetupCollisionGroups()

	-- Start in kickoff mode
	IsKickoff = true
	KickoffTeam = "Blue"
	GoalManager._FreezeTeams({"Red"})

	print("[GoalManager] Initialized - Goal detection active")
	return true
end

-- Private: Setup goal zone detection
function GoalManager._SetupGoalDetection()
	-- Blue Goal detection
	local blueConnection = BlueGoal.Touched:Connect(function(hit)
		if hit == Ball and not IsProcessingGoal then
			GoalManager._OnGoalScored("Red")  -- Red scores in Blue's goal
		end
	end)
	table.insert(GoalTouchConnections, blueConnection)

	-- Red Goal detection
	local redConnection = RedGoal.Touched:Connect(function(hit)
		if hit == Ball and not IsProcessingGoal then
			GoalManager._OnGoalScored("Blue")  -- Blue scores in Red's goal
		end
	end)
	table.insert(GoalTouchConnections, redConnection)
end

-- Private: Setup collision groups to prevent player-player and NPC-NPC collisions
function GoalManager._SetupCollisionGroups()
	local PhysicsService = game:GetService("PhysicsService")

	-- Create collision groups
	local success1 = pcall(function()
		PhysicsService:CreateCollisionGroup("Players")
	end)
	local success2 = pcall(function()
		PhysicsService:CreateCollisionGroup("NPCs")
	end)

	-- Set collision rules
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
		PhysicsService:CollisionGroupSetCollidable("NPCs", "NPCs", false)
		PhysicsService:CollisionGroupSetCollidable("Players", "NPCs", false)  -- Players don't collide with NPCs

		-- Make sure both groups can collide with Default group (ground, ball, etc.)
		PhysicsService:CollisionGroupSetCollidable("Players", "Default", true)
		PhysicsService:CollisionGroupSetCollidable("NPCs", "Default", true)
	end)

	print("[GoalManager] Collision groups configured - No player/NPC collisions")
end

-- Apply collision group to a character
function GoalManager.SetCharacterCollisionGroup(character, groupName)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = groupName
			end)
		end
	end
end

-- Private: Freeze specific teams
function GoalManager._FreezeTeams(teamNames)
	if not TeamManager then return end

	for _, teamName in ipairs(teamNames) do
		local slots = TeamManager.GetTeamSlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.NPC and slot.NPC.Parent then
				local humanoid = slot.NPC:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 0
					humanoid:MoveTo(slot.NPC.HumanoidRootPart.Position)
				end
			end
		end
	end

	print(string.format("[GoalManager] Frozen: %s", table.concat(teamNames, ", ")))
end

-- Private: Unfreeze all teams
function GoalManager._UnfreezeAllTeams()
	if not TeamManager then return end

	for _, teamName in ipairs({"Blue", "Red"}) do
		local slots = TeamManager.GetTeamSlots(teamName)
		for _, slot in ipairs(slots) do
			if slot.NPC and slot.NPC.Parent then
				local humanoid = slot.NPC:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 16  -- Default AI speed
				end
			end
		end
	end

	print("[GoalManager] All teams unfrozen")
end

-- Check if kickoff and handle ball touch
function GoalManager.OnBallTouched()
	if IsKickoff then
		IsKickoff = false
		GoalManager._UnfreezeAllTeams()
		print("[GoalManager] Kickoff complete - play started!")
	end
end

-- Private: Handle goal scored
function GoalManager._OnGoalScored(scoringTeam)
	if IsProcessingGoal then
		return
	end

	IsProcessingGoal = true

	-- Add score to team
	TeamManager.AddScore(scoringTeam, 1)

	-- Get current scores
	local blueScore = TeamManager.GetScore("Blue")
	local redScore = TeamManager.GetScore("Red")

	-- Broadcast to all clients
	GoalScored:FireAllClients(scoringTeam, blueScore, redScore)

	print(string.format("[GoalManager] GOAL! %s scored! Score: Blue %d - Red %d", 
		scoringTeam, blueScore, redScore))

	-- Reset all positions (players and NPCs)
	if TeamManager then
		TeamManager.ResetAllPositions()
	end

	-- Reset ball and game state
	GoalManager._ResetAfterGoal()

	-- Freeze everyone after reset
	GoalManager._FreezeTeams({"Blue", "Red"})

	-- Wait for intermission
	task.wait(Settings.IntermissionTime)

	-- Setup kickoff for opposite team
	IsKickoff = true
	KickoffTeam = scoringTeam == "Blue" and "Red" or "Blue"  -- Losing team kicks off
	local defendingTeam = scoringTeam

	-- Unfreeze everyone, then freeze defending team for kickoff
	GoalManager._UnfreezeAllTeams()
	GoalManager._FreezeTeams({defendingTeam})

	IsProcessingGoal = false
end

-- Private: Reset ball to center after goal
function GoalManager._ResetAfterGoal()
	if not Ball or not FieldCenter then
		return
	end

	-- Detach ball if possessed
	if BallManager then
		BallManager.DetachBall()
	end

	-- Reset ball position to center
	Ball.CFrame = CFrame.new(FieldCenter + Vector3.new(0, Settings.ResetBallHeight, 0))
	Ball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	Ball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	print("[GoalManager] Ball reset to center")
end

-- Manually reset ball (for testing or match start)
function GoalManager.ResetBall()
	GoalManager._ResetAfterGoal()
end

-- Get current processing state
function GoalManager.IsProcessingGoal()
	return IsProcessingGoal
end

-- Check if currently in kickoff
function GoalManager.IsInKickoff()
	return IsKickoff
end

-- Get which team is kicking off
function GoalManager.GetKickoffTeam()
	return KickoffTeam
end

-- Set intermission time
function GoalManager.SetIntermissionTime(seconds)
	Settings.IntermissionTime = seconds
end

-- Cleanup
function GoalManager.Cleanup()
	for _, connection in ipairs(GoalTouchConnections) do
		connection:Disconnect()
	end
	GoalTouchConnections = {}

	if RemoteFolder then
		RemoteFolder:Destroy()
	end

	IsProcessingGoal = false

	print("[GoalManager] Cleaned up")
end

return GoalManager
