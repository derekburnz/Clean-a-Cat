--!strict
-- CrateViewRules: what the crate window (UI/CrateWindow, switch crateWindow, issue 526) shows, from CrateRules. Every
-- pet in the crate with its chance and its boost, read from CrateRules.odds, the very list the server rolls from, so a
-- shown chance is always the real one. Pure, so tests/specs/CrateViewRules.spec.luau covers it.
local CrateRules = require(script.Parent:WaitForChild("CrateRules"))

local CrateViewRules = {}

CrateViewRules.FLAG = "crateWindow"
CrateViewRules.SUM_LINE = "The chances add up to 100%. " .. CrateRules.ODDS_NOTE

export type Row = {
	pet: string,
	rarity: string,
	chance: string, -- "25%", or one decimal place when it is not whole ("12.5%")
	boost: string, -- "+5%"
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
			boost = `+{math.floor(entry.boost * 100 + 0.5)}%`,
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

-- The kinds of every pet in a Pets list (the server's Pets remote), for `rows`.
function CrateViewRules.ownedKinds(pets: { CrateRules.Pet }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, pet in pets do
		out[pet.kind] = true
	end
	return out
end

return CrateViewRules
