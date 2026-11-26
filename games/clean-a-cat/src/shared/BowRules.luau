--!strict
-- BowRules: the bow tiers (issue 508, switch bowTiers). Every customer's cat the player washes by hand gets a bow,
-- and the bow pays a little more on top of the pay formula ("then + bow + tip", tuning pay). The plain Ribbon is
-- everyone's from the start; the better tiers are bought with coins, one after another, and kept for good. The tier
-- in use is always the best one bought (save.bow), so there is nothing to equip. The colour (pink, mint, sky) stays
-- the player's pick at the tub; the tier decides the look: Model-Agent's plain bow, its Double or its Royal model
-- (PR 556), with the plain look when a tier's model is not in the place yet.
-- Workers tie no bow (tuning bow.workers), so this bonus is only ever on a hand wash.
-- The numbers are Design-Agent's in docs/design/clean-a-cat/tuning.md, section 5; change them there and here
-- together. Pure, so tests/specs/BowRules.spec.luau covers it.
local BowRules = {}

BowRules.FLAG = "bowTiers"
BowRules.ATTRIBUTE = "BowTier" -- the Player attribute the server sets to the tier in use
BowRules.FIRST = "Ribbon"

-- In order, cheapest first.
BowRules.TIERS = table.freeze({ "Ribbon", "Silk", "Satin", "Golden" }) :: { string }

export type Tier = {
	name: string, -- as the board and the recap say it
	price: number, -- coins; 0 for the Ribbon, which is never sold
	bonus: number, -- coins on every hand washed customer's cat
	look: string, -- what goes after the colour in the bow's id ("BowPink" .. look), "" for the plain bow
}

BowRules.TIER = table.freeze({
	Ribbon = table.freeze({ name = "Ribbon", price = 0, bonus = 2, look = "" }),
	Silk = table.freeze({ name = "Silk", price = 150, bonus = 4, look = "Double" }),
	Satin = table.freeze({ name = "Satin", price = 600, bonus = 7, look = "Royal" }),
	-- no Golden model yet (Model-Agent's PR 556 has three looks), so it wears the Royal one until it has its own
	Golden = table.freeze({ name = "Golden", price = 2000, bonus = 12, look = "Royal" }),
}) :: { [string]: Tier }

-- A tier name made safe, else nil. For an attribute or a remote's argument.
function BowRules.clean(raw: unknown): string?
	if type(raw) ~= "string" or BowRules.TIER[raw] == nil then
		return nil
	end
	return raw
end

-- Whether `tier` is the player's: the Ribbon always is.
function BowRules.owns(bows: { [string]: boolean }, tier: string): boolean
	return tier == BowRules.FIRST or bows[tier] == true
end

-- The best tier bought: the one tied on every hand wash.
function BowRules.best(bows: { [string]: boolean }): string
	local best = BowRules.FIRST
	for _, tier in BowRules.TIERS do
		if BowRules.owns(bows, tier) then
			best = tier
		end
	end
	return best
end

-- The next tier on sale, or nil when the best is bought. Tiers are bought in order.
function BowRules.nextTier(bows: { [string]: boolean }): string?
	local at = table.find(BowRules.TIERS, BowRules.best(bows)) :: number
	return BowRules.TIERS[at + 1]
end

-- Whether the save may buy `tier` now, and the words to show when not.
function BowRules.canBuy(
	save: { coins: number, bows: { [string]: boolean } },
	tier: string
): (boolean, string?)
	local info = BowRules.TIER[tier]
	if info == nil or BowRules.owns(save.bows, tier) then
		return false, "You have that bow"
	end
	if BowRules.nextTier(save.bows) ~= tier then
		return false, "Buy the bows in order"
	end
	if save.coins < info.price then
		return false, `{info.price - save.coins} more coins for the {info.name} bow`
	end
	return true, nil
end

-- Buys `tier` for `save`: the coins come off, the tier is kept and is the one in use. Returns the coins spent, 0 when
-- it could not be bought.
function BowRules.buy(
	save: { coins: number, bows: { [string]: boolean }, bow: string },
	tier: string
): number
	if not BowRules.canBuy(save, tier) then
		return 0
	end
	local price = BowRules.TIER[tier].price
	save.coins -= price
	save.bows[tier] = true
	save.bow = BowRules.best(save.bows)
	return price
end

-- The coins `tier` adds to a hand washed customer's cat.
function BowRules.bonus(tier: string?): number
	local info = BowRules.TIER[BowRules.clean(tier) or BowRules.FIRST]
	return info.bonus
end

-- The worn bow's id for the colour picked at the tub and the tier in use: "BowPink" + "Double" = "BowPinkDouble", whose
-- model is CleanACat_Bow_PinkDouble (BowFit.assetName).
function BowRules.lookId(colourId: string, tier: string?): string
	local info = BowRules.TIER[BowRules.clean(tier) or BowRules.FIRST]
	return colourId .. info.look
end

return table.freeze(BowRules)
