--!strict
-- PillLayout: no two prompt pills on top of each other (bug hunt B7, issue 648). Sync saw the crate's "Look inside"
-- pill sit on the Tools board's "Buy Pro Brush" pill, and a tap meant for the crate bought the brush. PromptController
-- measures each small prompt's pill on screen and asks PillLayout which to show: a pill that wins (the PillWins
-- attribute, such as the door's Take cat) comes first, then the nearest to the player; a pill that would overlap one
-- already kept is hidden until the two part, and it takes no tap while hidden. Its key still works, as every prompt
-- that can be on screen at once has its own key.
--
-- Pure, so tests/specs/PillLayout.spec.luau covers it.

local PillLayout = {}

PillLayout.WINS_ATTRIBUTE = "PillWins" -- true on a prompt whose pill must win an overlap
PillLayout.MARGIN = 4 -- real px kept clear between two pills

export type Pill<K> = {
	key: K,
	center: Vector2, -- on screen, real px
	size: Vector2,
	wins: boolean,
	distance: number, -- studs from the player
}

local function overlaps<K>(a: Pill<K>, b: Pill<K>): boolean
	local gap = a.center - b.center
	local reach = (a.size + b.size) / 2 + Vector2.new(PillLayout.MARGIN, PillLayout.MARGIN)
	return math.abs(gap.X) < reach.X and math.abs(gap.Y) < reach.Y
end

-- With the switch fewerPills (issue 745, Derek 2026-11-26: "too many white bubbles for popups around spa"): at most
-- FEW pills at once, and only those within NEAR studs of the player. A winning pill shows at any distance.
PillLayout.FEW = 2
PillLayout.NEAR = 10 -- studs

-- Which pills show: { [key] = true } for each kept, the others overlap one that ranks above them. With `limit`, at
-- most that many show; with `near`, a pill that does not win shows only within that many studs.
function PillLayout.keep<K>(pills: { Pill<K> }, limit: number?, near: number?): { [K]: boolean }
	local order = table.clone(pills)
	table.sort(order, function(a: Pill<K>, b: Pill<K>): boolean
		if a.wins ~= b.wins then
			return a.wins
		end
		return a.distance < b.distance
	end)
	local kept: { Pill<K> } = {}
	local out: { [K]: boolean } = {}
	for _, pill in order do
		local clear = (limit == nil or #kept < limit)
			and (near == nil or pill.wins or pill.distance <= near)
		for _, other in kept do
			if overlaps(pill, other) then
				clear = false
				break
			end
		end
		if clear then
			table.insert(kept, pill)
			out[pill.key] = true
		end
	end
	return out
end

return PillLayout
