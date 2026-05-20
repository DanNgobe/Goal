--[[
	AnimationData.lua
	Central repository for all game animations.
	Shared between client and server.
]]

local AnimationData = {
	-- Kick Animations
	Kick = {
		Strike_Right = "rbxassetid://115809739746167",
		Strike_Left = "rbxassetid://87347422649910",
		Pass_Right = "rbxassetid://101232833818763",
		Pass_Left = "rbxassetid://131234004506399",
		Scissor = "rbxassetid://74412352139090",
		Header = "rbxassetid://96881341423107",
	},

	-- Goalkeeper Animations
	Goalkeeper = {
		Jump_Catch = "rbxassetid://120158735199963",
		Left_Diving_Save = "rbxassetid://104077097570606",
		Right_Diving_Save = "rbxassetid://107595615836359",
		Standing_Catch = "rbxassetid://112887896538098",
		Scoop = "rbxassetid://75441372973211",
		Place_And_Kick = "rbxassetid://73223478432127",
		Sidestep = "rbxassetid://95230333121745",
	},

	-- Defensive Animations
	Defense = {
		Tackle = "rbxassetid://127395994301132",
	},

	-- Receive/Reaction Animations
	Reactions = {
		Warmup = "rbxassetid://89752039183068",
	},

	-- Movement Animations
	Movement = {
		Running = "rbxassetid://507767714",
		Jump = "rbxassetid://507765000",
		Fall = "rbxassetid://507767968",
		Spin = "rbxassetid://94948391532531",
	},

	-- Idle Animations
	Idle = {
		Offensive = "rbxassetid://74598805521607",
		Goalkeeper = "rbxassetid://73974345355398"
	},

	-- Dance Animations
	Dance = {
		Gangnam_Style = "rbxassetid://108123803411938",
		Running_Man = "rbxassetid://97594594456283",
		Slide_Celebration = "rbxassetid://105515485883474",
		Random = "rbxassetid://126872480936751",
		Ymca = "rbxassetid://83963928978630",
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
