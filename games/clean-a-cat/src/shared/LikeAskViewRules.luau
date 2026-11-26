--!strict
-- LikeAskViewRules: the words on Suds's like ask (Derek on the plan page, 2026-11-26, q2-likeask: "Good moment like
-- rare customer cat finished. Maybe also after a purchase just a little bit after."). The server decides when the ask
-- is due (Gameplay's LikeAskService and LikeAskRules: after a good moment, once a visit, never near a lost cat or a
-- cancelled purchase) and names the moment; this only says what Suds says for it.
--
-- The ask is Suds's help bubble (UI/SudsBubble) with its own button word. It never names a reward: the coins live only
-- on the gift card's like row ("A gift either way, 150 coins", issue 748), so the like and the gift stay apart, and a
-- young player is never told a like buys something. "Sure!" opens the gift card, where the like row is first; the X is
-- a plain no; the card going by itself (a window opening, the wash) is no answer at all.
-- Pure, so tests/specs/LikeAskViewRules.spec.luau covers it.
local BubbleRules = require(script.Parent:WaitForChild("BubbleRules"))

local LikeAskViewRules = {}

LikeAskViewRules.FLAG = "likeAsk"
LikeAskViewRules.BUTTON = "Sure!"
LikeAskViewRules.LINE = "If you enjoy the spa, a like helps it grow!"

-- Suds's opener for each good moment the server names (LikeAskDue).
LikeAskViewRules.TITLES = table.freeze({
	special = "What a special visitor!",
	crate = "A new pet, how cute!",
	stars = "Three stars, wow!",
	helper = "The spa is growing!",
	purchase = "Hope you love it!",
}) :: { [string]: string }
LikeAskViewRules.DEFAULT_TITLE = "Having fun?"

-- The answer sent back for how the card went: "yes" for its button, "no" for the player's X, "closed" when it went by
-- itself.
export type Answer = "yes" | "no" | "closed"

function LikeAskViewRules.bubble(moment: unknown): BubbleRules.Bubble
	local title = if type(moment) == "string" then LikeAskViewRules.TITLES[moment] else nil
	return table.freeze({
		id = "likeAsk",
		title = title or LikeAskViewRules.DEFAULT_TITLE,
		line = LikeAskViewRules.LINE,
		showMe = false,
		button = LikeAskViewRules.BUTTON,
	}) :: BubbleRules.Bubble
end

function LikeAskViewRules.answer(pressed: boolean, closed: boolean): Answer
	if pressed then
		return "yes"
	end
	return if closed then "no" else "closed"
end

return table.freeze(LikeAskViewRules)
