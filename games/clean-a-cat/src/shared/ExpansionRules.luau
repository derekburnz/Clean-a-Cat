--!strict
-- ExpansionRules: the back door as a locked expansion (issue 1041, Derek's playtest of 2026-11-27: "maybe its blocked
-- off with caution tape and some construction materials ... and then when they go to it be unlocked with ... gold
-- for now for testing"). Behind the switch expansionDoor, off by default.
--
-- While locked, the plot's SpotGardenDoor holds Model-Agent's building site, LOCKED_ASSET (caution tape, a sawhorse,
-- planks, paint pots and a cone, with a _Barrier in the doorway). The player's own client puts one prompt there,
-- "Unlock · 1500 coins" (50 on the dev game, for testing). RequestUnlockExpansion() checks the switch, the save, that it is still locked, the coins and
-- that the player stands within SERVER_REACH of the door, takes the coins and saves expansionUnlocked; the door then
-- stands open (OPEN_ASSET) for everyone. Derek picked the Cat Hotel to go behind it (issue 1042; its server side is
-- issue 1049, behind catHotel), which reads expansionUnlocked; nothing here depends on it.
-- The Garden (tubBuilds) uses the same doorway, so with this switch on it shows only once the door is unlocked and the
-- garden is built (showGarden); its locked gate and building site stay away so they never stand in the open door.
-- Pure, so tests/specs/ExpansionRules.spec.luau covers it.
local Products = require(script.Parent:WaitForChild("Products"))

local ExpansionRules = {}

ExpansionRules.FLAG = "expansionDoor"
ExpansionRules.REMOTE = "RequestUnlockExpansion"
ExpansionRules.ATTRIBUTE = "ExpansionUnlocked" -- Player attribute: true once unlocked
ExpansionRules.SPOT = "SpotGardenDoor"
ExpansionRules.MODEL_NAME = "BackDoor" -- in the plot's stations folder
ExpansionRules.LOCKED_ASSET = "CleanACat_Area_BackDoorLocked"
ExpansionRules.OPEN_ASSET = "CleanACat_Area_BackDoorOpen"
ExpansionRules.PRICE = 1500 -- coins (Design-Agent's Cat Hotel spec, issue 1049)
ExpansionRules.DEV_PRICE = 50 -- coins on the dev game, for testing (Derek: "gold for now for testing")
ExpansionRules.PROMPT_REACH = 10 -- studs
ExpansionRules.SERVER_REACH = 14 -- studs, a little more than the prompt's for lag

-- The price in the experience `gameId` (game.GameId): DEV_PRICE on the dev game, PRICE everywhere else.
function ExpansionRules.priceIn(gameId: number): number
	return if gameId == Products.DEV_GAME_ID then ExpansionRules.DEV_PRICE else ExpansionRules.PRICE
end

-- Whether `coins` buy the unlock at `price` now, and the words to show when not.
function ExpansionRules.canUnlock(
	unlocked: boolean,
	coins: number,
	price: number
): (boolean, string?)
	if unlocked then
		return false, "Already open"
	end
	if coins < price then
		return false, `{price - coins} more coins to unlock`
	end
	return true, nil
end

-- The prompt's words.
function ExpansionRules.promptText(price: number): string
	return `Unlock · {price} coins`
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
