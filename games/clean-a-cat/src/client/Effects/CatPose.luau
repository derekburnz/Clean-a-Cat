--!strict
-- CatPose: pure rules for the cats' procedural motion. Angles in radians, times in seconds. No Roblox services and
-- no Instances, so every curve has specs; Effects/CatMotion turns a Pose into joint pivots each frame.
--
-- Motions (docs/vfx/clean-a-cat/effects-list.md, "Motion"):
--   idle    head breathing nod, slow tail sway; always on within range, off with Reduce Motion
--   blink   both eyes squash shut for BLINK_SECONDS every 2.5 to 6 s; kept with Reduce Motion (it is tiny)
--   twitch  one ear flicks for TWITCH_SECONDS every 4 to 9 s
--   shake   the shake-off on CatClean: head roll and tail whip, SHAKE_SECONDS, skipped with Reduce Motion
--   wiggle  the happy wiggle on CatFluffed: tail wag, ears up, head tilt, WIGGLE_SECONDS, skipped with Reduce Motion
--   mood    a waiting cat's heart bar (the HeartFill attribute, 1 full to 0 empty, issue #528): happy with the tail up
--           while the bar is high, grumpy as it drops (ears out to the side, head a little low, the tail lashing now
--           and then), and with the bar empty the leaving pose (ears flat, head and tail down, no sway). The pose is
--           held with Reduce Motion; only the lash stops.
local CatPose = {}

CatPose.JOINTS = { "Body", "Head", "Tail", "EarL", "EarR", "Eye1", "Eye2" }

CatPose.BLINK_SECONDS = 0.14
CatPose.BLINK_GAP = { 2.5, 6 }
CatPose.TWITCH_SECONDS = 0.25
CatPose.TWITCH_GAP = { 4, 9 }
CatPose.SHAKE_SECONDS = 0.5
CatPose.WIGGLE_SECONDS = 0.8
CatPose.BLINK_SQUASH = 0.85 -- how much of an eye's height closes at the middle of a blink

CatPose.NEAR = 30 -- studs: full update rate inside, half rate past it
CatPose.FAR = 60 -- studs: no motion past it (the cat is put back at rest)
CatPose.MAX_CATS = { low = 4, high = 10 }
CatPose.STEP = { low = 1 / 30, high = 1 / 60 }

export type Pose = {
	headPitch: number,
	headYaw: number,
	headRoll: number,
	tailPitch: number,
	tailYaw: number,
	earL: number,
	earR: number,
	blink: number, -- 0 open, 1 fully shut
}

export type State = {
	seed: number, -- per cat, so cats in a row do not move in step
	blinkAt: number, -- when the current or next blink starts
	blinkCount: number,
	twitchAt: number,
	twitchCount: number,
	shakeAt: number, -- -math.huge when none has played
	wiggleAt: number,
}

local TAU = 2 * math.pi

