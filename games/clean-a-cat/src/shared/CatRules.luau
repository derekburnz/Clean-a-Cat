--!strict
-- CatRules: the ten cats customers bring, how likely each rarity is, what each cat needs and what it pays.
-- Pure, so tests/specs/CatRules.spec.luau covers it. The server rolls from these tables and the chance board
-- (#33) shows the same tables, so a shown chance is always the real one. Numbers are draft tuning from the
-- first session plan (gdd-draft.md); Design-Agent owns them.

local WashDraft = require(script.Parent:WaitForChild("WashDraft"))

local CatRules = {}

export type Rarity = string -- one of RARITIES
export type Need = string -- "mud", "tangles", "wet", "smell" or "claws": a key of NEED_STATION

CatRules.RARITIES =
	table.freeze({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) :: { Rarity }

-- Percent per rarity for a new spa (star tier 1); sums to 100. Nothing paid changes these.
CatRules.CHANCES = table.freeze({
	Common = 60,
	Uncommon = 25,
	Rare = 11,
	Epic = 3.5,
	Legendary = 0.5,
}) :: { [string]: number }

-- Star tiers: a spa with more stars gets rarer customers. A tier starts at `stars`; each tier's chances sum to
-- 100 and no rarer chance ever goes down from one tier to the next. Stars come only from customers, so nothing
-- paid moves a spa up a tier.
export type Tier = { stars: number, chances: { [string]: number } }
CatRules.TIERS = table.freeze({
	table.freeze({ stars = 0, chances = CatRules.CHANCES }),
	table.freeze({
		stars = 15,
		chances = table.freeze({ Common = 54, Uncommon = 27, Rare = 13, Epic = 5, Legendary = 1 }),
	}),
	table.freeze({
		stars = 40,
		chances = table.freeze({ Common = 47, Uncommon = 28, Rare = 16, Epic = 7, Legendary = 2 }),
	}),
}) :: { Tier }
CatRules.TIER_ATTRIBUTE = "ChanceTier" -- Player attribute the server sets, so the board shows the player's tier

-- The cats, by rarity; each name matches Model-Agent's ReplicatedStorage.Assets.CleanACat_Cat_<Name>... models.
CatRules.ROSTER = table.freeze({
	Common = table.freeze({ "Cotton", "Inky", "Muffin", "Smudge" }),
	Uncommon = table.freeze({ "Patches", "Tux" }),
	Rare = table.freeze({ "Marble", "Toffee" }),
	Epic = table.freeze({ "LilacCloud" }),
	Legendary = table.freeze({ "Starcoat" }),
}) :: { [string]: { string } }

export type Pay = { coins: number, tip: number, stars: number }

-- What a customer pays when the cat goes back clean: coins, a tip for a clean job and stars for the spa.
CatRules.PAY = table.freeze({
	Common = table.freeze({ coins = 10, tip = 2, stars = 1 }),
	Uncommon = table.freeze({ coins = 15, tip = 3, stars = 1 }),
	Rare = table.freeze({ coins = 25, tip = 5, stars = 2 }),
	Epic = table.freeze({ coins = 40, tip = 8, stars = 3 }),
	Legendary = table.freeze({ coins = 80, tip = 15, stars = 5 }),
}) :: { [string]: Pay }

-- Station that each need takes; a need whose station is not built shows locked.
CatRules.NEED_STATION = table.freeze({
	mud = "Tub",
	tangles = "Brush",
	wet = "Dryer",
	smell = "BubbleBath", -- WashDraft, switch bubbleBath (#267)
	claws = "Pawdicure", -- WashDraft, switch pawdicure (#267)
}) :: { [string]: string }

-- The needs a cat may bring on top of its rarity's, in the order the wash does them: rolled per customer.
CatRules.LATER_NEEDS = table.freeze({ "smell", "claws" }) :: { Need }

CatRules.STARTING_STATIONS = table.freeze({ Tub = true, Brush = true }) :: { [string]: boolean }

-- The dirt levels' switch (DirtRules): with it on, every later step is in the wash from the start, with no station to
-- build first (the owner's `steps` pick, 2026-11-25). Here, not in DirtRules, because DirtRules needs this module.
CatRules.DIRT_FLAG = "dirtLevels"

-- Whether the later need `need` is in the game: a need with no switch always is; a later need is while its station's
-- switch or the dirt levels' switch is on.
function CatRules.needOn(need: Need, isOn: (flag: string) -> boolean): boolean
	local flag = WashDraft.NEED_FLAG[need]
	return flag == nil or isOn(flag) or isOn(CatRules.DIRT_FLAG)
end

-- The rarity of `name`, or nil for a name not on the roster.
function CatRules.rarityOf(name: string): Rarity?
	for _, rarity in CatRules.RARITIES do
		if table.find(CatRules.ROSTER[rarity], name) then
			return rarity
		end
	end
	return nil
end

-- The star tier (an index into TIERS) for a spa with `stars` stars.
function CatRules.tierFor(stars: number): number
	local tier = 1
	for index, entry in CatRules.TIERS do
		if stars >= entry.stars then
			tier = index
		end
	end
	return tier
end

-- A tier number made safe: a whole number within TIERS, else tier 1. For a value read from an attribute.
function CatRules.cleanTier(raw: unknown): number
	if type(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 or raw < 1 or raw > #CatRules.TIERS then
		return 1
	end
	return raw
end

-- The chances at a tier (tier 1 when nil).
function CatRules.chancesAt(tier: number?): { [string]: number }
	return CatRules.TIERS[CatRules.cleanTier(tier)].chances
end

-- The stars the next tier starts at, or nil at the top tier.
function CatRules.nextTierStars(tier: number?): number?
	local following = CatRules.TIERS[CatRules.cleanTier(tier) + 1]
	return if following then following.stars else nil
end

-- One customer's cat. `random()` returns a number in [0, 1) (Random.new():NextNumber in the game). `tier` is the
-- spa's star tier (1 when nil). The very first customer of a save (`first`) always brings a common cat, so the
-- board only lights up once its chances are true.
function CatRules.roll(random: () -> number, first: boolean, tier: number?): string
	local chances = CatRules.chancesAt(tier)
	local rarity = "Common"
	if not first then
		local pick = random() * 100
		local total = 0
		for _, candidate in CatRules.RARITIES do
			total += chances[candidate]
			if pick < total then
				rarity = candidate
				break
			end
		end
	end
	local cats = CatRules.ROSTER[rarity]
	local index = math.clamp(math.floor(random() * #cats) + 1, 1, #cats)
	return cats[index]
end

-- What a cat needs. Every cat needs the sponge and the brush; any cat rarer than common also has a wet coat
-- for the blow dryer, so rarer cats have more needs.
function CatRules.needs(name: string): { Need }
	local rarity = CatRules.rarityOf(name)
	if rarity == nil or rarity == "Common" then
		return { "mud", "tangles" }
	end
	return { "mud", "tangles", "wet" }
end

-- A customer's cat's needs: its rarity's (needs) plus each later need whose switch `isOn` and whose chance
-- (WashDraft.NEED_CHANCES) comes up. `random()` returns a number in [0, 1). With the switches off this is needs(name).
function CatRules.rollNeeds(
	name: string,
	random: () -> number,
	isOn: (flag: string) -> boolean
): { Need }
	local out = CatRules.needs(name)
	local rarity = CatRules.rarityOf(name) or "Common"
	for _, need in CatRules.LATER_NEEDS do
		local chance = WashDraft.NEED_CHANCES[need][rarity] or 0
		if isOn(WashDraft.NEED_FLAG[need]) and random() * 100 < chance then
			table.insert(out, need)
		end
	end
	return out
end

-- `needs` without the later needs that are off (needOn): a cat rolled with a smell keeps it only while bubbleBath
-- (or dirtLevels) is on, so switching a step off takes it out of the cats already waiting too.
function CatRules.liveNeeds(needs: { Need }, isOn: (flag: string) -> boolean): { Need }
	local out: { Need } = {}
	for _, need in needs do
		if CatRules.needOn(need, isOn) then
			table.insert(out, need)
		end
	end
	return out
end

-- The needs whose station is not in `stations` (built stations plus the starting ones). None while `isOn` says the
-- dirt levels are on, since then no step waits on a station.
function CatRules.lockedNeeds(
	needs: { Need },
	stations: { [string]: boolean },
	isOn: ((flag: string) -> boolean)?
): { Need }
	local locked: { Need } = {}
	if isOn and isOn(CatRules.DIRT_FLAG) then
		return locked
	end
	for _, need in needs do
		local station = CatRules.NEED_STATION[need]
		if not (CatRules.STARTING_STATIONS[station] or stations[station]) then
			table.insert(locked, need)
		end
	end
	return locked
end

export type BoardLine = { rarity: Rarity, percent: number, cats: { string } }

-- The chance board's lines at a star tier, read straight from TIERS and ROSTER (the tables roll uses), rarest
-- last. The board shows these and nothing else, so a shown chance is always the real one.
function CatRules.boardLines(tier: number?): { BoardLine }
	local chances = CatRules.chancesAt(tier)
	local lines: { BoardLine } = {}
	for _, rarity in CatRules.RARITIES do
		table.insert(lines, {
			rarity = rarity,
			percent = chances[rarity],
			cats = table.clone(CatRules.ROSTER[rarity]),
		})
	end
	return lines
end

-- A chance as the board prints it: "60%", "3.5%", "0.5%".
function CatRules.percentText(percent: number): string
	if percent == math.floor(percent) then
		return `{percent}%`
	end
	return `{string.format("%.1f", percent)}%`
end

-- What `name` pays. A cat not on the roster pays like a common one.
function CatRules.pay(name: string): Pay
	return CatRules.PAY[CatRules.rarityOf(name) or "Common"]
end

return table.freeze(CatRules)
