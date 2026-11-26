--!strict
-- QuestRules: the quest book (issue 516; tuning section 11). Two daily quests drawn from the pool each day of the
-- player's own calendar (SaveSchema.day) and three weekly quests from Monday 00:00 UTC. Each pays its coins once,
-- as soon as it is done; finishing all three weekly quests gives one normal crate, earned and never sold. Quests count
-- what the player already does with a customer's cat washed by hand: each wash brings its facts (Facts) and every
-- open quest of that kind moves on. A quest whose switch is off (its facts never come) is not drawn.
-- Pure, so tests/specs/QuestRules.spec.luau covers it; QuestService runs it. Behind the LiveFlags switch quests.

local QuestRules = {}

QuestRules.FLAG = "quests"
QuestRules.DAILY_COUNT = 2
QuestRules.WEEK_CRATE = "normal" -- quest.weeklyCrate

-- What one hand wash of a customer's cat did, by quest kind: 1 when it counts.
export type Facts = { [string]: number }

export type Quest = {
	id: string,
	text: string,
	goal: number,
	coins: number,
	counts: string, -- the Facts key it counts
	flag: string?, -- a switch its facts need; off, the quest is not drawn
}

local function quest(
	id: string,
	text: string,
	goal: number,
	coins: number,
	counts: string,
	flag: string?
): Quest
	return table.freeze({
		id = id,
		text = text,
		goal = goal,
		coins = coins,
		counts = counts,
		flag = flag,
	}) :: Quest
end

-- quest.dailyPool
QuestRules.DAILY = table.freeze({
	quest("wash5", "Wash 5 customer cats", 5, 50, "wash"),
	quest("bow3", "Put a bow on 3 cats", 3, 40, "bow", "bowTiers"),
	quest("dirty2", "Wash 2 cats at dirt level 3 or 4", 2, 60, "dirty", "dirtLevels"),
	quest("stars3x4", "Get 3 stars 4 times", 4, 50, "threeStars", "heartBar"),
	quest("early2", "Take 2 cats early", 2, 40, "early", "heartBar"),
}) :: { Quest }

-- quest.weekly
QuestRules.WEEKLY = table.freeze({
	quest("wStars20", "Get 3 stars on 20 cats", 20, 300, "threeStars", "heartBar"),
	quest("wSpecial2", "Wash 2 special visitors' cats", 2, 300, "special", "specialVisitors"),
	quest("wDirt4x10", "Wash 10 cats at dirt level 4", 10, 300, "dirt4", "dirtLevels"),
}) :: { Quest }

local BY_ID: { [string]: Quest } = {}
for _, list in { QuestRules.DAILY, QuestRules.WEEKLY } do
	for _, q in list do
		BY_ID[q.id] = q
	end
end

function QuestRules.get(id: string): Quest?
	return BY_ID[id]
end

export type Book = {
	tz: number?,
	day: number,
	daily: { string },
	progress: { [string]: number },
	claimed: { [string]: boolean },
	week: number,
	weeklyCrate: boolean,
}

type IsOn = (flag: string) -> boolean

-- The week number at `now` (os.time()), counted from Monday 00:00 UTC.
function QuestRules.week(now: number): number
	return (now // 86400 + 3) // 7 -- 1 January 1970 was a Thursday
end

local function available(q: Quest, isOn: IsOn): boolean
	return q.flag == nil or isOn(q.flag)
end

-- The weekly quests in play under the switches `isOn`.
function QuestRules.weekly(isOn: IsOn): { Quest }
	local out: { Quest } = {}
	for _, q in QuestRules.WEEKLY do
		if available(q, isOn) then
			table.insert(out, q)
		end
	end
	return out
end

-- Brings `book` to `today` and `week`: a new day draws DAILY_COUNT different daily quests (`random` gives 0 to 1)
-- and clears their progress; a new week clears the weekly quests and the crate. True when anything changed.
function QuestRules.refresh(
	book: Book,
	today: number,
	week: number,
	isOn: IsOn,
	random: () -> number
): boolean
	local changed = false
	if book.day ~= today then
		book.day = today
		for _, q in QuestRules.DAILY do
			book.progress[q.id] = nil
			book.claimed[q.id] = nil
		end
		local pool: { string } = {}
		for _, q in QuestRules.DAILY do
			if available(q, isOn) then
				table.insert(pool, q.id)
			end
		end
		local daily: { string } = {}
		while #daily < QuestRules.DAILY_COUNT and #pool > 0 do
			local pick = math.clamp(math.floor(random() * #pool) + 1, 1, #pool)
			table.insert(daily, table.remove(pool, pick) :: string)
		end
		book.daily = daily
		changed = true
	end
	if book.week ~= week then
		book.week = week
		for _, q in QuestRules.WEEKLY do
			book.progress[q.id] = nil
			book.claimed[q.id] = nil
		end
		book.weeklyCrate = false
		changed = true
	end
	return changed
end

-- The quests open in `book` now: today's daily ones, then the weekly ones.
function QuestRules.open(book: Book, isOn: IsOn): { Quest }
	local out: { Quest } = {}
	for _, id in book.daily do
		local q = BY_ID[id]
		if q then
			table.insert(out, q)
		end
	end
	for _, q in QuestRules.weekly(isOn) do
		table.insert(out, q)
	end
	return out
end

-- Counts one wash's `facts` on every open quest and pays the ones it finishes: returns those quests (each paid once,
-- marked claimed) and whether the weekly crate is now earned (once a week, when every weekly quest in play is done).
function QuestRules.count(book: Book, facts: Facts, isOn: IsOn): ({ Quest }, boolean)
	local done: { Quest } = {}
	for _, q in QuestRules.open(book, isOn) do
		local add = facts[q.counts] or 0
		if add > 0 and not book.claimed[q.id] then
			local now = math.min((book.progress[q.id] or 0) + add, q.goal)
			book.progress[q.id] = now
			if now >= q.goal then
				book.claimed[q.id] = true
				table.insert(done, q)
			end
		end
	end
	local weekly = QuestRules.weekly(isOn)
	local crate = false
	if not book.weeklyCrate and #weekly > 0 then
		crate = true
		for _, q in weekly do
			crate = crate and book.claimed[q.id] == true
		end
		if crate then
			book.weeklyCrate = true
		end
	end
	return done, crate
end

return table.freeze(QuestRules)
