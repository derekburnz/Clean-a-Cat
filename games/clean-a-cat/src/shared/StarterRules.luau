--!strict
-- StarterRules: the starter pack (issue 519; tuning starterPack; Growth-Agent's starter pack check). One developer
-- product that gives three passes together: the Golden Sponge, the Second pet slot and 2x Coins, fixed and never
-- random, no coins and no crate. It is offered for 72 hours of real time from the player's first join (a save from
-- before the switch went on starts its 72 hours at its first join after), kept on the server, and never restarts or
-- extends: at zero it is gone for that player for good, and the three passes stay in the shop at their own prices. It
-- is offered only to a player who owns none of the three, and only from the end of the tutorial (SpaRules
-- TUTORIAL_ENDS_AT). The window opens only when the player taps the button.
-- Pure, so tests/specs/StarterRules.spec.luau covers it; StarterService runs it. Behind the LiveFlags switch
-- starterPack (with passes on too, since the pack gives passes).

local StarterRules = {}

StarterRules.FLAG = "starterPack"
StarterRules.PRODUCT = "StarterPack" -- the Products key
StarterRules.CONTENTS =
	table.freeze({ "GoldenSponge", "SecondPetSlot", "DoubleCoins" }) :: { string }
StarterRules.SHOW_FROM = 2 * 60 + 45 -- seconds of play: the end of the tutorial (SpaRules.TUTORIAL_ENDS_AT)

-- Player attributes for Design's button and window and Motion-FX's attention bob.
StarterRules.ENDS_ATTRIBUTE = "StarterEndsAt" -- os.time() the offer ends, set only while it is offered
StarterRules.OPENED_ATTRIBUTE = "StarterOpened" -- true once the player opened the window
StarterRules.VISITS_ATTRIBUTE = "Visits" -- joins of this save, the first included

-- Whether the pack is offered: before its end, after the tutorial, and the player owning none of the three.
function StarterRules.offered(
	endsAt: number,
	now: number,
	played: number,
	owns: (key: string) -> boolean
): boolean
	if endsAt <= 0 or now >= endsAt or played < StarterRules.SHOW_FROM then
		return false
	end
	for _, key in StarterRules.CONTENTS do
		if owns(key) then
			return false
		end
	end
	return true
end

-- Hours from the offer's start (its end less 72 hours) to `now`, for pack_bought.
function StarterRules.hoursIn(endsAt: number, now: number, length: number): number
	return math.max(0, math.floor((now - (endsAt - length)) / 3600))
end

return table.freeze(StarterRules)
