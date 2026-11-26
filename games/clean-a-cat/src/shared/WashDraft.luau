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
	brushStrokes = 2, -- each stroke clears half the tangles (Design-Agent: one stroke would be a tap)
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

-- How the two steps feel (client): about 3 seconds of swirling on the cat clears the suds, and a hold of
-- CLAW_HOLD seconds on each front paw clips that paw's claws. The models carry four claws on each front paw, each
-- too small to press on a phone, so a paw's four clip together, one snip after another (Design-Agent).
WashDraft.SWIRL_TRAVEL = 12 -- studs of swirl on the cat
WashDraft.RINSE_REACH = 1.6 -- (washMeter) the shower pops foam this many sponge reaches round the finger
WashDraft.SUDS = 6 -- suds puffs round the cat (placeholders until the models carry their own)
WashDraft.CLAW_HOLD = 0.5 -- seconds on a paw (Design-Agent: 0.35 went by too fast to feel like trimming)
WashDraft.SNIP_GAP = 0.05 -- seconds between one paw's claw snips, so one hold reads as four trims
WashDraft.SAY = table.freeze({
	bath = "Swirl the suds", -- the step bar puts "Step 3 of 6 ·" before it
	bathHint = "Swirl to scrub",
	claws = "Trim the claws",
	clawsHint = "Hold on each paw",
})

-- (switch foamStep, issue 888) Derek on dev, 2026-11-26: "swirl the suds is a bad name for it, it should be like a
-- soap bar and it be like foam up the cat". The same step with a soap bar; the words also stop sounding like Suds.
WashDraft.FOAM_FLAG = "foamStep"
WashDraft.SAY_FOAM = table.freeze({
	bath = "Foam up the cat",
	bathHint = "Rub the soap on",
})

-- The Bubble Bath's words for the switch reader `isOn`.
function WashDraft.bathSay(isOn: (string) -> boolean): { bath: string, bathHint: string }
	local say = if isOn(WashDraft.FOAM_FLAG) then WashDraft.SAY_FOAM else WashDraft.SAY
	return { bath = say.bath, bathHint = say.bathHint }
end

return table.freeze(WashDraft)
