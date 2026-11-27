--!strict
-- OutdoorWalkRules: a faster walk outside the spa once the tutorial is done (switch outdoorWalk, issue 886). Derek on
-- dev, 2026-11-26: "making the walking outside spa faster after tutorial".
--
-- The tutorial ends at SpaRules.TUTORIAL_ENDS_AT seconds of play (2:45, the GDD's first session timeline). From then
-- the server sets the Player attribute ATTRIBUTE (OutdoorWalkService), and the client (OutdoorWalkController) walks
-- at OUTDOOR_SPEED while the player is outside every spa building, at Roblox's default INDOOR_SPEED inside one (the
-- rooms are small) and all through the tutorial. Inside means a spa's roof or ceiling stands over the player's head.
-- Pure, so specs cover it.
local SpaRules = require(script.Parent:WaitForChild("SpaRules"))

local OutdoorWalkRules = {}

OutdoorWalkRules.FLAG = "outdoorWalk"
OutdoorWalkRules.ATTRIBUTE = "TutorialDone" -- Player attribute: true once the first session's tutorial has ended
OutdoorWalkRules.INDOOR_SPEED = 16 -- studs a second: Roblox's default walk
OutdoorWalkRules.OUTDOOR_SPEED = 24
OutdoorWalkRules.ROOF_REACH = 40 -- studs up from the player's head that a spa's roof can be
OutdoorWalkRules.CHECK_SECONDS = 0.25 -- how often the client looks again

-- Whether the tutorial has ended after `played` seconds of play.
function OutdoorWalkRules.tutorialDone(played: number): boolean
	return played == played and played >= SpaRules.TUTORIAL_ENDS_AT
end

-- The walk speed for a player whose tutorial is done (`done`) standing inside a spa building or not.
function OutdoorWalkRules.speedFor(done: boolean, inside: boolean): number
	return if done and not inside
		then OutdoorWalkRules.OUTDOOR_SPEED
		else OutdoorWalkRules.INDOOR_SPEED
end

return table.freeze(OutdoorWalkRules)
