--!strict
-- GiftViewRules: what the gift stand's card (UI/GiftCard, issue 521) shows, from GiftController.state(): the free pet
-- and the steps to it. Favourite and Join each open Roblox's own prompt and tick once the server has them; the like
-- has no check on Roblox, so it is asked for in words and never ticked, and the pet never waits on it. Nothing costs
-- Robux and nothing is random. Plain words, no hurry. Pure, so tests/specs/GiftViewRules.spec.luau covers it.
local FreeRewardRules = require(script.Parent:WaitForChild("FreeRewardRules"))

local GiftViewRules = {}

-- What each free row gives, in words for the card.
local function rewardText(key: string): string
	return if key == "like" then `{FreeRewardRules.LIKE_COINS} coins` else "A free crate"
end

GiftViewRules.FLAG = "giftStand"
GiftViewRules.WINDOW = "Gift"
GiftViewRules.PET = "Starcoat"
GiftViewRules.TITLE = "A gift for you!"
GiftViewRules.FREE_TITLE = "Free gifts" -- with the free rewards rows (switch freeRewards, issue 730)
GiftViewRules.PET_LINE = "A free pet, yours to keep"
GiftViewRules.GROUP_NAME = "Creampuff Games"
-- With the switch giftCrate (CrateRules.GIFT_FLAG, issue 859) the stand gives a gift crate to open, not Starcoat: the
-- card shows the crate, says what can come out, and its button opens it.
GiftViewRules.CRATE = "Gift crate"
GiftViewRules.CRATE_LINE = "A free pet inside, Uncommon or better"
GiftViewRules.WELCOME_TITLE = "Welcome gifts" -- (switch giftFlow, issue 968) stage 1
GiftViewRules.PLAY_TITLE = "Playtime gift" -- stage 2
GiftViewRules.GOOD_CRATE = "Good crate"

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
	-- (switch giftFlow, issue 968) the stand's stage from the Player attribute GiftStage: 1 the welcome gifts with one
	-- Claim all, 2 the playtime gift, nil with the switch off (the card as before)
	stage: number?,
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
	local reward = rewardText("like")
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
			line = `A gift either way, {reward}`,
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

local function playStep(free: Free, good: boolean?): Step
	local reward = if good then "A good crate" else rewardText("play") -- (giftFlow) the playtime gift is a good crate
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

-- (giftFlow) The like in the welcome gifts: asked for in words, never a condition; its coins come with Claim all.
local function likeAsk(free: Free?): Step
	local asked = free ~= nil and (free.likeAsked or free.likeClaimed)
	return {
		key = "like",
		icon = "Heart",
		title = "Like the game",
		line = if asked
			then "Thank you!"
			elseif free then "If you enjoy it, gifts come either way"
			else "On its page, if you enjoy it",
		done = false,
		action = if free and not asked then "Like" else nil,
		style = if free and not asked then "ask" else nil,
	}
end

function GiftViewRules.steps(state: State): { Step }
	local free = state.free
	if state.stage == 2 and free then
		return { playStep(free, true) } -- the playtime gift alone
	end
	if state.stage == 1 then
		local base = GiftViewRules.steps({
			lit = state.lit,
			favourite = state.favourite,
			group = state.group,
			claimed = state.claimed,
		})
		return { likeAsk(free), base[1], base[2] }
	end
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

-- (giftFlow) The card's title at each stage.
function GiftViewRules.title(state: State): string
	if state.stage == 1 then
		return GiftViewRules.WELCOME_TITLE
	elseif state.stage == 2 then
		return GiftViewRules.PLAY_TITLE
	end
	return if state.free then GiftViewRules.FREE_TITLE else GiftViewRules.TITLE
end

-- Whether the card has its bottom claim button: not at the playtime stage, whose row has its own Claim.
function GiftViewRules.hasClaim(state: State): boolean
	return state.stage ~= 2
end

export type Prize = {
	crate: boolean, -- draw the crate picture, else the pet's portrait
	name: string,
	line: string,
}

-- What the picture side shows: the gift crate (`crate`, switch giftCrate) or Starcoat; with giftFlow the welcome gift
-- adds the like's coins unless they were taken, and the playtime stage shows its good crate.
function GiftViewRules.prize(state: State, crate: boolean?): Prize
	if state.stage == 2 then
		local minutes = FreeRewardRules.PLAY_SECONDS // 60
		return {
			crate = true,
			name = GiftViewRules.GOOD_CRATE,
			line = `Yours at {minutes} minutes of play`,
		}
	end
	local coins = state.stage == 1 and not (state.free ~= nil and state.free.likeClaimed)
	if crate then
		return {
			crate = true,
			name = GiftViewRules.CRATE,
			line = if coins
				then `A free pet inside, plus {FreeRewardRules.LIKE_COINS} coins`
				else GiftViewRules.CRATE_LINE,
		}
	end
	return {
		crate = false,
		name = GiftViewRules.PET,
		line = if coins
			then `A free pet, plus {FreeRewardRules.LIKE_COINS} coins`
			else GiftViewRules.PET_LINE,
	}
end

-- The claim button's words; `crate` with the switch giftCrate (issue 859).
function GiftViewRules.claimText(state: State, crate: boolean?): string
	if state.stage == 1 and not state.claimed then
		return "Claim all" -- (giftFlow) the welcome gifts in one tap
	end
	if crate then
		return if state.claimed then "Your gift crate is here!" else "Open your gift crate"
	end
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
