--!strict
-- StaffCarry: a helper carries a customer's cat lying in their arms, the way the player carries Suds (issue 1138,
-- Derek 2026-11-27: "make sure helpers have the proper holding animation with customers cats loafing the and not
-- hovering in between hands"). Client only and cosmetic, like every Effect.
--
-- Gameplay's HelperFetchController walks the helper and makes the held copy (a CleanACat_Cat_<Kind>_Dirty_Loaf on the
-- fetch, _Loaf on the walk back, under the switch loafCarry; a sitting body when a kind has no loaf). Each frame it
-- calls StaffCarry.place, which lays the cat across the forearms as CustomerMotion holds them (StaffPose.carry), on
-- the arms' top surface where the cat lies, so nothing floats and nothing sinks into the arms. A loaf lies across the
-- arms with its back to the chest and its head end at the helper's left, as Carry's loaf does for the player (R6 too,
-- the staff arms are straight blocks like R6's); a sitting cat sits on them facing out.
--
-- API
--   StaffCarry.place(staff, cat, loaf) -> boolean   puts `cat` in `staff`'s arms; false (nothing moved) when the staff
--                                                    has no rig with hands here, so the caller keeps its own spot
--   StaffCarry.spot(arms, chestDepth, catSize, loaf) -> Vector3   where the middle of the cat's base goes, in the
--                                                    Body part's upright frame (pure, for the specs)
local CustomerMotion = require(script.Parent:WaitForChild("CustomerMotion"))

local StaffCarry = {}

StaffCarry.ARM_HALF = 0.22 -- studs from an arm's middle line to its top surface (the staff's 0.42 to 0.47 arm blocks)
StaffCarry.GAP = 0.02 -- the cat's base this far over the arms' top: resting on them
StaffCarry.OUT = 0.3 -- a loaf this far out past the hug, where the straight arms are lower (Carry's loafOut6, R6)
StaffCarry.SIDE = -0.2 -- a loaf a touch left, its head past the left arm (Carry's loafSide)
StaffCarry.TURN = 90 -- degrees: a loaf lies across the arms (Carry's loafTurn)
StaffCarry.ROLL = 5 -- degrees: the head end rolled up a little (Carry's loafRoll)
StaffCarry.SIT_BACK = 0.3 -- a sitting cat this far back from the hands toward the chest (Carry's forward)

-- The top of the arm from `shoulder` to `hand` over depth `z` (-Z is in front), clamped to the arm's length.
local function armTop(shoulder: Vector3, hand: Vector3, z: number): number
	local dz = hand.Z - shoulder.Z
	local t = if math.abs(dz) < 1e-6 then 1 else math.clamp((z - shoulder.Z) / dz, 0, 1)
	return shoulder.Y + (hand.Y - shoulder.Y) * t + StaffCarry.ARM_HALF
end

function StaffCarry.spot(
	arms: { Vector3 },
	chestDepth: number,
	catSize: Vector3,
	loaf: boolean
): Vector3
	local shoulderL, handL, shoulderR, handR = arms[1], arms[2], arms[3], arms[4]
	local x = (handL.X + handR.X) / 2 + (if loaf then StaffCarry.SIDE else 0)
	local z: number
	if loaf then
		-- its back pressed to the chest (its width faces the chest after the turn), then out where the arms are lower
		z = -(chestDepth / 2 + catSize.X / 2 + 0.05) - StaffCarry.OUT
	else
		z = math.min(
			(handL.Z + handR.Z) / 2 + StaffCarry.SIT_BACK,
			-(chestDepth / 2 + catSize.Z / 2 + 0.05)
		)
	end
	-- never past the hands: the cat stays on the arms
	z = math.max(z, math.min(handL.Z, handR.Z))
	local y = math.max(armTop(shoulderL, handL, z), armTop(shoulderR, handR, z)) + StaffCarry.GAP
	return Vector3.new(x, y, z)
end

-- The cat's pivot from the middle of its base, measured once per copy (a copy keeps its scale while held).
local offsets: { [Model]: { offset: CFrame, size: Vector3 } } = setmetatable({}, { __mode = "k" }) :: any

local function measure(cat: Model): { offset: CFrame, size: Vector3 }
	local found = offsets[cat]
	if found == nil then
		local box, size = cat:GetBoundingBox()
		local base = box * CFrame.new(0, -size.Y / 2, 0)
		local made = { offset = base:ToObjectSpace(cat:GetPivot()), size = size }
		offsets[cat] = made
		return made
	end
	return found
end

function StaffCarry.place(staff: Model, cat: Model, loaf: boolean): boolean
	local base, arms = CustomerMotion.carryArms(staff)
	if base == nil or arms == nil then
		return false
	end
	local body = staff.PrimaryPart
	local chestDepth = if body then body.Size.Z else 0.8
	local m = measure(cat)
	-- the box was measured as built, before any turn, so its size is the cat's own
	local at = StaffCarry.spot(arms, chestDepth, m.size, loaf)
	local frame = (base :: CFrame) * CFrame.new(at)
	if loaf then
		frame = frame
			* CFrame.Angles(0, math.rad(StaffCarry.TURN), 0)
			* CFrame.Angles(math.rad(StaffCarry.ROLL), 0, 0)
	end
	cat:PivotTo(frame * m.offset)
	return true
end

return StaffCarry
