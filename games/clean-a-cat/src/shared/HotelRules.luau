--!strict
-- HotelRules: the Cat Hotel behind the back door (issue 1049, Derek's pick of 2026-11-27 for issue 1042; spec by
-- Design-Agent in the shared files, Design-Agent/cat-hotel/cat-hotel-spec.md). Behind the switch catHotel, off by
-- default, which needs expansionDoor (ExpansionRules) and builds (BuildRules) on too.
--
-- Opening the hotel is a timed build, like the other builds (Derek, plan page "hotelnums": "Make it take construction
-- time also like other builds"): the back door's prompt starts the build CatHotel (BuildRules: 1,500 coins, 20 min,
-- with Finish now), the door shows Model-Agent's building look while it runs, then stands open with the hotel behind
-- it. Rooms 1 and 2 are open at once; rooms 3 and 4 are the builds HotelRoom3 (3,000 coins, 30 min) and HotelRoom4
-- (8,000 coins, 1 h). A save that unlocked the door before this switch (expansionUnlocked) has the hotel open.
--
-- A stay: while a room is free a guest waits at the desk, rolled on the server like the bench (CatRules.roll at the
-- player's star tier, never a special visitor). BookStay(room, hours) puts it to bed for 1, 4 or 8 hours, on server
-- time, online or away. Once it ends, CollectRoom(room) (nil: every ready room) pays STAY_PAY times the rarity's
-- RARITY_TIMES and a thank-you gift rolled from GIFT_CHANCES: bonus coins (+25%), the next bow tier, or a normal
-- crate. The stay is cleared before the pay is added, so it pays once. No Robux inside the hotel.
--
-- While catHotel is on, the Garden leaves the back door for the side yard spot GARDEN_SPOT (Model-Agent's, #1050),
-- in its side yard looks GARDEN_*_ASSET. That spot is the old VIP door's site, so the side Garden needs noVipRoom on
-- too; with catHotel on and noVipRoom off there is no Garden at all (the hotel holds the back door).
-- Pure, so tests/specs/HotelRules.spec.luau covers it; HotelService and StationService use it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))

local HotelRules = {}

HotelRules.FLAG = "catHotel"
HotelRules.ID = "CatHotel" -- the BuildRules item that opens the hotel
HotelRules.ROOM_BUILDS =
	table.freeze({ [3] = "HotelRoom3", [4] = "HotelRoom4" }) :: { [number]: string }
HotelRules.START_ROOMS = 2
HotelRules.MAX_ROOMS = 4

-- Model-Agent's looks (#1050, PR 1079): the hotel pivots at the back door's spot, as the door looks do.
HotelRules.AREA_ASSET = "CleanACat_Area_Hotel"
HotelRules.AREA_NAME = "Hotel" -- in the plot's stations folder
HotelRules.DOOR_BUILDING_ASSET = "CleanACat_Area_BackDoorBuilding" -- the door while CatHotel builds
HotelRules.SUITCASE_ASSET = "CleanACat_Prop_Suitcase"
HotelRules.DESK_SPOT = "SpotHotelDesk"
HotelRules.ROOM_SPOT_PREFIX = "SpotHotelRoom" -- .. 1 to 4: a bed top
HotelRules.LOCK_DECOR = "Room%dLock_Decor" -- the end of a child model's name: shown until that room is built
HotelRules.BUILD_DECOR = "Room%dBuild_Decor" -- the end of a child model's name: shown only while that room builds
HotelRules.GUEST_SCALE_ATTRIBUTE = "GuestScale"
HotelRules.GARDEN_SPOT = "SpotGardenSide"
HotelRules.GARDEN_LOCKED_ASSET = "CleanACat_Area_GardenSideLocked"
HotelRules.GARDEN_BUILDING_ASSET = "CleanACat_Area_GardenSideBuilding"
HotelRules.GARDEN_AREA_ASSET = "CleanACat_Area_GardenSide"
HotelRules.NO_VIP_FLAG = "noVipRoom" -- the VIP Room taken out (issue 1063): its site is free for the side Garden

