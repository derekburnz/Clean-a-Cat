--!strict
-- CrateViewRules: what the crate window (UI/CrateWindow, switch crateWindow, issue 526) shows, from CrateRules. Every
-- pet in the crate with its chance and its boost, read from CrateRules.odds, the very list the server rolls from, so a
-- shown chance is always the real one. Pure, so tests/specs/CrateViewRules.spec.luau covers it.
local CrateRules = require(script.Parent:WaitForChild("CrateRules"))

local CrateViewRules = {}

CrateViewRules.FLAG = "crateWindow"
-- With the switch petLines (issue 927, the owner on 2026-11-26: "have a little description under the pets what they
-- give/do"), a pet's boost says what it boosts: the player's tips beside the player, a helper's pay beside a helper.
CrateViewRules.LINES_FLAG = "petLines"

-- Whether a boost is more than a helper's pets may add to their pay (CrateRules.PET_CAP).
function CrateViewRules.overCap(share: number): boolean
	return share > CrateRules.PET_CAP + 1e-9
end

-- A share as shown: 0.05 is "+5%".
local function plus(share: number): string
	return `+{math.floor(share * 100 + 0.5)}%`
end

-- What a pet's boost (a share, 0.05 is +5%) does, for its tile and its crate row: "+5% tips or pay" with petLines,
-- else "+5% boost". A helper's pets together raise their pay by at most CrateRules.PET_CAP, so a boost over the cap
-- says both true numbers: "+40% tips, +30% pay" (Review-QA on PR 953).
function CrateViewRules.effectText(share: number, isOn: ((flag: string) -> boolean)?): string
	local on = isOn ~= nil and isOn(CrateViewRules.LINES_FLAG)
	if not on then
		return `{plus(share)} boost`
	end
	if CrateViewRules.overCap(share) then
		return `{plus(share)} tips, {plus(CrateRules.PET_CAP)} pay`
	end
	return `{plus(share)} tips or pay`
end

-- A pet's boost as shown: "+5%" for `kind` at `star`.
function CrateViewRules.boostText(kind: string, star: number): string
	return plus(CrateRules.boost(kind, star))
end

CrateViewRules.SUM_LINE = "The chances add up to 100%. " .. CrateRules.ODDS_NOTE

export type Row = {
	pet: string,
	rarity: string,
	chance: string, -- "25%", or one decimal place when it is not whole ("12.5%")
	boost: string, -- "+5%"
	share: number, -- the same boost as a share (0.05), for CrateViewRules.effectText
	owned: boolean, -- the player has this pet already (an unowned one draws as a shadow)
}

-- A percent as the window writes it: whole numbers plain, anything else to one decimal place.
function CrateViewRules.percentText(percent: number): string
	local tenths = math.floor(percent * 10 + 0.5)
	if tenths % 10 == 0 then
		return `{tenths // 10}%`
	end
	return `{tenths / 10}%`
end

-- One row per pet in crate `kind`, Common first, rarest last. `owned` holds the kinds of the pets the player has.
function CrateViewRules.rows(kind: string, owned: { [string]: boolean }): { Row }
	local out: { Row } = {}
	for _, entry in CrateRules.odds(kind) do
		table.insert(out, {
			pet = entry.pet,
			rarity = entry.rarity,
			chance = CrateViewRules.percentText(entry.percent),
			boost = plus(entry.boost),
			share = entry.boost,
			owned = owned[entry.pet] == true,
		})
	end
	return out
end

-- The chances of crate `kind` added up (100 for every kind: CrateRules.CHANCES).
function CrateViewRules.total(kind: string): number
	local sum = 0
	for _, entry in CrateRules.odds(kind) do
		sum += entry.percent
	end
	return sum
end

function CrateViewRules.title(kind: string): string
	if kind == CrateRules.GIFT_KIND then
		return "Gift crate" -- the gift stand's crate (switch giftCrate, issue 859)
	end
	return if kind == "good" then "Good crate" else "Crate"
end

-- The line under the crate: how many of this kind the player holds. The good crate is the day 2 gift.
function CrateViewRules.haveLine(kind: string, count: number): string
	if count <= 0 then
		return "No crates yet"
	end
	if kind == "good" then
		return if count == 1 then "Your day 2 gift" else `You have {count} good crates`
	end
	return if count == 1 then "You have 1 crate" else `You have {count} crates`
end

-- The Robux crate rows (issue 514, switch crateShop): the same normal crate that is earned, for Robux. Shown only
-- on that crate's window, only while the server allows this player to buy (the Player attribute CrateShop, which
-- PolicyService gates), and only for a key whose real price is known. The chance list sits beside them on the same
-- screen, so it is seen before any buy. Plain words: no "best value", no hurry.
CrateViewRules.SHOP_TITLE = "More crates"

