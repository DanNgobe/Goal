--[[
	NPCNames.lua
	Provides a pool of cool soccer player names for NPCs
]]

local NPCNames = {}

-- Pool of cool player names (mix of real & believable names)
local FirstNames = {
	"Diego", "Lucas", "Carlos", "Miguel", "Antonio",
	"Rafael", "Fernando", "Marco", "Paolo", "Sergio",
	"Cristian", "Mateo", "Santiago", "Gabriel", "Jorge",
	"Eduardo", "Ricardo", "Alejandro", "Javier", "Ramon",
	"Dani", "Iker", "Xavi", "Andrés", "Fabio",
	"Thiago", "Neymar", "Karim", "Zinedine", "Pelé",
	"Ronaldo", "Ronaldinho", "Gianluigi", "Manuel", "Gennaro",
    "Francesco", "Alessandro", "Claudio", "Giorgio", "Luca",
    "Matteo", "Simone", "Davide", "Stefano", "Enzo",
    "Federico", "Giovanni", "Salvatore", "Vincenzo",
}

-- Generate a random unique name
function NPCNames.GetRandomName()
	local firstName = FirstNames[math.random(1, #FirstNames)]
	return firstName
end

-- Generate N unique names (no repeats in list)
function NPCNames.GetUniqueBatch(count)
	local usedIndices = {}
	local names = {}
	
	for i = 1, math.min(count, #FirstNames) do
		local firstIdx = math.random(1, #FirstNames)
		while usedIndices[firstIdx] do
			firstIdx = math.random(1, #FirstNames)
		end
		usedIndices[firstIdx] = true
		
		local firstName = FirstNames[firstIdx]
		table.insert(names, firstName)
	end
	
	return names
end

return NPCNames
