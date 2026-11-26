--!strict
-- WalkRules: how a customer at the door walks to their mat (switch townsfolk, #446). The server places each of
-- Model-Agent's townsfolk where it comes from (its old mat, or the pavement for a new customer) and marks it with
-- its mat (TO_ATTRIBUTE) and when it sets off (AT_ATTRIBUTE, server time); one already on its mat has neither. Each
-- client then walks it there (CustomerWalkController), so nothing jumps on any screen:
-- a new customer in from the pavement, the rest up one mat after a serve. A figure whose WalkAt changes walks again
-- from where it stands (FigureService redraws a line in place under the switch lineReuse). This moves only the whole customer; the
-- legs, arms and the look round on arrival are Motion-FX's (Effects/CustomerMotion, switch customerWalk), read from
-- that movement. Pure, so tests/specs/WalkRules.spec.luau covers the numbers.
local WalkRules = {}

WalkRules.TAG = "CleanACatCustomer" -- CollectionService tag on every townsfolk customer the server draws
WalkRules.TO_ATTRIBUTE = "WalkTo" -- CFrame: the mat the walk ends on; the figure's pivot as drawn is where it starts
WalkRules.AT_ATTRIBUTE = "WalkAt" -- number: Workspace:GetServerTimeNow() when the walk starts; a new customer walking
-- in from the pavement (FILE_ATTRIBUTE) is hidden before it, one stepping up stands where they are until then
WalkRules.FILE_ATTRIBUTE = "WalkFile" -- true on a new customer walking in from the pavement in single file
WalkRules.STREET_PLACE = 5 -- a new customer starts at the line's fifth place, past the last mat on the pavement
WalkRules.FILE_GAP = 0.7 -- seconds between new customers walking in together, so they come in single file
WalkRules.DEFAULT_SPEED = 6.5 -- studs a second when the model has no WalkSpeed
WalkRules.TURN_SECONDS = 0.3 -- a customer walking in turns to face the door over the last of the walk

-- Seconds the walk of `distance` studs takes at `speed`.
function WalkRules.duration(distance: number, speed: number?): number
	local pace = if speed and speed > 0 then speed else WalkRules.DEFAULT_SPEED
	return math.max(distance, 0) / pace
end

-- How far along the walk is, 0 to 1, `elapsed` seconds after it starts. Nil before it starts.
function WalkRules.progress(elapsed: number, duration: number): number?
	if elapsed < 0 then
		return nil
	end
	if duration <= 0 then
		return 1
	end
	return math.min(elapsed / duration, 1)
end

-- Whether a walk from `from` to `to` goes the way the mat there faces (`look`, its LookVector), so the customer turns
-- to walk it. A step back (after a pick) is walked facing the door.
function WalkRules.facesTravel(from: Vector3, to: Vector3, look: Vector3): boolean
	local travel = to - from
	local flat = Vector3.new(travel.X, 0, travel.Z)
	return flat.Magnitude > 0.05 and flat:Dot(look) > 0
end

return WalkRules
