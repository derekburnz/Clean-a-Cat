--!strict
-- HeartRules: the heart bar over each waiting customer's cat, and the wash pay formula (switch heartBar, issue 507;
-- the owner on the plan page, 2026-11-25: pay is "a base money amount" multiplied by "how fast you cleaned them (stars
-- received), how long the cat waited ... within the first 10% of heart bar it should be a big bonus ... no penalty if
-- it was above another certain amount ... and how dirty there were", and waiting cats get "grumpy and leave after bar
-- is fully empty").
--
-- A customer's bar starts full when they join the line and empties over `lasts` seconds of server time. Picked while
-- at least 1 - EARLY_SHARE of it is left, the wash pays EARLY_TIMES; any other wait costs nothing. At empty the
-- customer leaves with their cat and that job is lost; nothing else is taken. In a save's first minutes of play the
-- bars are long and stop at a sliver, so a new player on a phone never loses a cat; nothing drains before the spa's
-- first serve (the tutorial). Nothing is ever sold to keep or bring back a cat, and no price shows on a leaving cat.
--
-- The wash grade is the "stars received": 1 to 3 by the seconds per step the wash took, each with a pay multiplier.
-- Pay = base x grade x early x dirt, rounded once (tuning section 3), then the stations' bonus and the tip.
-- The numbers are Design-Agent's starting values in docs/design/clean-a-cat/tuning.md, sections 3 and 4.
-- Pure, so tests/specs/HeartRules.spec.luau covers it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))
local DirtRules = require(script.Parent:WaitForChild("DirtRules"))

local HeartRules = {}

HeartRules.FLAG = "heartBar"
HeartRules.SPACING_FLAG = "barSpacing" -- spacedSince is used only while this is on (issue 573)
-- A waiting customer's bar, full to empty, by rarity (tuning heart.seconds): rarer cats are a bit more urgent.
HeartRules.SECONDS = table.freeze({
	Common = 150,
	Uncommon = 140,
	Rare = 120,
	Epic = 100,
	Legendary = 90,
	Special = 240, -- heart.seconds.special
}) :: { [string]: number }
HeartRules.FIRST_SPECIAL_SECONDS = 600 -- heart.seconds.firstSpecial: the scripted first visitor, "so nobody rushes"
HeartRules.FIRST_MINUTES_SECONDS = 240 -- every bar while the save has played less than FIRST_MINUTES
HeartRules.FIRST_MINUTES = 10 * 60 -- seconds of play
-- Before NO_LEAVE_BEFORE seconds of play a bar stops at SLIVER: the cat stays grumpy but never leaves (heart.noLeaveBefore).
HeartRules.NO_LEAVE_BEFORE = 10 * 60
HeartRules.SLIVER = 0.03
HeartRules.EARLY_SHARE = 0.1 -- picked within this share of the bar: the early bonus
HeartRules.EARLY_TIMES = 1.25 -- tuning pay.early
HeartRules.GRUMPY_AT = 0.3 -- the cat looks grumpy once this share of its bar or less is left
HeartRules.FILL_ATTRIBUTE = "HeartFill" -- number 0 to 1 on each waiting customer's figure, for the mood poses

-- The wash grade (tuning pay.starTimes): 3 stars at GRADE_STEP_SECONDS[1] seconds or less per hand step on average,
-- 2 at [2] or less, else 1. A slow wash is never a cut (tuning pay.stars).
HeartRules.GRADE_STEP_SECONDS = table.freeze({ 12, 20 }) :: { number }
HeartRules.GRADE_TIMES = table.freeze({ 1, 1.1, 1.2 }) :: { number } -- by grade 1, 2, 3 (tuning pay.stars)
-- Suds and a new spa's first TUTORIAL_STARS_CUSTOMERS customers always get 3 stars (tuning pay.starsTutorial).
HeartRules.TUTORIAL_STARS_CUSTOMERS = 2

-- How long a customer with a cat of `name` joining the line now waits at most, after `played` seconds of play.
function HeartRules.lasts(name: string, played: number): number
	if played < HeartRules.FIRST_MINUTES then
		return HeartRules.FIRST_MINUTES_SECONDS
	end
	return HeartRules.SECONDS[CatRules.rarityOf(name) or "Common"] or HeartRules.SECONDS.Common
end

-- How much of the bar is left, 1 (full) to 0 (empty), `now` for a customer who joined at `since`. A bar of no length
-- (a customer whose cat is already taken) stays full.
function HeartRules.left(since: number, lasts: number, now: number): number
	if lasts <= 0 then
		return 1
	end
	return math.clamp(1 - (now - since) / lasts, 0, 1)
end

-- What the bar shows after `played` seconds of play: before NO_LEAVE_BEFORE it never drops under SLIVER.
function HeartRules.shown(since: number, lasts: number, now: number, played: number): number
	local left = HeartRules.left(since, lasts, now)
	if played < HeartRules.NO_LEAVE_BEFORE then
		return math.max(left, HeartRules.SLIVER)
	end
	return left
end

-- Extra seconds of grace per place in the line when the first minutes end (tuning heart.releaseStagger), so the cats
-- held on the sliver leave one at a time.
HeartRules.RELEASE_STAGGER = 15

