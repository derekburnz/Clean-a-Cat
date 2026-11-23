--!strict
-- SpaRules: the pure rules of one cat's visit, in order: scrub it clean, brush it fluffy, pick a bow, take the
-- photo and get paid. No Roblox calls, so specs cover it. SpaService (server) holds one Cat per player and is the
-- only thing that pays; the client follows along for feel and the server checks every step.
-- Numbers are draft tuning from the first session plan.

local SpaRules = {}

SpaRules.BRUSH_STROKES = 3 -- strokes that fluff the cat
SpaRules.MIN_STROKE_GAP = 0.2 -- client only: seconds between strokes it reports. The server does not time strokes
-- (packets can arrive bunched); its rate limit bounds them instead.
SpaRules.MIN_VISIT_SECONDS = 15 -- the photo pays no sooner than this after the cat arrived, about an honest visit.
-- An earlier photo is not refused: it pays when the time is up, so a quick player only waits a moment.
SpaRules.PHOTO_COINS = 10 -- draft: a common cat's pay; tips arrive with customers
SpaRules.BOWS = table.freeze({ "BowPink", "BowBlue", "BowGold" }) -- the three bows a player picks from

export type Stage = "dirty" | "clean" | "fluffed" | "styled" | "done"

-- Stages in visit order, so the client can tell whether the server is behind it.
SpaRules.STAGE_ORDER =
	table.freeze({ dirty = 1, clean = 2, fluffed = 3, styled = 4, done = 5 }) :: { [string]: number }

export type Cat = {
	id: number,
	stage: Stage,
	arrivedAt: number,
	strokes: number,
	lastStrokeAt: number,
	bow: string?,
	photoTaken: boolean, -- the photo was asked for and is waiting for MIN_VISIT_SECONDS to pass
}

function SpaRules.newCat(id: number, now: number): Cat
	return {
		id = id,
		stage = "dirty",
		arrivedAt = now,
		strokes = 0,
		lastStrokeAt = -math.huge,
		bow = nil,
		photoTaken = false,
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

-- One brush stroke landed. Returns (counted, fluffed): counted is false for a stroke out of order; fluffed is
-- true on the stroke that finishes the brushing.
function SpaRules.brushStroke(cat: Cat, now: number): (boolean, boolean)
	if cat.stage ~= "clean" then
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

-- The player asked for the photo of a styled cat. Returns the seconds until it may pay (0 means now), or nil
-- when the cat is not ready for a photo or one is already waiting.
function SpaRules.askPhoto(cat: Cat, now: number): number?
	if cat.stage ~= "styled" or cat.photoTaken then
		return nil
	end
	cat.photoTaken = true
	return math.max(0, cat.arrivedAt + SpaRules.MIN_VISIT_SECONDS - now)
end

-- Pays the photo. Returns PHOTO_COINS once, for a styled cat whose photo was asked for and that arrived at least
-- MIN_VISIT_SECONDS ago; 0 otherwise.
function SpaRules.photo(cat: Cat, now: number): number
	if
		cat.stage ~= "styled"
		or not cat.photoTaken
		or now - cat.arrivedAt < SpaRules.MIN_VISIT_SECONDS
	then
		return 0
	end
	cat.stage = "done"
	return SpaRules.PHOTO_COINS
end

return table.freeze(SpaRules)
