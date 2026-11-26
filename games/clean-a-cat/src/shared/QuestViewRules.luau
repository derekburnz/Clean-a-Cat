--!strict
-- QuestViewRules: what the quest book (UI/QuestBook, issue 516) shows, from the server's Quests remote (QuestService):
-- a list of { id, text, goal, progress, coins, weekly, done } with today's daily quests first, and whether this week's
-- crate is taken. A finished quest pays at once, so the book has no Claim button: it shows each quest's progress, a
-- tick once paid, and the weekly crate's pips. Resets are said in plain words, never a clock or "hurry", and nothing is
-- lost by missing a day. Pure, so tests/specs/QuestViewRules.spec.luau covers it.
local QuestRules = require(script.Parent:WaitForChild("QuestRules"))

local QuestViewRules = {}

-- Player attribute QuestService sets true once the save has played QuestRules' first 6:00 (gdd: "Quests at 6:00"):
-- the HUD button and Suds's tip wait for it.
QuestViewRules.OPEN_ATTRIBUTE = "QuestsOpen"
QuestViewRules.WINDOW = "Quests"
QuestViewRules.TODAY = "Today"
QuestViewRules.TODAY_NOTE = "New quests tomorrow"
QuestViewRules.WEEK = "This week"
QuestViewRules.CRATE_TITLE = "Weekly crate"

export type Entry = {
	id: string,
	text: string,
	goal: number,
	progress: number,
	coins: number,
	weekly: boolean,
	done: boolean,
}

-- Icons names by what a quest counts (QuestRules' `counts`).
local ICONS: { [string]: string } = {
	wash = "Paw",
	bow = "Bow",
	dirty = "Mud",
	dirt4 = "Mud",
	threeStars = "Star",
	early = "Heart",
	special = "Sparkle",
}

local function count(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw or raw == math.huge or raw == -math.huge then
		return nil
	end
	return math.max(0, math.floor(raw))
end

-- The server's list, kept only where every field has its type; progress is held between 0 and the goal.
function QuestViewRules.clean(raw: unknown): { Entry }
	local out: { Entry } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, item in raw :: { any } do
		if type(item) == "table" and type(item.id) == "string" and type(item.text) == "string" then
			local goal, progress, coins = count(item.goal), count(item.progress), count(item.coins)
			if goal and goal > 0 and progress and coins then
				table.insert(out, {
					id = item.id,
					text = item.text,
					goal = goal,
					progress = math.min(progress, goal),
					coins = coins,
					weekly = item.weekly == true,
					done = item.done == true,
				})
			end
		end
	end
	return out
end

-- Today's quests and this week's, each in the server's order.
function QuestViewRules.split(entries: { Entry }): ({ Entry }, { Entry })
	local daily: { Entry } = {}
	local weekly: { Entry } = {}
	for _, entry in entries do
		table.insert(if entry.weekly then weekly else daily, entry)
	end
	return daily, weekly
end

function QuestViewRules.icon(id: string): string
	local q = QuestRules.get(id)
	return if q then ICONS[q.counts] or "Star" else "Star"
end

function QuestViewRules.progressText(entry: Entry): string
	return `{entry.progress} / {entry.goal}`
end

function QuestViewRules.fill(entry: Entry): number
	return if entry.done then 1 else math.clamp(entry.progress / entry.goal, 0, 1)
end

-- The line beside "This week": how many weekly quests there are to finish for the crate.
function QuestViewRules.weekNote(weekly: { Entry }): string
	if #weekly == 1 then
		return "Finish it for a crate"
	end
	return `Finish all {#weekly} for a crate`
end

-- The weekly crate's line under its title.
function QuestViewRules.crateLine(taken: boolean): string
	if taken then
		return "Yours this week! A new one next week."
	end
	return "A pet for finishing every weekly quest"
end

function QuestViewRules.doneCount(weekly: { Entry }): number
	local n = 0
	for _, entry in weekly do
		if entry.done then
			n += 1
		end
	end
	return n
end

return table.freeze(QuestViewRules)
