--!strict
-- HelperFetchRules: a helper walks to the counter for their cat and carries it to their stand (switch helperFetch,
-- issue 884). Derek on dev, 2026-11-26: "after hiring cats shouldnt teleport into the station the helper should walk
-- and grab them".
--
-- When a helper takes a waiting cat (WorkerService), the cat stays where it sat (on the counter, or with its customer
-- at the door) and the server marks the helper's staff model with the walk: FROM (where they stand at their stand),
-- TO (where they pick the cat up), AT (the server time they set off), CAT (the cat model they carry) and WAY ("fetch"
-- or "return"). Every client walks the helper there in a straight line at SPEED, picks the cat up for PICK_SECONDS and
-- carries it back (HelperFetchController); the server takes the cat off the counter at the pick moment and sits it
-- in the stand when the helper is back. When it is washed the helper carries it out the same way and sets it down,
-- where it goes home. Nothing per frame replicates: all clients go by server time. Pure, so specs cover it.
local HelperFetchRules = {}

HelperFetchRules.FLAG = "helperFetch"
HelperFetchRules.FROM_ATTRIBUTE = "FetchFrom" -- Vector3: the helper's spot at their stand, on the floor
HelperFetchRules.TO_ATTRIBUTE = "FetchTo" -- Vector3: where they stand to pick the cat up (or set it down)
HelperFetchRules.AT_ATTRIBUTE = "FetchAt" -- number: server time they set off
HelperFetchRules.CAT_ATTRIBUTE = "FetchCat" -- string: the cat model they carry (ReplicatedStorage.Assets)
HelperFetchRules.WAY_ATTRIBUTE = "FetchWay" -- "fetch": out empty, back with the cat; "return": out with it, back empty
HelperFetchRules.HELD_NAME = "FetchCat" -- the cat left on the counter for the helper, until they pick it up

HelperFetchRules.SPEED = 9 -- studs a second
HelperFetchRules.PICK_SECONDS = 0.6 -- the stop at the counter to pick the cat up or set it down
HelperFetchRules.SHORT_OF = 2 -- studs short of the cat they stop, on their own side of the counter
HelperFetchRules.MIN_WALK = 0.5 -- seconds each way at least
HelperFetchRules.MAX_WALK = 6 -- and at most, so a far spot never holds a cat for long
HelperFetchRules.HELD_SCALE = 0.9 -- the carried cat's scale
HelperFetchRules.HELD_AHEAD = 1.1 -- studs in front of the helper the carried cat sits
HelperFetchRules.HELD_UP = 0.55 -- the carried cat's height, as a share of the helper's height

-- Where the helper stops for a cat at `cat` (flat, on the floor at `from`'s height): SHORT_OF studs before it on the
-- line from `from`, never past `from`.
function HelperFetchRules.stopFor(from: Vector3, cat: Vector3): Vector3
	local flat = Vector3.new(cat.X, from.Y, cat.Z)
	local along = flat - from
	local distance = along.Magnitude
	if distance <= HelperFetchRules.SHORT_OF or distance < 1e-6 then
		return from
	end
	return from + along.Unit * (distance - HelperFetchRules.SHORT_OF)
end

-- Seconds one way from `from` to `to`.
function HelperFetchRules.walkSeconds(from: Vector3, to: Vector3): number
	local seconds = (to - from).Magnitude / HelperFetchRules.SPEED
	return math.clamp(seconds, HelperFetchRules.MIN_WALK, HelperFetchRules.MAX_WALK)
end

-- Seconds from setting off to being back at the stand.
function HelperFetchRules.totalSeconds(from: Vector3, to: Vector3): number
	return 2 * HelperFetchRules.walkSeconds(from, to) + HelperFetchRules.PICK_SECONDS
end

-- Seconds from setting off to the pick up (or the set down): the middle of the stop at the counter.
function HelperFetchRules.pickAt(from: Vector3, to: Vector3): number
	return HelperFetchRules.walkSeconds(from, to) + HelperFetchRules.PICK_SECONDS / 2
end

export type Pose = {
	position: Vector3, -- on the floor
	facing: Vector3, -- flat, unit
	holding: boolean, -- the cat is in their arms
	done: boolean, -- back at the stand
}

-- Where the helper is `elapsed` seconds after setting off on `way` ("fetch" or "return") between `from` and `to`.
function HelperFetchRules.pose(way: string, from: Vector3, to: Vector3, elapsed: number): Pose
	local walk = HelperFetchRules.walkSeconds(from, to)
	local pick = HelperFetchRules.PICK_SECONDS
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local out = if flat.Magnitude > 1e-6 then flat.Unit else Vector3.zAxis
	local fetching = way ~= "return"
	local t = if elapsed == elapsed then elapsed else 0
	if t < walk then
		return {
			position = from:Lerp(to, math.max(t, 0) / walk),
			facing = out,
			holding = not fetching,
			done = false,
		}
	elseif t < walk + pick then
		local before = t < walk + pick / 2
		return {
			position = to,
			facing = out,
			holding = if fetching then not before else before,
			done = false,
		}
	elseif t < 2 * walk + pick then
		return {
			position = to:Lerp(from, (t - walk - pick) / walk),
			facing = -out,
			holding = fetching,
			done = false,
		}
	end
	return { position = from, facing = -out, holding = false, done = true }
end

return table.freeze(HelperFetchRules)
