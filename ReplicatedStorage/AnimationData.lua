--[[
	AnimationData.lua
	Central repository for all game animations.
	Shared between client and server.
]]

local AnimationData = {
	-- Kick Animations
	Kick = {
		Strike_Right = "rbxassetid://76069154190283",
		Strike_Left = "rbxassetid://108579500601701",
		Pass_Right = "rbxassetid://133927349049921",
		Pass_Left = "rbxassetid://99205226261734",
		Penalty_Right = "rbxassetid://116121335607160",
		Penalty_Left = "rbxassetid://99585716270614",
		Scissor = "rbxassetid://74338726601668",
		Header = "rbxassetid://94820443873245",
	},
	
	-- Goalkeeper Animations
	Goalkeeper = {
		Jump_Catch = "rbxassetid://119888679150732",
		Left_Diving_Save = "rbxassetid://134119711911427",
		Right_Diving_Save = "rbxassetid://118774312513760",
		Standing_Catch = "rbxassetid://110067978291476",
		Scoop = "rbxassetid://90457004291903",
		Throw = "rbxassetid://135849061306619",
		Place_And_Kick = "rbxassetid://103229672981962",
	},
	
	-- Defensive Animations
	Defense = {
		Tackle = "rbxassetid://125557299989744",
		Tackle_Reaction = "rbxassetid://81895517933113",
	},
	
	-- Receive/Reaction Animations
	Reactions = {
		Chest_Receive = "rbxassetid://107892350986805",
		Defeat = "rbxassetid://128827561762854",
	},
	
	-- Movement Animations
	Movement = {
		Running = "rbxassetid://84576343092696",
		Jump = "rbxassetid://127586004923181",
		Fall = "rbxassetid://138262391726997",
		Spin = "rbxassetid://97707998406279",
	},
	
	-- Idle Animations
	Idle = {
		Offensive = "rbxassetid://99972725424538",
		Goalkeeper = "rbxassetid://92162025465133"
	},
}

-- Helper function to choose kick animation based on context
function AnimationData.ChooseKickAnimation(rootPart, direction, power, kickType)
	if not rootPart or not direction then
		return AnimationData.Kick.Strike_Right
	end
	
	-- Determine if ball is going left or right relative to character
	local characterRight = rootPart.CFrame.RightVector
	local dotRight = characterRight:Dot(direction)
	
	-- Determine if it's a pass (low power) or strike (high power)
	local isStrike = power > 0.85 or kickType == "Air"
	
	if isStrike then
		-- Strike animations (powerful shots)
		if dotRight > 0 then
			return AnimationData.Kick.Strike_Right
		else
			return AnimationData.Kick.Strike_Left
		end
	else
		-- Pass animations (lower power passes)
		if dotRight > 0 then
			return AnimationData.Kick.Pass_Right
		else
			return AnimationData.Kick.Pass_Left
		end
	end
end

return AnimationData
