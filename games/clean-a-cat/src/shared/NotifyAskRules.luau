--!strict
-- NotifyAskRules: Suds asks once about notifications in the first session (issue 814, switch notifyAsk with askQueue,
-- sudsBubble and longBuildOffer). The GDD's 1:45 row and Design's timeline (row notify, 105 s): Suds's bubble, and
-- Roblox's opt-in prompt only from a tap on its button. Players Roblox will not ask (under 13, or already opted in)
-- never see it, since the client asks CanPromptOptInAsync first. Shown once per save: the server keeps it in
-- save.asks[SAVE_KEY] once the client reports the bubble went up. The words are Design-Agent's (2026-11-26); the
-- notification is the build finished one (issue 816).
-- Pure, so tests/specs/NotifyAskRules.spec.luau covers it; NotifyAskService and NotifyAskController use it.
local BubbleRules = require(script.Parent:WaitForChild("BubbleRules"))

local NotifyAskRules = {}

NotifyAskRules.FLAG = "notifyAsk"
NotifyAskRules.ASK_ID = "notify" -- AskRules.IDS
NotifyAskRules.ATTRIBUTE = "NotifyAskDue" -- Player attribute: true while the ask is due
NotifyAskRules.SAVE_KEY = "notifyAsk" -- save.asks key: the bubble went up once
NotifyAskRules.AT = 105 -- seconds of play (1:45)

NotifyAskRules.BUBBLE = table.freeze({
	id = "notify",
	title = "Want a heads up?",
	line = "We'll tell you when a build is done. Once a day at most.",
	showMe = false,
	button = "Sure!",
}) :: BubbleRules.Bubble

-- Whether the ask is due for a save with `played` seconds of play that has `asked` it before.
function NotifyAskRules.due(played: number, asked: boolean): boolean
	return not asked and played >= NotifyAskRules.AT
end

return table.freeze(NotifyAskRules)
