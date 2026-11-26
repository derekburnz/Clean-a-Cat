--!strict
-- LeaveLineRules: the two lines shown above and below Roblox's own leave screen while its menu is open (issue 726,
-- Derek's ask of 2026-11-26), behind the switch leaveLines. Each line says something true for this player right now,
-- or is left out: never a guess, never guilt or a hurry (a young audience). Pure, so
-- tests/specs/LeaveLineRules.spec.luau covers it; UI/LeaveLines draws them and LeaveLinesController feeds them.
local CheckinRules = require(script.Parent:WaitForChild("CheckinRules"))

local LeaveLineRules = {}

LeaveLineRules.FLAG = "leaveLines"

export type State = {
	helpers: boolean, -- a helper is hired (any WorkerLevel_<id>)
	jar: boolean, -- the tip jar fills while away (switch tipJar, with workers)
	checkin: boolean, -- the check in card is on (switch checkinCard)
	ready: number?, -- the check in day waiting to be taken now (CheckinReady), nil when none
	days: number, -- check in days already taken (CheckinDays)
}

-- The top line, about what happens while the player is away, or nil.
function LeaveLineRules.top(state: State): string?
	if state.helpers and state.jar then
		return "Your helpers fill the tip jar while you're away!"
	end
	return nil
end

-- The bottom line, about the next visit, or nil.
function LeaveLineRules.bottom(state: State): string?
	if not state.checkin then
		return nil
	end
	if state.ready ~= nil then
		return "Your check in gift is waiting in Gifts!"
	end
	local days = if state.days == state.days then math.floor(state.days) else 0
	if days < 1 then
		return nil -- nothing taken yet: the first gift comes after a few minutes of play, not tomorrow
	end
	local nextDay = CheckinRules.nextDay({ days = days, lastDay = 0 })
	local reward = CheckinRules.REWARDS[nextDay]
	return if reward then `Come back tomorrow for day {nextDay}: {reward.text}!` else nil
end

return LeaveLineRules
