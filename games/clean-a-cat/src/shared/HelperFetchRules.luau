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
HelperFetchRules.PATH_ATTRIBUTE = "FetchPath" -- string: the corners walked between FROM and TO, "x,y,z;x,y,z" (none:
-- a straight line). On the big spa the walk keeps to the aisles (route) so no helper walks through a tub (Sync on
-- 844315b: Jo's straight line crossed the third tub and the mascot)

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

export type Aisle = {
	front: number, -- the Z of the cross aisle in front of the helpers' stands
	lane: number, -- the X of the lane down the room, between the second station and the player's tub
	counter: number, -- the Z the helper stands at behind the counter, SHORT_OF studs from the cats
	cats: number, -- the Z of the cats on the counter
}

-- The aisles of a big spa from its spots: a helper's stand, the second station, the player's tub and the first
-- counter cat, all world positions on one plot (the plots are never turned, so X and Z are the room's own).
function HelperFetchRules.aisle(
	stand: Vector3,
	station: Vector3,
	tub: Vector3,
	counterCat: Vector3
): Aisle
	local toward = if stand.Z >= counterCat.Z then 1 else -1
	return {
		front = (stand.Z + station.Z) / 2,
		lane = (station.X + tub.X) / 2,
		counter = counterCat.Z + toward * HelperFetchRules.SHORT_OF,
		cats = counterCat.Z,
	}
end

-- (big spa) The walk from `from` to a cat at `cat` along `aisle`: out to the cross aisle in front of the stands,
-- along it to the lane, down the lane to behind the counter and along the counter to the cat. Returns the corners
-- and the stop, on the floor at `from`'s height. A cat not on the counter row (the door line), or no aisle: the
-- straight line (no corners, stopFor).
function HelperFetchRules.route(from: Vector3, cat: Vector3, aisle: Aisle?): ({ Vector3 }, Vector3)
	if aisle == nil or math.abs(cat.Z - aisle.cats) > 1 then
		return {}, HelperFetchRules.stopFor(from, cat)
	end
	local y = from.Y
	local stop = Vector3.new(cat.X, y, aisle.counter)
	local wanted = {
		Vector3.new(from.X, y, aisle.front),
		Vector3.new(aisle.lane, y, aisle.front),
		Vector3.new(aisle.lane, y, aisle.counter),
	}
	local corners: { Vector3 } = {}
	local last = from
	for _, point in wanted do
		if (point - last).Magnitude > 0.05 and (point - stop).Magnitude > 0.05 then
			table.insert(corners, point)
			last = point
		end
	end
	return corners, stop
end

-- The corners as the FetchPath text, and back. Bad text reads as no corners.
function HelperFetchRules.encode(corners: { Vector3 }): string
	local parts = {}
	for _, point in corners do
		table.insert(parts, string.format("%.2f,%.2f,%.2f", point.X, point.Y, point.Z))
	end
	return table.concat(parts, ";")
end

function HelperFetchRules.decode(text: unknown): { Vector3 }
	local corners: { Vector3 } = {}
	if type(text) ~= "string" or text == "" or #text > 400 then
		return corners
	end
	for _, piece in string.split(text, ";") do
		local x, y, z = string.match(piece, "^(-?[%d%.]+),(-?[%d%.]+),(-?[%d%.]+)$")
		local nx, ny, nz = tonumber(x), tonumber(y), tonumber(z)
		if nx == nil or ny == nil or nz == nil then
			return {}
		end
		table.insert(corners, Vector3.new(nx, ny, nz))
	end
	return corners
end

-- The corners a staff model's walk keeps to (its FetchPath).
function HelperFetchRules.viaOf(model: Instance): { Vector3 }
	return HelperFetchRules.decode(model:GetAttribute(HelperFetchRules.PATH_ATTRIBUTE))
end

local function pointsOf(from: Vector3, to: Vector3, via: { Vector3 }?): { Vector3 }
	local points: { Vector3 } = { from }
	if via then
		for _, point in via do
			table.insert(points, point)
		end
	end
	table.insert(points, to)
	return points
end

local function lengthOf(points: { Vector3 }): number
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	return total
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(v.X, 0, v.Z)
	return if flat.Magnitude > 1e-6 then flat.Unit else fallback
end

-- Where `distance` studs along `points` is, and the flat way that stretch goes.
local function along(points: { Vector3 }, distance: number): (Vector3, Vector3)
	local left = math.max(distance, 0)
	local way = Vector3.zAxis
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local stretch = (b - a).Magnitude
		way = flatUnit(b - a, way)
		if left <= stretch or i == #points then
			local u = if stretch > 1e-6 then math.clamp(left / stretch, 0, 1) else 1
			return a:Lerp(b, u), way
		end
		left -= stretch
	end
	return points[#points], way
end

-- Seconds one way from `from` to `to`, by way of the corners `via`.
function HelperFetchRules.walkSeconds(from: Vector3, to: Vector3, via: { Vector3 }?): number
	local seconds = lengthOf(pointsOf(from, to, via)) / HelperFetchRules.SPEED
	return math.clamp(seconds, HelperFetchRules.MIN_WALK, HelperFetchRules.MAX_WALK)
end

-- Seconds from setting off to being back at the stand.
function HelperFetchRules.totalSeconds(from: Vector3, to: Vector3, via: { Vector3 }?): number
	return 2 * HelperFetchRules.walkSeconds(from, to, via) + HelperFetchRules.PICK_SECONDS
end

-- Seconds from setting off to the pick up (or the set down): the middle of the stop at the counter.
function HelperFetchRules.pickAt(from: Vector3, to: Vector3, via: { Vector3 }?): number
	return HelperFetchRules.walkSeconds(from, to, via) + HelperFetchRules.PICK_SECONDS / 2
end

export type Pose = {
	position: Vector3, -- on the floor
	facing: Vector3, -- flat, unit
	holding: boolean, -- the cat is in their arms
	done: boolean, -- back at the stand
}

-- Where the helper is `elapsed` seconds after setting off on `way` ("fetch" or "return") between `from` and `to`, by
-- way of the corners `via` (out along them, back the same way).
function HelperFetchRules.pose(
	way: string,
	from: Vector3,
	to: Vector3,
	elapsed: number,
	via: { Vector3 }?
): Pose
	local walk = HelperFetchRules.walkSeconds(from, to, via)
	local pick = HelperFetchRules.PICK_SECONDS
	local points = pointsOf(from, to, via)
	local total = lengthOf(points)
	local _, first = along(points, 0)
	local _, last = along(points, total)
	local fetching = way ~= "return"
	local t = if elapsed == elapsed then elapsed else 0
	if t < walk then
		local position, facing = along(points, total * math.max(t, 0) / walk)
		return {
			position = position,
			facing = facing,
			holding = not fetching,
			done = false,
		}
	elseif t < walk + pick then
		local before = t < walk + pick / 2
		return {
			position = to,
			facing = last,
			holding = if fetching then not before else before,
			done = false,
		}
	elseif t < 2 * walk + pick then
		local position, facing = along(points, total * (1 - (t - walk - pick) / walk))
		return {
			position = position,
			facing = -facing,
			holding = fetching,
			done = false,
		}
	end
	return { position = from, facing = -first, holding = false, done = true }
end

return table.freeze(HelperFetchRules)
