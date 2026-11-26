--!strict
-- BuildRules: stations and rooms that take time to build. There is one build slot per kind (SLOTS): the builder
-- kitten builds one station at a time and the building site one room at a time, so a long room never blocks a
-- station and the spa never closes. The server sets every end time (os.time()), so a build also finishes while
-- the player is away. No paid skips. Pure, so tests/specs/BuildRules.spec.luau covers it; BuildService runs it.
-- Prices, times and bonuses are draft tuning from the first session plan; Design-Agent owns them.
--
-- Tubs, the VIP Room and the Garden (switch tubBuilds, issue 515; tuning section 8, "What each build does"): the
-- Second, Third and Fourth Tub (90 coins 15 s, 1,000 coins 30 min, 5,000 coins 4 h, in that order), the VIP Room at
-- 15,000 coins 12 h and the Garden at 25,000 coins 24 h. One builder: one build at a time. Each built tub adds a bench
-- place (3 to at most 6), takes 1 s off the bench refill (6 to 3) and adds TUB_HAND_BONUS coins to every cat washed by
-- hand (never a worker's or the jar); a tub is not a washer. The VIP Room brings special visitors every 5 to 10 minutes
-- of play instead of 8 to 15; the Garden makes the tip jar hold 12 h and fill 25% faster. While dirtLevels is on too,
-- the Brush Table, Dryer, Bubble Bath and Pawdicure leave the board, stop standing in the plot and stop paying.
-- Every read of an item goes through BuildRules.item(id, isOn), which gives the VIP Room its new price and time.
--
-- A finished build is saved as save.stations[id] = true. These ids are the only station keys in the save; the
-- tub and the hand brush are there from the start (CatRules.STARTING_STATIONS) and never saved.

local WashDraft = require(script.Parent:WaitForChild("WashDraft"))

local BuildRules = {}

export type Item = {
	name: string, -- what the board and notices say
	slot: string, -- one of SLOTS
	price: number, -- coins
	seconds: number, -- build time
	requires: string?, -- an id that must be built first
	payBonus: number, -- extra coins every customer's cat pays once this is built
	flag: string?, -- a LiveFlags switch: while it is off the item is not offered (offered)
	alsoFlag: string?, -- a second switch that must be on as well
	hiddenWhen: { string }?, -- while every one of these switches is on, the item is gone (shown)
}

BuildRules.TUBS_FLAG = "tubBuilds"
local DIRT_FLAG = "dirtLevels" -- DirtRules.FLAG: every step is in from the start, so the old stations go
local OLD_STATION = table.freeze({ BuildRules.TUBS_FLAG, DIRT_FLAG })

-- A WashDraft station as a build item (#267).
local function later(draft: WashDraft.Station): Item
	return table.freeze({
		name = draft.name,
		slot = "station",
		price = draft.price,
		seconds = draft.seconds,
		requires = draft.requires,
		payBonus = draft.payBonus,
		flag = draft.flag,
		hiddenWhen = OLD_STATION,
	}) :: Item
end

BuildRules.SLOTS = table.freeze({ "station", "room" }) -- the slot count is this list's length

local function tub(name: string, price: number, seconds: number, requires: string?): Item
	return table.freeze({
		name = name,
		slot = "station",
		price = price,
		seconds = seconds,
		requires = requires,
		payBonus = 0, -- a tub's coins are TUB_HAND_BONUS, for hand washes only (handBonus)
		flag = BuildRules.TUBS_FLAG,
		alsoFlag = DIRT_FLAG,
	}) :: Item
end

BuildRules.ITEMS = table.freeze({
	BrushTable = table.freeze({
		name = "Brush Table",
		slot = "station",
		price = 40,
		seconds = 10,
		payBonus = 2,
		hiddenWhen = OLD_STATION,
	}) :: Item,
	Dryer = table.freeze({
		name = "Blow Dryer",
		slot = "station",
		price = 75,
		seconds = 60,
		requires = "BrushTable",
		payBonus = 5,
		hiddenWhen = OLD_STATION,
	}) :: Item,
	BubbleBath = later(WashDraft.BUBBLE_BATH),
	Pawdicure = later(WashDraft.PAWDICURE),
	VipRoom = table.freeze({
		name = "VIP Room",
		slot = "room",
		price = 100,
		seconds = 8 * 3600,
		requires = "Dryer",
		payBonus = 0,
	}) :: Item,
	SecondTub = tub("Second Tub", 90, 15), -- must stay 15 s or less: Finish now hides under 15 s left (issue 531)
	ThirdTub = tub("Third Tub", 1000, 30 * 60, "SecondTub"),
	FourthTub = tub("Fourth Tub", 5000, 4 * 3600, "ThirdTub"),
	Garden = table.freeze({
		name = "Garden",
		slot = "room",
		price = 25000,
		seconds = 24 * 3600, -- never more than 24 h
		payBonus = 0,
		flag = BuildRules.TUBS_FLAG,
		alsoFlag = DIRT_FLAG, -- the new board comes whole, so it never has more rows than MAX_ROWS
	}) :: Item,
}) :: { [string]: Item }

-- The VIP Room while tubBuilds is on (tuning build.VipRoom): its own price and time, and nothing to build first.
local VIP_TUNED: Item = table.freeze({
	name = "VIP Room",
	slot = "room",
	price = 15000,
	seconds = 12 * 3600,
	requires = nil,
	payBonus = 0,
}) :: Item

-- board order; every id is a key of ITEMS
BuildRules.IDS = table.freeze({
	"SecondTub",
	"ThirdTub",
	"FourthTub",
	"BrushTable",
	"Dryer",
	"BubbleBath",
	"Pawdicure",
	"VipRoom",
	"Garden",
})
BuildRules.TUBS = table.freeze({ "SecondTub", "ThirdTub", "FourthTub" })
-- Rows the builder board can give their own key (BoardProp.rowKeys, issue 574), the bell's included: the offered
-- items plus the bell stay within it under every switch (tests/specs/BuildRules.spec.luau).
BuildRules.MAX_ROWS = 6
BuildRules.TUB_HAND_BONUS = 2 -- build.tub.effect: coins on every cat washed by hand, per built tub
BuildRules.BENCH_START = 3 -- bench.size before any tub
BuildRules.BENCH_MAX = 6
BuildRules.REFILL_START = 6 -- bench.refillSeconds before any tub
BuildRules.GARDEN_JAR_HOURS = 12 -- build.Garden.effect: the tip jar holds this many hours (jar.cap is 8)
BuildRules.GARDEN_JAR_TIMES = 1.25 -- and fills this much faster (jar.rate 30 to 37.5 an hour per worker)
BuildRules.LONG_SECONDS = 3600 -- a build this long or longer logs long_build_started
BuildRules.PROMPT_REACH = 10 -- studs; the board's prompts show within this distance
BuildRules.SERVER_REACH = 16 -- studs; the server's distance check, with room for lag

export type Build = { item: string, endsAt: number }

export type State = {
	coins: number,
	stations: { [string]: boolean },
	builds: { [string]: Build },
}

-- The save's running builds that are well formed: a known slot holding a known item of that slot, with a real
-- end time. A save edited by an old or broken server can hold anything.
function BuildRules.cleanBuilds(raw: unknown): { [string]: Build }
	local out: { [string]: Build } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, slot in BuildRules.SLOTS do
		local entry = (raw :: { [string]: unknown })[slot]
		if type(entry) == "table" then
			local e = entry :: { [string]: unknown }
			local item = e.item
			local endsAt = e.endsAt
			if
				type(item) == "string"
				and BuildRules.ITEMS[item]
				and BuildRules.ITEMS[item].slot == slot
				and type(endsAt) == "number"
				and endsAt == endsAt
				and endsAt < math.huge
			then
				out[slot] = { item = item, endsAt = endsAt }
			end
		end
	end
	return out
end

type IsOn = (flag: string) -> boolean

-- Item `id` as the switches `isOn` make it (the VIP Room's price and time under tubBuilds), or nil.
function BuildRules.item(id: string, isOn: IsOn?): Item?
	local base = BuildRules.ITEMS[id]
	if base == nil then
		return nil
	end
	if id == "VipRoom" and isOn and isOn(BuildRules.TUBS_FLAG) then
		return VIP_TUNED
	end
	return base
end

-- Whether item `id` is in the game under the switches `isOn`: its own switches on and not hidden by others.
function BuildRules.shown(id: string, isOn: IsOn): boolean
	local item = BuildRules.ITEMS[id]
	if item == nil then
		return false
	end
	if
		(item.flag ~= nil and not isOn(item.flag))
		or (item.alsoFlag ~= nil and not isOn(item.alsoFlag))
	then
		return false
	end
	local hidden = item.hiddenWhen
	if hidden then
		for _, flag in hidden do
			if not isOn(flag) then
				return true
			end
		end
		return false
	end
	return true
end

-- Can `state` start building `id`? False plus a short reason the player can read. Under tubBuilds (with `isOn`)
-- there is one builder, so one build at a time whatever its slot; with `builders` 2 (the Second Builder pass, issue
-- 518) each slot builds on its own again, so a room and a station (a tub) can build at once.
function BuildRules.canStart(
	state: State,
	id: string,
	isOn: IsOn?,
	builders: number?
): (boolean, string?)
	local item = BuildRules.item(id, isOn)
	if item == nil then
		return false, "Unknown build"
	end
	if state.stations[id] then
		return false, `{item.name} is already built`
	end
	local running = state.builds[item.slot]
	if running == nil and isOn and isOn(BuildRules.TUBS_FLAG) and (builders or 1) < 2 then
		for _, slot in BuildRules.SLOTS do
			running = running or state.builds[slot]
		end
	end
	if running ~= nil then
		local busy = BuildRules.ITEMS[running.item]
		return false, `Wait for the {if busy then busy.name else "build"} to finish`
	end
	local before = item.requires
	if before and not state.stations[before] then
		local first = BuildRules.ITEMS[before]
		return false, `Build the {if first then first.name else before} first`
	end
	if not (state.coins >= item.price) then
		return false, `Needs {item.price} coins`
	end
	return true, nil
end

-- Starts `id` at `now` when canStart allows it: takes the price and sets the slot's end time. Returns the
-- coins spent (0 when refused).
function BuildRules.start(
	state: State,
	id: string,
	now: number,
	isOn: IsOn?,
	builders: number?
): number
	if not BuildRules.canStart(state, id, isOn, builders) then
		return 0
	end
	local item = BuildRules.item(id, isOn) :: Item
	state.coins -= item.price
	state.builds[item.slot] = { item = id, endsAt = now + item.seconds }
	return item.price
end

-- Finishes every build whose end time has passed at `now` and returns their ids. Coming back late loses nothing.
function BuildRules.finish(state: State, now: number): { string }
	local done: { string } = {}
	for _, slot in BuildRules.SLOTS do
		local build = state.builds[slot]
		if build and now >= build.endsAt then
			state.stations[build.item] = true
			state.builds[slot] = nil
			table.insert(done, build.item)
		end
	end
	return done
end

-- True when a long build (LONG_SECONDS or more) was still running at time `at`. Read on join with `at` the save's
-- lastSeen, before finish, it says whether one was running when the player left (returned_day_2).
function BuildRules.longRunningAt(state: State, at: number, isOn: IsOn?): boolean
	for _, slot in BuildRules.SLOTS do
		local build = state.builds[slot]
		local item = if build then BuildRules.item(build.item, isOn) else nil
		if build and item and item.seconds >= BuildRules.LONG_SECONDS and build.endsAt > at then
			return true
		end
	end
	return false
end

-- Every switch an item's showing depends on (flag, alsoFlag, hiddenWhen), once each, for the redraws.
function BuildRules.itemFlags(): { string }
	local out: { string } = {}
	local function add(flag: string?)
		if flag and not table.find(out, flag) then
			table.insert(out, flag)
		end
	end
	for _, id in BuildRules.IDS do
		local item = BuildRules.ITEMS[id]
		add(item.flag)
		add(item.alsoFlag)
		local hidden: { string } = item.hiddenWhen or {}
		for _, flag in hidden do
			add(flag)
		end
	end
	return out
end

-- The ids the board shows and the server takes: IDS less those the switches `isOn` leave out (shown).
function BuildRules.offered(isOn: IsOn): { string }
	local out: { string } = {}
	for _, id in BuildRules.IDS do
		if BuildRules.shown(id, isOn) then
			table.insert(out, id)
		end
	end
	return out
end

-- Extra coins a customer's cat pays for the stations built. A station whose switch is off pays nothing, so the off
-- switch takes its bonus away too (Review-QA on #269).
function BuildRules.payBonus(
	stations: { [string]: boolean },
	isOn: (flag: string) -> boolean
): number
	local bonus = 0
	for id, item in BuildRules.ITEMS do
		if stations[id] and BuildRules.shown(id, isOn) then
			bonus += item.payBonus
		end
	end
	return bonus
end

-- How many tubs are built and in the game now (switch tubBuilds).
function BuildRules.tubsBuilt(stations: { [string]: boolean }, isOn: IsOn): number
	local count = 0
	for _, id in BuildRules.TUBS do
		if stations[id] and BuildRules.shown(id, isOn) then
			count += 1
		end
	end
	return count
end

-- Extra coins on a cat washed by hand for the tubs built, added after rounding with the bow and the tip.
function BuildRules.handBonus(stations: { [string]: boolean }, isOn: IsOn): number
	return BuildRules.TUB_HAND_BONUS * BuildRules.tubsBuilt(stations, isOn)
end

-- The bench's places once the tutorial is over: 3 plus one per built tub, at most BENCH_MAX.
function BuildRules.benchSize(stations: { [string]: boolean }, isOn: IsOn): number
	return math.min(
		BuildRules.BENCH_START + BuildRules.tubsBuilt(stations, isOn),
		BuildRules.BENCH_MAX
	)
end

-- Seconds before a new customer walks in after one is taken: 6 less one per built tub.
function BuildRules.refillSeconds(stations: { [string]: boolean }, isOn: IsOn): number
	return BuildRules.REFILL_START - BuildRules.tubsBuilt(stations, isOn)
end

-- Whether the tubBuilds VIP Room is built: it brings special visitors more often.
function BuildRules.hasVip(stations: { [string]: boolean }, isOn: IsOn): boolean
	return stations.VipRoom == true and isOn(BuildRules.TUBS_FLAG)
end

-- The tip jar (issue 517) with the Garden built: hours it holds and how much faster it fills; 8 h and 1 without.
function BuildRules.jar(stations: { [string]: boolean }, isOn: IsOn): (number, number)
	if stations.Garden and BuildRules.shown("Garden", isOn) then
		return BuildRules.GARDEN_JAR_HOURS, BuildRules.GARDEN_JAR_TIMES
	end
	return 8, 1
end

return table.freeze(BuildRules)
