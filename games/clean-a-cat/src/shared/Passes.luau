--!strict
-- Passes: the game's five game passes (issue 518; tuning section 13). A game pass is a one time Robux purchase that
-- stays with the player for good. Each is listed by our own key with the pass id the owner gets when he creates it
-- on the group's game (Creator Hub > the game > Monetization > Passes). An id of 0 means "not created yet": its
-- button stays hidden and it can never be prompted. Prices are not here: the owner sets each on Roblox and
-- PassService reads it back (GetProductInfo) into the ReplicatedStorage attribute PRICE_PREFIX .. key, which the
-- buttons show before the confirm. Pass ids are public on Roblox, so they are fine in this repo.
--
-- The server keeps the Player attribute ATTRIBUTE_PREFIX .. key = true for each pass a player owns (PassService),
-- so the client can show what it changes (the Golden Sponge's gold bubbles, a second pet slot) and hide its button.
-- Shared, so a client can tell which buttons exist; only the server gives anything. Behind the LiveFlags switch
-- passes.
--
-- Each experience has its own passes (Derek, 2026-11-26, q2-wheremake), listed per experience as Products' are; IDS is
-- the set of the experience this runs in, and every id is 0 anywhere else.
--
-- The coin ladder (issue 1031, Derek 2026-11-27: "2x/3x coins ... make 3x appear when 2x is purchased"): 3x Coins
-- (TripleCoins) is offered only once 2x Coins is owned, with the switch coinLadder on (Passes.offered), and takes the
-- place of 2x on a hand wash (3 times, never 6). It always works once owned, switch or not.

local Products = require(script.Parent:WaitForChild("Products"))

local Passes = {}

Passes.FLAG = "passes"
Passes.PRICE_PREFIX = "PassPrice_"
Passes.ATTRIBUTE_PREFIX = "Pass_" -- Player attribute: true while the player owns that pass

-- What each pass does, in the tuning's words, for the shop card.
export type Info = {
	name: string,
	text: string,
}

-- key -> pass id, per experience; the shop's order is KEYS.
Passes.IDS_BY_GAME = table.freeze({
	[Products.DEV_GAME_ID] = table.freeze({
		DoubleCoins = 2098734880,
		TripleCoins = 0, -- made by store-setup (passes), then its id goes here
		SecondBuilder = 2098968783,
		GoldenSponge = 2102105899,
		Lou = 2100252843,
		SecondPetSlot = 2098518803,
	}),
	[Products.LIVE_GAME_ID] = table.freeze({
		DoubleCoins = 0,
		TripleCoins = 0,
		SecondBuilder = 0,
		GoldenSponge = 0,
		Lou = 0,
		SecondPetSlot = 0,
	}),
}) :: { [number]: { [string]: number } }

-- Every key with id 0, with the design's price for each: the set for an experience not listed above.
Passes.NONE = table.freeze({
	DoubleCoins = 0, -- 2x Coins (SaleRules.REGULAR_PASSES)
	TripleCoins = 0, -- 3x Coins, offered once 2x is owned
	SecondBuilder = 0, -- Second Builder (299)
	GoldenSponge = 0, -- Golden Sponge (99)
	Lou = 0, -- Extra Worker, Lou the third helper (249)
	SecondPetSlot = 0, -- Second pet slot (249)
}) :: { [string]: number }

-- key -> pass id in the experience this runs in.
Passes.IDS = Products.pick(Passes.IDS_BY_GAME, Products.currentGame(), Passes.NONE)

Passes.KEYS = table.freeze({
	"DoubleCoins",
	"TripleCoins",
	"SecondBuilder",
	"GoldenSponge",
	"Lou",
	"SecondPetSlot",
}) :: { string }

Passes.INFO = table.freeze({
	DoubleCoins = table.freeze({
		name = "2x Coins",
		text = "Every cat you wash by hand pays double",
	}) :: Info,
	TripleCoins = table.freeze({
		name = "3x Coins",
		text = "Every cat you wash by hand pays triple, in place of double",
	}) :: Info,
	SecondBuilder = table.freeze({
		name = "Second Builder",
		text = "Build a tub or station and a room at the same time",
	}) :: Info,
	GoldenSponge = table.freeze({
		name = "Golden Sponge",
		text = "The best sponge with gold bubbles, and +20% on every cat you wash by hand",
	}) :: Info,
	-- the pass is "Extra Worker", never the helper's own name (Derek, 2026-11-27); the key stays Lou in saves and code
	Lou = table.freeze({ name = "Extra Worker", text = "A third helper, with his own wash stand" }) :: Info,
	SecondPetSlot = table.freeze({
		name = "2nd pet slot", -- short enough for the small phone Shop card (issue 838)
		text = "A second pet for you and every helper",
	}) :: Info,
}) :: { [string]: Info }

-- Hand wash pay (tuning worker.doubleCoins: hand washes only, never a worker's pay or the tip jar).
Passes.DOUBLE_TIMES = 2
Passes.TRIPLE_TIMES = 3 -- 3x Coins, in place of DOUBLE_TIMES (never both)
Passes.LADDER_FLAG = "coinLadder"
Passes.SPONGE_TIMES = 1.2

-- The pass id for `key`, or nil while it is not created (0) or unknown.
function Passes.id(key: string): number?
	local id = Passes.IDS[key]
	return if type(id) == "number" and id > 0 then id else nil
end

-- Our key for a pass id, or nil.
function Passes.keyOf(id: number): string?
	if id <= 0 then
		return nil
	end
	for key, value in Passes.IDS do
		if value == id then
			return key
		end
	end
	return nil
end

-- Whether the shop offers pass `key` now. The coin ladder shows one rung: 2x Coins until 3x is offered; 3x Coins
-- only while coinLadder is on and 2x is owned (or 3x is owned already, so its card says Owned), and then in 2x's
-- place, as it pays in its place. Every other pass always.
function Passes.offered(
	key: string,
	owns: (key: string) -> boolean,
	isOn: (flag: string) -> boolean
): boolean
	local triple = owns("TripleCoins") or (isOn(Passes.LADDER_FLAG) and owns("DoubleCoins"))
	if key == "TripleCoins" then
		return triple
	elseif key == "DoubleCoins" then
		return not triple
	end
	return true
end

-- The most cards the shop shows at once: every pass but one rung of the coin ladder.
Passes.SHOP_CARDS = 5

-- The extra coins the pay passes add to a hand wash that paid `coins`: 2x Coins doubles it (3x Coins triples it in
-- its place) and the Golden Sponge adds 20%, one on top of the other (2x and the sponge give 2.4 times, 3x and the
-- sponge 3.6). 0 with none.
function Passes.handExtra(coins: number, owns: (key: string) -> boolean): number
	local times = 1
	if owns("TripleCoins") then
		times *= Passes.TRIPLE_TIMES
	elseif owns("DoubleCoins") then
		times *= Passes.DOUBLE_TIMES
	end
	if owns("GoldenSponge") then
		times *= Passes.SPONGE_TIMES
	end
	return math.max(0, math.floor(coins * times + 0.5) - coins)
end

-- Every recap line handLine can give, for the client's check of a recap.
Passes.LINES = table.freeze({
	"3x Coins and Golden Sponge",
	"3x Coins",
	"2x Coins and Golden Sponge",
	"2x Coins",
	"Golden Sponge",
}) :: { string }

-- The recap line's words for the pay passes a player owns, or nil with neither.
function Passes.handLine(owns: (key: string) -> boolean): string?
	local triple, double, sponge = owns("TripleCoins"), owns("DoubleCoins"), owns("GoldenSponge")
	if triple then
		return if sponge then "3x Coins and Golden Sponge" else "3x Coins"
	elseif double and sponge then
		return "2x Coins and Golden Sponge"
	elseif double then
		return "2x Coins"
	elseif sponge then
		return "Golden Sponge"
	end
	return nil
end

return table.freeze(Passes)
