--!strict
-- ExpansionRules: the back door as a locked expansion (issue 1041, Derek's playtest of 2026-11-27: "maybe its blocked
-- off with caution tape and some construction materials ... and then when they go to it be unlocked with ... gold
-- for now for testing"). Behind the switch expansionDoor, off by default.
--
-- While locked, the plot's SpotGardenDoor holds Model-Agent's building site, LOCKED_ASSET (caution tape, a sawhorse,
-- planks, paint pots and a cone, with a _Barrier in the doorway). The player's own client puts one prompt there,
-- "Unlock · 500 coins". RequestUnlockExpansion() checks the switch, the save, that it is still locked, the coins and
-- that the player stands within SERVER_REACH of the door, takes the coins and saves expansionUnlocked; the door then
-- stands open (OPEN_ASSET) for everyone. What goes behind it waits on Derek's pick (issue 1042), so nothing here
-- depends on that.
-- The Garden (tubBuilds) uses the same doorway, so with this switch on it shows only once the door is unlocked and the
-- garden is built (showGarden); its locked gate and building site stay away so they never stand in the open door.
-- Pure, so tests/specs/ExpansionRules.spec.luau covers it.
local ExpansionRules = {}

ExpansionRules.FLAG = "expansionDoor"
ExpansionRules.REMOTE = "RequestUnlockExpansion"
ExpansionRules.ATTRIBUTE = "ExpansionUnlocked" -- Player attribute: true once unlocked
ExpansionRules.SPOT = "SpotGardenDoor"
ExpansionRules.MODEL_NAME = "BackDoor" -- in the plot's stations folder
ExpansionRules.LOCKED_ASSET = "CleanACat_Area_BackDoorLocked"
ExpansionRules.OPEN_ASSET = "CleanACat_Area_BackDoorOpen"
ExpansionRules.PRICE = 500 -- coins; a test price for dev (Derek: "gold for now for testing")
ExpansionRules.PROMPT_REACH = 10 -- studs
ExpansionRules.SERVER_REACH = 14 -- studs, a little more than the prompt's for lag

-- Whether `coins` buy the unlock now, and the words to show when not.
function ExpansionRules.canUnlock(unlocked: boolean, coins: number): (boolean, string?)
	if unlocked then
		return false, "Already open"
	end
	if coins < ExpansionRules.PRICE then
		return false, `{ExpansionRules.PRICE - coins} more coins to unlock`
	end
	return true, nil
end

-- The prompt's words.
function ExpansionRules.promptText(): string
	return `Unlock · {ExpansionRules.PRICE} coins`
end

-- Whether the Garden is drawn at the back door: always without this switch; with it, only behind the open door and
-- once built.
function ExpansionRules.showGarden(
	isOn: (flag: string) -> boolean,
	unlocked: boolean,
	built: boolean
): boolean
	if not isOn(ExpansionRules.FLAG) then
		return true
	end
	return unlocked and built
end

return ExpansionRules
