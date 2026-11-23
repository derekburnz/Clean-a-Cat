--!strict
-- SpaRules: the pure rules of one cat's visit, in order: scrub it clean, brush it fluffy, pick a bow, take the
-- photo and get paid. No Roblox calls, so specs cover it. SpaService (server) holds one Cat per player and is the
-- only thing that pays; the client follows along for feel and the server checks every step.
-- Numbers are draft tuning from the first session plan.

local SpaRules = {}

SpaRules.BRUSH_STROKES = 3 -- strokes that fluff the cat
SpaRules.MIN_STROKE_GAP = 0.2 -- seconds between counted strokes, so a flood of reports is not a fluffed cat
SpaRules.MIN_VISIT_SECONDS = 5 -- the photo pays only this long after the cat arrived (a real scrub takes longer)
SpaRules.PHOTO_COINS = 10 -- draft: a common cat's pay; tips arrive with customers
SpaRules.BOWS = table.freeze({ "BowPink", "BowBlue", "BowGold" }) -- the three bows a player picks from

export type Stage = "dirty" | "clean" | "fluffed" | "styled" | "done"

export type Cat = {
	id: number,
	stage: Stage,
	arrivedAt: number,
	strokes: number,
	lastStrokeAt: number,
	bow: string?,
}

function SpaRules.newCat(id: number, now: number): Cat
	return {
		id = id,
		stage = "dirty",
		arrivedAt = now,
		strokes = 0,
		lastStrokeAt = -math.huge,
		bow = nil,
	}
end

-- The scrub is done. True when the cat moves from dirty to clean.
function SpaRules.scrubbed(cat: Cat): boolean
	if cat.stage ~= "dirty" then
		return false
	end
	cat.stage = "clean"
	return true
end

-- One brush stroke landed. Returns (counted, fluffed): counted is false for a stroke out of order or too soon
-- after the last; fluffed is true on the stroke that finishes the brushing.
function SpaRules.brushStroke(cat: Cat, now: number): (boolean, boolean)
	if cat.stage ~= "clean" or now - cat.lastStrokeAt < SpaRules.MIN_STROKE_GAP then
		return false, false
	end
	cat.strokes += 1
	cat.lastStrokeAt = now
	if cat.strokes >= SpaRules.BRUSH_STROKES then
		cat.stage = "fluffed"
		return true, true
	end
	return true, false
end

function SpaRules.isBow(bowId: string): boolean
	return table.find(SpaRules.BOWS, bowId) ~= nil
end

-- The player picked a bow. True when it is a known bow and the cat is fluffed.
function SpaRules.pickBow(cat: Cat, bowId: string): boolean
	if cat.stage ~= "fluffed" or not SpaRules.isBow(bowId) then
		return false
	end
	cat.bow = bowId
	cat.stage = "styled"
	return true
end

-- The photo. Returns the coins to pay: PHOTO_COINS once, for a styled cat that arrived at least
-- MIN_VISIT_SECONDS ago; 0 otherwise (and the cat stays styled, so a too-early tap can be repeated).
function SpaRules.photo(cat: Cat, now: number): number
	if cat.stage ~= "styled" or now - cat.arrivedAt < SpaRules.MIN_VISIT_SECONDS then
		return 0
	end
	cat.stage = "done"
	return SpaRules.PHOTO_COINS
end

return table.freeze(SpaRules)
