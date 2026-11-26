--!strict
-- CrateRules: crates and pets (issues 511 and 512, switch pets). A crate holds one pet, a cat, rolled on the server from
-- the chance list that shows on the crate before it is opened: every pet with its chance as a percentage, adding up to
-- 100, the same list the roll uses (`odds`), so a shown chance is always the real one. The same list serves earned and
-- bought crates; the day 2 crate ("good") has its own. Crates are earned (the weekly quests, the check in card, now and
-- then a special visitor) and, later, bought with Robux (issue 514, behind PolicyService); coins never buy one.
-- The player opens a crate with their own tap: no timers, no stock counters, no near miss.
-- A pet stays beside the player (their slot) or beside a worker (that worker's slot) and boosts by its rarity: with a
-- worker, that worker's pay (all their pets together capped at PET_CAP); with the player, their tips. Boosts add, never
-- multiply. A pet already owned is kept; three of the same pet at the same star fuse into one a star higher, for pets
-- only, never Robux, and the result is fixed.
-- The numbers are Design-Agent's in docs/design/clean-a-cat/tuning.md, section 10 (and worker.petCap); change them
-- there and here together. Pure, so tests/specs/CrateRules.spec.luau covers it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))

local CrateRules = {}

CrateRules.FLAG = "pets"
CrateRules.KINDS = table.freeze({ "normal", "good" }) :: { string }
CrateRules.CRATE_ATTRIBUTE_PREFIX = "Crates_" -- Player attribute Crates_<kind>: crates of that kind held
CrateRules.PET_ATTRIBUTE_PREFIX = "Pet_" -- Player attribute Pet_<slot>: "<kind>:<star>" of the pet in that slot
CrateRules.ODDS_NOTE =
	"Pets you already own are kept. Three of the same can be fused into a star up."

-- The pets by rarity: Model-Agent's CleanACat_Pet_<Name> models (the roster cat body, root attributes Pet, PetId,
-- Rarity and PetScale, a Burst attachment, star pieces as child Models with StarLevel 2 or 3). A rarity's chance is
-- split evenly between its pets.
CrateRules.PETS = table.freeze({
	Common = table.freeze({ "Cozy", "Scrubby" }),
	Uncommon = table.freeze({ "Pebble", "Pickle" }),
	Rare = table.freeze({ "Koi", "Bamboo" }),
	Epic = table.freeze({ "Coral" }),
	Legendary = table.freeze({ "Nimbus" }),
}) :: { [string]: { string } }

-- Percent per rarity for each crate kind; each sums to 100 (tuning crate.chance and crate.good).
CrateRules.CHANCES = table.freeze({
	normal = table.freeze({ Common = 50, Uncommon = 26, Rare = 16, Epic = 6, Legendary = 2 }),
	good = table.freeze({ Common = 30, Uncommon = 30, Rare = 24, Epic = 12, Legendary = 4 }),
}) :: { [string]: { [string]: number } }

-- Boost per rarity (tuning pet.boost), and times it at each star (pet.starUp).
CrateRules.BOOST =
	table.freeze({ Common = 0.05, Uncommon = 0.08, Rare = 0.12, Epic = 0.16, Legendary = 0.2 }) :: {
		[string]: number,
	}
CrateRules.STAR_TIMES = table.freeze({ 1, 1.5, 2 }) :: { number }
CrateRules.MAX_STAR = 3
CrateRules.FUSE_COUNT = 3
CrateRules.PET_CAP = 0.3 -- worker.petCap: a worker's pets together boost their pay at most this much
CrateRules.PLAYER_SLOT = "player"

-- The Robux crate (issue 514, switch crateShop; tuning crate.price): a developer product per row, each giving that many
-- normal crates, the very crate that is earned, with the same chance list. A paid random item: the chances show before
-- any buy, and a player whose PolicyService info restricts paid random items never sees it (the Player attribute
-- SHOP_ATTRIBUTE stays nil for them) and keeps the earned crates.
CrateRules.SHOP_FLAG = "crateShop"
CrateRules.SHOP_KIND = "normal"
CrateRules.SHOP_ATTRIBUTE = "CrateShop" -- Player attribute: true while this player may buy crates for Robux
CrateRules.SHOP = table.freeze({ CrateOne = 1, CrateFive = 5 }) :: { [string]: number } -- Products key -> crates
CrateRules.SHOP_KEYS = table.freeze({ "CrateOne", "CrateFive" }) :: { string } -- the shop's order

export type Odds = { pet: string, rarity: string, percent: number, boost: number }
export type Pet = { id: number, kind: string, star: number, slot: string? }

local PET_RARITY: { [string]: string } = {}
for _, rarity in CatRules.RARITIES do
	local pets: { string } = CrateRules.PETS[rarity] or {}
	for _, pet in pets do
		PET_RARITY[pet] = rarity
	end
end

function CrateRules.rarityOf(pet: string): string?
	return PET_RARITY[pet]
end

function CrateRules.cleanKind(raw: unknown): string?
	if type(raw) ~= "string" or CrateRules.CHANCES[raw] == nil then
		return nil
	end
	return raw
end

