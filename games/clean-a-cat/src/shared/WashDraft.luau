--!strict
-- WashDraft: the DRAFT numbers for the later wash steps (issue #267): the Bubble Bath, the Pawdicure, which cats
-- bring a bad smell or long claws, and the Pro Brush. Design-Agent's picks of 2026-11-24, continuing gdd-draft.md's
-- curve. Nothing here is decided until Derek picks the game: each value is a one line change, and CatRules,
-- BuildRules, ToolRules and the wash read them from here. Each piece has its own switch, off by default.

local WashDraft = {}

export type Station = {
	flag: string, -- LiveFlags switch: off, the station is not offered and its need never rolls
	name: string,
	price: number, -- coins
	seconds: number, -- build time
	payBonus: number, -- extra coins every customer's cat pays once it is built
	requires: string, -- BuildRules id built first
}

WashDraft.BUBBLE_BATH = table.freeze({
	flag = "bubbleBath",
	name = "Bubble Bath",
	price = 250,
	seconds = 10 * 60,
	payBonus = 8,
	requires = "Dryer",
}) :: Station

WashDraft.PAWDICURE = table.freeze({
	flag = "pawdicure",
	name = "Pawdicure",
	price = 900,
	seconds = 60 * 60,
	payBonus = 15,
	requires = "BubbleBath",
}) :: Station

-- The better hand brush on the Tools board: fewer strokes brush the tangles out (the hand brush takes 3).
WashDraft.PRO_BRUSH = table.freeze({
	flag = "proBrush",
	name = "Pro Brush",
	price = 120,
	brushStrokes = 1,
})

-- Percent chance, per rarity, that a customer's cat brings each later need. Rolled by the server when the
-- customer joins the line, so the card shows it before the pick.
WashDraft.NEED_CHANCES = table.freeze({
	smell = table.freeze({ Common = 0, Uncommon = 50, Rare = 100, Epic = 100, Legendary = 100 }),
	claws = table.freeze({ Common = 0, Uncommon = 0, Rare = 50, Epic = 100, Legendary = 100 }),
}) :: { [string]: { [string]: number } }

-- The switch for each later need (its station's switch).
WashDraft.NEED_FLAG =
	table.freeze({ smell = "bubbleBath", claws = "pawdicure" }) :: { [string]: string }

-- How the two steps feel (client): about 3 seconds of swirling empties the smell meter, and a hold of
-- CLAW_HOLD seconds on each of the front-paw claws clips it.
WashDraft.SWIRL_TRAVEL = 12 -- studs of swirl on the suds
WashDraft.CLAW_HOLD = 0.35 -- seconds
WashDraft.CLAWS = 4 -- _Claw01 to _Claw04, the front paws
WashDraft.SAY = table.freeze({
	bath = "Bubble bath · Swirl the suds",
	bathHint = "Swirl to scrub",
	claws = "Trim the claws",
	clawsHint = "Hold on each claw",
})

return table.freeze(WashDraft)
