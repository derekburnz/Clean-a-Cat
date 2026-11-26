--!strict
-- FavouriteAskRules: the one favourite reminder (issue 815, switch favouriteAsk with askQueue, sudsBubble, giftStand
-- and pets). The GDD: "A player who skipped the stand gets one favourite ask on the second visit or after 10 cats."
-- Design's timeline row favourite: Suds's bubble, and Roblox's favourite prompt only from a tap on its button. Never
-- for a save whose favourite the stand already has (save.giftFavourite), and once a save (save.asks[SAVE_KEY]). The
-- bubble names no reward (the like and favourite rule). Words: Design-Agent, 2026-11-26.
-- Pure, so tests/specs/FavouriteAskRules.spec.luau covers it; FavouriteAskService and FavouriteAskController use it.
local BubbleRules = require(script.Parent:WaitForChild("BubbleRules"))

local FavouriteAskRules = {}

FavouriteAskRules.FLAG = "favouriteAsk"
FavouriteAskRules.ASK_ID = "favourite" -- AskRules.IDS
FavouriteAskRules.ATTRIBUTE = "FavouriteAskDue" -- Player attribute: true while the reminder is due
FavouriteAskRules.SAVE_KEY = "favouriteAsk" -- save.asks key: the bubble went up once
FavouriteAskRules.FROM_VISIT = 2 -- the second visit
FavouriteAskRules.AFTER_CATS = 10 -- or this many cats washed by hand in one visit

FavouriteAskRules.BUBBLE = table.freeze({
	id = "favourite",
	title = "Find us again!",
	line = "Favourite the spa to find it fast next time.",
	showMe = false,
	button = "Favourite",
}) :: BubbleRules.Bubble

export type State = {
	visit: number, -- this visit's number (the save's visits)
	washes: number, -- cats washed by hand this visit
	favourited: boolean, -- the stand already has the favourite
	asked: boolean, -- the reminder went up before
}

function FavouriteAskRules.due(state: State): boolean
	if state.favourited or state.asked then
		return false
	end
	return state.visit >= FavouriteAskRules.FROM_VISIT
		or state.washes >= FavouriteAskRules.AFTER_CATS
end

return table.freeze(FavouriteAskRules)
