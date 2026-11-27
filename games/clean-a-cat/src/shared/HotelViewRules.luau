--!strict
-- HotelViewRules: what the Cat Hotel's stay card and room bubbles show (issue 1051, the UI half of issue 1049; Design-
-- Agent's spec, Design-Agent/cat-hotel/cat-hotel-spec.md). Behind catHotel, like HotelRules. The server sends the
-- hotel's state on the Hotel event (HotelRules.STATE_EVENT); this turns it into words and numbers:
--   * the guest at the desk, and the three stays it can book (1, 4 or 8 hours), each with its true pay for that guest
--     (HotelRules.pay) and its gift chances, always shown (rule 9's spirit: anything random shows its odds);
--   * each room: free, asleep with the time left, ready with its coins, or not built yet;
--   * "Collect all" with the coins every ready room pays (the bonus gift is extra, so it is not counted here).
-- Calm words only: no "hurry", nothing that counts down in red. No Robux anywhere in the hotel.
-- Pure, so tests/specs/HotelViewRules.spec.luau covers it; UI/HotelWindow and HotelController use it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))
local HotelRules = require(script.Parent:WaitForChild("HotelRules"))

local HotelViewRules = {}

HotelViewRules.WINDOW = "Hotel"
HotelViewRules.TITLE = "Cat Hotel"
HotelViewRules.PROMPT = "Front desk"
HotelViewRules.FINE = "Stays count while you're away. Every guest leaves a thank-you gift."
-- Suds, the first time the hotel opens (the spec's line)
HotelViewRules.SUDS_TITLE = "The Cat Hotel is open!"
HotelViewRules.SUDS_LINE = "Book a stay before you go. Guests pay you while you're away."

HotelViewRules.GIFT_WORDS = table.freeze({
	coins = "Bonus coins",
	bow = "Bow",
	crate = "Crate",
}) :: { [string]: string }

export type State = {
	open: boolean,
	rooms: number,
	stays: { [string]: HotelRules.Stay },
	guest: HotelRules.Guest?,
	now: number, -- server os.time() when it was sent
}

export type Option = {
	hours: number,
	label: string, -- "4 hours"
	pay: number, -- coins for this guest
	chances: string, -- "Bonus coins 75% · Bow 18% · Crate 7%"
}

export type Room = {
	room: number,
	status: string, -- "free" | "asleep" | "ready" | "locked"
	line: string, -- the room's words on the card
	bubble: string?, -- the words over its bed: the time left, or "+300"
	kind: string?, -- the cat in it
	rarity: string?,
	coins: number?, -- while ready
}

HotelViewRules.EMPTY = table.freeze({
	open = false,
	rooms = 0,
	stays = {},
	guest = nil,
	now = 0,
}) :: State

local function whole(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw or raw == math.huge or raw == -math.huge then
		return nil
	end
	return math.floor(raw)
end

-- A state from the Hotel event's table, safe whatever arrives.
function HotelViewRules.clean(raw: unknown): State
	if type(raw) ~= "table" then
		return HotelViewRules.EMPTY
	end
	local t = raw :: any
	local guest: HotelRules.Guest? = nil
	if type(t.guest) == "table" and type(t.guest.kind) == "string" then
		local rarity = if type(t.guest.rarity) == "string" then t.guest.rarity else "Common"
		guest = { kind = t.guest.kind, rarity = rarity }
	end
	local rooms = whole(t.rooms) or 0
	return {
		open = t.open == true,
		rooms = math.clamp(rooms, 0, HotelRules.MAX_ROOMS),
		stays = HotelRules.cleanStays(t.stays),
		guest = guest,
		now = whole(t.now) or 0,
	}
end

-- "1 hour", "4 hours".
function HotelViewRules.hoursText(hours: number): string
	return if hours == 1 then "1 hour" else `{hours} hours`
end

-- Time left, calm: "3h 12m", "12m", "under 1m". Never seconds.
function HotelViewRules.leftText(seconds: number): string
	if seconds < 60 then
		return "under 1m"
	end
	local minutes = math.floor(seconds / 60)
	local hours = math.floor(minutes / 60)
	minutes -= hours * 60
	if hours > 0 then
		return if minutes > 0 then `{hours}h {minutes}m` else `{hours}h`
	end
	return `{minutes}m`
end

-- The gift chances of a stay of `hours`, in HotelRules.GIFTS order: the first on its own line, the rest on the next
-- ("Bonus coins 75%\nBow 18% · Crate 7%"), so no chance is split across two lines on a phone.
function HotelViewRules.chancesText(hours: number): string
	local chances = HotelRules.GIFT_CHANCES[hours] or HotelRules.GIFT_CHANCES[1]
	local parts: { string } = {}
	for _, gift in HotelRules.GIFTS do
		table.insert(parts, `{HotelViewRules.GIFT_WORDS[gift] or gift} {chances[gift]}%`)
	end
	local first = table.remove(parts, 1) or ""
	return if #parts > 0 then `{first}\n{table.concat(parts, " · ")}` else first
end

-- The three stays for `guest` (or for a Common guest when none waits, so the card still shows the pay).
function HotelViewRules.options(guest: HotelRules.Guest?): { Option }
	local rarity = if guest then guest.rarity else "Common"
	local out: { Option } = {}
	for _, hours in HotelRules.HOURS do
		table.insert(out, {
			hours = hours,
			label = HotelViewRules.hoursText(hours),
			pay = HotelRules.pay(hours, rarity),
			chances = HotelViewRules.chancesText(hours),
		})
	end
	return out
end

-- The room a booking goes to now, or nil (no guest, or every open room has one).
function HotelViewRules.bookRoom(state: State): number?
	if not state.open or state.guest == nil then
		return nil
	end
	return HotelRules.freeRoom(state.stays, state.rooms)
end

-- The words over the desk on the card: who waits, or why nobody does.
function HotelViewRules.guestLine(state: State): string
	local guest = state.guest
	if guest and HotelViewRules.bookRoom(state) then
		return `{CatRules.displayName(guest.kind)} would like a room`
	end
	if HotelRules.freeRoom(state.stays, state.rooms) == nil then
		return "Every room has a guest"
	end
	return "A guest will be here soon"
end

-- Each of the four rooms at server time `now`.
function HotelViewRules.rooms(state: State, now: number): { Room }
	local out: { Room } = {}
	for room = 1, HotelRules.MAX_ROOMS do
		local stay = state.stays[tostring(room)]
		if stay then
			if now >= stay.endsAt then
				local coins = HotelRules.pay(stay.hours, stay.rarity)
				table.insert(out, {
					room = room,
					status = "ready",
					line = `Ready · +{coins}`,
					bubble = `+{coins}`,
					kind = stay.kind,
					rarity = stay.rarity,
					coins = coins,
				})
			else
				local left = HotelViewRules.leftText(stay.endsAt - now)
				table.insert(out, {
					room = room,
					status = "asleep",
					line = `Asleep · {left}`,
					bubble = left,
					kind = stay.kind,
					rarity = stay.rarity,
				})
			end
		elseif room > state.rooms then
			table.insert(out, {
				room = room,
				status = "locked",
				line = "Build it on the Build board",
			})
		else
			table.insert(out, { room = room, status = "free", line = "Free" })
		end
	end
	return out
end

-- How many rooms are ready and the coins they pay together (without the gifts).
function HotelViewRules.ready(state: State, now: number): (number, number)
	local count, coins = 0, 0
	for _, room in HotelViewRules.rooms(state, now) do
		if room.status == "ready" then
			count += 1
			coins += room.coins or 0
		end
	end
	return count, coins
end

-- The Collect all button's words, or nil to hide it.
function HotelViewRules.collectText(state: State, now: number): string?
	local count, coins = HotelViewRules.ready(state, now)
	if count == 0 then
		return nil
	end
	return `Collect all · {coins} coins`
end

return HotelViewRules
