--!strict
-- VisitRules: visiting and the friend bonus (issue 520).
--   - Visiting (switch visiting): other players may walk into a spa; that is on for every new save (save.visiting),
--     and the spa's owner can turn it off. While it is off, a visitor found inside the spa is moved out to the
--     pavement in front of it, and stays out. A visitor can look and walk about, never wash, pick, take or block
--     anything: every spa action on the server acts only on the player's own spa.
--   - The friend bonus (switch friendBonus; tuning pay.friend): each of the player's Roblox friends in the same
--     server adds 10% to every cat they wash by hand, at most 30%, on the wash's total, shown on the HUD and as its own
--     recap line.
-- Pure, so tests/specs/VisitRules.spec.luau covers it; VisitService and SpaService use it.

local VisitRules = {}

VisitRules.FLAG = "visiting"
VisitRules.FRIEND_FLAG = "friendBonus"
VisitRules.ALLOWED_ATTRIBUTE = "VisitorsAllowed" -- Player attribute: the owner's setting (nil while visiting is off)
VisitRules.FRIENDS_ATTRIBUTE = "FriendsHere" -- Player attribute: friends in the server (nil while friendBonus is off)

VisitRules.FRIEND_SHARE = 0.1 -- pay.friend: per friend in the server
VisitRules.FRIEND_MAX = 0.3 -- at most

-- The spa's inside, in the plot's own space (its pivot at the plot centre on the ground, street side -Z): from wall
-- to wall and from the front wall (the window seat and the sign, z -17) to the back. The pavement with the line's
-- outer mats and the street are outside.
VisitRules.INSIDE_MIN = Vector3.new(-16.5, -3, -17)
VisitRules.INSIDE_MAX = Vector3.new(16.5, 25, 13.5)
-- Where a visitor is put when the spa is closed to them: on the pavement in front, clear of the line's mats.
VisitRules.OUTSIDE = Vector3.new(4, 3.5, -24)

-- The share friends add: 10% each, at most 30%; 0 with none.
function VisitRules.friendShare(friends: number): number
	if friends ~= friends or friends <= 0 then
		return 0
	end
	return math.min(math.floor(friends) * VisitRules.FRIEND_SHARE, VisitRules.FRIEND_MAX)
end

-- The coins friends add on a hand wash's total of `coins`.
function VisitRules.friendExtra(coins: number, friends: number): number
	return math.max(0, math.floor(coins * VisitRules.friendShare(friends) + 0.5))
end

-- Whether `point` (in the plot's own space) is inside the spa.
function VisitRules.inside(point: Vector3): boolean
	local low, high = VisitRules.INSIDE_MIN, VisitRules.INSIDE_MAX
	return point.X >= low.X
		and point.X <= high.X
		and point.Y >= low.Y
		and point.Y <= high.Y
		and point.Z >= low.Z
		and point.Z <= high.Z
end

-- The setting from a client: true or false, or nil for anything else.
function VisitRules.cleanSetting(raw: unknown): boolean?
	if raw == true or raw == false then
		return raw
	end
	return nil
end

return table.freeze(VisitRules)
