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

-- A worker the player hired (WorkerRules, issue 509), by id ("Jo", "Sam", "Lou").
export type Worker = {
	mode: string, -- which cat they take next: "first", "leaving", "rarest" or "dirtiest"
	level: number, -- 1 to 5
	name: string?, -- the name the player typed, raw; filtered again on every load (#487); nil for the default
	station: string?, -- the plot spot their station stands on, nil until it is placed
	hiredAt: number, -- os.time()
}

-- A pet from a crate (issues 511 and 512). `id` is unique in this save (nextPetId).
export type Pet = {
	id: number,
	kind: string, -- the pet's name in the crate tables
	star: number, -- 1, 2 or 3 after star ups
	slot: string?, -- who it stays beside: "player", "player2" (second slot pass) or a worker id plus "1" or "2"; nil
	-- in the pen
}

-- The quest book (issue 516). Days count in the player's own time zone (tz, hours, saved once and never changed);
-- weeks from Monday 00:00 UTC.
export type Quests = {
	tz: number?, -- whole hours from -12 to +14; nil until the first join after quests switch on
	day: number, -- the day the daily quests were drawn for
	daily: { string }, -- today's quest ids
	progress: { [string]: number }, -- by quest id, daily and weekly
	claimed: { [string]: boolean }, -- rewards taken, by quest id
	week: number, -- the week the weekly quests are for
	weeklyCrate: boolean, -- the crate for finishing every weekly quest is taken
}

-- The check in card (issue 517): days played, not days in a row.
export type CheckIn = {
	days: number, -- rewards taken on this card, 0 to 7; the card starts again after 7
	lastDay: number, -- the day number (SaveSchema.day, the player's own time zone as quests use) of the last reward,
	-- so one a day
}

-- A cat waiting on the bench, so the bench survives a rejoin (issue 523).
export type BenchCat = {
	kind: string,
	dirt: number,
	needs: { string },
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
	oldRefunds: { [string]: boolean }, -- builds whose coins were paid back once a switch took them out (BuildRules.oldRefund)
	index: { [string]: IndexEntry }, -- Cat Index stamps by coat name
	indexBonusPaid: boolean, -- the full set bonus, paid once
	tutorialStep: number, -- the highest first session step reached (0 before the first scrub)
	suds: number, -- how far the opening's kitten got: SudsRules.NONE, BOX (box opened) or DONE (washed and named)
	bubbles: { [string]: boolean }, -- Suds's help bubbles this save already showed, by BubbleRules id (switch sudsBubble)
	-- The agreed design (issue 523). Each is written only by its own feature behind its own switch.
	bows: { [string]: boolean }, -- bow tiers bought (issue 508); the plain ribbon is everyone's and not stored
	bow: string, -- the bow tier tied on every hand washed cat
	workers: { [string]: Worker }, -- hired workers by id
	pets: { Pet }, -- every pet owned, doubles too, until three fuse
	nextPetId: number,
	crates: { [string]: number }, -- unopened crates by kind ("normal", "good")
	quests: Quests,
	checkin: CheckIn,
	receipts: { string }, -- the newest PurchaseIds already granted (at most RECEIPTS_KEPT), so a product is never
	-- granted twice
	starterEndsAt: number, -- os.time() the starter pack offer ends: stamped once by SaveSchema.stampStarter as
	-- createdAt + 72 hours (the owner's call: 72 hours from first join) while it is 0, and never moved after
	starterPet: boolean, -- the starter pack's golden pet was given (StarterRules.givePet, issue 1090)
	starterOpened: boolean, -- the player opened the starter pack window once: its button never bobs again (issue 528)
	visits: number, -- joins of this save, the first included (the starter pack button bobs on visits 2 to 4)
	asks: { [string]: boolean }, -- first session asks and HUD unlocks already shown, by ask id (issue 522)
	giftClaimed: boolean, -- the gift stand's pet (issue 521) is granted
	giftFavourite: boolean, -- the player said they favourited, as the client told it (only for that cosmetic)
	freeRewards: { play: boolean, like: boolean }, -- the gift card's Free Rewards rows already paid (issue 730)
	likeAskedAt: number, -- os.time() the card's like ask was first opened, 0 before (FreeRewardRules; never a like)
	likeNoVisit: number, -- the visit the like ask was last answered "Not now", 0 before (LikeAskRules)
	likeNos: number, -- how many times the like ask was answered "Not now" (LikeAskRules.MAX_NOS)
	likeYes: boolean, -- the like ask was once answered "yes": it never comes again
	visiting: boolean, -- others may visit this spa (issue 520)
	expansionUnlocked: boolean, -- the back door expansion is unlocked with coins (ExpansionRules, issue 1041)
	hotel: { stays: { [string]: any } }, -- the Cat Hotel's stays by room "1" to "4" (HotelRules.Stay; issue 1049)
	jarCoins: number, -- the tip jar's coins waiting (issue 517)
	jarAt: number, -- os.time() the jar was last filled or emptied
	bench: { BenchCat }, -- the cats waiting, front first, as last saved
	reopens: number, -- Grand Reopenings done (none at launch; see reopen)
	finishCredits: { [string]: number }, -- Finish now bought with nothing left to finish, by tier "1" to "5": the next
	-- one it covers is free (FinishRules, issue 515)
	passes: { [string]: boolean }, -- game passes this save knows the player owns, by Passes key (issue 518): set when a
	-- purchase completes or Roblox says so on a join, and never taken back, so a slow ownership check loses nothing
}

local CrateRules = require(script.Parent:WaitForChild("CrateRules"))

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
		oldRefunds = {},
		index = {},
		indexBonusPaid = false,
		tutorialStep = 0,
		suds = 0,
		bubbles = {},
		bows = {},
		bow = "Ribbon",
		workers = {},
		pets = {},
		nextPetId = 1,
		crates = {},
		quests = {
			day = 0,
			daily = {},
			progress = {},
			claimed = {},
			week = 0,
			weeklyCrate = false,
		},
		checkin = { days = 0, lastDay = 0 },
		receipts = {},
		starterEndsAt = 0,
		starterOpened = false,
		starterPet = false,
		visits = 0,
		asks = {},
		giftClaimed = false,
		giftFavourite = false,
		freeRewards = { play = false, like = false },
		likeAskedAt = 0,
		likeNoVisit = 0,
		likeNos = 0,
		likeYes = false,
		visiting = true,
		expansionUnlocked = false,
		hotel = { stays = {} },
		jarCoins = 0,
		jarAt = 0,
		bench = {},
		reopens = 0,
		finishCredits = {},
		passes = {},
	}
end

-- Receipts kept so a repeated purchase callback is never granted twice; older ones are long settled.
SaveSchema.RECEIPTS_KEPT = 100

-- What a Grand Reopening would reset: the spa's layout and progress. Everything else is what the player owns for good
-- (pets, crates, the Cat Index, passes, the quest book, the check in card, settings) and is kept. Not at launch; the
-- owner has not decided it, so this list is a draft to change when he does. Two paid things sit in reset fields and
-- need care before this is ever used: Lou is a paid helper (a pass) in `workers`, so the reopen must grant him again
-- from the pass, and a build finished with Robux (Finish now, issue 515) is in `builds`, so it would be lost.
SaveSchema.REOPEN_RESETS = table.freeze({
	"coins",
	"stars",
	"residents",
	"tools",
	"stations",
	"builds",
	"bows",
	"bow",
	"workers",
	"bench",
	"jarCoins",
	"jarAt",
}) :: { string }

-- A Grand Reopening of `save`: the REOPEN_RESETS fields go back to a new save's, a pet beside a worker goes back to
-- the pen (the worker is gone), and the count goes up. Pure; nothing calls it at launch.
function SaveSchema.reopen(save: Save, now: number): Save
	local fresh = SaveSchema.template(now) :: any
	local data = save :: any
	for _, key in SaveSchema.REOPEN_RESETS do
		data[key] = fresh[key]
	end
	for _, pet in save.pets do
		if pet.slot ~= nil and string.sub(pet.slot, 1, 6) ~= "player" then
			pet.slot = nil
		end
	end
	save.reopens += 1
	return save
end

-- How long the starter pack offer lasts from first join (tuning: starter pack, 72 hours).
SaveSchema.STARTER_SECONDS = 72 * 60 * 60

-- Stamps the starter pack's end once, from first join; a save stamped already keeps its end. With `now`, a save from
-- before the pack existed starts its 72 hours at this join instead (Growth-Agent's rule), never earlier than its
-- first join. Returns the end.
function SaveSchema.stampStarter(save: Save, now: number?): number
	if save.starterEndsAt == 0 then
		save.starterEndsAt = math.max(save.createdAt, now or 0) + SaveSchema.STARTER_SECONDS
	end
	return save.starterEndsAt
end

-- The day number at `now` in the player's own time zone (quests.tz, UTC until it is saved), for the quest book and
-- the check in card alike.
function SaveSchema.day(save: Save, now: number): number
	return (now + (save.quests.tz or 0) * 60 * 60) // 86400
end

-- Records `id` as granted; false when it was granted already. Keeps the newest RECEIPTS_KEPT.
function SaveSchema.addReceipt(save: Save, id: string): boolean
	if table.find(save.receipts, id) then
		return false
	end
	table.insert(save.receipts, id)
	while #save.receipts > SaveSchema.RECEIPTS_KEPT do
		table.remove(save.receipts, 1)
	end
	return true
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
	local function fill(into: { [string]: any }, template: { [string]: any })
		for key, value in template do
			local current = into[key]
			local wrongKind = type(current) ~= type(value)
			local badNumber = type(current) == "number"
				and (current ~= current or math.abs(current) == math.huge)
			if current == nil or wrongKind or badNumber then
				into[key] = value
			elseif type(value) == "table" and type((next(value))) == "string" then
				-- a record with fields of its own (quests, checkin): its missing or broken fields are filled too
				fill(current, value)
			end
		end
	end
	fill(data, SaveSchema.template(now) :: any)
	-- (issue 883) the old eight crate pets' names become the new eight's (CrateRules.RENAMED). No VERSION bump: an
	-- older server keeps a pet whose name it does not know as it is, so a save loaded there loses nothing either.
	for _, pet in data.pets do
		if type(pet) == "table" and type(pet.kind) == "string" then
			pet.kind = CrateRules.renamed(pet.kind)
		end
	end
	data.version = SaveSchema.VERSION
	return (data :: any) :: Save, nil
end

return SaveSchema
