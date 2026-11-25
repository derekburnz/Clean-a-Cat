--!strict
-- DirtRules: how dirty a customer's cat is (switch dirtLevels; the owner's pick on the plan page, 2026-11-25: "the
-- cats look dirtier in their pictures the more dirty they are and take more steps to clean. Rarer the cat the more
-- likely its dirtier/has more steps but pays a lot more"). The server rolls a level from 1 to 4 for each customer
-- when it joins the line. The level decides:
--   * the mud and tangles on the cat: Model-Agent's dirty models carry every piece, each child Model with a
--     DirtLevel attribute, and the client takes away the pieces above the cat's level (trim);
--   * the later steps: level 2 adds the bath (lather and rinse), level 3 the claws as well, level 4 the most mud;
--   * the pay: coins and tip times PAY[level].
-- With the switch on, every step kind is in the game from the start (the owner's `steps` pick): no step waits on a
-- station. The numbers are drafts for Design-Agent's tuning pass. Pure, so tests/specs/DirtRules.spec.luau covers it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))

local DirtRules = {}

DirtRules.FLAG = CatRules.DIRT_FLAG
DirtRules.ATTRIBUTE = "DirtLevel" -- on each mud or tangle piece of a dirty model, and on the cat in the tub
DirtRules.LEVELS = 4

-- Percent per level (1 to 4) for each rarity; each row sums to 100. Rarer cats are more likely dirtier.
DirtRules.CHANCES = table.freeze({
	Common = table.freeze({ 55, 30, 12, 3 }),
	Uncommon = table.freeze({ 30, 40, 22, 8 }),
	Rare = table.freeze({ 12, 30, 38, 20 }),
	Epic = table.freeze({ 5, 20, 40, 35 }),
	Legendary = table.freeze({ 0, 10, 40, 50 }),
}) :: { [string]: { number } }

-- The later needs each level adds to the cat's rarity needs (CatRules.needs), in the wash's order.
DirtRules.EXTRA_NEEDS = table.freeze({
	table.freeze({}),
	table.freeze({ "smell" }),
	table.freeze({ "smell", "claws" }),
	table.freeze({ "smell", "claws" }),
}) :: { { CatRules.Need } }

-- A special visitor's cat (issue 510) is always this dirty.
DirtRules.SPECIAL_LEVEL = 4

-- What the coins and the tip are multiplied by at each level.
DirtRules.PAY = table.freeze({ 1, 1.5, 2, 3 }) :: { number }

-- A level made safe: a whole number from 1 to LEVELS, else nil. For a value from a remote or an attribute.
function DirtRules.clean(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 or raw < 1 or raw > DirtRules.LEVELS then
		return nil
	end
	return raw
end

-- One customer's dirt level. `random()` returns a number in [0, 1). The first customer of a save (`first`), who is
-- the tutorial's, is always level 1. A cat not on the roster rolls like a common one.
function DirtRules.roll(name: string, random: () -> number, first: boolean): number
	if first then
		return 1
	end
	local chances = DirtRules.CHANCES[CatRules.rarityOf(name) or "Common"]
	local pick = random() * 100
	local total = 0
	for level, percent in chances do
		total += percent
		if pick < total then
			return level
		end
	end
	return DirtRules.LEVELS
end

-- What a cat of `name` at `level` needs: its rarity's needs, then the level's later needs.
function DirtRules.needs(name: string, level: number): { CatRules.Need }
	local out = CatRules.needs(name)
	for _, need in DirtRules.EXTRA_NEEDS[DirtRules.clean(level) or 1] do
		if table.find(out, need) == nil then
			table.insert(out, need)
		end
	end
	return out
end

-- What `pay` comes to at `level`: coins and tip multiplied and rounded, the stars as they are.
function DirtRules.pay(pay: CatRules.Pay, level: number?): CatRules.Pay
	local times = DirtRules.PAY[DirtRules.clean(level) or 1]
	return {
		coins = math.floor(pay.coins * times + 0.5),
		tip = math.floor(pay.tip * times + 0.5),
		stars = pay.stars,
	}
end

-- How many steps a wash of these needs shows on the step bar: the scrub, the brush, the bath for a smell, the claws,
-- and the bow that ends every wash. The dryer is left out: it is a station's look, not a step the player does.
function DirtRules.steps(needs: { CatRules.Need }): number
	local count = 1 -- the bow
	for _, need in needs do
		if need ~= "wet" then
			count += 1
		end
	end
	return count
end

-- Whether a piece whose DirtLevel is `pieceLevel` stays on a cat at `level`: a piece with no level always stays.
function DirtRules.keeps(pieceLevel: unknown, level: number): boolean
	return type(pieceLevel) ~= "number" or pieceLevel <= level
end

return table.freeze(DirtRules)
