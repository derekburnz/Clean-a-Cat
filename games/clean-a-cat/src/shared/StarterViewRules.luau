--!strict
-- StarterViewRules: what the starter pack's window and HUD button (UI/StarterWindow, issue 519) show, from
-- StarterRules and Design-Agent's starterpack.html. Three item cards joined by plus signs, each with its own shop
-- price; the total struck through and the saving, both worked out from the live prices and hidden if any price is
-- missing (so the saving is always true); one green "Get pack" button with the pack's price. The countdown is calm:
-- days, hours and minutes on the HUD (never seconds), seconds only inside the window, and nothing changes near the
-- end; with starterNoClock no time shows at all. No words say "hurry", "limited" or "72 hours". Pure, so tests/specs/StarterViewRules.spec.luau covers it.
local StarterRules = require(script.Parent:WaitForChild("StarterRules"))

local StarterViewRules = {}

StarterViewRules.WINDOW = "Starter"
StarterViewRules.TITLE = "Spa Starter Pack"
StarterViewRules.FINE = "Nothing random. All three are yours to keep."
-- Switch starterNoClock (issue 1069, Derek's plan answer of 2026-11-27, "same offer, no clock shown"): the offer still
-- ends 72 hours after the first join, but nothing on screen counts down; the chip and the window say NO_CLOCK.
StarterViewRules.NO_CLOCK_FLAG = "starterNoClock"
StarterViewRules.NO_CLOCK = "New player offer"
-- Switch starterPet (issue 1090, Derek 2026-11-27: "make it like a golden flashing pet or crate or something crazy"):
-- the pack also gives Midas, a golden pet found nowhere else (Model-Agent's CleanACat_Pet_Midas, Gameplay's grant). He
-- is the HUD card's one big picture and a fourth card in the window. He has no shop price, so he is never counted in
-- the struck total or the saving: those stay the three passes' own prices against the pack's.
StarterViewRules.PET_FLAG = "starterPet"
StarterViewRules.FINE_PET = "Nothing random. All four are yours to keep."
StarterViewRules.PET_ICON = "ShopStarterPet" -- an Icons name: Midas whole, with sparkles

export type Item = {
	key: string, -- a Passes key
	name: string,
	what: string,
	icon: string, -- an Icons name
	badge: string?, -- "x2", "+1"
	price: number?, -- the pass's own Robux price, nil while unknown
	note: string?, -- shown in place of a price on a card that has none of its own (Midas)
}

local LOOK: { [string]: { name: string, what: string, icon: string, badge: string? } } = {
	GoldenSponge = {
		name = "Golden Sponge",
		what = "Gold bubbles, +20% on hand washes",
		icon = "Sponge",
	},
	SecondPetSlot = {
		name = "2nd pet slot", -- short enough for the small phone Shop card (issue 838)
		what = "One more pet for you and each helper",
		icon = "Paw",
		badge = "+1",
	},
	-- Derek 2026-11-27: "remove the golden sponge from starter pack it seems lame replace with something else"; the
	-- card is ready for Gameplay's CONTENTS change (Second Builder in, Golden Sponge out)
	SecondBuilder = {
		name = "Second Builder",
		what = "Two builds at the same time",
		icon = "ShopBuilder2",
	},
	DoubleCoins = {
		name = "2x Coins",
		what = "Double coins on cats you wash by hand",
		icon = "Coins",
		badge = "x2",
	},
}

local function whole(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw or raw <= 0 or raw == math.huge then
		return nil
	end
	return math.floor(raw)
end

-- The three cards in StarterRules.CONTENTS order. `price(key)` reads the pass's price attribute.
function StarterViewRules.items(price: (key: string) -> unknown): { Item }
	local out: { Item } = {}
	for _, key in StarterRules.CONTENTS do
		local look = LOOK[key]
		if look then
			table.insert(out, {
				key = key,
				name = look.name,
				what = look.what,
				icon = look.icon,
				badge = look.badge,
				price = whole(price(key)),
			})
		end
	end
	return out
end

-- Midas's card in the window: no price (he is not sold alone), a "Bonus" tag.
function StarterViewRules.petItem(): Item
	return {
		key = "Midas",
		name = "Midas",
		what = "A golden pet that shines",
		icon = StarterViewRules.PET_ICON,
		badge = "Bonus",
		price = nil,
		note = "Pack only",
	}
end

-- The window's small print, with or without Midas.
function StarterViewRules.fine(withPet: boolean): string
	return if withPet then StarterViewRules.FINE_PET else StarterViewRules.FINE
end

-- The pack's own price, or nil while it is unknown (then there is no button to press).
function StarterViewRules.packPrice(raw: unknown): number?
	return whole(raw)
end

-- The struck total and the saving in whole percent, or nil, nil when any price is missing or the pack does not save.
function StarterViewRules.saving(items: { Item }, pack: number?): (number?, number?)
	if pack == nil or #items == 0 then
		return nil, nil
	end
	local total = 0
	for _, item in items do
		local p = item.price
		if p == nil then
			return nil, nil
		end
		total += p
	end
	if total <= pack then
		return nil, nil
	end
	return total, math.floor((1 - pack / total) * 100)
end

function StarterViewRules.saveText(percent: number): string
	return `Bundle · save {percent}%`
end

function StarterViewRules.buyText(pack: number): string
	return `{pack} Robux · Get pack`
end

-- Seconds left, never below 0.
function StarterViewRules.left(endsAt: unknown, now: number): number
	if type(endsAt) ~= "number" or endsAt ~= endsAt then
		return 0
	end
	return math.max(0, math.floor(endsAt - now))
end

-- The HUD chip: "1d 20h", "5h 12m", "12m"; never seconds (no ticking on the HUD). "1m" in the last minute.
function StarterViewRules.hudText(seconds: number): string
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{math.max(1, minutes)}m`
end

-- The window's line: "Ends in 1d 20h", "Ends in 5h 12m", "Ends in 12m". Minutes at most, like the HUD chip, so
-- nothing ticks in front of the player (Review-QA on PR 620).
function StarterViewRules.windowText(seconds: number): string
	return `Ends in {StarterViewRules.hudText(seconds)}`
end

-- The HUD chip with the switch starterNoClock in `calm`: NO_CLOCK, else the time left (hudText).
function StarterViewRules.hudNote(seconds: number, calm: boolean): string
	return if calm then StarterViewRules.NO_CLOCK else StarterViewRules.hudText(seconds)
end

-- The window's line the same way: NO_CLOCK, else "Ends in ..." (windowText).
function StarterViewRules.windowNote(seconds: number, calm: boolean): string
	return if calm then StarterViewRules.NO_CLOCK else StarterViewRules.windowText(seconds)
end

-- How many times the HUD button bobs as it appears this visit: 3 on the first visit, 1 on the next two, and never
-- once the player has opened the window or after three visits (the caller owns the limit, Effects/Attention).
function StarterViewRules.bobs(visits: unknown, opened: boolean): number
	if opened or type(visits) ~= "number" then
		return 0
	end
	if visits <= 1 then
		return 3
	end
	return if visits <= 3 then 1 else 0
end

return table.freeze(StarterViewRules)
