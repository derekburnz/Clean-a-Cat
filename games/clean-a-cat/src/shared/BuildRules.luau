--!strict
-- BuildRules: stations and rooms that take time to build. There is one build slot per kind (SLOTS): the builder
-- kitten builds one station at a time and the building site one room at a time, so a long room never blocks a
-- station and the spa never closes. The server sets every end time (os.time()), so a build also finishes while
-- the player is away. No paid skips. Pure, so tests/specs/BuildRules.spec.luau covers it; BuildService runs it.
-- Prices, times and bonuses are draft tuning from the first session plan; Design-Agent owns them.
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
}

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
	}) :: Item
end

BuildRules.SLOTS = table.freeze({ "station", "room" }) -- the slot count is this list's length

BuildRules.ITEMS = table.freeze({
	BrushTable = table.freeze({
		name = "Brush Table",
		slot = "station",
		price = 40,
		seconds = 10,
		payBonus = 2,
	}) :: Item,
	Dryer = table.freeze({
		name = "Blow Dryer",
		slot = "station",
		price = 75,
		seconds = 60,
		requires = "BrushTable",
		payBonus = 5,
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
}) :: { [string]: Item }

-- board order; every id is a key of ITEMS
BuildRules.IDS = table.freeze({ "BrushTable", "Dryer", "BubbleBath", "Pawdicure", "VipRoom" })
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

-- Can `state` start building `id`? False plus a short reason the player can read.
function BuildRules.canStart(state: State, id: string): (boolean, string?)
	local item = BuildRules.ITEMS[id]
	if item == nil then
		return false, "Unknown build"
	end
	if state.stations[id] then
		return false, `{item.name} is already built`
	end
	local running = state.builds[item.slot]
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
function BuildRules.start(state: State, id: string, now: number): number
	if not BuildRules.canStart(state, id) then
		return 0
	end
	local item = BuildRules.ITEMS[id]
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
function BuildRules.longRunningAt(state: State, at: number): boolean
	for _, slot in BuildRules.SLOTS do
		local build = state.builds[slot]
		local item = if build then BuildRules.ITEMS[build.item] else nil
		if build and item and item.seconds >= BuildRules.LONG_SECONDS and build.endsAt > at then
			return true
		end
	end
	return false
end

-- The ids the board shows and the server takes: IDS less those whose switch `isOn` says is off.
function BuildRules.offered(isOn: (flag: string) -> boolean): { string }
	local out: { string } = {}
	for _, id in BuildRules.IDS do
		local flag = BuildRules.ITEMS[id].flag
		if flag == nil or isOn(flag) then
			table.insert(out, id)
		end
	end
	return out
end

-- Extra coins a customer's cat pays for the stations built.
function BuildRules.payBonus(stations: { [string]: boolean }): number
	local bonus = 0
	for id, item in BuildRules.ITEMS do
		if stations[id] then
			bonus += item.payBonus
		end
	end
	return bonus
end

return table.freeze(BuildRules)
