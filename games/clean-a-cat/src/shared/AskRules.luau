--!strict
-- AskRules: the first session's ask queue (issue 522, switch askQueue). Everything that asks something of the player
-- outside the wash goes through one queue, so nothing piles up on the screen (the owner's words: "make sure they
-- don't appear all at same time and overload a player"):
--   - one ask at a time, and at least GAP seconds from the end of one to the start of the next;
--   - an ask that comes due waits (never dropped) until the screen is free; AskController decides "free" (no wash, no
--     recap, no window, no tutorial step);
--   - when two wait, the one first in IDS goes first;
--   - a "no" is final for the visit: the same ask is not wanted again until the next join;
--   - a QUIET ask (the starter button's bob) only needs a free screen and nothing else shown: it neither waits for
--     the gap nor starts it, and it ends the moment it shows.
-- Pure, so tests/specs/AskRules.spec.luau covers it; AskController holds one Queue for the session.

local AskRules = {}

AskRules.FLAG = "askQueue"
AskRules.GAP = 60 -- seconds from the end of one ask to the start of the next
AskRules.MAX_SHOWN = 180 -- seconds an ask may stay up without done(); after that the queue moves on

-- Every ask, first served first when two wait.
AskRules.IDS = table.freeze({
	"notify", -- the notification ask
	"checkin", -- the check in card
	"gift", -- the gift stand's ask
	"favourite", -- the favourite ask
	"menu_index", -- each new HUD button with its tip
	"menu_quests",
	"menu_helpers",
	"menu_build",
	"starterButton", -- the starter pack button's bob (quiet)
}) :: { string }

AskRules.QUIET = table.freeze({ starterButton = true }) :: { [string]: boolean }

export type Answer = "yes" | "no" | "closed"

export type Queue = {
	waiting: { [string]: number }, -- id -> when it was first wanted
	shown: string?, -- the ask up now
	shownAt: number,
	lastEnd: number, -- when the last (not quiet) ask ended
	refused: { [string]: boolean }, -- said no this visit
}

function AskRules.new(): Queue
	return { waiting = {}, shown = nil, shownAt = 0, lastEnd = -math.huge, refused = {} }
end

function AskRules.known(id: string): boolean
	return table.find(AskRules.IDS, id) ~= nil
end

-- Puts `id` in the line. False when it is unknown, refused this visit or up now; wanting it again keeps its place.
function AskRules.want(queue: Queue, id: string, now: number): boolean
	if not AskRules.known(id) or queue.refused[id] or queue.shown == id then
		return false
	end
	if queue.waiting[id] == nil then
		queue.waiting[id] = now
	end
	return true
end

-- Takes `id` out of the line (its reason went away, say the card was claimed from its button).
function AskRules.drop(queue: Queue, id: string)
	queue.waiting[id] = nil
end

-- The ask to show now, or nil, given whether the screen is free. The pick is taken out of the line; a non quiet pick
-- becomes queue.shown until done().
function AskRules.pick(queue: Queue, now: number, free: boolean): string?
	if queue.shown ~= nil or not free then
		return nil
	end
	local gapOver = now - queue.lastEnd >= AskRules.GAP
	for _, id in AskRules.IDS do
		if queue.waiting[id] == nil then
			continue
		end
		local quiet = AskRules.QUIET[id] == true
		if quiet or gapOver then
			queue.waiting[id] = nil
			if not quiet then
				queue.shown = id
				queue.shownAt = now
			end
			return id
		end
	end
	return nil
end

-- `id` was answered or closed. A "no" is final for the visit. False when `id` was not up.
function AskRules.done(queue: Queue, id: string, answer: Answer, now: number): boolean
	if answer == "no" then
		queue.refused[id] = true
		queue.waiting[id] = nil
	end
	if queue.shown ~= id then
		return false
	end
	queue.shown = nil
	queue.lastEnd = now
	return true
end

-- True when the ask up now has been up longer than MAX_SHOWN (its done() never came).
function AskRules.stale(queue: Queue, now: number): boolean
	return queue.shown ~= nil and now - queue.shownAt >= AskRules.MAX_SHOWN
end

return table.freeze(AskRules)
