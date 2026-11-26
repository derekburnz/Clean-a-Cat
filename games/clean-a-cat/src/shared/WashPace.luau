--!strict
-- WashPace: how much work each wash step takes, behind the switch washPace (issue 865). The owner on 2026-11-26,
-- after a playtest: "the brushing fur minigame goes way too fast they should take around 4-5 seconds each
-- minigame". With the switch off every step keeps its old amount; on, each one asks for about 4 to 5 seconds from a
-- normal player (Design-Agent's estimates in docs/design/clean-a-cat/tuning.md). The scrub is not here: it was
-- already tuned to about 8 seconds (ScrubRules). Pure, so tests/specs/WashPace.spec.luau covers it.
local SpaRules = require(script.Parent:WaitForChild("SpaRules"))
local WashDraft = require(script.Parent:WaitForChild("WashDraft"))

local WashPace = {}

WashPace.FLAG = "washPace"

export type Pace = {
	brushStrokes: number, -- strokes that brush the tangles out with the hand brush
	strokeGap: number, -- seconds between two strokes that count (client only)
	swirlTravel: number, -- studs of rubbing that lather the bath foam on (and swirl it off without the shower)
	rinseReach: number, -- sponge reaches round the finger that the shower pops foam within
	clawHold: number, -- seconds a paw is held to clip it
}

WashPace.OFF = table.freeze({
	brushStrokes = SpaRules.BRUSH_STROKES, -- 3
	strokeGap = SpaRules.MIN_STROKE_GAP, -- 0.2
	swirlTravel = WashDraft.SWIRL_TRAVEL, -- 12
	rinseReach = WashDraft.RINSE_REACH, -- 1.6
	clawHold = WashDraft.CLAW_HOLD, -- 0.5
}) :: Pace

WashPace.ON = table.freeze({
	brushStrokes = 8, -- 7 gaps of 0.45 s is a 3.2 s floor; about 4.5 s at a normal stroke
	strokeGap = 0.45,
	swirlTravel = 26, -- about 4.5 s of rubbing, double the old
	rinseReach = 1, -- a narrower spray, so the rinse is a sweep over the whole cat
	clawHold = 0.8, -- four paws at 0.8 s plus the moves between is about 4.5 s
}) :: Pace

-- The most strokes any cat's brushing can take; the client trusts no more than this from the server.
WashPace.MAX_STROKES = math.max(WashPace.ON.brushStrokes, WashPace.OFF.brushStrokes)

function WashPace.pace(isOn: ((flag: string) -> boolean)?): Pace
	return if isOn ~= nil and isOn(WashPace.FLAG) then WashPace.ON else WashPace.OFF
end

-- A better brush's strokes (`fewer` of the old hand brush's 3) at this pace: the same share of the hand brush's,
-- rounded up, so the Pro Brush's 2 of 3 is 6 of 8.
function WashPace.toolStrokes(fewer: number, pace: Pace): number
	return math.max(1, math.ceil(fewer * pace.brushStrokes / SpaRules.BRUSH_STROKES - 1e-9))
end

return table.freeze(WashPace)
