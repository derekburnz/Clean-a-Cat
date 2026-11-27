--!strict
-- LikeHowToRules: the like how-to on the gift card (issue 869, switch likeHowTo; Growth-Agent's spec of 2026-11-26).
-- When Like is tapped on the card's like row, the card's picture side shows, once per visit, how to like the game: a
-- thumbs up that a hand taps and that fills pink, about 2 s, looping, with "Tap the thumbs up on the game's page".
-- The game cannot read a like, so nothing says it is checked: the gift comes either way. It never covers a button,
-- and "Got it" puts the picture back. Pure, so tests/specs/LikeHowToRules.spec.luau covers it.
local LikeHowToRules = {}

LikeHowToRules.FLAG = "likeHowTo"
LikeHowToRules.ASK_ID = "likeHowTo" -- AskRules.IDS: logged as ask_shown and ask_answered
LikeHowToRules.LOOP = 2 -- seconds
LikeHowToRules.CAPTION = "Tap the thumbs up on the game's page"
LikeHowToRules.BUTTON = "Got it"

-- The line under the caption: the gift comes either way (one gift, or the welcome gifts with giftFlow).
function LikeHowToRules.note(gifts: boolean): string
	return if gifts then "Your gifts come either way" else "Your gift comes either way"
end

export type Frame = {
	hand: number, -- 0 the hand up and away, 1 the hand on the thumb
	press: number, -- 1 the hand pressed (a little smaller), else 0
	ring: number, -- 0 no ring, then 0 to 1 as it grows and fades
	filled: boolean, -- the thumbs up is pink
}

-- The loop at `t` seconds: the hand comes down (0 to 0.6), taps with a ring (0.6 to 0.9), the thumb stays pink until
-- 1.7, then all resets. Reduced Motion: the last frame, still (hand on the pink thumb).
function LikeHowToRules.frame(t: number, reduced: boolean): Frame
	if reduced then
		return { hand = 1, press = 0, ring = 0, filled = true }
	end
	local k = t % LikeHowToRules.LOOP
	if k < 0.6 then
		local e = k / 0.6
		return { hand = 1 - (1 - e) * (1 - e), press = 0, ring = 0, filled = false }
	elseif k < 0.9 then
		return { hand = 1, press = 1, ring = (k - 0.6) / 0.3, filled = true }
	elseif k < 1.7 then
		return { hand = 1, press = 0, ring = 0, filled = true }
	end
	local e = (k - 1.7) / 0.3
	return { hand = 1 - e, press = 0, ring = 0, filled = e < 0.5 }
end

return table.freeze(LikeHowToRules)
