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

-- The first session funnel (milestone-1 analytics plan). Step numbers are the positions in this list. If the steps
-- ever change, the funnel gets a new name (onboarding_v2).
TelemetryRules.ONBOARDING = "onboarding_v1"
TelemetryRules.ONBOARDING_STEPS = table.freeze({
	"joined", -- the save's first load
	"loaded", -- the client finished loading and the character can move (reported by the client)
	"first_scrub", -- the first rub on a dirty cat (reported by the client)
	"first_reveal", -- the server accepted the first fully scrubbed cat
	"first_photo", -- the first photo paid
	"first_customer", -- the first customer handed over a cat
	"first_return", -- the first customer took their cat home and paid
	"upgrade_1", -- the first tool bought
	"first_build", -- the first build started
	"dryer_built", -- the Blow Dryer finished
})
-- Steps only the client can see. It reports them through ReportStep; a lie only moves our own chart.
TelemetryRules.CLIENT_STEPS = table.freeze({ "loaded", "first_scrub" })
TelemetryRules.DAY_SECONDS = 86400

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
