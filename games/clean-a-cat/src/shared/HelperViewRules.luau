--!strict
-- HelperViewRules: what the Helpers window (UI/HelpersWindow, issue 526 item 3) shows, from WorkerRules and the
-- server's Player attributes WorkerLevel_<id> and WorkerMode_<id> (WorkerService sets them; a missing level means
-- not hired). One row per helper in WorkerRules.IDS order. A hired helper shows their level, the coins for the next
-- one (none at the top level) and the line they wash first. Jo and Sam not hired yet show their price, paid at their
-- pad; Lou not hired says he comes with his game pass. Nothing is sold here, and nothing says "hurry". Pure, so
-- tests/specs/HelperViewRules.spec.luau covers it.
local WorkerRules = require(script.Parent:WaitForChild("WorkerRules"))

local HelperViewRules = {}

HelperViewRules.WINDOW = "Helpers"
HelperViewRules.FLAG = "helpersWindow"
HelperViewRules.PETS_FLAG = "helperPets" -- a pet box on each hired row; pets are given only from the menu (issue 929)
HelperViewRules.LEVEL_PREFIX = "WorkerLevel_"
HelperViewRules.MODE_PREFIX = "WorkerMode_"

export type Row = {
	id: string,
	name: string, -- the shown name: the filtered StaffName_<id>, or the default
	hired: boolean,
	level: number?, -- hired only
	nextCost: number?, -- coins for the next level; nil when not hired or at the top
	mode: string?, -- hired only, one of WorkerRules.MODES
	modeName: string?,
	price: number?, -- coins at their pad, for one not hired; nil for a pass helper
	pass: boolean, -- comes with a game pass (Lou)
}

-- The rows in WorkerRules.IDS order. `attribute(name)` reads a Player attribute; `names[id]` is a shown name.
function HelperViewRules.rows(
	attribute: (name: string) -> unknown,
	names: { [string]: string },
	isOn: ((flag: string) -> boolean)?
): { Row }
	local out: { Row } = {}
	for _, id in WorkerRules.IDS do
		local info = WorkerRules.WORKERS[id]
		local rawLevel = attribute(HelperViewRules.LEVEL_PREFIX .. id)
		local hired = rawLevel ~= nil
		local level = if hired then WorkerRules.cleanLevel(rawLevel) else nil
		local mode = if hired
			then WorkerRules.cleanMode(attribute(HelperViewRules.MODE_PREFIX .. id))
				or WorkerRules.DEFAULT_MODE
			else nil
		local shown = names[id]
		table.insert(out, {
			id = id,
			name = if type(shown) == "string" and shown ~= "" then shown else info.name,
			hired = hired,
			level = level,
			nextCost = if level and level < WorkerRules.MAX_LEVEL
				then WorkerRules.LEVEL_COST[level + 1]
				else nil,
			mode = mode,
			modeName = if mode then WorkerRules.MODE_NAMES[mode] else nil,
			price = if hired then nil else WorkerRules.priceOf(id, isOn),
			pass = info.pass,
		})
	end
	return out
end

-- True once any helper is hired: the HUD's Helpers button waits for it.
function HelperViewRules.anyHired(attribute: (name: string) -> unknown): boolean
	for _, id in WorkerRules.IDS do
		if attribute(HelperViewRules.LEVEL_PREFIX .. id) ~= nil then
			return true
		end
	end
	return false
end

-- The small line under a helper's name.
function HelperViewRules.say(row: Row): string
	if row.hired then
		return if row.level == WorkerRules.MAX_LEVEL
			then `Level {row.level}, the top`
			else `Level {row.level}`
	elseif row.pass then
		return "Comes with the Lou pass"
	end
	return `Hire at their pad · {row.price} coins`
end

-- The mode button's words: which waiting cat they take first (the same words as their stand's prompt).
function HelperViewRules.modeText(row: Row): string
	return `Takes: {row.modeName or WorkerRules.MODE_NAMES[WorkerRules.DEFAULT_MODE]}`
end

-- The Level up button's words, or nil at the top level (no button then).
function HelperViewRules.levelText(row: Row): string?
	local cost = row.nextCost
	return if cost then `Level up · {cost}` else nil
end

-- The pet beside helper `id` (in their first slot, else their second), or nil: the pet box on their row.
export type Pet = { id: number, kind: string, star: number, slot: string? } -- the shape of CrateRules.Pet
function HelperViewRules.petOf(id: string, pets: { Pet }): Pet?
	local second: Pet? = nil
	for _, pet in pets do
		if pet.slot == `{id}1` then
			return pet
		elseif pet.slot == `{id}2` then
			second = pet
		end
	end
	return second
end

return HelperViewRules
