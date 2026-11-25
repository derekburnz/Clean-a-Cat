--!strict
-- TelemetryRules: the checks every analytics call passes before it goes to Roblox. Pure, so
-- tests/specs/TelemetryRules.spec.luau covers it; server/Services/Telemetry uses it.
--
-- Roblox facts these rules follow (AnalyticsService):
-- - At most 3 custom fields per event (CustomField01 to 03). A 4th is dropped without an error, so we refuse it.
-- - A field with more than about 8,000 distinct values is folded into "Other": send short words ("phone", "tier_2"),
--   never a player's name, an id or free text.
-- - Funnel and event names show up in Creator Hub about a day later. Keep names stable; a funnel whose steps
--   change gets a new name (onboarding_v2) and is never compared across the change.

local TelemetryRules = {}

TelemetryRules.MAX_FIELDS = 3
TelemetryRules.MAX_FIELD_LENGTH = 50
TelemetryRules.MAX_NAME_LENGTH = 50

-- Lower case letters, digits and underscores: the same name everywhere, easy to search for in Creator Hub.
function TelemetryRules.validName(name: string): boolean
	return #name > 0
		and #name <= TelemetryRules.MAX_NAME_LENGTH
		and name:match("^[a-z][a-z0-9_]*$") ~= nil
end

-- A field value as sent: trimmed to MAX_FIELD_LENGTH, with anything but letters, digits, _ - . and spaces removed.
function TelemetryRules.cleanField(value: string): string
	local cleaned = value:gsub("[^%w_%-%. ]", "")
	return cleaned:sub(1, TelemetryRules.MAX_FIELD_LENGTH)
end

-- The custom fields table AnalyticsService takes, or nil plus a reason when the call is wrong.
function TelemetryRules.fields(values: { string }?): ({ [string]: string }?, string?)
	if values == nil or #values == 0 then
		return {}, nil
	end
	if #values > TelemetryRules.MAX_FIELDS then
		return nil, `{#values} custom fields; Roblox keeps only {TelemetryRules.MAX_FIELDS}`
	end
	local out: { [string]: string } = {}
	for i, value in values do
		out[string.format("CustomField%02d", i)] = TelemetryRules.cleanField(value)
	end
	return out, nil
end