-- The start of a bar once the first minutes end (Review-QA on #543): a bar that sat at the sliver, or anywhere under
-- GRUMPY_AT, gets GRUMPY_AT of itself back, plus RELEASE_STAGGER seconds for each place after the first (`place`,
-- 1 at the front), so the cats that waited on the sliver do not all leave together. Any other bar keeps its start.
function HeartRules.graceSince(since: number, lasts: number, now: number, place: number?): number
	if HeartRules.left(since, lasts, now) >= HeartRules.GRUMPY_AT then
		return since
	end
	local stagger = HeartRules.RELEASE_STAGGER * math.max((place or 1) - 1, 0)
	return now - lasts * (1 - HeartRules.GRUMPY_AT) + stagger
end

-- The start of a bar of `lasts` seconds joining the line `now` behind a bar that ends at `aheadEnds` (nil for the
-- front): never before now, and late enough that it ends RELEASE_STAGGER seconds or more after the one ahead, so bars
-- that start in the same second (the line unpausing at the first serve, a returning save's line rolled on join) do
-- not all empty and leave together (Sync's bug hunt B2). A start after now shows a full bar until then.
function HeartRules.spacedSince(now: number, lasts: number, aheadEnds: number?): number
	if aheadEnds == nil then
		return now
	end
	return math.max(now, aheadEnds + HeartRules.RELEASE_STAGGER - lasts)
end

-- True once the bar is empty and the save has played NO_LEAVE_BEFORE: the customer leaves.
function HeartRules.gone(since: number, lasts: number, now: number, played: number): boolean
	return lasts > 0 and played >= HeartRules.NO_LEAVE_BEFORE and now - since >= lasts
end

-- True while a pick now still gets the early bonus.
function HeartRules.early(since: number, lasts: number, now: number): boolean
	return now - since <= lasts * HeartRules.EARLY_SHARE
end

export type Heart = { since: number, lasts: number, stops: boolean, paused: boolean }

-- A card's heart bar as the server sent it beside the line ({ since, lasts, stops, paused }), or nil.
function HeartRules.cleanHeart(raw: unknown): Heart?
	if type(raw) ~= "table" then
		return nil
	end
	local t = raw :: { [number]: unknown }
	local since, lasts, stops, paused = t[1], t[2], t[3], t[4]
	if
		type(since) ~= "number"
		or since ~= since
		or type(lasts) ~= "number"
		or lasts ~= lasts
		or lasts < 0
		or lasts > 3600
	then
		return nil
	end
	return { since = since, lasts = lasts, stops = stops == 1, paused = paused == 1 }
end

-- What a card's bar shows `now` (server time): full while paused, never under SLIVER while it stops.
function HeartRules.fill(heart: Heart, now: number): number
	if heart.paused then
		return 1
	end
	local left = HeartRules.left(heart.since, heart.lasts, now)
	return if heart.stops then math.max(left, HeartRules.SLIVER) else left
end

-- No hand step takes less than this: a wash reported faster than MIN_STEP_SECONDS a step is not a hand wash, and
-- grades 1 (Review-QA on #543), so a client that rushes its reports gains nothing.
HeartRules.MIN_STEP_SECONDS = 2

-- The wash grade, 1 to 3 stars, for a wash of `steps` hand steps that took `seconds` of hand work.
function HeartRules.grade(seconds: number, steps: number): number
	local each = seconds / math.max(steps, 1)
	if each < HeartRules.MIN_STEP_SECONDS then
		return 1
	end
	for index, most in HeartRules.GRADE_STEP_SECONDS do
		if each <= most then
			return 4 - index
		end
	end
	return 1
end

export type Pay = {
	base: number, -- the rarity's coins for the wash
	speed: number, -- extra coins for the wash grade
	early: number, -- extra coins for picking the cat early
	dirt: number, -- extra coins for a dirtier cat
	coins: number, -- base + speed + early + dirt
	tip: number,
	stars: number, -- spa stars, by rarity
	grade: number, -- 1 to 3, the wash's stars
}

export type Wash = {
	grade: number?, -- nil: no grade multiplier (switch off)
	early: boolean,
	dirt: number?, -- nil: no dirt multiplier (switch off)
}

-- What a customer's cat of `name` pays after `wash`: the base times each multiplier in turn, each step's extra kept
-- as its own amount so the recap lists one line per multiplier and the lines add up to the coins exactly. The tip
-- stays as it is.
function HeartRules.pay(name: string, wash: Wash): Pay
	local rarity = CatRules.pay(name)
	local grade = math.clamp(wash.grade or 1, 1, #HeartRules.GRADE_TIMES)
	local gradeTimes = if wash.grade then HeartRules.GRADE_TIMES[grade] else 1
	local earlyTimes = if wash.early then HeartRules.EARLY_TIMES else 1
	local dirtTimes = if wash.dirt then DirtRules.PAY[DirtRules.clean(wash.dirt) or 1] else 1
	local function round(value: number): number
		return math.floor(value + 0.5)
	end
	local base = rarity.coins
	local afterSpeed = round(base * gradeTimes)
	local afterEarly = round(base * gradeTimes * earlyTimes)
	local afterDirt = round(base * gradeTimes * earlyTimes * dirtTimes)
	return {
		base = base,
		speed = afterSpeed - base,
		early = afterEarly - afterSpeed,
		dirt = afterDirt - afterEarly,
		coins = afterDirt,
		tip = rarity.tip,
		stars = rarity.stars,
		grade = grade,
	}
end

return table.freeze(HeartRules)
