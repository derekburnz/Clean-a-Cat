--!strict
-- CheckinViewRules: what the check in card (UI/CheckinCard, issue 517) shows, from CheckinRules and the two Player
-- attributes CheckinService keeps: CheckinReady (the card's day waiting, 1 to 7, or nil) and CheckinDays (days taken
-- on this card, 0 to 7). Seven tiles, one per day played, not days in a row: no streak, nothing is lost by missing a
-- day, and the words never say "don't lose it". Pure, so tests/specs/CheckinViewRules.spec.luau covers it.
local CheckinRules = require(script.Parent:WaitForChild("CheckinRules"))

local CheckinViewRules = {}

CheckinViewRules.LEAD =
	"A gift for each day you play. Come back any day, nothing is lost if you miss one."
CheckinViewRules.BIG_DAY = 2 -- the good crate, drawn bigger with its button for the chance list

export type Tile = {
	day: number,
	icon: string, -- an Icons name: Coins, Gift or Bow
	what: string, -- "50" for coins, else the reward's own words ("Good crate")
	got: boolean, -- taken already on this card: a tick
	today: boolean, -- the one waiting now: it glows
	big: boolean,
	crate: string?, -- the crate kind when the reward is a crate, for its chance list
}

local function whole(raw: unknown, low: number, high: number): number?
	if type(raw) ~= "number" or raw ~= raw then
		return nil
	end
	local n = math.floor(raw)
	return if n >= low and n <= high then n else nil
end

-- The attributes as the card reads them: ready nil or 1 to 7, days 0 to 7. Anything else counts as nothing.
function CheckinViewRules.read(readyRaw: unknown, daysRaw: unknown): (number?, number)
	return whole(readyRaw, 1, CheckinRules.DAYS), whole(daysRaw, 0, CheckinRules.DAYS) or 0
end

function CheckinViewRules.icon(reward: CheckinRules.Reward): string
	if reward.bow then
		return "Bow"
	end
	if reward.crate then
		return "Gift"
	end
	return "Coins"
end

-- The tile words: a coin day shows just its number beside the coin; other days their own words.
function CheckinViewRules.what(reward: CheckinRules.Reward): string
	if reward.coins and not reward.crate and not reward.bow then
		return tostring(reward.coins)
	end
	return reward.text
end

-- The seven tiles. A day 1 waiting after day 7 starts a fresh card, so nothing shows ticked then.
function CheckinViewRules.tiles(ready: number?, days: number): { Tile }
	local fresh = ready == 1
	local out: { Tile } = {}
	for day, reward in CheckinRules.REWARDS do
		table.insert(out, {
			day = day,
			icon = CheckinViewRules.icon(reward),
			what = CheckinViewRules.what(reward),
			got = not fresh and day <= days,
			today = day == ready,
			big = day == CheckinViewRules.BIG_DAY,
			crate = reward.crate,
		})
	end
	return out
end

-- The claim button's words for day `day`, or nil when nothing waits (the button hides).
function CheckinViewRules.claimText(ready: number?): string?
	if ready == nil then
		return nil
	end
	local reward = CheckinRules.REWARDS[ready]
	if reward == nil then
		return nil
	end
	if reward.coins and not reward.crate and not reward.bow then
		return `Claim {reward.coins} coins`
	end
	if reward.bow then
		return `Claim the {reward.text}` -- a bow keeps its name's capital: "Claim the Silk bow"
	end
	return `Claim the {string.lower(reward.text)}`
end

-- The line beside the button: when the next gift comes. Never a countdown and never a warning.
function CheckinViewRules.note(ready: number?, days: number): string
	if ready then
		return if ready == CheckinRules.DAYS
			then "Day 7 is the last on this card. A new card starts after it."
			else "Your next gift waits for the next day you play."
	end
	if days >= CheckinRules.DAYS then
		return "All seven taken! A new card starts the next day you play."
	end
	return `Day {days + 1} waits for the next day you play.`
end

return table.freeze(CheckinViewRules)
