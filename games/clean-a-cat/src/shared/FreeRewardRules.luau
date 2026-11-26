--!strict
-- FreeRewardRules: the Free Rewards rows on the gift card (issue 730, switch freeRewards, which needs giftStand). Two
-- rows are paid here, each once per save; the third row (favourite plus group, for Starcoat) stays GiftRules'.
-- - like: the card asks the player to like the game if they enjoy it and says the gift comes either way. A game
--   cannot read a like, so nothing is checked: the ask is stamped once (likeAskedAt, server os.time()) and the
--   reward can be claimed LIKE_WAIT seconds later, liked or not.
-- - play: PLAY_SECONDS of play in total (the save's play time) gives PLAY_CRATES crates of PLAY_CRATE.
-- Pure, so tests/specs/FreeRewardRules.spec.luau covers it; FreeRewardService uses it.

local FreeRewardRules = {}

FreeRewardRules.FLAG = "freeRewards"
FreeRewardRules.KEYS = { "like", "play" } -- the card's order: the like row first (Derek, 2026-11-26)

FreeRewardRules.LIKE_WAIT = 10 -- seconds from the like ask to its Claim (Derek, 2026-11-26)
FreeRewardRules.LIKE_COINS = 150
FreeRewardRules.PLAY_SECONDS = 1800 -- 30 minutes of play in total
FreeRewardRules.PLAY_CRATE = "normal" -- a CrateRules kind
FreeRewardRules.PLAY_CRATES = 1

-- Player attributes the server keeps for the card.
FreeRewardRules.PLAY_CLAIMED_ATTRIBUTE = "FreePlayClaimed" -- true once the play reward is paid
FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE = "FreeLikeClaimed" -- true once the like reward is paid
FreeRewardRules.LIKE_READY_ATTRIBUTE = "FreeLikeReadyAt" -- os.time() the like's Claim unlocks, once asked
FreeRewardRules.PLAY_SECONDS_ATTRIBUTE = "PlaySeconds" -- the save's play time so far, whole seconds

export type Key = "like" | "play"
export type Claimed = { play: boolean, like: boolean }
export type State = { claimed: Claimed, likeAskedAt: number, played: number, now: number }

-- `raw` as one of KEYS, or nil.
function FreeRewardRules.cleanKey(raw: unknown): Key?
	if raw == "like" or raw == "play" then
		return raw :: Key
	end
	return nil
end

-- The os.time() the like's Claim unlocks after an ask at `askedAt`; nil before any ask.
function FreeRewardRules.likeReadyAt(askedAt: number): number?
	if askedAt <= 0 then
		return nil
	end
	return askedAt + FreeRewardRules.LIKE_WAIT
end

-- Whether `key` can be paid now: not paid before, and for like the ask made LIKE_WAIT or more seconds ago, for play
-- PLAY_SECONDS of play. Nil when it can, else why not ("claimed", "wait", "notAsked", "notYet").
function FreeRewardRules.refusal(state: State, key: Key): string?
	local paid = if key == "like" then state.claimed.like else state.claimed.play
	if paid then
		return "claimed"
	end
	if key == "like" then
		local readyAt = FreeRewardRules.likeReadyAt(state.likeAskedAt)
		if readyAt == nil then
			return "notAsked"
		end
		return if state.now >= readyAt then nil else "wait"
	end
	return if state.played >= FreeRewardRules.PLAY_SECONDS then nil else "notYet"
end

return FreeRewardRules
