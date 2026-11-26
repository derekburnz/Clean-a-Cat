--!strict
-- GardenRules: the Garden behind the back door (issue 515, tuning build.Garden, switch tubBuilds; models by Model-Agent,
-- issue 579). Until it is built, SpotGardenDoor holds the locked gate (LOCKED_ASSET), then the building site
-- (BUILDING_ASSET) while its build runs; once built, the finished garden (AREA_ASSET) stands there. With the switch
-- pets on too, the pets in the player's pen (not beside the player or a worker) play there: one on each of the
-- garden's pet spots, play spots and sit spots in turn (SpotPetPlay1, SpotPetSit1, SpotPetPlay2, ...), the best stars
-- first. Pure, so tests/specs/GardenRules.spec.luau covers it.
local GardenRules = {}

GardenRules.ID = "Garden" -- the BuildRules item and save.stations key
GardenRules.SPOT = "SpotGardenDoor" -- the plot spot all three looks are pivoted for
GardenRules.LOCKED_ASSET = "CleanACat_Area_GardenLocked"
GardenRules.BUILDING_ASSET = "CleanACat_Area_GardenBuilding"
GardenRules.AREA_ASSET = "CleanACat_Area_Garden"
GardenRules.AREA_NAME = "GardenArea" -- the finished garden's name in the plot's stations folder
GardenRules.PLAY_PREFIX = "SpotPetPlay"
GardenRules.SIT_PREFIX = "SpotPetSit"
GardenRules.SPOTS_ATTRIBUTE = "PetSpots" -- on the garden's root: how many pet spots it has
GardenRules.DEFAULT_SPOTS = 8
GardenRules.PET_SCALE = 0.7 -- the spots are sized for pets at this scale (Model-Agent)
GardenRules.PET_ATTRIBUTE = "GardenPet" -- on each pet in the garden: its spot number

export type Pet = { kind: string, star: number, slot: string? }
export type Seated = { kind: string, star: number }

-- The pets that play in the garden, in spot order: those in the pen (no slot), best star first and in save order
-- among the same star, at most `spots` of them.
function GardenRules.pets(pets: { Pet }, spots: number): { Seated }
	type Entry = { pet: Pet, order: number }
	local pen: { Entry } = {}
	for order, pet in pets do
		if pet.slot == nil then
			table.insert(pen, { pet = pet, order = order })
		end
	end
	table.sort(pen, function(a: Entry, b: Entry): boolean
		local starA: number, starB: number = a.pet.star, b.pet.star
		if starA ~= starB then
			return starA > starB
		end
		local orderA: number, orderB: number = a.order, b.order
		return orderA < orderB
	end)
	local out: { Seated } = {}
	for _, entry in pen do
		if #out >= spots then
			break
		end
		table.insert(out, { kind = entry.pet.kind, star = entry.pet.star })
	end
	return out
end

-- The Attachment name of pet spot `n` (1 based): play and sit spots in turn, so a few pets spread over the garden.
function GardenRules.spotName(n: number): string
	if n % 2 == 1 then
		return `{GardenRules.PLAY_PREFIX}{(n + 1) // 2}`
	end
	return `{GardenRules.SIT_PREFIX}{n // 2}`
end

-- The garden's pet spot count from its attribute, or the default when it is missing or not a sane whole number.
function GardenRules.spotCount(raw: unknown): number
	if type(raw) == "number" and raw >= 0 and raw <= 32 and raw == math.floor(raw) then
		return raw
	end
	return GardenRules.DEFAULT_SPOTS
end

return table.freeze(GardenRules)
