--!strict
-- SaleRules: the launch sale (issue 1032, Derek's playtest of 2026-11-27: "put everything on 50% off and throw the
-- classic redline cut through old pricing with the new pricing"). Behind the switch launchSale, off by default.
--
-- Honest by how it is built (rule 10, monetization-policy): Roblox charges the price it holds, and that is the price
-- a card shows (the PRICE attributes PassService and the product services read from Roblox). The struck price is the
-- REGULAR one below, the price the item goes back to when the sale ends, and it shows only while the switch is on and
-- the live price really is lower. Prices on Roblox are changed by store-setup (action sale-prices sets salePrice of
-- each REGULAR price, regular-prices sets them back), dev first, live only on Derek's word. No timer, no "hurry".
--
-- REGULAR here and the prices in tools/opencloud/store-setup.py are the same list; change both together.
-- Pure, so tests/specs/SaleRules.spec.luau covers it.
local SaleRules = {}

SaleRules.FLAG = "launchSale"
SaleRules.LABEL = "Launch sale: 50% off"

-- Robux, by Passes key: 2x then 3x Coins is the cheap ladder (issue 1031: 25 and 50 on the sale).
SaleRules.REGULAR_PASSES = table.freeze({
	DoubleCoins = 50,
	TripleCoins = 100,
	SecondBuilder = 299,
	GoldenSponge = 99,
	Lou = 249,
	SecondPetSlot = 249,
}) :: { [string]: number }

-- Robux, by Products key.
SaleRules.REGULAR_PRODUCTS = table.freeze({
	FinishTier1 = 5,
	FinishTier2 = 15,
	FinishTier3 = 35,
	FinishTier4 = 75,
	FinishTier5 = 99,
	CrateOne = 49,
	CrateFive = 199,
	StarterPack = 199,
}) :: { [string]: number }

-- The sale price of a regular price: half, rounded down, at least 1 Robux.
function SaleRules.salePrice(regular: number): number
	return math.max(1, regular // 2)
end

-- The struck price to show beside `live` (the price Roblox charges), or nil: only with the sale on, a regular price
-- known for `key` and `live` really below it.
function SaleRules.was(
	regular: { [string]: number },
	key: string,
	live: number?,
	isOn: (flag: string) -> boolean
): number?
	local full = regular[key]
	if not isOn(SaleRules.FLAG) or full == nil or live == nil or live >= full then
		return nil
	end
	return full
end

return table.freeze(SaleRules)
