--!strict
-- ShopViewRules: what the shop's Passes page (UI/ShopWindow, issue 518 and 526 item 8) shows, from Passes. One card
-- per game pass in Passes.KEYS order, drawn only while its real Robux price is known (the ReplicatedStorage
-- attribute Passes.PRICE_PREFIX .. key, which PassService reads from Roblox once the owner has created the pass), so
-- every price shows before Roblox's own prompt. A pass the player owns says Owned and has no button. No coins are
-- sold, nothing says "hurry" or "only today". With `isOn`: 3x Coins has a card only once 2x is owned (Passes.offered,
-- switch coinLadder, issue 1031), and with launchSale a card on sale carries `was`, its true regular price, to show
-- struck through beside the price (SaleRules, issue 1032). Pure, so tests/specs/ShopViewRules.spec.luau covers it.
local Passes = require(script.Parent:WaitForChild("Passes"))
local SaleRules = require(script.Parent:WaitForChild("SaleRules"))

local ShopViewRules = {}

ShopViewRules.WINDOW = "Shop"
ShopViewRules.EMPTY = "Nothing here yet. Come back soon!"

export type Card = {
	key: string,
	name: string,
	text: string,
	icon: string, -- an Icons name
	badge: string?, -- the corner tag on the picture: "x2", "+1"
	price: number,
	owned: boolean,
	was: number?, -- launchSale: the regular price, struck through; nil when not on sale
}

-- `short`: the card's words, shorter than Passes.INFO's so five cards fit a phone held sideways.
type Look = { icon: string, badge: string?, short: string? }

local LOOK: { [string]: Look } = {
	-- Model-Agent's shop pictures (issues 1030, 1031) carry their own x2, x3 or +1, so the cards draw no tag
	DoubleCoins = { icon = "ShopCoins2x", short = "Double coins on cats you wash by hand" },
	TripleCoins = { icon = "ShopCoins3x", short = "Triple coins on hand washes, in place of 2x" },
	SecondBuilder = { icon = "ShopBuilder2", short = "Build a tub and a room at once" },
	GoldenSponge = { icon = "ShopGoldenSponge", short = "Gold sponge, +20% on hand washes" },
	Lou = { icon = "ShopExtraWorker", short = "A third helper with his own stand" },
	SecondPetSlot = { icon = "ShopPetSlot2", short = "A second pet for you and helpers" },
}

-- Switch shopRevamp (issue 1030, Derek's playtest of 2026-11-27: "monetization shop needs a complete revamp and the
-- robux text is hard to read ... do better mono pics in shop they kinda suck and suck at selling it properly"; Growth's
-- docs/growth/shop-layout-research.md): one featured card, bigger, on the left; the rest in a two by two grid beside
-- it; each with its picture large, its name, ONE short line of what it does, and the price in white words with an ink
-- outline on the green button. No "best value" ribbons, no stock counters, nothing that says hurry.
ShopViewRules.REVAMP_FLAG = "shopRevamp"
-- What each pass does, in one short line (the picture shows the x2, x3 or +1).
ShopViewRules.LINE = table.freeze({
	DoubleCoins = "2x coins",
	TripleCoins = "3x coins",
	SecondBuilder = "2 builds at once",
	GoldenSponge = "+20% washes",
	Lou = "A third helper",
	SecondPetSlot = "A 2nd pet each",
}) :: { [string]: string }
-- The passes that can be the featured card, best first: what a new player feels at once (Growth: "passes ordered by
-- what a new player needs first"). The first one priced and not owned is featured; else the first card not owned.
ShopViewRules.FEATURE_ORDER =
	table.freeze({ "DoubleCoins", "TripleCoins", "SecondBuilder" }) :: { string }

local function whole(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw or raw <= 0 or raw == math.huge then
		return nil
	end
	return math.floor(raw)
end

-- The cards in shop order. `price(key)` reads the price attribute, `owns(key)` the player's pass attribute.
function ShopViewRules.cards(
	price: (key: string) -> unknown,
	owns: (key: string) -> boolean,
	isOn: ((flag: string) -> boolean)?
): { Card }
	local out: { Card } = {}
	local flags: (flag: string) -> boolean = isOn
		or function(_flag: string): boolean
			return false
		end
	for _, key in Passes.KEYS do
		local info = Passes.INFO[key]
		local robux = whole(price(key))
		if info and robux and Passes.offered(key, owns, flags) then
			local look: Look = LOOK[key] or { icon = "Star", badge = nil, short = nil }
			table.insert(out, {
				key = key,
				name = info.name,
				text = look.short or info.text,
				icon = look.icon,
				badge = look.badge,
				price = robux,
				owned = owns(key),
				was = SaleRules.was(SaleRules.REGULAR_PASSES, key, robux, flags),
			})
		end
	end
	return out
end

-- The featured card (or nil when every pass is owned) and the rest: the passes not owned in shop order, then the
-- owned ones, so what can still be bought comes first.
function ShopViewRules.arrange(cards: { Card }): (Card?, { Card })
	local featured: Card? = nil
	for _, key in ShopViewRules.FEATURE_ORDER do
		for _, card in cards do
			if featured == nil and card.key == key and not card.owned then
				featured = card
			end
		end
	end
	if featured == nil then
		for _, card in cards do
			if featured == nil and not card.owned then
				featured = card
			end
		end
	end
	local rest: { Card } = {}
	for _, owned in { false, true } do
		for _, card in cards do
			if card ~= featured and card.owned == owned then
				table.insert(rest, card)
			end
		end
	end
	return featured, rest
end

-- A card's one line with shopRevamp.
function ShopViewRules.lineOf(card: Card): string
	return ShopViewRules.LINE[card.key] or card.text
end

-- The price on a card's button, in words every font draws: "199 Robux" (Roblox's private-use Robux sign is not in
-- every font, and a box in its place would hide the price).
function ShopViewRules.priceText(robux: number): string
	return `{robux} Robux`
end

return table.freeze(ShopViewRules)
