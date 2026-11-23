--!strict
-- SaveSchema: what one player's save holds, and how an old save is brought up to date. Pure (no Roblox services),
-- so tests/specs/SaveSchema.spec.luau checks it.
--
-- Adding a field:
-- 1. Add it to Save and to template() with its starting value.
-- 2. If old saves need a value other than the template's, raise VERSION and add a step to migrate().
-- 3. A field old saves can simply lack (read as nil until first written) needs no VERSION bump. Then keep the
--    feature that writes it behind a live switch (shared/LiveFlags) that stays off until every running server has
--    the new code: an old server loads the save without that field and writes it back without it.
-- Never rename or reuse a field: old saves still hold the old name.

-- A cat living in the display window. `cat` is a coat name from the Cat Index (for example "Smudge").
export type Resident = {
	cat: string,
	bow: string?, -- one of SpaRules.BOWS, or nil
	since: number, -- os.time() it moved in
}

-- A build running in one slot. The server sets endsAt (os.time()); it finishes when os.time() passes it, so it
-- also finishes while the player is away.
export type Build = {
	item: string, -- what is being built, for example "BrushTable" or "VipRoom"
	endsAt: number,
}

-- One cat's Cat Index stamps.
export type IndexEntry = {
	washed: boolean,
	resident: boolean,
}

export type Save = {
	version: number,
	createdAt: number, -- os.time() of the first join
	lastSeen: number, -- os.time() of the last save
	playSeconds: number,
	coins: number, -- paid by SpaService (photo, customers)
	funnel: { [string]: boolean }, -- Telemetry funnel steps this save already logged
	-- First slice (#31). Each is filled in by its own feature behind its own switch.
	stars: number, -- customer stars
	residents: { Resident }, -- window cats, in the order they moved in
	tools: { [string]: boolean }, -- bought tools, for example BubbleSoap = true
	stations: { [string]: boolean }, -- finished stations and rooms, for example BrushTable = true
	builds: { [string]: Build }, -- running builds by slot name ("station", "room")
	index: { [string]: IndexEntry }, -- Cat Index stamps by coat name
	indexBonusPaid: boolean, -- the full set bonus, paid once
	tutorialStep: number, -- the highest first session step reached (0 before the first scrub)
}

local SaveSchema = {}

SaveSchema.VERSION = 1

function SaveSchema.template(now: number): Save
	return {
		version = SaveSchema.VERSION,
		createdAt = now,
		lastSeen = now,
		playSeconds = 0,
		coins = 0,
		funnel = {},
		stars = 0,
		residents = {},
		tools = {},
		stations = {},
		builds = {},
		index = {},
		indexBonusPaid = false,
		tutorialStep = 0,
	}
end

-- Steps from each old version to the next. migrate() runs them in order. Example for VERSION 2:
--   [1] = function(data) data.gems = 0 end,
local STEPS: { [number]: (data: { [string]: any }) -> () } = {}

-- Takes whatever the DataStore held and returns a save of the current shape, or nil plus a reason when the save
-- is newer than this server understands (an old server must never load and overwrite a newer save).
function SaveSchema.migrate(raw: unknown, now: number): (Save?, string?)
	if type(raw) ~= "table" then
		return SaveSchema.template(now), nil
	end
	local data = raw :: { [string]: any }
	local version = if type(data.version) == "number" then data.version else 0
	if version > SaveSchema.VERSION then
		return nil, `save version {version} is newer than this server's {SaveSchema.VERSION}`
	end
	for v = version, SaveSchema.VERSION - 1 do
		local step = STEPS[v]
		if step ~= nil then
			step(data)
		end
	end
	-- Missing fields take the template's value, so a save from before a field existed still works. A field of the
	-- wrong kind (a damaged save) takes it too, so code can trust the types above. Keys this server does not know
	-- are left alone: a newer server's fields survive an older server loading and writing the save back.
	-- Number fields must also be finite: NaN or infinity would poison every sum they touch.
	for key, value in SaveSchema.template(now) :: any do
		local current = data[key]
		local wrongKind = type(current) ~= type(value)
		local badNumber = type(current) == "number"
			and (current ~= current or math.abs(current) == math.huge)
		if current == nil or wrongKind or badNumber then
			data[key] = value
		end
	end
	data.version = SaveSchema.VERSION
	return (data :: any) :: Save, nil
end

return SaveSchema
