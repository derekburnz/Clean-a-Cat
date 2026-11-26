--!strict
-- FreeRewardRules: the free rewards on the gift stand's card (issue 730, Derek's ask of 2026-11-26), behind the switch
-- freeRewards with giftStand. Two rows join the favourite and group steps (whose reward stays Starcoat, GiftRules):
--
--   like   first on the card. Tapping Like asks the server to stamp the ask (RequestLikeAsk); LIKE_WAIT seconds later
--          the gift can be claimed (RequestFreeReward "like"). A game cannot read a like, so the gift never depends on
--          it, and the card says so ("either way"); nothing pretends to check. Pays LIKE_COINS coins.
--   play   PLAY_SECONDS of play in total (save.playSeconds). Pays one PLAY_CRATE crate.
--
-- Each is paid once per save, by the server. Pure, so tests/specs/FreeRewardRules.spec.luau covers it; the server's
-- service (Gameplay-Engineer) and the card's controller both use it.
local FreeRewardRules = {}

FreeRewardRules.FLAG = "freeRewards"
FreeRewardRules.KEYS = table.freeze({ "like", "play" }) :: { string }
FreeRewardRules.LIKE_WAIT = 10 -- seconds from the ask until the like gift can be claimed (Derek: "like 10 seconds")
FreeRewardRules.LIKE_COINS = 150
FreeRewardRules.PLAY_SECONDS = 30 * 60
FreeRewardRules.PLAY_CRATE = "normal" -- a CrateRules kind; its chance list shows before it is opened

-- Player attributes the server keeps for the card.
FreeRewardRules.LIKE_READY_ATTRIBUTE = "FreeLikeReadyAt" -- the server time (os.time) the like gift unlocks; nil before
FreeRewardRules.CLAIMED_PREFIX = "FreeClaimed_" -- FreeClaimed_like, FreeClaimed_play: true once paid
FreeRewardRules.PLAYED_ATTRIBUTE = "PlaySeconds" -- the save's play seconds, refreshed now and then

-- The time the like gift unlocks for an ask stamped at `askedAt` (0 or less: not asked).
function FreeRewardRules.likeReadyAt(askedAt: number): number?
	if askedAt ~= askedAt or askedAt <= 0 then
		return nil
	end
	return askedAt + FreeRewardRules.LIKE_WAIT
end

-- Whether reward `key` can be paid now. `askedAt` is the like's stamp, `played` the save's play seconds.
function FreeRewardRules.canClaim(
	key: string,
	claimed: boolean,
	askedAt: number,
	played: number,
	now: number
): boolean
	if claimed then
		return false
	end
	if key == "like" then
		local readyAt = FreeRewardRules.likeReadyAt(askedAt)
		return readyAt ~= nil and now >= readyAt
	elseif key == "play" then
		return played == played and played >= FreeRewardRules.PLAY_SECONDS
	end
	return false
end

-- What the reward is, in words for the card.
function FreeRewardRules.rewardText(key: string): string
	if key == "like" then
		return `{FreeRewardRules.LIKE_COINS} coins`
	end
	return "A free crate"
end

return table.freeze(FreeRewardRules)
