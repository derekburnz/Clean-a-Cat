--!strict
-- GiftViewRules: what the gift stand's card (UI/GiftCard, issue 521) shows, from GiftController.state(): the free pet
-- and the steps to it. Favourite and Join each open Roblox's own prompt and tick once the server has them; the like
-- has no check on Roblox, so it is asked for in words and never ticked, and the pet never waits on it. Nothing costs
-- Robux and nothing is random. Plain words, no hurry. Pure, so tests/specs/GiftViewRules.spec.luau covers it.
local FreeRewardRules = require(script.Parent:WaitForChild("FreeRewardRules"))

local GiftViewRules = {}

GiftViewRules.FLAG = "giftStand"
GiftViewRules.WINDOW = "Gift"
GiftViewRules.PET = "Starcoat"
GiftViewRules.TITLE = "A gift for you!"
GiftViewRules.FREE_TITLE = "Free gifts" -- with the free rewards rows (switch freeRewards, issue 730)
GiftViewRules.PET_LINE = "A free pet, yours to keep"
GiftViewRules.GROUP_NAME = "Creampuff Games"

-- The free rewards rows (switch freeRewards, issue 730), nil while they are off.
export type Free = {
	likeAsked: boolean, -- Like was tapped (the server stamped it)
	likeIn: number, -- whole seconds until the like gift unlocks (0 once it can be claimed)
	likeClaimed: boolean,
	played: number, -- seconds of play in total
	playClaimed: boolean,
}

export type State = {
	lit: boolean,
	favourite: boolean,
	group: boolean,
	claimed: boolean,
	free: Free?,
}

export type Step = {
	key: string, -- "like", "favourite", "group"
	icon: string, -- Icons name
	title: string,
	line: string,
	done: boolean, -- ticked (never for the like)
	action: string?, -- the button's word, nil when there is nothing to press
	style: string?, -- the button's look: "ask" (blue, opens something), "claim" (green) or "wait" (soft, not pressable)
	reward: string?, -- the row's own gift, for the free rewards rows
}

local function likeStep(free: Free): Step
	local reward = FreeRewardRules.rewardText("like")
	if free.likeClaimed then
		return {
			key = "like",
			icon = "Heart",
			title = "Like the game",
			line = "Thank you!",
			done = true,
			reward = reward,
		}
	elseif not free.likeAsked then
		return {
			key = "like",
			icon = "Heart",
			title = "Like the game",
			line = `If you enjoy it · {reward}`,
			done = false,
			action = "Like",
			style = "ask",
			reward = reward,
		}
	elseif free.likeIn > 0 then
		return {
			key = "like",
			icon = "Heart",
			title = "Like the game",
			line = "Your gift comes either way",
			done = false,
			action = `{free.likeIn} s`,
			style = "wait",
			reward = reward,
		}
	end
	return {
		key = "likeClaim",
		icon = "Heart",
		title = "Like the game",
		line = `Your gift is ready · {reward}`,
		done = false,
		action = "Claim",
		style = "claim",
		reward = reward,
	}
end

local function playStep(free: Free): Step
	local reward = FreeRewardRules.rewardText("play")
	local goalMinutes = FreeRewardRules.PLAY_SECONDS // 60
	if free.playClaimed then
		return {
			key = "play",
			icon = "Crate",
			title = `Play {goalMinutes} minutes`,
			line = "Done, enjoy!",
			done = true,
		}
	end
	local left = math.max(
		0,
		FreeRewardRules.PLAY_SECONDS - (if free.played == free.played then free.played else 0)
	)
	if left > 0 then
		return {
			key = "play",
			icon = "Crate",
			title = `Play {goalMinutes} minutes`,
			line = `{reward} · {math.ceil(left / 60)} min to go`,
			done = false,
			reward = reward,
		}
	end
	return {
		key = "playClaim",
		icon = "Crate",
		title = `Play {goalMinutes} minutes`,
		line = `Your gift is ready · {reward}`,
		done = false,
		action = "Claim",
		style = "claim",
		reward = reward,
	}
end

function GiftViewRules.steps(state: State): { Step }
	local free = state.free
	if free then
		-- Derek (2026-11-26): the like first, then favourite and group while its wait runs, then play time
		local base = GiftViewRules.steps({
			lit = state.lit,
			favourite = state.favourite,
			group = state.group,
			claimed = state.claimed,
		})
		return { likeStep(free), base[1], base[2], playStep(free) }
	end
	return {
		{
			key = "favourite",
			icon = "Star",
			title = "Favourite the game",
			line = if state.favourite then "Done, thank you!" else "So you can find the spa again",
			done = state.favourite,
			action = if state.favourite then nil else "Favourite",
		},
		{
			key = "group",
			icon = "Crown",
			title = `Join {GiftViewRules.GROUP_NAME}`,
			line = if state.group then "Done, welcome!" else "Our group, for news and events",
			done = state.group,
			action = if state.group then nil else "Join",
		},
		{
			key = "like",
			icon = "Heart",
			title = "Like the game",
			line = "On its page, if you enjoy it",
			done = false,
			action = nil,
		},
	}
end

-- The pet comes once both checked steps are done, and only once.
function GiftViewRules.ready(state: State): boolean
	return state.favourite and state.group and not state.claimed
end

-- The claim button's words.
function GiftViewRules.claimText(state: State): string
	if state.claimed then
		return `{GiftViewRules.PET} is yours!`
	end
	return `Get {GiftViewRules.PET}`
end

-- The line under the claim button while it waits.
function GiftViewRules.waitLine(state: State): string?
	if state.claimed or GiftViewRules.ready(state) then
		return nil
	end
	local left = (if state.favourite then 0 else 1) + (if state.group then 0 else 1)
	return if left == 1 then "One step to go" else "Two steps to go"
end

return table.freeze(GiftViewRules)
