--!strict
-- FeedbackRules: "Send feedback" in Settings (issue 1081, Derek 2026-11-27: "add a feedback option in settings").
-- Behind the switch feedback, off by default. A player taps one of CHOICES and may add a short note; the server
-- (FeedbackService) runs the note through Roblox's text filter, counts the choice in analytics and keeps the choice
-- and the filtered note in the DataStore STORE, one key per UTC day (dayKey), at most DAY_CAP entries a day. No name
-- or user id is kept. Derek reads the entries in Creator Hub > the game > Data Stores, and the counts in its
-- Analytics (custom event "feedback").
-- Pure, so tests/specs/FeedbackRules.spec.luau covers it.
local FeedbackRules = {}

FeedbackRules.FLAG = "feedback"
FeedbackRules.REMOTE = "SendFeedback"
FeedbackRules.STORE = "Feedback_v1"
FeedbackRules.STUDIO_STORE = "Feedback_v1_Studio" -- a Studio test never mixes with players' feedback
FeedbackRules.NOTE_MAX = 140 -- characters (bytes, as Guard.text counts)
FeedbackRules.PER_VISIT = 3 -- sends a player may make in one visit
FeedbackRules.DAY_CAP = 500 -- entries kept a day; past it the choice is still counted in analytics
FeedbackRules.THANKS = "Thanks! We read every one." -- Design-Agent's words
-- Player attribute: how many times the player sent feedback this visit (absent before the first), so Settings can
-- show "Sent, thank you" and stop offering it at PER_VISIT.
FeedbackRules.SENT_ATTRIBUTE = "FeedbackSent"

-- The tap choices, in the window's order: our ids (the window's words are Design-Agent's).
FeedbackRules.CHOICES = table.freeze({ "love", "hard", "bug", "idea" }) :: { string }

export type Entry = {
	choice: string,
	note: string?,
	at: number,
	placeVersion: number,
}

-- The day's key for time `now` (os.time()): "YYYY-MM-DD" in UTC.
function FeedbackRules.dayKey(now: number): string
	return os.date("!%Y-%m-%d", now) :: string
end

-- A note as typed, trimmed: nil when there is none or it is too long or not text.
function FeedbackRules.cleanNote(raw: unknown): string?
	if type(raw) ~= "string" then
		return nil
	end
	local text = string.gsub(raw, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if #text == 0 or #text > FeedbackRules.NOTE_MAX or utf8.len(text) == nil then
		return nil
	end
	return text
end

-- A filtered note worth keeping: nil when the filter gave nothing, or hid all of it (only #s and spaces left).
function FeedbackRules.kept(filtered: string?): string?
	if filtered == nil or string.match(filtered, "^[#%s]*$") ~= nil then
		return nil
	end
	return filtered
end

-- The day's list with `entry` added: a list that is not a list starts again; a full day keeps what it has.
-- Gives the new list and whether the entry went in.
function FeedbackRules.append(old: unknown, entry: Entry): ({ Entry }, boolean)
	local list: { Entry } = if type(old) == "table" then old :: { Entry } else {}
	if #list >= FeedbackRules.DAY_CAP then
		return list, false
	end
	table.insert(list, entry)
	return list, true
end

return table.freeze(FeedbackRules)
