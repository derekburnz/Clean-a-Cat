--!strict
-- StaffPose: pure curves for the spa staff at work (issue #528: "worker wash loop"). Model-Agent's staff
-- (CleanACat_NPC_Staff_Jo, _Sam, _Lou) have the townsfolk's five joints, each turned about its own X; both arms hang
-- straight (CarryArmDegrees 0). A positive turn about X swings an arm forward, a negative head pitch looks down.
--
-- While a worker washes (Gameplay sets the Washing attribute on the staff model, with workers in #509) both arms
-- reach forward over the cat and rub in turn, a soft scrub, with the head bent to look at the work and a small nod in
-- time. It blends in and out over about half a second, and only while standing: a walking worker walks. Reduced
-- Motion keeps the reach and the look but drops the rubbing.
--
-- A helper carrying a cat to or from the counter (Gameplay's helperFetch, issue 884) holds both arms forward under it
-- and looks down at it a little (StaffPose.carry). The builder by the builder board (Model-Agent's CleanACat_NPC_Builder,
-- switch humanBuilder, issue 891) hammers while a build runs (StaffPose.hammer): the right arm, with the hammer, lifts
-- slowly and strikes quickly, the left arm steadies the work and the head looks down at it.
-- CustomerMotion finds the joints and writes the pose; everything here is numbers, for the specs.
local StaffPose = {}

StaffPose.REACH = math.rad(58) -- both arms forward, over the cat on the stand
StaffPose.RUB = math.rad(9) -- each way, the arms in turn
StaffPose.RUB_HZ = 1.6 -- rubs a second: unhurried, cosy
StaffPose.LOOK_DOWN = math.rad(14)
StaffPose.NOD = math.rad(2.5)
StaffPose.BLEND = 7 -- how fast the wash pose comes and goes, per second

type Pose = {
	legL: number,
	legR: number,
	armL: number,
	armR: number,
	headPitch: number,
	headYaw: number,
}

-- The staff's walk: both arms are free, so the right one swings against the left, as people walk.
function StaffPose.freeArms(pose: Pose)
	pose.armR = -pose.armL
end

-- Lays the wash pose over `pose` by `amount` (0 to 1, the blend times how much the worker is standing still).
function StaffPose.scrub(pose: Pose, now: number, seed: number, amount: number, still: boolean)
	local a = math.clamp(amount, 0, 1)
	if a <= 0 then
		return
	end
	local rub = if still then 0 else math.sin(2 * math.pi * (StaffPose.RUB_HZ * now + seed))
	local function mix(from: number, to: number): number
		return from + (to - from) * a
	end
	pose.armL = mix(pose.armL, StaffPose.REACH + StaffPose.RUB * rub)
	pose.armR = mix(pose.armR, StaffPose.REACH - StaffPose.RUB * rub)
	local nod = StaffPose.NOD * math.abs(rub)
	pose.headPitch = mix(pose.headPitch, -StaffPose.LOOK_DOWN - nod)
	pose.headYaw = mix(pose.headYaw, 0)
end

StaffPose.CARRY = math.rad(62) -- both arms forward under the cat
StaffPose.CARRY_LOOK = math.rad(8)

-- Lays the carry pose over `pose` by `amount` (0 to 1). It holds steady at a walk too, since the arms hold the cat.
function StaffPose.carry(pose: Pose, amount: number)
	local a = math.clamp(amount, 0, 1)
	if a <= 0 then
		return
	end
	pose.armL += (StaffPose.CARRY - pose.armL) * a
	pose.armR += (StaffPose.CARRY - pose.armR) * a
	pose.headPitch += (-StaffPose.CARRY_LOOK - pose.headPitch) * a
end

StaffPose.HAMMER_HZ = 1.3 -- strikes a second
StaffPose.HAMMER_UP = math.rad(115) -- the right arm at the top of the lift
StaffPose.HAMMER_DOWN = math.rad(50) -- where the hammer meets the work
StaffPose.HAMMER_STRIKE = 0.25 -- share of a cycle the strike takes; the lift takes the rest
StaffPose.STEADY = math.rad(40) -- the left arm, holding the work
StaffPose.HAMMER_LOOK = math.rad(18)

-- How high the hammer is at cycle phase `u` (0 to 1): 0 on the work, 1 at the top. It lifts with an ease out over
-- most of the cycle, then drops fast and lands at the end.
function StaffPose.hammerLift(u: number): number
	local k = u % 1
	local lift = 1 - StaffPose.HAMMER_STRIKE
	if k < lift then
		local t = k / lift
		return 1 - (1 - t) * (1 - t)
	end
	local t = (k - lift) / StaffPose.HAMMER_STRIKE
	return 1 - t * t
end

-- Lays the hammering pose over `pose` by `amount`. Reduced Motion holds the hammer still, halfway up.
function StaffPose.hammer(pose: Pose, now: number, seed: number, amount: number, still: boolean)
	local a = math.clamp(amount, 0, 1)
	if a <= 0 then
		return
	end
	local h = if still then 0.5 else StaffPose.hammerLift(StaffPose.HAMMER_HZ * now + seed)
	local arm = StaffPose.HAMMER_DOWN + (StaffPose.HAMMER_UP - StaffPose.HAMMER_DOWN) * h
	pose.armR += (arm - pose.armR) * a
	pose.armL += (StaffPose.STEADY - pose.armL) * a
	pose.headPitch += (-StaffPose.HAMMER_LOOK - pose.headPitch) * a
	pose.headYaw += (0 - pose.headYaw) * a
end

return StaffPose