-- Which rig joint an instance name is: the plain name ("Head", as on placeholders) or the asset prefix form
-- ("CleanACat_Cat_Cotton_Head", as Model-Agent's generator names them). Nil for anything else (mud, tangles, parts).
function CatPose.jointKey(name: string): string?
	for _, key in CatPose.JOINTS do
		if name == key or string.sub(name, -(#key + 1)) == "_" .. key then
			return key
		end
	end
	return nil
end

-- A repeatable number in [0, 1) from a seed and a counter, so the schedule needs no Random object and has specs.
function CatPose.hash(seed: number, n: number): number
	local x = math.sin(seed * 12.9898 + n * 78.233) * 43758.5453
	return x - math.floor(x)
end

function CatPose.gap(range: { number }, seed: number, n: number): number
	return range[1] + (range[2] - range[1]) * CatPose.hash(seed, n)
end

function CatPose.newPose(): Pose
	return {
		headPitch = 0,
		headYaw = 0,
		headRoll = 0,
		tailPitch = 0,
		tailYaw = 0,
		earL = 0,
		earR = 0,
		blink = 0,
	}
end

function CatPose.newState(seed: number, now: number): State
	return {
		seed = seed,
		blinkAt = now + CatPose.gap(CatPose.BLINK_GAP, seed, 0),
		blinkCount = 0,
		twitchAt = now + CatPose.gap(CatPose.TWITCH_GAP, seed + 0.5, 0),
		twitchCount = 0,
		shakeAt = -math.huge,
		wiggleAt = -math.huge,
	}
end

-- A 0 -> 1 -> 0 hump over `length` seconds, 0 outside it.
function CatPose.hump(elapsed: number, length: number): number
	if elapsed < 0 or elapsed >= length then
		return 0
	end
	return math.sin(math.pi * elapsed / length)
end

-- A decaying wobble: `cycles` full swings over `length`, amplitude falling to zero at the end.
function CatPose.wobble(elapsed: number, length: number, cycles: number): number
	if elapsed < 0 or elapsed >= length then
		return 0
	end
	local u = elapsed / length
	return math.sin(TAU * cycles * u) * (1 - u)
end

-- Is a motion still playing? Lets CatMotion keep a cat at full rate during a shake.
function CatPose.busy(state: State, now: number): boolean
	return now - state.shakeAt < CatPose.SHAKE_SECONDS
		or now - state.wiggleAt < CatPose.WIGGLE_SECONDS
end

-- Fill `pose` for time `now`. Moves the blink and twitch schedules on when one ends. No allocation.
function CatPose.sample(pose: Pose, state: State, now: number, reducedMotion: boolean)
	local phase = state.seed * TAU

	-- Idle: a slow breath (about 3.2 s) nods the head, the tail sways on its own slower beat.
	if reducedMotion then
		pose.headPitch = 0
		pose.headYaw = 0
		pose.headRoll = 0
		pose.tailPitch = 0
		pose.tailYaw = 0
	else
		pose.headPitch = math.rad(2) * math.sin(TAU * now / 3.2 + phase)
		pose.headYaw = math.rad(3) * math.sin(TAU * now / 7.1 + phase * 0.7)
		pose.headRoll = 0
		pose.tailPitch = math.rad(4) * math.sin(TAU * now / 3.2 + phase + 0.6)
		pose.tailYaw = math.rad(14) * math.sin(TAU * now / 2.6 + phase)
	end
	pose.earL = 0
	pose.earR = 0

	-- Blink, kept with Reduce Motion.
	while now >= state.blinkAt + CatPose.BLINK_SECONDS do
		state.blinkCount += 1
		state.blinkAt += CatPose.BLINK_SECONDS + CatPose.gap(
			CatPose.BLINK_GAP,
			state.seed,
			state.blinkCount
		)
	end
	pose.blink = CatPose.hump(now - state.blinkAt, CatPose.BLINK_SECONDS)

	-- Ear twitch: one ear, picked by the schedule.
	while now >= state.twitchAt + CatPose.TWITCH_SECONDS do
		state.twitchCount += 1
		state.twitchAt += CatPose.TWITCH_SECONDS + CatPose.gap(
			CatPose.TWITCH_GAP,
			state.seed + 0.5,
			state.twitchCount
		)
	end
	if not reducedMotion then
		local flick = math.rad(18)
			* CatPose.wobble(now - state.twitchAt, CatPose.TWITCH_SECONDS, 1.5)
		if CatPose.hash(state.seed, state.twitchCount + 100) < 0.5 then
			pose.earL = flick
		else
			pose.earR = -flick
		end
	end

	if reducedMotion then
		return
	end

	-- Shake-off: a fast head roll and tail whip that die away.
	local shake = now - state.shakeAt
	if shake < CatPose.SHAKE_SECONDS then
		pose.headRoll += math.rad(22) * CatPose.wobble(shake, CatPose.SHAKE_SECONDS, 4)
		pose.tailYaw += math.rad(30) * CatPose.wobble(shake, CatPose.SHAKE_SECONDS, 4)
		local ears = math.rad(15) * CatPose.hump(shake, CatPose.SHAKE_SECONDS)
		pose.earL += ears
		pose.earR -= ears
	end

	-- Happy wiggle: tail wags, ears perk forward, head tilts once.
	local wiggle = now - state.wiggleAt
	if wiggle < CatPose.WIGGLE_SECONDS then
		pose.tailYaw += math.rad(25) * CatPose.wobble(wiggle, CatPose.WIGGLE_SECONDS, 3)
		pose.tailPitch += math.rad(20) * CatPose.hump(wiggle, CatPose.WIGGLE_SECONDS)
		pose.headRoll += math.rad(10) * CatPose.hump(wiggle, CatPose.WIGGLE_SECONDS)
		local ears = math.rad(12) * CatPose.wobble(wiggle, CatPose.WIGGLE_SECONDS, 2)
		pose.earL += ears
		pose.earR -= ears
	end
end

-- Mood (issue #528). Signs follow the rig's axes (cats.py and rbx_export.py: EarL on the cat's left at +X, the cat
-- facing -Z, the tail out behind at +Z): a negative tail pitch lifts the tail, a negative earL and a positive earR
-- tip the ears out to the side, a negative head pitch lowers the head.
CatPose.MOOD = table.freeze({
	happyFrom = 0.45, -- the bar's fill where happy starts to show
	happyFull = 0.65,
	grumpyFrom = 0.5, -- grumpy grows below this
	grumpyFull = 0.3,
	goneFrom = 0.1, -- the leaving pose grows below this, full at 0
	tailUp = math.rad(14),
	happySway = 0.35, -- happy: this much more tail sway
	grumpyEars = math.rad(22),
	grumpyHead = math.rad(5),
	lash = math.rad(20), -- the grumpy tail lash, each way
	lashEvery = 1.6, -- seconds between lashes
	lashSeconds = 0.5,
	goneEars = math.rad(34),
	goneHead = math.rad(10),
	goneTail = math.rad(12), -- down
})

local function smooth(from: number, to: number, x: number): number
	local u = math.clamp((x - from) / (to - from), 0, 1)
	return u * u * (3 - 2 * u)
end

-- The three mood weights for a heart bar at `fill` (0 to 1), each 0 to 1: happy, grumpy, gone. Grumpy and gone do
-- not add up: gone takes over from grumpy as the bar empties.
function CatPose.mood(fill: number): (number, number, number)
	local m = CatPose.MOOD
	local f = math.clamp(fill, 0, 1)
	local happy = smooth(m.happyFrom, m.happyFull, f)
	local gone = 1 - smooth(0, m.goneFrom, f)
	local grumpy = smooth(m.grumpyFrom, m.grumpyFull, f) * (1 - gone)
	return happy, grumpy, gone
end

-- Adds the mood for a heart bar at `fill` on top of a sampled pose. Call after CatPose.sample.
function CatPose.applyMood(
	pose: Pose,
	state: State,
	now: number,
	fill: number,
	reducedMotion: boolean
)
	local m = CatPose.MOOD
	local happy, grumpy, gone = CatPose.mood(fill)
	pose.tailPitch += -m.tailUp * happy + m.tailUp * 0.5 * grumpy + m.goneTail * gone
	pose.tailYaw *= (1 + m.happySway * happy) * (1 - 0.6 * grumpy) * (1 - 0.85 * gone)
	local ears = m.grumpyEars * grumpy + m.goneEars * gone
	pose.earL -= ears
	pose.earR += ears
	pose.headPitch -= m.grumpyHead * grumpy + m.goneHead * gone
	if not reducedMotion and grumpy > 0 then
		local into = (now + state.seed * m.lashEvery) % m.lashEvery
		pose.tailYaw += m.lash * grumpy * CatPose.wobble(into, m.lashSeconds, 1.5)
	end
end

function CatPose.baseStep(tier: "low" | "high"): number
	return if tier == "low" then CatPose.STEP.low else CatPose.STEP.high
end

function CatPose.maxCats(tier: "low" | "high"): number
	return if tier == "low" then CatPose.MAX_CATS.low else CatPose.MAX_CATS.high
end

-- Seconds between updates for a cat at `distance` studs, or nil when it should not move at all.
function CatPose.step(distance: number, tier: "low" | "high"): number?
	if distance > CatPose.FAR then
		return nil
	end
	local step = CatPose.baseStep(tier)
	if distance > CatPose.NEAR then
		step *= 2
	end
	return step
end

return CatPose
