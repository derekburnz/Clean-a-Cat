--!strict
-- CustomerPose: pure curves for the customers' walk in and idle (Derek, 2026-11-25: what bothers him most is the
-- customers' "look/walk in"). Model-Agent's townsfolk (CleanACat_NPC_Customer_*, PR 460) have five joints, each a
-- child Model pivoted at the joint and turned about its own X: _Head (neck), _ArmL and _ArmR (shoulder), _LegL and
-- _LegR (hip). No knees. The right arm holds the carrier, so it barely moves.
-- CustomerMotion finds the joints and writes the pose; everything here is numbers, for the specs.
local CustomerPose = {}

CustomerPose.JOINTS = table.freeze({ "Body", "Head", "ArmL", "ArmR", "LegL", "LegR" })
CustomerPose.LEG_SWING = math.rad(26) -- each way, Model-Agent's test pose
CustomerPose.ARM_SWING = math.rad(22) -- the free (left) arm, each way
CustomerPose.CARRY_SWAY = math.rad(2) -- the carrying arm: a hint of sway, so the carrier stays clear of the hips
CustomerPose.HEAD_BOB = math.rad(2.5) -- a small nod on each footfall
CustomerPose.WALK_FROM = 0.4 -- studs a second: slower than this is standing
CustomerPose.WALK_FULL = 2.5 -- studs a second: the full swing from here up
CustomerPose.LOOK = math.rad(16) -- the idle look round, each way
CustomerPose.NOD = math.rad(9) -- the idle nod

export type Pose = {
	legL: number,
	legR: number,
	armL: number,
	armR: number,
	headPitch: number,
	headYaw: number,
}

function CustomerPose.newPose(): Pose
	return { legL = 0, legR = 0, armL = 0, armR = 0, headPitch = 0, headYaw = 0 }
end

-- A child's name to its joint key: "Body" or "<Model>_Body", and so on; nil for anything else.
function CustomerPose.jointKey(name: string): string?
	for _, key in CustomerPose.JOINTS do
		if name == key or string.sub(name, -(#key + 1)) == "_" .. key then
			return key
		end
	end
	return nil
end

-- How far one step carries the body: the foot swings `swing` each way from a hip `legLength` over the floor.
function CustomerPose.stride(legLength: number, swing: number): number
	return 2 * legLength * math.sin(swing)
end

-- Walk cycles a second at `speed` so the feet do not slide: one cycle is two steps.
function CustomerPose.cadence(speed: number, legLength: number, swing: number): number
	local stride = CustomerPose.stride(legLength, swing)
	if stride <= 1e-3 then
		return 0
	end
	return speed / (2 * stride)
end

-- 0 standing, 1 walking: eases the swing in from WALK_FROM to WALK_FULL studs a second.
function CustomerPose.walkAmount(speed: number): number
	local u = math.clamp(
		(speed - CustomerPose.WALK_FROM) / (CustomerPose.WALK_FULL - CustomerPose.WALK_FROM),
		0,
		1
	)
	return u * u * (3 - 2 * u)
end

-- Moves `current` toward `target` at a rate of `k` a second (frame-rate independent).
function CustomerPose.approach(current: number, target: number, k: number, dt: number): number
	return target + (current - target) * math.exp(-k * dt)
end

-- The idle at time `t` (seconds) for a customer with `seed` in [0, 1): a slow look round and now and then a nod.
-- Each customer's seed puts them out of step with the others. `still` (reduced motion) holds the head.
function CustomerPose.idle(t: number, seed: number, still: boolean): (number, number)
	if still then
		return 0, 0
	end
	local yaw = CustomerPose.LOOK
		* math.sin(t * 0.55 + seed * 6.28)
		* math.sin(t * 0.21 + seed * 3.1)
	local beat = math.max(0, math.sin(t * 0.8 + seed * 9.4))
	local pitch = CustomerPose.NOD * beat ^ 6 -- mostly 0, a short nod on each peak
	return pitch, yaw
end

-- Fills `pose` for walk phase `phase` (cycles), walk amount `amount` (0 to 1) and the idle head (`pitch`, `yaw`),
-- which fades out as the walk takes over. The left arm swings with the right leg, as people walk.
function CustomerPose.sample(pose: Pose, phase: number, amount: number, pitch: number, yaw: number)
	local s = math.sin(2 * math.pi * phase)
	pose.legL = CustomerPose.LEG_SWING * amount * s
	pose.legR = -pose.legL
	pose.armL = -CustomerPose.ARM_SWING * amount * s
	pose.armR = CustomerPose.CARRY_SWAY * amount * s
	local idle = 1 - amount
	pose.headPitch = pitch * idle
		+ CustomerPose.HEAD_BOB * amount * math.abs(math.sin(2 * math.pi * phase))
	pose.headYaw = yaw * idle
end

return CustomerPose
