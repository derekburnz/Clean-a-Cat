--!strict
-- StaffPose: pure curves for the spa staff at work (issue #528: "worker wash loop"). Model-Agent's staff
-- (CleanACat_NPC_Staff_Jo, _Sam, _Lou) have the townsfolk's five joints, each turned about its own X; both arms hang
-- straight (CarryArmDegrees 0). A positive turn about X swings an arm forward, a negative head pitch looks down.
--
-- While a worker washes (Gameplay sets the Washing attribute on the staff model, with workers in #509) both arms
-- reach forward over the cat and rub in turn, a soft scrub, with the head bent to look at the work and a small nod in
-- time. It blends in and out over about half a second, and only while standing: a walking worker walks. Reduced
-- Motion keeps the reach and the look but drops the rubbing.
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

return StaffPose
