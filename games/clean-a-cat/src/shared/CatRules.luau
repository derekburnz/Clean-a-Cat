--!strict
-- CatRules: the ten cats customers bring, how likely each rarity is, what each cat needs and what it pays.
-- Pure, so tests/specs/CatRules.spec.luau covers it. The server rolls from these tables and the chance board
-- (#33) shows the same tables, so a shown chance is always the real one. Numbers are draft tuning from the
-- first session plan (gdd-draft.md); Design-Agent owns them.

local CatRules = {}

export type Rarity = string -- one of RARITIES
export type Need = string -- "mud", "tangles" or "wet": a key of NEED_STATION

CatRules.RARITIES =
	table.freeze({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) :: { Rarity }

-- Percent per rarity; sums to 100. Nothing paid changes these.
CatRules.CHANCES = table.freeze({
	Common = 60,
	Uncommon = 25,
	Rare = 11,
	Epic = 3.5,
	Legendary = 0.5,
}) :: { [string]: number }

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
}) :: { [string]: string }

CatRules.STARTING_STATIONS = table.freeze({ Tub = true, Brush = true }) :: { [string]: boolean }

-- The rarity of `name`, or nil for a name not on the roster.
function CatRules.rarityOf(name: string): Rarity?
	for _, rarity in CatRules.RARITIES do
		if table.find(CatRules.ROSTER[rarity], name) then
			return rarity
		end
	end
	return nil
end

-- One customer's cat. `random()` returns a number in [0, 1) (Random.new():NextNumber in the game). The very
-- first customer of a save (`first`) always brings a common cat, so the board only lights up once its
-- chances are true.
function CatRules.roll(random: () -> number, first: boolean): string
	local rarity = "Common"
	if not first then
		local pick = random() * 100
		local total = 0
		for _, candidate in CatRules.RARITIES do
			total += CatRules.CHANCES[candidate]
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

-- The needs whose station is not in `stations` (built stations plus the starting ones).
function CatRules.lockedNeeds(needs: { Need }, stations: { [string]: boolean }): { Need }
	local locked: { Need } = {}
	for _, need in needs do
		local station = CatRules.NEED_STATION[need]
		if not (CatRules.STARTING_STATIONS[station] or stations[station]) then
			table.insert(locked, need)
		end
	end
	return locked
end

export type BoardLine = { rarity: Rarity, percent: number, cats: { string } }

-- The chance board's lines, read straight from CHANCES and ROSTER (the tables roll uses), rarest last. The
-- board shows these and nothing else, so a shown chance is always the real one.
function CatRules.boardLines(): { BoardLine }
	local lines: { BoardLine } = {}
	for _, rarity in CatRules.RARITIES do
		table.insert(lines, {
			rarity = rarity,
			percent = CatRules.CHANCES[rarity],
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
