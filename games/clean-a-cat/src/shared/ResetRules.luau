--!strict
-- ResetRules: "Reset my game" in Settings (issue 1037, Derek's playtest of 2026-11-27: "add a reset account in
-- settings so I can wipe and reset from tutorial easy"). Behind the switch resetSave, off by default.
--
-- Who: only on the dev game, in Studio, or for the owner of the game's Roblox group (rank OWNER_RANK) on any game,
-- until Derek says players get it. The server sets the Player attribute CanResetSave (ATTRIBUTE) to true for a player
-- who may, so Settings shows the row only then; it checks again on the request.
-- What: the save goes back to a new one (SaveSchema.template), so the next join starts at the opening. KEPT stays:
-- the purchase receipts (so a Robux purchase Roblox sends again is never granted twice) and the game passes the save
-- knows about (Roblox owns those; Lou comes back from his pass on the next join).
-- How: the server stores the new save as it lets go of the old one and kicks with KICK_TEXT; the rejoin loads it.
-- Pure, so tests/specs/ResetRules.spec.luau covers it.
local SaveSchema = require(script.Parent:WaitForChild("SaveSchema"))

local ResetRules = {}

ResetRules.FLAG = "resetSave"
ResetRules.REMOTE = "RequestResetSave"
ResetRules.ATTRIBUTE = "CanResetSave"
ResetRules.OWNER_RANK = 255 -- a Roblox group's owner rank
ResetRules.KICK_TEXT = "Your game was reset. Rejoin to start again from the beginning."
ResetRules.KEPT = table.freeze({ "receipts", "passes" }) :: { string }

-- Whether a player may reset: the dev game or Studio for anyone, elsewhere only the group's owner.
function ResetRules.allowed(
	gameId: number,
	devGameId: number,
	isStudio: boolean,
	rank: number
): boolean
	return isStudio or gameId == devGameId or rank >= ResetRules.OWNER_RANK
end

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, inner in value do
		out[key] = copy(inner)
	end
	return out
end

-- A new save at `now` that keeps `save`'s KEPT fields (copied, so the old save can't change them).
function ResetRules.fresh(save: SaveSchema.Save, now: number): SaveSchema.Save
	local fresh = SaveSchema.template(now) :: any
	local old = save :: any
	for _, key in ResetRules.KEPT do
		if old[key] ~= nil then
			fresh[key] = copy(old[key])
		end
	end
	return fresh
end

return ResetRules
