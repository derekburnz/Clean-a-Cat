--!strict
-- SpecialRules: special visitors (issue 510, switch specialVisitors). The owner's picks on the plan page, 2026-11-25:
-- "special customers appear that expire that only I can take their cats and have them have the really cool cat
-- designs", and "Dont make crates always drop from rare visitors also but have it be a rare possibility maybe script
-- the first one to drop a crate and make a rare customer come within the first 5 minutes so they stay".
-- Now and then a special visitor joins the front of the line with one of the special cats (CatRules.SPECIAL_CATS),
-- always at dirt level 4, paying the most. Workers never take them. Their heart bar runs and at empty they leave, like
-- any customer. The first visitor of a save comes at about 4:00 of play with a very long bar, and washing their cat
-- always gives a crate; after that a crate is a rare chance. One visitor per spa at a time.
-- The numbers are Design-Agent's in docs/design/clean-a-cat/tuning.md, section 9; change them there and here
-- together. Pure, so tests/specs/SpecialRules.spec.luau covers it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))

local SpecialRules = {}

SpecialRules.FLAG = "specialVisitors"
SpecialRules.FIRST_AT = 4 * 60 -- seconds of play: special.first
SpecialRules.FIRST_AFTER_JOIN = 30 -- at least this long after a join, so a returning save is not met at the door
SpecialRules.EVERY_MIN = 8 * 60 -- special.every: a random 8 to 15 minutes of play after the last one
SpecialRules.EVERY_MAX = 15 * 60
SpecialRules.CRATE_CHANCE = 0.05 -- special.crateChance
SpecialRules.CRATE_KIND = "normal" -- the crate a visitor leaves (save.crates key)
-- The Player attribute with the count of normal crates held, for the crates' HUD and open (issue 511).
SpecialRules.CRATES_ATTRIBUTE = "Crates_normal"
-- save.asks keys: the first visitor's cat was washed and its crate given; from then on visits are random.
SpecialRules.FIRST_DONE = "visitorFirst"
SpecialRules.FIGURE_ATTRIBUTE = "Special" -- true on a visitor's figure in the line
-- Model-Agent's special customers (CleanACat_NPC_Customer_<name>, with the royal carrier).
SpecialRules.LOOKS = table.freeze({ "Vivi", "Rex", "Pearl" }) :: { string }
SpecialRules.CARRIER = "CleanACat_Prop_CarrierRoyal"

-- When the next visitor is due, in seconds of play. `played` is the save's play now, `joinedAt` its play at this
-- session's join, `firstDone` whether the first visitor's crate was given. `random()` is in [0, 1).
function SpecialRules.dueAt(
	played: number,
	joinedAt: number,
	firstDone: boolean,
	random: () -> number
): number
	if not firstDone then
		return math.max(SpecialRules.FIRST_AT, joinedAt + SpecialRules.FIRST_AFTER_JOIN)
	end
	return played
		+ SpecialRules.EVERY_MIN
		+ random() * (SpecialRules.EVERY_MAX - SpecialRules.EVERY_MIN)
end

-- Which special cat a visitor brings.
function SpecialRules.pickCat(random: () -> number): string
	local cats = CatRules.SPECIAL_CATS
	return cats[math.clamp(math.floor(random() * #cats) + 1, 1, #cats)]
end

-- Whether washing a visitor's cat gives a crate: always for the first visitor of a save, else CRATE_CHANCE.
function SpecialRules.dropsCrate(firstDone: boolean, random: () -> number): boolean
	return not firstDone or random() < SpecialRules.CRATE_CHANCE
end

-- The visitor's look for a special cat, by its place in SPECIAL_CATS, so a cat always comes with the same person.
function SpecialRules.lookFor(cat: string): string
	local at = table.find(CatRules.SPECIAL_CATS, cat) or 1
	return SpecialRules.LOOKS[(at - 1) % #SpecialRules.LOOKS + 1]
end

return table.freeze(SpecialRules)