-- The chance list of crate `kind`: every pet with its percent and its boost at star 1, rarest last. The roll uses this
-- very list.
function CrateRules.odds(kind: string): { Odds }
	local chances = CrateRules.CHANCES[CrateRules.cleanKind(kind) or "normal"]
	local out: { Odds } = {}
	for _, rarity in CatRules.RARITIES do
		local pets = CrateRules.PETS[rarity]
		for _, pet in pets do
			table.insert(out, {
				pet = pet,
				rarity = rarity,
				percent = chances[rarity] / #pets,
				boost = CrateRules.BOOST[rarity],
			})
		end
	end
	return out
end

-- A pet from crate `kind`. `random()` returns a number in [0, 1).
function CrateRules.roll(kind: string, random: () -> number): string
	local list = CrateRules.odds(kind)
	local pick = random() * 100
	local total = 0
	for _, entry in list do
		total += entry.percent
		if pick < total then
			return entry.pet
		end
	end
	return list[#list].pet
end

-- How much one pet boosts, as a share (0.05 is +5%).
function CrateRules.boost(kind: string, star: number): number
	local rarity = CrateRules.rarityOf(kind)
	local times = CrateRules.STAR_TIMES[math.clamp(math.floor(star), 1, CrateRules.MAX_STAR)] or 1
	return if rarity then CrateRules.BOOST[rarity] * times else 0
end

-- The boosts of every pet in `slots` added together, at most `cap` when given.
function CrateRules.boostOf(pets: { Pet }, slots: { string }, cap: number?): number
	local total = 0
	for _, pet in pets do
		if pet.slot ~= nil and table.find(slots, pet.slot) then
			total += CrateRules.boost(pet.kind, pet.star)
		end
	end
	return if cap then math.min(total, cap) else total
end

-- The player's own slots: "player", and "player2" with the Second pet slot pass (`second`, issue 518).
function CrateRules.playerSlots(second: boolean?): { string }
	return if second
		then { CrateRules.PLAYER_SLOT, CrateRules.PLAYER_SLOT .. "2" }
		else { CrateRules.PLAYER_SLOT }
end

-- Worker `id`'s slots: "<id>1", and "<id>2" with the Second pet slot pass.
function CrateRules.workerSlots(id: string, second: boolean?): { string }
	return if second then { `{id}1`, `{id}2` } else { `{id}1` }
end

-- The slots a save has: the player's, and one beside each hired worker ("<id>1"); with `second` (the Second pet slot
-- pass, tuning pet.slots) two each. A pet left in a second slot once the pass no longer counts boosts nothing.
function CrateRules.slots(save: { workers: { [string]: any } }, second: boolean?): { string }
	local out = CrateRules.playerSlots(second)
	for id in save.workers do
		for _, slot in CrateRules.workerSlots(id, second) do
			table.insert(out, slot)
		end
	end
	table.sort(out)
	return out
end

type Save = {
	crates: { [string]: number },
	pets: { Pet },
	nextPetId: number,
	workers: { [string]: any },
}

local function find(save: Save, id: number): (Pet?, number?)
	for index, pet in save.pets do
		if pet.id == id then
			return pet, index
		end
	end
	return nil, nil
end

-- Opens one crate of `kind` from `save`: the pet goes into the save (into the player's slot when it is empty). Nil when
-- the save holds no such crate.
function CrateRules.open(save: Save, kind: string, random: () -> number): Pet?
	local clean = CrateRules.cleanKind(kind)
	if clean == nil or (save.crates[clean] or 0) < 1 then
		return nil
	end
	save.crates[clean] -= 1
	local pet: Pet =
		{ id = save.nextPetId, kind = CrateRules.roll(clean, random), star = 1, slot = nil }
	save.nextPetId += 1
	local playerSlotTaken = false
	for _, other in save.pets do
		if other.slot == CrateRules.PLAYER_SLOT then
			playerSlotTaken = true
		end
	end
	if not playerSlotTaken then
		pet.slot = CrateRules.PLAYER_SLOT
	end
	table.insert(save.pets, pet)
	return pet
end

-- Puts pet `id` in `slot` (nil sends it to the pen). A pet already there goes to the pen. False when the pet or the
-- slot is not the save's (`second`: the Second pet slot pass counts).
function CrateRules.place(save: Save, id: number, slot: string?, second: boolean?): boolean
	local pet = find(save, id)
	if pet == nil or (slot ~= nil and table.find(CrateRules.slots(save, second), slot) == nil) then
		return false
	end
	if slot ~= nil then
		for _, other in save.pets do
			if other.slot == slot then
				other.slot = nil
			end
		end
	end
	pet.slot = slot
	return true
end

-- Fuses the three pets `ids` (the same pet at the same star, below the top, all different and all the save's) into
-- the first of them a star higher; the other two are gone. Returns the fused pet, or nil and nothing changes.
function CrateRules.fuse(save: Save, ids: { number }): Pet?
	if #ids ~= CrateRules.FUSE_COUNT then
		return nil
	end
	local pets: { Pet } = {}
	for index, id in ids do
		if table.find(ids, id) ~= index then
			return nil -- the same pet twice
		end
		local pet = find(save, id)
		if pet == nil then
			return nil
		end
		table.insert(pets, pet)
	end
	local first = pets[1]
	for _, pet in pets do
		if pet.kind ~= first.kind or pet.star ~= first.star then
			return nil
		end
	end
	if first.star >= CrateRules.MAX_STAR then
		return nil
	end
	for index = 2, #pets do
		local _, at = find(save, pets[index].id)
		if at then
			table.remove(save.pets, at)
		end
	end
	first.star += 1
	return first
end

return table.freeze(CrateRules)
