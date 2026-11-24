--!strict
-- TruckDrop: pure timing and curves for the opening scene (issue #281): a delivery truck drives past, hits a bump,
-- its back door swings open and a box falls out and lands in front of the player. No Roblox services and no
-- Instances, so every curve has specs; Effects/OpeningScene turns the numbers into pivots, sounds and the camera.
--
-- Scene space, in studs: the origin is the box's landing spot on the pavement. +Z points from there across the road
-- (the way the player faces), +X is the way the truck drives (left to right for the player), +Y is up.
--
-- Every beat is in BEATS, so a change of mind is a one-line edit. Derek's lean is not locked (2026-11-24 ET).
local TruckDrop = {}

TruckDrop.BEATS = {
	honk = 0.4, -- one soft honk so the player looks up
	frontHit = 1.2, -- front wheels hit the bump: nose jolts up, thunk, dust puff
	backHit = 1.45, -- back wheels hit it: nose dips, the back door swings open
	drop = 1.85, -- the box slides off the back: the truck is far enough on that it falls back along the road
	land = 2.45, -- the box hits the pavement: squash, one bounce
	settle = 2.83, -- the box is at rest
	done = 3.7, -- the truck is gone and the camera is the player's again
}

TruckDrop.ROAD_Z = 8 -- the middle of the truck's lane, across the road from the landing spot
TruckDrop.BUMP_X = -3 -- where the bump is along the road when the scene has no bump to time to (off the plot)
TruckDrop.BUMP_RANGE = 20 -- a bump further than this along the road from the box is ignored, and BUMP_X is used
TruckDrop.WHEELBASE = 8 -- front to back axle; with the two hits 0.25 s apart the truck drives at 32 studs a second
TruckDrop.WHEEL_RADIUS = 1.1
TruckDrop.TAILGATE = { back = 6.5, up = 1.9, side = 2 } -- where the box leaves (the Tailgate attachment), from the
-- truck's pivot; `side` studs from the lane's middle toward the curb, the door's near corner
-- (on the road under the middle of the 13 stud truck, Model-Agent's CleanACat_Prop_DeliveryTruck)

TruckDrop.JOLT = { lift = 0.35, frontPitch = math.rad(5), backPitch = math.rad(-4), seconds = 0.22 }
TruckDrop.RATTLE = { pitch = math.rad(1.2), seconds = 0.7 } -- the little rattle after each hit
TruckDrop.DOOR = { open = math.rad(100), seconds = 0.25, swing = math.rad(8) } -- hinged along its top edge, flaps up
TruckDrop.ARC = { height = 1.2, spin = math.pi / 2 } -- a quarter tumble that ends flat, so a cube lands square
TruckDrop.LANDING = { squash = 0.22, squashSeconds = 0.1, bounce = 0.5, bounceSeconds = 0.28 }
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

-- Sound and effect beats, in the order they happen. OpeningScene plays each once as the clock passes it.
TruckDrop.EVENTS = {
	{ at = TruckDrop.BEATS.honk, name = "honk" },
	{ at = TruckDrop.BEATS.frontHit, name = "frontHit" },
	{ at = TruckDrop.BEATS.backHit, name = "backHit" },
	{ at = TruckDrop.BEATS.land, name = "land" },
	{
		at = TruckDrop.BEATS.land
			+ TruckDrop.LANDING.squashSeconds
			+ TruckDrop.LANDING.bounceSeconds,
		name = "settle",
	},
}

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

-- The truck at time t. `reduced` (Reduced Motion or Less shake) drops the jolt, the rattle and the door's swing.
function TruckDrop.truck(t: number, reduced: boolean, bumpX: number?): Truck
	local b = TruckDrop.BEATS
	local jolt = TruckDrop.JOLT
	local lift, pitch = 0, 0
	if not reduced then
		local front = t - b.frontHit
		local back = t - b.backHit
		lift = jolt.lift
			* (TruckDrop.hump(front, jolt.seconds) + TruckDrop.hump(back, jolt.seconds))
		pitch = jolt.frontPitch * TruckDrop.hump(front, jolt.seconds)
			+ jolt.backPitch * TruckDrop.hump(back, jolt.seconds)
			+ TruckDrop.RATTLE.pitch
				* TruckDrop.wobble(back - jolt.seconds, TruckDrop.RATTLE.seconds, 4)
	end
	local door = 0
	local opened = t - b.backHit
	if opened > 0 then
		local d = TruckDrop.DOOR
		if reduced then
			door = d.open
		else
			door = d.open * TruckDrop.backOut(opened / d.seconds, 1.4)
				+ d.swing * math.sin(opened * 9) * math.exp(-opened * 1.5)
		end
	end
	return { x = TruckDrop.truckX(t, bumpX), lift = lift, pitch = pitch, door = door }
end

-- Where the box leaves the truck, in scene space.
function TruckDrop.launch(bumpX: number?): (number, number, number)
	return TruckDrop.truckX(TruckDrop.BEATS.drop, bumpX) - TruckDrop.TAILGATE.back,
		TruckDrop.TAILGATE.up,
		TruckDrop.ROAD_Z - TruckDrop.TAILGATE.side
end

-- The box at time t (scene clock), before it is opened. After settle it rests at the origin, wiggling.
function TruckDrop.box(t: number, reduced: boolean, bumpX: number?): Box
	local b = TruckDrop.BEATS
	local box: Box =
		{ x = 0, y = 0, z = 0, tumble = 0, roll = 0, squash = 1, visible = t >= b.drop }
	if t < b.drop then
		return box
	end
	if t < b.land then
		local u = (t - b.drop) / (b.land - b.drop)
		local lx, ly, lz = TruckDrop.launch(bumpX)
		box.x = lx * (1 - u)
		box.z = lz * (1 - u)
		-- through the launch height at u = 0 and the ground at u = 1, peaking ARC.height above the straight line
		box.y = ly * (1 - u) + TruckDrop.ARC.height * 4 * u * (1 - u)
		if not reduced then
			box.tumble = -TruckDrop.ARC.spin * (1 - u)
		end
		return box
	end
	local l = TruckDrop.LANDING
	local after = t - b.land
	box.squash = 1 - l.squash * TruckDrop.hump(after, l.squashSeconds)
	local bounce = after - l.squashSeconds
	box.y = l.bounce * TruckDrop.hump(bounce, l.bounceSeconds)
	box.squash -= l.squash * 0.5 * TruckDrop.hump(bounce - l.bounceSeconds, l.squashSeconds)
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

-- Where the shot camera looks at t, as an X along the road: it follows the truck in, holds on the box from the
-- drop and stays there, so the landing is always framed.
function TruckDrop.lookX(t: number, bumpX: number?): number
	local b = TruckDrop.BEATS
	local follow = math.clamp(TruckDrop.truckX(t, bumpX) - TruckDrop.TAILGATE.back, -8, 0)
	if t >= b.drop then
		local u = math.clamp((t - b.drop) / (b.land - b.drop), 0, 1)
		local lx = TruckDrop.launch(bumpX)
		return lx * (1 - u)
	end
	return follow
end

return TruckDrop
