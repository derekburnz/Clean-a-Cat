--!strict
-- CheckinRules: the seven day check in card (issue 517; tuning section 12). Days are days played, not days in a row:
-- missing a day loses nothing. The first card is ready at about 3:45 of the first session (FIRST_AT seconds of
-- play), then once on each new day the player joins. After day 7 the card starts again at day 1. A day is the
-- player's own calendar day (SaveSchema.day, from the time zone saved once at first join), on the server's clock.
-- Pure, so tests/specs/CheckinRules.spec.luau covers it; CheckinService runs it. Behind the LiveFlags switch
-- checkinCard. The card itself is Design's (UI); it reads the Player attributes below and asks RequestCheckin.

local CheckinRules = {}

CheckinRules.FLAG = "checkinCard"
CheckinRules.DAYS = 7
CheckinRules.FIRST_AT = 225 -- seconds of play before the very first card (about 3:45)
CheckinRules.READY_ATTRIBUTE = "CheckinReady" -- Player attribute: the card's day (1 to 7) waiting, nil when none
CheckinRules.DAYS_ATTRIBUTE = "CheckinDays" -- Player attribute: days already taken on this card (0 to 7)

export type Reward = {
	coins: number?, -- coins straight to the wallet
	crate: string?, -- a crate kind (CrateRules.KINDS)
	bow: string?, -- a bow tier (BowRules.TIERS); one already owned pays `worth` coins instead
	worth: number?,
	text: string, -- what the card says
}

CheckinRules.REWARDS = table.freeze({
	table.freeze({ coins = 50, text = "50 coins" } :: Reward),
	table.freeze({ crate = "good", text = "Good crate" } :: Reward), -- "Day 2 the good crate"
	table.freeze({ coins = 100, text = "100 coins" } :: Reward),
	table.freeze({ bow = "Silk", worth = 150, text = "Silk bow" } :: Reward),
	table.freeze({ coins = 200, text = "200 coins" } :: Reward),
	table.freeze({ coins = 300, text = "300 coins" } :: Reward),
	table.freeze({ crate = "normal", text = "Crate" } :: Reward),
}) :: { Reward }

export type CheckIn = { days: number, lastDay: number }

-- The card's day the next claim takes: 1 to 7, back to 1 after 7.
function CheckinRules.nextDay(checkin: CheckIn): number
	local days = if checkin.days == checkin.days then math.floor(checkin.days) else 0
	return (math.clamp(days, 0, CheckinRules.DAYS) % CheckinRules.DAYS) + 1
end

-- The day waiting to be claimed on `today`, or nil: one claim a day, and a save that never claimed waits until
-- FIRST_AT seconds of play.
function CheckinRules.ready(checkin: CheckIn, today: number, played: number): number?
	if checkin.lastDay >= today then
		return nil
	end
	local never = checkin.days <= 0 and checkin.lastDay <= 0
	if never and not (played >= CheckinRules.FIRST_AT) then
		return nil
	end
	return CheckinRules.nextDay(checkin)
end

-- Takes today's day on the card. Returns it and its reward, or nil when there is none to take.
function CheckinRules.claim(checkin: CheckIn, today: number, played: number): (number?, Reward?)
	local day = CheckinRules.ready(checkin, today, played)
	if day == nil then
		return nil, nil
	end
	checkin.days = day
	checkin.lastDay = today
	return day, CheckinRules.REWARDS[day]
end

return table.freeze(CheckinRules)
