--!strict
-- StarterRules: the starter pack (issue 519; tuning starterPack; Growth-Agent's starter pack check). One developer
-- product that gives three passes together: the Golden Sponge, the Second pet slot and 2x Coins, fixed and never
-- random, no coins and no crate. It is offered for 72 hours of real time from the player's first join (a save from
-- before the switch went on starts its 72 hours at its first join after), kept on the server, and never restarts or
-- extends: at zero it is gone for that player for good, and the three passes stay in the shop at their own prices. It
-- is offered only to a player who owns none of the three, and only from the end of the tutorial (SpaRules
-- TUTORIAL_ENDS_AT). The window opens only when the player taps the button.
-- Pure, so tests/specs/StarterRules.spec.luau covers it; StarterService runs it. Behind the LiveFlags switch
-- starterPack (with passes on too, since the pack gives passes).

local StarterRules = {}

StarterRules.FLAG = "starterPack"
StarterRules.PRODUCT = "StarterPack" -- the Products key
StarterRules.CONTENTS =
	table.freeze({ "GoldenSponge", "SecondPetSlot", "DoubleCoins" }) :: { string }

-- (switch starterBuilder, issue 1097, Derek 2026-11-27: "remove the golden sponge from starter pack it seems lame
-- replace with something else") The pack gives the Second Builder in place of the Golden Sponge, still 199 Robux; the
-- Golden Sponge stays in the shop on its own. CONTENTS above is the pack with the switch off.
StarterRules.BUILDER_FLAG = "starterBuilder"
StarterRules.BUILDER_CONTENTS =
	table.freeze({ "SecondPetSlot", "DoubleCoins", "SecondBuilder" }) :: { string }

-- The pack's three passes now: BUILDER_CONTENTS with starterBuilder on, else CONTENTS. `isOn` is LiveFlags.isOn.
function StarterRules.contents(isOn: ((key: string) -> boolean)?): { string }
	return if isOn and isOn(StarterRules.BUILDER_FLAG)
		then StarterRules.BUILDER_CONTENTS
		else StarterRules.CONTENTS
end

-- What the grant's notice lists, by pass key.
StarterRules.NAMES = table.freeze({
	GoldenSponge = "the Golden Sponge",
	SecondPetSlot = "a second pet slot",
	DoubleCoins = "2x Coins",
	SecondBuilder = "a second builder",
}) :: { [string]: string }

-- "a, b and c" from `keys` (a pack's contents), with `first` ahead when given.
function StarterRules.listText(keys: { string }, first: string?): string
	local words: { string } = {}
	if first then
		table.insert(words, first)
	end
	for _, key in keys do
		table.insert(words, StarterRules.NAMES[key] or key)
	end
	if #words == 1 then
		return words[1]
	end
	return table.concat(words, ", ", 1, #words - 1) .. " and " .. words[#words]
end
StarterRules.SHOW_FROM = 2 * 60 + 45 -- seconds of play: the end of the tutorial (SpaRules.TUTORIAL_ENDS_AT)

-- (switch starterPet, issue 1090, Derek 2026-11-27: "make it like a golden flashing pet ... or something crazy") The
-- pack also gives PET, a starter-only golden pet: never rolled from a crate (CrateRules.GIFT_PETS), boosting like any
-- PET_RARITY pet, so no stronger than the best crate pet. It has no shop price, so the pack's struck total stays the
-- sum of the three passes. Given once per save (save.starterPet): with the pack's grant, and on join to a save that
-- bought the pack before the switch (all three passes in save.passes; the live game has sold no pack yet).
StarterRules.PET_FLAG = "starterPet"
StarterRules.PET = "Midas" -- Model-Agent's CleanACat_Pet_Midas (gold coat, crown and wings; model attribute Starter)
StarterRules.PET_RARITY = "Epic"

type Pet = { id: number, kind: string, star: number, slot: string? }

local function holdsAll(passes: { [string]: boolean }, keys: { string }): boolean
	for _, key in keys do
		if passes[key] ~= true then
			return false
		end
	end
	return true
end

-- Whether `passes` (save.passes) hold all three passes of the pack, as it was (CONTENTS) or is with starterBuilder
-- (BUILDER_CONTENTS): the pack was bought (or all three were).
function StarterRules.boughtBefore(passes: { [string]: boolean }): boolean
	return holdsAll(passes, StarterRules.CONTENTS)
		or holdsAll(passes, StarterRules.BUILDER_CONTENTS)
end

-- Gives the starter pet into `save` once: into the player's slot when it is empty. Nil when it was given already.
function StarterRules.givePet(
	save: { pets: { Pet }, nextPetId: number, starterPet: boolean },
	playerSlot: string
): Pet?
	if save.starterPet then
		return nil
	end
	save.starterPet = true
	local pet: Pet = { id = save.nextPetId, kind = StarterRules.PET, star = 1, slot = nil }
	save.nextPetId += 1
	local taken = false
	for _, other in save.pets do
		if other.slot == playerSlot then
			taken = true
		end
	end
	if not taken then
		pet.slot = playerSlot
	end
	table.insert(save.pets, pet)
	return pet
end

-- Player attributes for Design's button and window and Motion-FX's attention bob.
StarterRules.ENDS_ATTRIBUTE = "StarterEndsAt" -- os.time() the offer ends, set only while it is offered
StarterRules.OPENED_ATTRIBUTE = "StarterOpened" -- true once the player opened the window
StarterRules.VISITS_ATTRIBUTE = "Visits" -- joins of this save, the first included

-- Whether the pack is offered: before its end, after the tutorial, and the player owning none of the three
-- (`contents`, StarterRules.contents; CONTENTS when nil).
function StarterRules.offered(
	endsAt: number,
	now: number,
	played: number,
	owns: (key: string) -> boolean,
	contents: { string }?
): boolean
	if endsAt <= 0 or now >= endsAt or played < StarterRules.SHOW_FROM then
		return false
	end
	for _, key in contents or StarterRules.CONTENTS do
		if owns(key) then
			return false
		end
	end
	return true
end

-- Hours from the offer's start (its end less 72 hours) to `now`, for pack_bought.
function StarterRules.hoursIn(endsAt: number, now: number, length: number): number
	return math.max(0, math.floor((now - (endsAt - length)) / 3600))
end

return table.freeze(StarterRules)