export type ShopRow = {
	key: string, -- the Products key (CrateRules.SHOP_KEYS)
	label: string, -- "1 crate", "5 crates"
	price: number, -- Robux
}

function CrateViewRules.shopRows(
	kind: string,
	allowed: boolean,
	price: (key: string) -> unknown
): { ShopRow }
	local out: { ShopRow } = {}
	if not allowed or kind ~= CrateRules.SHOP_KIND then
		return out
	end
	for _, key in CrateRules.SHOP_KEYS do
		local raw = price(key)
		local crates = CrateRules.SHOP[key]
		if type(raw) == "number" and raw == raw and raw > 0 and raw < math.huge and crates then
			table.insert(out, {
				key = key,
				label = if crates == 1 then "1 crate" else `{crates} crates`,
				price = math.floor(raw),
			})
		end
	end
	return out
end

-- The kinds of every pet in a Pets list (the server's Pets remote), for `rows`.
function CrateViewRules.ownedKinds(pets: { CrateRules.Pet }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, pet in pets do
		out[pet.kind] = true
	end
	return out
end

-- The pets window (UI/PetsWindow, switch petsWindow): the player's pets grouped by kind and star, and the slots.

CrateViewRules.PETS_FLAG = "petsWindow"
CrateViewRules.HELPERS = table.freeze({ "Jo", "Sam", "Lou" }) :: { string } -- WorkerRules.WORKERS, in hiring order

export type Group = {
	key: string, -- "<kind>:<star>"
	kind: string,
	rarity: string,
	star: number,
	count: number,
	ids: { number }, -- the pets' ids, the ones in a slot first (a fuse keeps the first, so a slotted pet stays put)
	free: { number }, -- the ids not in any slot
	slots: { string }, -- the slots holding one of these
	canFuse: boolean, -- three or more, below the top star
}

export type SlotRow = {
	slot: string,
	who: string, -- "You" or the helper's name
	helper: string?, -- the helper's id, nil for the player
	pet: CrateRules.Pet?,
	say: string, -- "Clover: tips +5%", "Angler, 2 stars: pay +18%", "No pet yet", "Comes when Lou is hired"
	locked: boolean,
	slot2: string?, -- the second slot beside the first, with the Second pet slot pass ("player2", "<id>2")
	pet2: CrateRules.Pet?,
}

local RARITY_ORDER: { [string]: number } =
	{ Legendary = 1, Epic = 2, Rare = 3, Uncommon = 4, Common = 5 }

local function boostPercent(kind: string, star: number): string
	return `+{math.floor(CrateRules.boost(kind, star) * 100 + 0.5)}%`
end

-- The player's pets as one group per kind and star: rarest first, then the higher star, then by name.
function CrateViewRules.groups(pets: { CrateRules.Pet }): { Group }
	local byKey: { [string]: Group } = {}
	local out: { Group } = {}
	for _, pet in pets do
		local rarity = CrateRules.rarityOf(pet.kind)
		if rarity then
			local key = `{pet.kind}:{pet.star}`
			local group = byKey[key]
			if group == nil then
				group = {
					key = key,
					kind = pet.kind,
					rarity = rarity,
					star = pet.star,
					count = 0,
					ids = {},
					free = {},
					slots = {},
					canFuse = false,
				}
				byKey[key] = group
				table.insert(out, group)
			end
			group.count += 1
			if pet.slot then
				table.insert(group.ids, 1, pet.id)
				table.insert(group.slots, pet.slot)
			else
				table.insert(group.ids, pet.id)
				table.insert(group.free, pet.id)
			end
		end
	end
	for _, group in out do
		group.canFuse = group.count >= CrateRules.FUSE_COUNT and group.star < CrateRules.MAX_STAR
	end
	table.sort(out, function(a: Group, b: Group): boolean
		local ra, rb = RARITY_ORDER[a.rarity] or 9, RARITY_ORDER[b.rarity] or 9
		if ra ~= rb then
			return ra < rb
		end
		if a.star ~= b.star then
			return a.star > b.star
		end
		return a.kind < b.kind
	end)
	return out
end

-- The three ids a Fuse on `group` sends, or nil when it cannot fuse.
function CrateViewRules.fuseIds(group: Group): { number }?
	if not group.canFuse then
		return nil
	end
	return { group.ids[1], group.ids[2], group.ids[3] }
end

-- What a pet in a slot says: its name (and stars past the first) and what it boosts.
function CrateViewRules.petLine(pet: CrateRules.Pet, slot: string): string
	local name = if pet.star > 1 then `{pet.kind}, {pet.star} stars` else pet.kind
	local what = if slot == CrateRules.PLAYER_SLOT then "tips" else "pay"
	return `{name}: {what} {boostPercent(pet.kind, pet.star)}`
end

-- A pet's short boost for a row holding two: "Clover +5%".
local function shortLine(pet: CrateRules.Pet): string
	return `{pet.kind} {boostPercent(pet.kind, pet.star)}`
end

-- The slots in order: the player, then each helper. A helper not hired yet shows locked. `hired` holds the hired
-- helpers' ids (the server's WorkerLevel_<id> attributes). With `second` (the Second pet slot pass, issue 518) each
-- row holds two slots, "<slot>" and its second ("player2", "<id>2"), and says both pets in short.
function CrateViewRules.slotRows(
	pets: { CrateRules.Pet },
	hired: { [string]: boolean },
	second: boolean?
): { SlotRow }
	local inSlot: { [string]: CrateRules.Pet } = {}
	for _, pet in pets do
		if pet.slot then
			inSlot[pet.slot] = pet
		end
	end
	local rows: { SlotRow } = {}
	local function add(slot: string, slot2: string, who: string, helper: string?, locked: boolean)
		local pet = inSlot[slot]
		local pet2 = if second then inSlot[slot2] else nil
		local say
		if locked then
			say = `Comes when {who} is hired`
		elseif second and (pet or pet2) then
			-- the pets there in short; an empty box shows as empty, so the line stays short on a phone
			if pet and pet2 then
				say = `{shortLine(pet)}, {shortLine(pet2)}`
			else
				say = shortLine((pet or pet2) :: CrateRules.Pet)
			end
		elseif pet then
			say = CrateViewRules.petLine(pet, slot)
		else
			say = if second then "No pets yet" else "No pet yet"
		end
		table.insert(rows, {
			slot = slot,
			who = who,
			helper = helper,
			pet = if locked then nil else pet,
			say = say,
			locked = locked,
			slot2 = if second then slot2 else nil,
			pet2 = if locked then nil else pet2,
		})
	end
	add(CrateRules.PLAYER_SLOT, CrateRules.PLAYER_SLOT .. "2", "You", nil, false)
	for _, id in CrateViewRules.HELPERS do
		add(`{id}1`, `{id}2`, id, id, hired[id] ~= true)
	end
	return rows
end

-- The pet id a tap on `group` places in `slot`, and where it goes: the group's pet already in that slot comes off
-- (to nil, the pen); otherwise a free one goes in, or the group's slotted one moves over. Nil when there is none.
function CrateViewRules.placeFor(
	group: Group,
	slot: string,
	pets: { CrateRules.Pet }
): (number?, string?)
	for _, pet in pets do
		if pet.slot == slot and `{pet.kind}:{pet.star}` == group.key then
			return pet.id, nil
		end
	end
	local id = group.free[1] or group.ids[1]
	return id, slot
end

return CrateViewRules