-- Attributes the server keeps for the client.
HotelRules.GUEST_ATTRIBUTE = "HotelGuest" -- on the guest model, and on the stay's sleeping cat: the cat's kind
HotelRules.ROOM_ATTRIBUTE = "HotelRoom" -- on a sleeping guest model: its room
HotelRules.ENDS_ATTRIBUTE = "EndsAt" -- on a sleeping guest model: os.time() the stay ends
HotelRules.BUILDING_ATTRIBUTE = "HotelBuilding" -- Player attribute: true while the CatHotel build runs

HotelRules.BOOK_REMOTE = "BookStay"
HotelRules.COLLECT_REMOTE = "CollectRoom"
HotelRules.STATE_EVENT = "Hotel" -- server to client: the hotel's state (HotelRules.view)
HotelRules.SERVER_REACH = 26 -- studs from the hotel's pivot: anywhere inside it, with room for lag

-- Stays (tuning hotel.stay and hotel.rarity).
HotelRules.HOURS = table.freeze({ 1, 4, 8 }) :: { number }
HotelRules.STAY_PAY = table.freeze({ [1] = 60, [4] = 200, [8] = 360 }) :: { [number]: number }
HotelRules.RARITY_TIMES = table.freeze({
	Common = 1,
	Uncommon = 1.25,
	Rare = 1.5,
	Epic = 2,
	Legendary = 3,
}) :: { [string]: number }

-- The thank-you gift (tuning hotel.gift), in percent per stay length; each row sums to 100. Shown on the stay card.
HotelRules.GIFTS = table.freeze({ "coins", "bow", "crate" }) :: { string }
HotelRules.GIFT_CHANCES = table.freeze({
	[1] = table.freeze({ coins = 90, bow = 8, crate = 2 }),
	[4] = table.freeze({ coins = 75, bow = 18, crate = 7 }),
	[8] = table.freeze({ coins = 65, bow = 23, crate = 12 }),
}) :: { [number]: { [string]: number } }
HotelRules.BONUS_SHARE = 0.25 -- hotel.bonusCoins: the coins gift is this share of the stay's pay
HotelRules.GIFT_CRATE = "normal" -- CrateRules kind

export type Stay = { kind: string, rarity: string, hours: number, endsAt: number }
export type Guest = { kind: string, rarity: string }
export type Save = {
	stations: { [string]: boolean },
	expansionUnlocked: boolean,
	hotel: { stays: { [string]: Stay } }?,
}

-- Whether the hotel is open for this save: the CatHotel build done, or the back door unlocked before this switch.
function HotelRules.open(stations: { [string]: boolean }, expansionUnlocked: boolean): boolean
	return stations[HotelRules.ID] == true or expansionUnlocked
end

-- Whether build `id` is one of the hotel's (opening it, rooms 3 and 4): started and finished at the hotel too.
function HotelRules.isBuild(id: string): boolean
	return id == HotelRules.ID or id == HotelRules.ROOM_BUILDS[3] or id == HotelRules.ROOM_BUILDS[4]
end

-- How many rooms take guests: 2, then 3 with HotelRoom3 built, 4 with HotelRoom4 too.
function HotelRules.rooms(stations: { [string]: boolean }): number
	local rooms = HotelRules.START_ROOMS
	for room = HotelRules.START_ROOMS + 1, HotelRules.MAX_ROOMS do
		if stations[HotelRules.ROOM_BUILDS[room]] == true then
			rooms = room
		else
			break
		end
	end
	return rooms
end

-- The coins a stay of `hours` pays for a guest of `rarity`.
function HotelRules.pay(hours: number, rarity: string): number
	local base = HotelRules.STAY_PAY[hours] or 0
	return math.floor(base * (HotelRules.RARITY_TIMES[rarity] or 1) + 0.5)
end

-- The gift for a stay of `hours` from a roll `pick` in [0, 1).
function HotelRules.gift(hours: number, pick: number): string
	local chances = HotelRules.GIFT_CHANCES[hours] or HotelRules.GIFT_CHANCES[1]
	local at = pick * 100
	local total = 0
	for _, gift in HotelRules.GIFTS do
		total += chances[gift]
		if at < total then
			return gift
		end
	end
	return "coins"
end

-- The bonus coins gift for a stay that paid `coins`.
function HotelRules.bonus(coins: number): number
	return math.max(1, math.floor(coins * HotelRules.BONUS_SHARE + 0.5))
end

