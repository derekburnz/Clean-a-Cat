--!strict
-- FriendViewRules: the HUD's friend chip (issue 520, switch friendBonus), from the Player attribute FriendsHere that
-- VisitService keeps (friends in this server; nil while the switch is off). Nothing shows with none. The bonus is
-- VisitRules' own share (10% a friend, at most 30%), so the chip says what the recap pays. Pure, so
-- tests/specs/FriendViewRules.spec.luau covers it.
local VisitRules = require(script.Parent:WaitForChild("VisitRules"))

local FriendViewRules = {}

-- "1 friend · +10%", "3 friends · +30%"; nil with none, or with a value that is not a whole count.
function FriendViewRules.chipText(raw: unknown): string?
	if type(raw) ~= "number" or raw ~= raw or raw < 1 or raw == math.huge then
		return nil
	end
	local friends = math.floor(raw)
	local percent = math.floor(VisitRules.friendShare(friends) * 100 + 0.5)
	local who = if friends == 1 then "1 friend" else `{friends} friends`
	return `{who} · +{percent}%`
end

return table.freeze(FriendViewRules)
