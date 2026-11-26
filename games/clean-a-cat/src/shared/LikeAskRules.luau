--!strict
-- LikeAskRules: when a player is asked to like the game (Derek, 2026-11-26, q2-likeask, switch likeAsk with askQueue).
-- A game cannot read or prompt a like, so the ask is our own small card (Design's), and its "Like the game" opens the
-- gift card's like row; the card never mentions coins. His rule, as the server applies it:
--   - only after a good moment (MOMENTS): a special visitor's cat finished, a crate opened, a three star card, a
--     helper hired, and (his "maybe", its own switch PURCHASE_FLAG) a completed purchase, PURCHASE_DELAY seconds later;
--   - one ask a visit; after a "no", none for NO_VISITS visits; never once the like row is paid;
--   - never within GUARD_SECONDS of a lost cat or a cancelled purchase.
-- Review-QA's pressure limits on top (review of Design PR 774): never again after a "yes" or after MAX_NOS "no"s, and
-- never while the first session's tutorial runs (SpaRules.TUTORIAL_ENDS_AT seconds of play).
-- Pure, so tests/specs/LikeAskRules.spec.luau covers it; LikeAskService uses it.

local LikeAskRules = {}

LikeAskRules.FLAG = "likeAsk"
LikeAskRules.ATTRIBUTE = "LikeAskDue" -- Player attribute: the moment's name while the ask is due, nil otherwise
LikeAskRules.MOMENTS =
	table.freeze({ "special", "crate", "stars", "helper", "purchase" }) :: { string }
-- Derek's "maybe also after a purchase just a little bit after", confirmed 2026-11-26 with its own switch (issue 813)
LikeAskRules.PURCHASE_FLAG = "likeAskPurchase"
LikeAskRules.PURCHASE_DELAY = 120 -- seconds from a completed purchase to its ask, so it is never on the purchase screen
LikeAskRules.GUARD_SECONDS = 120 -- no ask this long after a lost cat or a cancelled purchase
LikeAskRules.NO_VISITS = 3 -- visits with no ask after a "no"
LikeAskRules.MAX_NOS = 2 -- after this many "no"s the ask never comes again

export type Moment = "special" | "crate" | "stars" | "helper" | "purchase"
export type Answer = "yes" | "no" | "closed"
export type State = {
	visit: number, -- this visit's number (the save's visits, the first is 1)
	noVisit: number, -- the visit of the last "no", 0 for none
	nos: number, -- how many times the ask was answered "no"
	saidYes: boolean, -- the ask was once answered "yes"
	inTutorial: boolean, -- the first session's tutorial is still running
	likePaid: boolean, -- the gift card's like row is paid
	askedThisVisit: boolean,
	lastBadAt: number, -- when a cat was last lost or a purchase cancelled, -math.huge for never
	now: number,
}

function LikeAskRules.cleanMoment(raw: unknown): Moment?
	if type(raw) == "string" and table.find(LikeAskRules.MOMENTS, raw) then
		return raw :: Moment
	end
	return nil
end

function LikeAskRules.cleanAnswer(raw: unknown): Answer?
	if raw == "yes" or raw == "no" or raw == "closed" then
		return raw :: Answer
	end
	return nil
end

-- Whether no ask may come due now, whatever the moment.
function LikeAskRules.blocked(state: State): boolean
	if state.likePaid or state.askedThisVisit or state.saidYes or state.inTutorial then
		return true
	end
	if state.nos >= LikeAskRules.MAX_NOS then
		return true
	end
	if state.noVisit > 0 and state.visit - state.noVisit <= LikeAskRules.NO_VISITS then
		return true
	end
	return state.now - state.lastBadAt < LikeAskRules.GUARD_SECONDS
end

-- When `moment` at `now` makes the ask due: now, PURCHASE_DELAY later for a purchase while `afterPurchase` (the
-- switch PURCHASE_FLAG) is on, or nil when it never does.
function LikeAskRules.dueAt(moment: Moment, now: number, afterPurchase: boolean?): number?
	if moment == "purchase" then
		return if afterPurchase then now + LikeAskRules.PURCHASE_DELAY else nil
	end
	return now
end

return table.freeze(LikeAskRules)
