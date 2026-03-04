--[[
	NPCNames.lua
	Provides a pool of cool soccer player names for NPCs
]]

local NPCNames = {}

-- Pool of gamer tag style names for NPCs
local GamerTags = {
	"ShadowStrike", "BlazeFury", "IceVenom", "ThunderBolt", "NightHawk",
	"PhantomX", "VortexKing", "RapidFire", "SilverBullet", "DarkKnight",
	"LightningFast", "NovaBlast", "CrimsonWave", "FrostBite", "StealthMode",
	"TurboCharge", "NeonGhost", "ViperStrike", "CyberNinja", "FlashBang",
	"ArcticWolf", "BlazeStar", "PixelHunter", "DragonFist", "MidnightRush",
	"EchoBlast", "StormChaser", "TitanForce", "OmegaRush", "AlphaStrike",
	"QuantumLeap", "RoguePanda", "SonicBoom", "LazerBeam", "VoidWalker",
    "NitroBoost", "PhoenixDown", "GhostRider", "IronClad", "ShadowBlade",
    "CobaltFury", "VoltageHigh", "FrozenSoul", "BlazeRunner", "CyberPunk",
    "DriftKing", "NeonSamurai", "ApexHunter", "RiftMaster", "PulseWave",
}

-- Generate a random gamer tag
function NPCNames.GetRandomName()
	local gamerTag = GamerTags[math.random(1, #GamerTags)]
	return gamerTag
end

-- Generate N unique gamer tags (no repeats in list)
function NPCNames.GetUniqueBatch(count)
	local usedIndices = {}
	local names = {}
	
	for i = 1, math.min(count, #GamerTags) do
		local tagIdx = math.random(1, #GamerTags)
		while usedIndices[tagIdx] do
			tagIdx = math.random(1, #GamerTags)
		end
		usedIndices[tagIdx] = true
		
		local gamerTag = GamerTags[tagIdx]
		table.insert(names, gamerTag)
	end
	
	return names
end

return NPCNames
