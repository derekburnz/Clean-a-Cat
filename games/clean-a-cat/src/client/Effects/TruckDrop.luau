--!strict
-- TruckDrop: pure timing and curves for the opening scene (issue #281): a delivery truck drives past, hits a bump,
-- its back door swings open and a box falls out and lands in front of the player. No Roblox services and no
-- Instances, so every curve has specs; Effects/OpeningScene turns the numbers into pivots, sounds and the camera.
--
-- Scene space, in studs: the origin is where the box comes to rest on the pavement. +Z points from there across the road
-- (the way the player faces), +X is the way the truck drives (left to right for the player), +Y is up.
--
-- Every beat is in BEATS, so a change of mind is a one-line edit. Derek's lean is not locked (2026-11-24 ET).
local TruckDrop = {}

-- Derek's dev tests (2026-11-24): 3:10 PM ET "the truck comes a little too fast so start it further back and slower",
-- then 3:34 PM ET "speed bump should be changed to pothole and closer to being right infront of you and the back
-- should swing open and kind of tumble infront of you not float to you and the back of truck should only briefly
-- swing open then back close". So the truck starts about 55 studs up the road at 20 studs a second; its front
-- wheels drop into a pothole 2.5 studs up the road from the player, which kicks the back door open; the box slides
-- out and falls under gravity, carrying on along the road with the truck's speed, lands on its leading edge and
-- rolls end over end once (four sides, about 8 studs) to a stop flaps up, in front of the player; the door slams
-- shut behind it. The truck's speed, the box's fall and its roll are one motion, so the numbers below are derived
-- from each other (see the specs), not tuned apart.
TruckDrop.BEATS = {
	honk = 0.8, -- one soft honk so the player looks up
	frontHit = 2.4, -- front wheels drop into the pothole: the nose dips, clunk, dust; the jolt kicks the door open
	backHit = 2.8, -- back wheels drop in: the tail dips and the nose comes up
	slide = 2.5, -- the box starts sliding out of the open door
	drop = 2.75, -- it tips off the edge and falls
	land = 3.05, -- it hits the road on its leading edge and starts to roll
	settle = 4.45, -- rolled over once, flaps up, squashed flat and still
	done = 5.1, -- the truck is gone and the camera is the player's again
}

TruckDrop.ROAD_Z = 8 -- the middle of the truck's lane, across the road from the landing spot
-- Where the pothole is along the road when the scene has none to time to (off the plot): 7.5 studs up the road
-- from where the box comes to rest, so it lands short of the player and rolls past in front of them (the plot's
-- SpotBump and SpotBox are set to match).
TruckDrop.BUMP_X = -7.5
TruckDrop.BUMP_RANGE = 20 -- a pothole further than this along the road from the box is ignored, and BUMP_X is used
TruckDrop.WHEELBASE = 8 -- front to back axle; with the two hits 0.4 s apart the truck drives at 20 studs a second
TruckDrop.WHEEL_RADIUS = 1.1
TruckDrop.TAILGATE = { back = 6.5, up = 2, side = 0.9 } -- where the box leaves (the Tailgate attachment), from the
-- truck's pivot; `up` is the cargo floor's top (1.95, plus its 0.03 lining and a hair); `side` studs from the lane's middle toward the curb, toward the door's
-- near corner but with the whole box inside the 5.5 stud opening, clear of the side wall, the corner posts and the
-- rear lamps (their inner edge 2.32 from the middle; Sync-Agent's overlap check) (on the road under the middle of the
-- 13 stud truck, Model-Agent's CleanACat_Prop_DeliveryTruck; posts and trim added in #352)
TruckDrop.OPENING = 2.32 -- the box keeps inside this from the lane's middle at the back: the rear lamps' inner edge

-- The pothole jolt: each axle dips `dip` studs and bounces back over `seconds`; the front's dip tips the nose down
-- by `frontPitch`, the back's tips it up by `backPitch`.
TruckDrop.JOLT = { dip = 0.4, frontPitch = math.rad(4), backPitch = math.rad(5), seconds = 0.3 }
TruckDrop.RATTLE = { pitch = math.rad(1.2), seconds = 0.7 } -- the little rattle after each hit
-- The back door (hinged along its top edge): kicked open by the front wheels' drop over `seconds`, held open until
-- `hold` after the box drops, then swung shut over `closeSeconds` with two small settling bounces. The close starts
-- from rest and gathers speed (no snap), and the bounces last `settleSeconds` (Derek asked for a more fluid close,
-- 2026-11-25). The hold lets the box fall clear of the door's sweep first (Sync-Agent saw the slamming door clip it;
-- the clearance spec checks it).
-- `model` is the door's real shape for the clearance spec (Model-Agent's truck: hinge height over the pivot, how far
-- back of it, the panel's length and thickness with its ribs, and the model's DoorOpenDegrees that `open` scales to).
TruckDrop.DOOR = {
	model = { hinge = 7.18, back = 6.5, length = 5.43, thick = 0.22, openDegrees = 75 },
	open = math.rad(100),
	seconds = 0.1,
	swing = math.rad(10),
	hold = 0.34,
	closeSeconds = 0.3,
	rebound = math.rad(5),
	settleSeconds = 0.45,
}
-- The box (Model-Agent's CleanACat_Prop_DeliveryBox): its footprint along the road and its height.
TruckDrop.BOX = { width = 2.38, height = 1.7 }
TruckDrop.GRAVITY = 35 -- studs a second squared: about real gravity at 0.28 m a stud, so it falls with weight
-- The slide out of the door: the box's middle goes from `inside` box widths in from the door's edge to `out`
-- beyond it (where it tips over), riding with the truck as it goes.
TruckDrop.SLIDE = { inside = 0.6, out = 0.55 } -- out past half a width: it leaves the floor whole before it falls
-- The fall tips it forward to `tilt` radians, so its leading bottom edge meets the road first; then it rolls from
-- there to a whole turn (flaps up again) over BEATS.land to the roll's end, slowing as it goes (`ease` 2 is a
-- quadratic ease out: it lands at about the speed it fell with and stops gently).
TruckDrop.ROLL = { tilt = 0.3, ease = 2 }
TruckDrop.LANDING = { squash = 0.2, squashSeconds = 0.14 } -- the last face slapping down flat
TruckDrop.WIGGLE = { start = 0.4, every = 1.6, seconds = 0.45, angle = math.rad(7), meowEvery = 2 }
TruckDrop.OPEN = {
	flap = math.rad(215),
	flapSeconds = 0.35,
	peekDelay = 0.15,
	peekSeconds = 0.35,
	overshoot = 1.6,
	stagger = 0.08, -- the short flaps (FlapF, FlapB) lie under the long ones, so they start this much later
	settle = 0.6, -- after the peek: the shake-off plays out before open()'s onDone fires
}
-- The kitten hops out of the box toward the spa (Gameplay-Engineer's ask): a small arc, then onDone.
TruckDrop.HOP = { distance = 2.5, height = 1.4, seconds = 0.42, squash = 0.15 }

-- When the roll ends and the last face slaps down.
function TruckDrop.rollEnd(): number
	return TruckDrop.BEATS.settle - TruckDrop.LANDING.squashSeconds
end

-- The roll's angle `e` seconds after landing: from ROLL.tilt to a whole turn, easing out. With `reduced` it does not
-- turn (it slides to a stop).
function TruckDrop.rollAngle(e: number, reduced: boolean): number
	if reduced then
		return 0
	end
	local r = TruckDrop.ROLL
	local u = math.clamp(e / (TruckDrop.rollEnd() - TruckDrop.BEATS.land), 0, 1)
	return r.tilt + (2 * math.pi - r.tilt) * (1 - (1 - u) ^ r.ease)
end

-- Seconds after landing until the roll reaches `angle` (the inverse of rollAngle), for the thud of each face.
function TruckDrop.rollTime(angle: number): number
	local r = TruckDrop.ROLL
	local k = math.clamp((angle - r.tilt) / (2 * math.pi - r.tilt), 0, 1)
	local u = 1 - (1 - k) ^ (1 / r.ease)
	return u * (TruckDrop.rollEnd() - TruckDrop.BEATS.land)
end

-- Where the middle of a box rolling toward +X sits (x along the road, y up) when it has turned `angle` radians
-- (0 to a whole turn) about its bottom edges, ending flat with its middle over x = 0. It pivots on one edge per
-- quarter turn: lying on its width, then its height, then its width, then its height.
function TruckDrop.rollCenter(angle: number): (number, number)
	local w, h = TruckDrop.BOX.width, TruckDrop.BOX.height
	local quarter = math.pi / 2
	local q = math.clamp(math.floor(angle / quarter), 0, 3)
	local theta = angle - q * quarter
	-- each quarter's pivot edge: the first is a whole roll (2 widths and 2 heights) short of the resting box's
	-- leading edge, w / 2
	local pivot = w / 2 - 2 * (w + h)
	local foot = { h, w, h, w } -- what it lies on after each quarter
	for i = 1, q do
		pivot += foot[i]
	end
	-- before quarter q it stands on `along` (the side on the road) with `up` (the other side) upright
	local along = if q % 2 == 0 then w else h
	local up = if q % 2 == 0 then h else w
	local a, b = along / 2, up / 2
	return pivot - a * math.cos(theta) + b * math.sin(theta),
		a * math.sin(theta) + b * math.cos(theta)
end

-- Sound and effect beats, in the order they happen. OpeningScene plays each once as the clock passes it.
type Event = { at: number, name: string }
local function events(): { Event }
	local b = TruckDrop.BEATS
	local list: { Event } = {
		{ at = b.honk, name = "honk" },
		{ at = b.frontHit, name = "frontHit" },
		{ at = b.backHit, name = "backHit" },
		{ at = b.land, name = "land" },
		{ at = b.drop + TruckDrop.DOOR.hold + TruckDrop.DOOR.closeSeconds, name = "doorSlam" },
	}
	-- a thud as each of the first three faces comes down; the fourth is the settle
	for k = 1, 3 do
		table.insert(list, { at = b.land + TruckDrop.rollTime(k * math.pi / 2), name = "tumble" })
	end
	table.insert(list, { at = TruckDrop.rollEnd(), name = "settle" })
	table.sort(list, function(x: Event, y: Event): boolean
		return x.at < y.at
	end)
	return list
end
TruckDrop.EVENTS = events()

export type Truck = { x: number, lift: number, pitch: number, door: number }
export type Box = {
	x: number,
	y: number,
	z: number,
	tumble: number, -- radians about +X (the box tips toward the player), 0 at rest
	roll: number, -- radians about +Z (the wiggle rock), 0 at rest
	squash: number, -- 1 at rest, below 1 squashed flat (the X and Z sizes grow to keep the volume)
	visible: boolean, -- false while still inside the truck
}

-- A 0 -> 1 -> 0 hump over `length` seconds, 0 outside it.
function TruckDrop.hump(elapsed: number, length: number): number
	if elapsed < 0 or elapsed >= length then
		return 0
	end
	return math.sin(math.pi * elapsed / length)
end

-- A decaying wobble: `cycles` full swings over `length`, the swing falling to zero at the end.
function TruckDrop.wobble(elapsed: number, length: number, cycles: number): number
	if elapsed < 0 or elapsed >= length then
		return 0
	end
	local u = elapsed / length
	return math.sin(2 * math.pi * cycles * u) * (1 - u)
end

-- Back Out easing: overshoots past 1 and comes back, for the door and the flaps.
function TruckDrop.backOut(u: number, overshoot: number): number
	if u <= 0 then
		return 0
	end
	if u >= 1 then
		return 1
	end
	local v = u - 1
	return 1 + (overshoot + 1) * v * v * v + overshoot * v * v
end

function TruckDrop.speed(): number
	return TruckDrop.WHEELBASE / (TruckDrop.BEATS.backHit - TruckDrop.BEATS.frontHit)
end

-- The bump's place along the road for the scene's timing: the real bump's offset when it is a sane number, else
-- BUMP_X. The scene passes the plot's SpotBump, so the jolt always lands on the bump the player can see.
function TruckDrop.bumpAt(offset: number?): number
	if offset == nil or offset ~= offset or math.abs(offset) > TruckDrop.BUMP_RANGE then
		return TruckDrop.BUMP_X
	end
	return offset
end

-- The truck's pivot along the road: the front axle is over the bump at frontHit, the back axle at backHit.
-- bumpX (from bumpAt) defaults to BUMP_X; every function below that takes it passes it on.
function TruckDrop.truckX(t: number, bumpX: number?): number
	return (bumpX or TruckDrop.BUMP_X)
		- TruckDrop.WHEELBASE / 2
		+ TruckDrop.speed() * (t - TruckDrop.BEATS.frontHit)
end

-- The door's angle `opened` seconds after the front wheels' drop: kicked open, held, slammed shut with a rebound.
function TruckDrop.door(opened: number, reduced: boolean): number
	local d = TruckDrop.DOOR
	if opened <= 0 then
		return 0
	end
	local closeAt = TruckDrop.BEATS.drop + d.hold - TruckDrop.BEATS.frontHit
	local function held(at: number): number
		if reduced then
			return d.open
		end
		return d.open * TruckDrop.backOut(at / d.seconds, 1.4)
			+ d.swing * math.sin(at * 12) * math.exp(-at * 4)
	end
	if opened < closeAt then
		return held(opened)
	end
	local u = (opened - closeAt) / d.closeSeconds
	if u < 1 then
		-- from where the hold left it, easing out of rest and speeding up into the frame: u^2 (2 - u) has no speed
		-- at the start and a gentle one at the end, so the door swings shut instead of snapping
		return held(closeAt) * (1 - u * u * (2 - u))
	end
	if reduced then
		return 0
	end
	return TruckDrop.settle(opened - closeAt - d.closeSeconds, d.settleSeconds) * d.rebound
end

-- Two bounces off the frame after a close, the second smaller, falling to rest at `length`: 0 to 1, never below 0.
function TruckDrop.settle(elapsed: number, length: number): number
	if elapsed < 0 or elapsed >= length then
		return 0
	end
	local u = elapsed / length
	return math.abs(math.sin(2 * math.pi * u)) * (1 - u) * (1 - u)
end

-- The truck at time t. `reduced` (Reduced Motion or Less shake) drops the jolt, the rattle and the door's swing.
function TruckDrop.truck(t: number, reduced: boolean, bumpX: number?): Truck
	local b = TruckDrop.BEATS
	local jolt = TruckDrop.JOLT
	local lift, pitch = 0, 0
	if not reduced then
		local front = t - b.frontHit
		local back = t - b.backHit
		-- into the pothole first (down), then a small bounce back up
		local fw = TruckDrop.wobble(front, jolt.seconds, 0.75)
		local bw = TruckDrop.wobble(back, jolt.seconds, 0.75)
		lift = -jolt.dip * (fw + bw)
		pitch = -jolt.frontPitch * fw
			+ jolt.backPitch * bw
			+ TruckDrop.RATTLE.pitch
				* TruckDrop.wobble(back - jolt.seconds, TruckDrop.RATTLE.seconds, 4)
	end
	return {
		x = TruckDrop.truckX(t, bumpX),
		lift = lift,
		pitch = pitch,
		door = TruckDrop.door(t - b.frontHit, reduced),
	}
end

-- Where the box's base sits on the cargo floor at time t, `behind` studs back from the truck's pivot: the floor rides
-- the truck's dip and pitch (positive pitch lowers the back), and a level box on a tipped floor rests on its lower
-- edge, so it never sinks in (Sync-Agent measured up to 0.15 studs before).
function TruckDrop.floorAt(t: number, reduced: boolean, bumpX: number?, behind: number): number
	local state = TruckDrop.truck(t, reduced, bumpX)
	local p = state.pitch
	return state.lift
		+ TruckDrop.TAILGATE.up * math.cos(p)
		- behind * math.sin(p)
		+ TruckDrop.BOX.width / 2 * math.abs(math.sin(p))
end

-- The box's middle as it tips off the door's edge (BEATS.drop), in scene space: x along the road, y, z across.
function TruckDrop.launch(bumpX: number?, reduced: boolean?): (number, number, number)
	local w = TruckDrop.BOX.width
	local behind = TruckDrop.TAILGATE.back + TruckDrop.SLIDE.out * w
	return TruckDrop.truckX(TruckDrop.BEATS.drop, bumpX) - behind,
		TruckDrop.floorAt(TruckDrop.BEATS.drop, reduced == true, bumpX, behind)
			+ TruckDrop.BOX.height / 2,
		TruckDrop.ROAD_Z - TruckDrop.TAILGATE.side
end

-- The box at time t (scene clock), before it is opened: x, y and z are its base's middle (y = 0 on the road) as if
-- it were upright, and `roll` turns it about its middle toward +X (so a rolled box's middle is where
-- rollCenter says). After settle it rests at the origin, wiggling.
function TruckDrop.box(t: number, reduced: boolean, bumpX: number?): Box
	local b = TruckDrop.BEATS
	local half = TruckDrop.BOX.height / 2
	local box: Box =
		{ x = 0, y = 0, z = 0, tumble = 0, roll = 0, squash = 1, visible = t >= b.slide }
	if t < b.slide then
		return box
	end
	local lx, ly, lz = TruckDrop.launch(bumpX, reduced)
	-- across the road: from the door's corner to the pavement, over the fall and the roll. It eases out (so the box
	-- leaves the truck straight back, clear of the side wall, #352) and slows to a stop as it rolls.
	local across = math.clamp((t - b.drop) / (TruckDrop.rollEnd() - b.drop), 0, 1)
	box.z = lz * (1 - across * across * (3 - 2 * across))
	if t < b.drop then
		-- sliding out of the door, riding with the truck
		local u = (t - b.slide) / (b.drop - b.slide)
		local w = TruckDrop.BOX.width
		local rel = TruckDrop.SLIDE.inside * w * (1 - u) - TruckDrop.SLIDE.out * w * u
		box.x = TruckDrop.truckX(t, bumpX) - TruckDrop.TAILGATE.back + rel
		box.y = TruckDrop.floorAt(t, reduced, bumpX, TruckDrop.TAILGATE.back - rel)
		return box
	end
	local cx0, cy0 = TruckDrop.rollCenter(TruckDrop.rollAngle(0, reduced))
	if reduced then
		cy0 = half
	end
	if t < b.land then
		-- falling under gravity, straight on along the road, tipping forward onto its leading edge
		local fall = b.land - b.drop
		local s = t - b.drop
		local g = TruckDrop.GRAVITY
		local vy = (cy0 - ly + g / 2 * fall * fall) / fall
		local cx = lx + (cx0 - lx) * s / fall
		local cy = ly + vy * s - g / 2 * s * s
		box.x = cx
		box.y = cy - half
		if not reduced then
			box.roll = TruckDrop.ROLL.tilt * s / fall
		end
		return box
	end
	local rollEnd = TruckDrop.rollEnd()
	if t < rollEnd then
		local angle = TruckDrop.rollAngle(t - b.land, reduced)
		if reduced then
			-- no turning: it slides to a stop where the roll would end
			local k = 1 - (1 - (t - b.land) / (rollEnd - b.land)) ^ 2
			box.x = cx0 + (0 - cx0) * k
			return box
		end
		local cx, cy = TruckDrop.rollCenter(angle)
		box.x = cx
		box.y = cy - half
		box.roll = angle
		return box
	end
	box.squash = 1
		- TruckDrop.LANDING.squash
			* TruckDrop.hump(t - rollEnd, TruckDrop.LANDING.squashSeconds)
	if not reduced then
		box.roll = TruckDrop.wiggle(t)
	end
	return box
end

-- Which wiggle is playing at t, from 0, or nil between wiggles and before the first.
function TruckDrop.wiggleIndex(t: number): number?
	local w = TruckDrop.WIGGLE
	local since = t - TruckDrop.BEATS.settle - w.start
	if since < 0 then
		return nil
	end
	local n = math.floor(since / w.every)
	if since - n * w.every >= w.seconds then
		return nil
	end
	return n
end

-- The wiggle's rock angle at t: two quick side to side swings every WIGGLE.every seconds until the box is opened.
function TruckDrop.wiggle(t: number): number
	local w = TruckDrop.WIGGLE
	local since = t - TruckDrop.BEATS.settle - w.start
	if since < 0 then
		return 0
	end
	local into = since % w.every
	return w.angle * TruckDrop.wobble(into, w.seconds, 2)
end

-- Does wiggle n meow? Every meowEvery-th wiggle, starting with the first, so the box is not noisy.
function TruckDrop.wiggleMeows(n: number): boolean
	return n % TruckDrop.WIGGLE.meowEvery == 0
end

-- After the tap, `e` seconds in: how far each flap has swung (radians) and how far the kitten has risen (0..1).
-- With `reduced` the flaps open without the overshoot.
function TruckDrop.open(e: number, reduced: boolean): (number, number)
	local o = TruckDrop.OPEN
	local u = e / o.flapSeconds
	local flap = if reduced
		then o.flap * math.clamp(u, 0, 1)
		else o.flap * TruckDrop.backOut(u, o.overshoot)
	local rise = math.clamp((e - o.peekDelay) / o.peekSeconds, 0, 1)
	rise = 1 - (1 - rise) * (1 - rise) -- ease out
	return flap, rise
end

function TruckDrop.openSeconds(): number
	return math.max(
		TruckDrop.OPEN.flapSeconds + TruckDrop.OPEN.stagger,
		TruckDrop.OPEN.peekDelay + TruckDrop.OPEN.peekSeconds
	)
end

-- Seconds from the tap until open()'s onDone: the flaps and the peek, then the shake-off.
function TruckDrop.openDoneSeconds(): number
	return TruckDrop.openSeconds() + TruckDrop.OPEN.settle
end

-- The hop out of the box, `e` seconds in: how far along (0..1, eased) and how high (studs) above the straight line
-- from the rim to the ground. With `reduced` it is a lower arc (still a hop, so it reads as leaving).
function TruckDrop.hop(e: number, reduced: boolean): (number, number)
	local h = TruckDrop.HOP
	local u = math.clamp(e / h.seconds, 0, 1)
	local along = u * (2 - u) * 0.35 + u * 0.65 -- a little quicker off the rim
	local height = (if reduced then h.height * 0.4 else h.height) * 4 * u * (1 - u)
	return along, height
end

-- Names of the EVENTS whose time falls in (from, to].
function TruckDrop.eventsBetween(from: number, to: number): { string }
	local list = {}
	for _, event in TruckDrop.EVENTS do
		if event.at > from and event.at <= to then
			table.insert(list, event.name)
		end
	end
	return list
end

-- Where the shot camera looks at t, as an X along the road: it follows the truck in, then the box from the
-- moment it slides out until it stops at the origin, so the tumble is always framed.
function TruckDrop.lookX(t: number, bumpX: number?): number
	if t >= TruckDrop.BEATS.slide then
		return math.clamp(TruckDrop.box(t, true, bumpX).x, -12, 0)
	end
	return math.clamp(TruckDrop.truckX(t, bumpX) - TruckDrop.TAILGATE.back, -12, 0)
end

return TruckDrop
