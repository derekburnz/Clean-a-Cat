--!strict
-- Products: the game's developer products (one time Robux buys a player can make again) by our own key, with the
-- product id the owner gets when he creates each one on the group's game (Creator Hub > the game > Monetization >
-- Developer Products). An id of 0 means "not created yet": whatever sells it stays hidden, so nothing can be bought
-- before the owner has made it. Prices are not here: each product's price is set by the owner on Roblox, and
-- PurchaseService reads it back (GetProductInfo) into the ReplicatedStorage attribute PRICE_PREFIX .. key, which
-- the buttons show. Product ids are public on Roblox, so they are fine in this repo.
--
-- Shared, so a client can tell which buttons exist; only the server (PurchaseService) grants anything.
--
-- Each experience has its own products (Derek, 2026-11-26, q2-wheremake): he makes the dev set now and the live set
-- when he promotes, so the ids are listed per experience (game.GameId) and IDS is the set of the experience this runs
-- in. Anywhere else (a place file opened on its own in Studio, GameId 0) every id is 0, so nothing sells.

local Products = {}

Products.PRICE_PREFIX = "ProductPrice_"

Products.DEV_GAME_ID = 10778775478 -- Clean-a-Cat-Dev
Products.LIVE_GAME_ID = 10778773655 -- Clean a Cat

-- The experience this runs in (game.GameId), 0 when it cannot be read.
function Products.currentGame(): number
	local ok, id = pcall(function()
		return game.GameId
	end)
	return if ok and type(id) == "number" then id else 0
end

-- The set of ids of experience `gameId` in `byGame`, or `none` (every id 0) for any other experience.
function Products.pick(
	byGame: { [number]: { [string]: number } },
	gameId: number,
	none: { [string]: number }
): { [string]: number }
	local set: { [string]: number }? = byGame[gameId]
	return set or none
end

-- key -> product id, per experience. Finish now tiers (FinishRules.TIERS, issue 515).
Products.IDS_BY_GAME = table.freeze({
	[Products.DEV_GAME_ID] = table.freeze({
		FinishTier1 = 0,
		FinishTier2 = 0,
		FinishTier3 = 0,
		FinishTier4 = 0,
		FinishTier5 = 0,
		CrateOne = 0,
		CrateFive = 0,
		StarterPack = 0,
	}),
	[Products.LIVE_GAME_ID] = table.freeze({
		FinishTier1 = 0,
		FinishTier2 = 0,
		FinishTier3 = 0,
		FinishTier4 = 0,
		FinishTier5 = 0,
		CrateOne = 0,
		CrateFive = 0,
		StarterPack = 0,
	}),
}) :: { [number]: { [string]: number } }

-- Every key with id 0, with the design's price for each: the set for an experience not listed above.
Products.NONE = table.freeze({
	FinishTier1 = 0, -- Finish now, 5 minutes or less left (design: 5 Robux)
	FinishTier2 = 0, -- 30 minutes or less (15)
	FinishTier3 = 0, -- 2 hours or less (35)
	FinishTier4 = 0, -- 8 hours or less (75)
	FinishTier5 = 0, -- more than 8 hours (99)
	CrateOne = 0, -- one normal crate (CrateRules.SHOP, issue 514; 49 Robux): a paid random item, odds shown first
	CrateFive = 0, -- five normal crates (199)
	StarterPack = 0, -- the starter pack: Golden Sponge, Second pet slot and 2x Coins (StarterRules, issue 519; 199, Derek 2026-11-26)
}) :: { [string]: number }

-- key -> product id in the experience this runs in.
Products.IDS = Products.pick(Products.IDS_BY_GAME, Products.currentGame(), Products.NONE)

-- The product id for `key`, or nil while it is not created (0) or unknown.
function Products.id(key: string): number?
	local id = Products.IDS[key]
	return if type(id) == "number" and id > 0 then id else nil
end

-- Our key for a product id, or nil.
function Products.keyOf(id: number): string?
	if id <= 0 then
		return nil
	end
	for key, value in Products.IDS do
		if value == id then
			return key
		end
	end
	return nil
end

return table.freeze(Products)