-- A guest for the desk: a customer's cat at the player's star tier, never a special visitor. `random()` in [0, 1).
function HotelRules.rollGuest(random: () -> number, tier: number?): Guest
	local kind = CatRules.roll(random, false, tier)
	return { kind = kind, rarity = CatRules.rarityOf(kind) or "Common" }
end

local function cleanStay(raw: unknown): Stay?
	if type(raw) ~= "table" then
		return nil
	end
	local stay = raw :: any
	local kind, hours, endsAt = stay.kind, stay.hours, stay.endsAt
	if type(kind) ~= "string" or CatRules.rarityOf(kind) == nil or CatRules.isSpecial(kind) then
		return nil
	end
	if type(hours) ~= "number" or HotelRules.STAY_PAY[hours] == nil then
		return nil
	end
	if type(endsAt) ~= "number" or endsAt ~= endsAt or endsAt <= 0 then
		return nil
	end
	return {
		kind = kind,
		rarity = CatRules.rarityOf(kind) :: string,
		hours = hours,
		endsAt = endsAt,
	}
end

-- The save's stays that are well formed, by room "1" to "4" (strings, as a DataStore keeps them). A save edited by an
-- old or broken server can hold anything; a stay in a room the save has no more of is kept (rooms are never lost).
function HotelRules.cleanStays(raw: unknown): { [string]: Stay }
	local out: { [string]: Stay } = {}
	if type(raw) ~= "table" then
		return out
	end
	for room = 1, HotelRules.MAX_ROOMS do
		local stay = cleanStay((raw :: any)[tostring(room)])
		if stay then
			out[tostring(room)] = stay
		end
	end
	return out
end

-- The first free room of `rooms`, or nil when every one holds a guest.
function HotelRules.freeRoom(stays: { [string]: Stay }, rooms: number): number?
	for room = 1, rooms do
		if stays[tostring(room)] == nil then
			return room
		end
	end
	return nil
end

-- Whether `guest` may go to bed in `room` for `hours` now, and the words when not.
function HotelRules.canBook(
	stays: { [string]: Stay },
	rooms: number,
	room: number,
	hours: number,
	guest: Guest?
): (boolean, string?)
	if guest == nil then
		return false, "No guest is waiting"
	end
	if room < 1 or room > rooms or room ~= math.floor(room) then
		return false, "That room isn't open yet"
	end
	if stays[tostring(room)] ~= nil then
		return false, "That room has a guest"
	end
	if HotelRules.STAY_PAY[hours] == nil then
		return false, "Pick 1, 4 or 8 hours"
	end
	return true, nil
end

-- Books `guest` into `room` for `hours` from `now`. Gives the stay.
function HotelRules.book(
	stays: { [string]: Stay },
	room: number,
	hours: number,
	guest: Guest,
	now: number
): Stay
	local stay: Stay = {
		kind = guest.kind,
		rarity = guest.rarity,
		hours = hours,
		endsAt = now + hours * 3600,
	}
	stays[tostring(room)] = stay
	return stay
end

-- Takes the ended stays out of `stays`: room `room`, or every ended one when nil. Gives each taken stay with its room,
-- in room order. A stay still running is left. Taken out before anything is paid, so each pays once.
function HotelRules.checkOut(
	stays: { [string]: Stay },
	room: number?,
	now: number
): { { room: number, stay: Stay } }
	local out: { { room: number, stay: Stay } } = {}
	for at = 1, HotelRules.MAX_ROOMS do
		local key = tostring(at)
		local stay = stays[key]
		if stay and (room == nil or room == at) and now >= stay.endsAt then
			stays[key] = nil
			table.insert(out, { room = at, stay = stay })
		end
	end
	return out
end

-- The next bow tier after `current` among `tiers` (cheapest first), or nil at the top: the bow gift.
function HotelRules.nextBow(tiers: { string }, owned: { [string]: boolean }): string?
	for index = 2, #tiers do
		if not owned[tiers[index]] then
			return tiers[index]
		end
	end
	return nil
end

-- Whether the Garden stands at the side yard (catHotel on, and noVipRoom on so the VIP Room's site is free).
function HotelRules.gardenAtSide(isOn: (flag: string) -> boolean): boolean
	return isOn(HotelRules.FLAG) and isOn(HotelRules.NO_VIP_FLAG)
end

return table.freeze(HotelRules)
