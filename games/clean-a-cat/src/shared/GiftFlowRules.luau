--!strict
-- GiftFlowRules: the gift stand in three stages (switch giftFlow, issue 919; Design-Agent's gift stand spec of
-- 2026-11-26). Derek's stand note: "have the first free gift just be all of the top 3 and then replace it with a
-- different playtime reward thats good after and once thats claimed then remove it from spa so it doesnt take up room".
--   1  the welcome gift (from 7:00): one Claim all, for the favourite and the group as before, pays the like row's 150
--      coins and the gift (the gift crate with giftCrate, else Starcoat) in one tap
--   2  the playtime gift: once stage 1 is claimed, a good crate at 30 minutes of play in total
--   3  gone: once stage 2 is claimed the stand leaves the spa for good; the asks stay in More, then Gifts
-- Stages come from what the save already holds (giftClaimed, freeRewards.play), so an old save that has Starcoat is
-- past stage 1, and one that took the play crate is past stage 2. Pure, so specs cover it; GiftService and
-- FreeRewardService use it.
local GiftFlowRules = {}

GiftFlowRules.FLAG = "giftFlow"
GiftFlowRules.STAGE_ATTRIBUTE = "GiftStage" -- Player attribute: 1, 2 or 3 while the switch is on, for the card
GiftFlowRules.PLAY_CRATE = "good" -- the playtime gift is a good crate (it was a normal one)
GiftFlowRules.LEAVING_ATTRIBUTE = "Leaving" -- on the stand for LEAVE_SECONDS before it goes, for Motion-FX's puff
GiftFlowRules.LEAVE_SECONDS = 0.8

-- The stage a save is at: 1 until the welcome gift is claimed, 2 until the playtime gift is, then 3.
function GiftFlowRules.stage(giftClaimed: boolean, playClaimed: boolean): number
	if not giftClaimed then
		return 1
	end
	return if playClaimed then 3 else 2
end

-- Whether the stand still stands in the spa at `stage`.
function GiftFlowRules.standStays(stage: number): boolean
	return stage < 3
end

-- Whether the playtime gift may be claimed at `stage`: only once the welcome gift is (the 30 minutes are
-- FreeRewardRules' own check).
function GiftFlowRules.playOpen(stage: number): boolean
	return stage == 2
end

return table.freeze(GiftFlowRules)