-- The first session funnel (Growth-Agent's funnel spec, #421). Step numbers are the positions in this list. If the
-- steps ever change once a live server has logged them, the funnel gets a new name (onboarding_v2).
TelemetryRules.ONBOARDING = "onboarding_v1"
TelemetryRules.ONBOARDING_STEPS = table.freeze({
	"joined", -- the save's first load
	"loaded", -- the client finished loading and the character can move (reported by the client)
	"first_move", -- the player's first input (reported by the client)
	"first_scrub", -- the first rub on a dirty cat (reported by the client)
	"first_reveal", -- the server accepted the first fully scrubbed cat: the mud is gone and the coat shows
	"first_photo", -- the first photo paid: the before and after card shows
	"first_customer", -- the first customer handed over a cat
	"first_upgrade", -- the first tool bought or station build started
	"first_build_started", -- the first build timer started
	"first_long_build_started", -- the first build of BuildRules.LONG_SECONDS (an hour) or more (optional in session one)
})
-- Steps only the client can see. It reports them through ReportStep; a lie only moves our own chart.
TelemetryRules.CLIENT_STEPS = table.freeze({ "loaded", "first_move", "first_scrub" })
TelemetryRules.DAY_SECONDS = 86400

-- The play time funnel: marks every session passes, logged once per session (not per save), so it reads as how
-- long sessions last. Step 1 is the first input; the rest are seconds since the session's save loaded.
TelemetryRules.PLAYTIME = "playtime_v1"
export type Mark = { name: string, seconds: number? }
local marks: { Mark } = {
	{ name = "moved" },
	{ name = "sec_30", seconds = 30 },
	{ name = "min_1", seconds = 60 },
	{ name = "min_2", seconds = 120 },
	{ name = "min_3", seconds = 180 },
	{ name = "min_4", seconds = 240 },
	{ name = "min_5", seconds = 300 },
	{ name = "min_10", seconds = 600 },
	{ name = "min_15", seconds = 900 },
	{ name = "min_30", seconds = 1800 },
	{ name = "hour_1", seconds = 3600 },
}
TelemetryRules.PLAYTIME_MARKS = table.freeze(marks)

-- The play time marks reached by `elapsed` seconds that `logged` (this session's marks, by step number) does not
-- have yet, in order. "moved" is never due by time: the client's first input logs it.
function TelemetryRules.playtimeDue(elapsed: number, logged: { [number]: boolean }): { number }
	local due = {}
	for step, mark in TelemetryRules.PLAYTIME_MARKS do
		local seconds = mark.seconds
		if seconds ~= nil and elapsed >= seconds and not logged[step] then
			table.insert(due, step)
		end
	end
	return due
end

-- Side events the client reports (ReportStep with a second argument), each with the details it may name. The
-- server logs each pair once per save, only in the save's first session.
local clientEvents: { [string]: { string } } = {
	hint_shown = { "pick", "wash" }, -- the opening's tip line showed (OpeningController)
	hint_followed_10s = { "pick", "wash" }, -- the player did what it said within HINT_FOLLOW_SECONDS
	window_opened = { "Settings", "Queue", "CatIndex", "Example", "other" }, -- UI.open's window names
}
TelemetryRules.CLIENT_EVENTS = table.freeze(clientEvents)
TelemetryRules.HINT_FOLLOW_SECONDS = 10
TelemetryRules.WINDOW_SECONDS = 300 -- window_opened counts only in the first 5 minutes of the first session

-- True when `name` and `detail` are a side event the client may report.
function TelemetryRules.clientEvent(name: unknown, detail: unknown): boolean
	if type(name) ~= "string" or type(detail) ~= "string" then
		return false
	end
	local details: { string }? = TelemetryRules.CLIENT_EVENTS[name]
	return details ~= nil and table.find(details, detail) ~= nil
end

-- The step's number in the onboarding funnel, or nil for a name not in it.
function TelemetryRules.stepNumber(name: string): number?
	return table.find(TelemetryRules.ONBOARDING_STEPS, name)
end

-- The once per save rule: true the first time `key` is seen in `logged` (the save's funnel table), and records
-- it. Every later call for the same key is false. A step missed earlier is not filled in by a later one.
function TelemetryRules.markOnce(logged: { [string]: boolean }, key: string): boolean
	if logged[key] then
		return false
	end
	logged[key] = true
	return true
end

-- Only a save whose first session ran with the funnel on is in it: `joined` (step 1) goes in only for a brand new
-- save (no play time yet), and every later step only for a save that logged `joined`. A save from before the
-- switch went on stays out, so it never looks like a first session.
function TelemetryRules.inFunnel(
	logged: { [string]: boolean },
	step: number,
	playSeconds: number
): boolean
	if step == 1 then
		return playSeconds <= 0
	end
	return logged[`{TelemetryRules.ONBOARDING}:1`] == true
end

-- The highest onboarding step this save has logged: its number and name, or 0 and "none".
function TelemetryRules.lastStep(logged: { [string]: boolean }): (number, string)
	for step = #TelemetryRules.ONBOARDING_STEPS, 1, -1 do
		if logged[`{TelemetryRules.ONBOARDING}:{step}`] then
			return step, TelemetryRules.ONBOARDING_STEPS[step]
		end
	end
	return 0, "none"
end

-- True when `now` falls on the day after the first join (UTC days), which is what returned_day_2 counts.
function TelemetryRules.isDay2(createdAt: number, now: number): boolean
	local day = TelemetryRules.DAY_SECONDS
	return math.floor(now / day) == math.floor(createdAt / day) + 1
end

return TelemetryRules
