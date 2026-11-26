--!strict
-- GiftViewRules: what the gift stand's card (UI/GiftCard, issue 521) shows, from GiftController.state(): the free pet
-- and the steps to it. Favourite and Join each open Roblox's own prompt and tick once the server has them; the like
-- has no check on Roblox, so it is asked for in words and never ticked, and the pet never waits on it. Nothing costs
-- Robux and nothing is random. Plain words, no hurry. Pure, so tests/specs/GiftViewRules.spec.luau covers it.
local GiftViewRules = {}

GiftViewRules.FLAG = "giftStand"
GiftViewRules.WINDOW = "Gift"
GiftViewRules.PET = "Starcoat"
GiftViewRules.TITLE = "A gift for you!"
GiftViewRules.PET_LINE = "A free pet, yours to keep"
GiftViewRules.GROUP_NAME = "Creampuff Games"

export type State = { lit: boolean, favourite: boolean, group: boolean, claimed: boolean }

export type Step = {
	key: string, -- "like", "favourite", "group"
	icon: string, -- Icons name
	title: string,
	line: string,
	done: boolean, -- ticked (never for the like)
	action: string?, -- the button's word, nil when there is nothing to press
}

function GiftViewRules.steps(state: State): { Step }
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
