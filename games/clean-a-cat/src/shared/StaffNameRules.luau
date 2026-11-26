--!strict
-- StaffNameRules: players rename their spa staff (issue 487, switch staffRename). A typed name is cleaned here (spaces
-- trimmed and collapsed, letters, numbers and spaces only, at most MAX_LENGTH), saved raw in the worker's save entry
-- and run through Roblox's text filter on the server every time it is shown (on each join too, as filter results can
-- change). Only the filtered name ever reaches any player, on the owner's Player attribute NAME_PREFIX .. id; a
-- failed filter, or a name the filter hid with #, shows the default name (Jo, Sam, Lou). An empty name is the default.
-- Pure, so tests/specs/StaffNameRules.spec.luau covers it.

local StaffNameRules = {}

StaffNameRules.FLAG = "staffRename"
StaffNameRules.MAX_LENGTH = 16
StaffNameRules.MAX_RAW = 100 -- a longer string from a client is refused outright
StaffNameRules.NAME_PREFIX = "StaffName_" -- Player attribute StaffName_<workerId>: the filtered name, nil for default

-- The typed name made safe to save: "" means the default name; nil for anything that is not a string or too long.
function StaffNameRules.clean(raw: unknown): string?
	if type(raw) ~= "string" or #raw > StaffNameRules.MAX_RAW then
		return nil
	end
	local kept = string.gsub(raw, "[^%w ]", "")
	local collapsed = string.gsub(kept, " +", " ")
	local trimmed = string.match(collapsed, "^ *(.-) *$") or ""
	local cut = string.sub(trimmed, 1, StaffNameRules.MAX_LENGTH)
	return (string.match(cut, "^(.-) *$") or "")
end

-- What to show for a cleaned name after the filter: `filtered` (nil when filtering failed) unless it is empty or
-- the filter hid any of it, in which case the default name.
function StaffNameRules.shown(name: string, filtered: string?, default: string): string
	if name == "" or filtered == nil or filtered == "" then
		return default
	end
	if string.find(filtered, "#", 1, true) then
		return default
	end
	return filtered
end

return table.freeze(StaffNameRules)
