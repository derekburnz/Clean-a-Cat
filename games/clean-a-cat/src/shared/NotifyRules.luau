--!strict
-- NotifyRules: the pure rules of the build finished notification (#38), behind the LiveFlags switch
-- `longBuildOffer`. The bell ("Tell me when it's done") shows beside a running build of LONG_SECONDS or more;
-- only a tap on it asks Roblox to show the opt-in prompt. When the player leaves with a long build running, the
-- server queues one message for the moment the last of their long builds finishes, and sends at most one a day.
-- Pure, so tests/specs/NotifyRules.spec.luau covers it; NotifyService and BuildBoardController use it.
local BuildRules = require(script.Parent.BuildRules)

local NotifyRules = {}

NotifyRules.LONG_SECONDS = BuildRules.LONG_SECONDS -- a build this long or longer gets the bell
NotifyRules.DAY_SECONDS = 86400
-- The notification string's asset id per experience (game.GameId): Creator Hub > the game > Engagement >
-- Notifications > Create a Notification String, then ⋯ > Copy Asset ID. Not secret. "" until the owner makes it;
-- NotifyService falls back to the ServerStorage attribute NotifyMessageId, then sends nothing.
NotifyRules.MESSAGE_IDS = table.freeze({
	[10778775478] = "", -- Clean-a-Cat-Dev
	[10778773655] = "", -- Clean a Cat
}) :: { [number]: string }
NotifyRules.MAX_WAIT_SECONDS = 30 * 86400 -- a queued message older than this is dropped (MemoryStore keeps 45 days)
-- What the client reports about the opt-in prompt (notify_opt_in): the bell tapped and the prompt shown, the
-- prompt closed, or Roblox would not show the prompt (not eligible, or already opted in): they see the come back
-- line instead.
NotifyRules.RESULTS = table.freeze({ "shown", "closed", "cannot_prompt" })

export type Due = { item: string, endsAt: number }

-- True when `item` gets the bell.
function NotifyRules.isLong(item: string): boolean
	local entry = BuildRules.ITEMS[item]
	return entry ~= nil and entry.seconds >= NotifyRules.LONG_SECONDS
end

-- The one message to queue when the player leaves at `now`: the long build that finishes last, or nil when no
-- long build is still running.
function NotifyRules.dueAtLeave(builds: { [string]: BuildRules.Build }, now: number): Due?
	local due: Due? = nil
	for _, build in builds do
		if NotifyRules.isLong(build.item) and build.endsAt > now then
			local current = due
			if current == nil or build.endsAt > current.endsAt then
				due = { item = build.item, endsAt = build.endsAt }
			end
		end
	end
	return due
end

-- At most one message a day (UTC days): true when nothing was sent on `now`'s day.
function NotifyRules.canSend(lastSent: number?, now: number): boolean
	if lastSent == nil then
		return true
	end
	local day = NotifyRules.DAY_SECONDS
	return math.floor(lastSent / day) ~= math.floor(now / day)
end

-- The line players see instead of the bell when they cannot get notifications: whole hours, rounded up, so it
-- never counts down in front of them. No pressure words.
function NotifyRules.comeBackText(secondsLeft: number): string
	local hours = math.max(1, math.ceil(secondsLeft / 3600))
	return `Ready in {hours} h. Come back to see it!`
end

-- A queued message read back from the MemoryStore, checked: a known long item with a real end time.
function NotifyRules.cleanDue(raw: unknown): Due?
	if type(raw) ~= "table" then
		return nil
	end
	local entry = raw :: { [string]: unknown }
	local item = entry.item
	local endsAt = entry.endsAt
	if type(item) ~= "string" or not NotifyRules.isLong(item) then
		return nil
	end
	if type(endsAt) ~= "number" or endsAt ~= endsAt or math.abs(endsAt) == math.huge then
		return nil
	end
	return { item = item, endsAt = endsAt }
end

return table.freeze(NotifyRules)
