--!strict
-- Carry: the player picks a cat up and holds it in folded arms, then sets it down somewhere (Derek 2026-11-24: "we
-- should pick him up out of crate"). Ported from Derek's Roblox-Asset-Library (effects/luau-effects Carry.luau,
-- Avatar.carryArms, Avatar.cradle and Presets.carryPose); the numbers are the library's, which Derek tuned in play.
--
-- Client only and cosmetic, like every Effect: the arms are joint Transforms written after the Animator each frame
-- (PreSimulation), which never replicate, so only this player sees their own arms fold; the cat is a client-only
-- model the caller made (the opening's kitten). What is carried, and when, is Gameplay's (the carry state); this
-- module only draws it. The legs, hips and root stay the character's own, so they keep walking under the cat.
--
-- API
--   Carry.hold(character, cat) -> Handle
--       folds the arms over FOLD_SECONDS and lifts `cat` from where it is onto them, with a purr that loops while
--       it is held. The cat follows the arms every frame until placeIn.
--   handle.placeIn(target, onDone?)   the arms open and the cat hops off them, landing with its base on `target`
--                                     (a world point, e.g. the tub's seat); onDone once it lands
--   handle.destroy()                  lets go at once: the arms go back to the character's own, the purr stops
--   onDone fires exactly once, deferred, also when placeIn is called twice or the handle is destroyed first.
--   Reduced Motion (or Less screen shake): no arc on the lift or the hop, so nothing bounces; the arms still fold.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Audio = require(script.Parent.Parent:WaitForChild("Audio"))
local Effects = require(script.Parent)
local TruckDrop = require(script.Parent:WaitForChild("TruckDrop"))

local Carry = {}

-- Degrees about each joint, in the character's axes (it faces -Z, +X is its right): sh raises an arm forward, sp
-- swings it out to the side (negative: in), tw turns the upper arm in about its length, el bends the elbow. arms6 is
-- the R6 hold (no elbows).
--
-- POSE is Derek's hold (his clip, 2026-11-24: "here is how the carrying should look"): upper arms down at the sides,
-- elbows bent to a right angle so both forearms point straight ahead at belly height, a little in toward each
-- other, head up, and the cat sitting on the forearms in front of the belly. On R6 both straight arms reach forward
-- level-ish and in. Behind the switch `carryHold` (dev first; Studio always uses it) until Derek confirms it.
Carry.POSE = table.freeze({
	arms = table.freeze({
		shL = 12,
		shR = 12,
		spL = -8,
		spR = -8,
		twL = 10,
		twR = 10,
		elL = 88,
		elR = 88,
		neck = 0,
		waist = 0,
	} :: { [string]: number }),
	arms6 = table.freeze(
		{ shL = 75, shR = 75, spL = -18, spR = -18, neck = 0 } :: { [string]: number }
	),
	gap = -0.1, -- the cat's base this far above the higher forearm's top
	forward = -0.35, -- and this far ahead of the forearms' middles (-Z is ahead), over the hands
	sitTurn = 0, -- facing straight out
	sitSide = 0,
})

Carry.HOLD_FLAG = "carryHold"

-- The first hold (Presets.carryPose from Derek's library): arms crossed over the chest, head tipped down. Live keeps
-- it until `carryHold` is on.
Carry.CROSSED = table.freeze({
	arms = table.freeze({
		shL = 25,
		twL = 25,
		spL = -35,
		elL = 30,
		shR = 25,
		twR = 25,
		spR = -35,
		elR = 35,
		neck = -12,
		waist = -4,
	} :: { [string]: number }),
	arms6 = table.freeze(
		{ shL = 65, shR = 65, spL = -35, spR = -35, neck = -12 } :: { [string]: number }
	),
	gap = -0.15, -- the cat's base this far above the higher forearm's top
	forward = -0.6, -- and this far ahead of the forearms (a sit; -Z is ahead)
	sitTurn = 15, -- degrees the sitting cat turns to the character's left, so its face shows past the chest
	sitSide = -0.55, -- studs to the character's left
})

Carry.FOLD_SECONDS = 0.3 -- the arms fold and the cat rises onto them (Derek's ask, about 0.3 s)
Carry.OPEN_SECONDS = 0.25 -- the arms open as the cat hops off
Carry.LIFT_ARC = 0.6 -- studs the cat rises above the straight line on the way up into the arms
Carry.HOP_SECONDS = TruckDrop.HOP.seconds
Carry.HOP_HEIGHT = 1.2 -- the hop off the arms into the tub, at its top

local FIELDS = { "shL", "shR", "spL", "spR", "twL", "twR", "elL", "elR", "neck", "waist" }

export type Pose = { [string]: number }
export type Handle = {
	placeIn: (target: Vector3, onDone: (() -> ())?) -> (),
	destroy: () -> (),
}

-- A full upper-body pose from a spec: every field, 0 where the spec leaves it out.
function Carry.pose(spec: { [string]: number }): Pose
	local out: Pose = {}
	for _, name in FIELDS do
		out[name] = spec[name] or 0
	end
	return out
end

-- The fold's weight `dt` seconds on, easing toward 1 while held and back to 0 while not.
function Carry.weight(weight: number, holding: boolean, dt: number): number
	if holding then
		return math.min(1, weight + dt / Carry.FOLD_SECONDS)
	end
	return math.max(0, weight - dt / Carry.OPEN_SECONDS)
end

-- Smoothstep, so the lift starts and ends gently.
function Carry.ease(u: number): number
	local k = math.clamp(u, 0, 1)
	return k * k * (3 - 2 * k)
end

-- The lift into the arms at `elapsed`: how far along (0 to 1) and how high above the straight line.
function Carry.lift(elapsed: number, reduced: boolean): (number, number)
	local u = math.clamp(elapsed / Carry.FOLD_SECONDS, 0, 1)
	local arc = if reduced then 0 else Carry.LIFT_ARC * 4 * u * (1 - u)
	return Carry.ease(u), arc
end

-- The hop off the arms at `elapsed`: how far along (0 to 1) and how high above the straight line.
function Carry.hop(elapsed: number, reduced: boolean): (number, number)
	local u = math.clamp(elapsed / Carry.HOP_SECONDS, 0, 1)
	local arc = if reduced then 0 else Carry.HOP_HEIGHT * 4 * u * (1 - u)
	return Carry.ease(u), arc
end

-- Joints by the parts each joins (parent, child), as the library finds them: rigs name their joints differently.
local R15: { [string]: { string } } = {
	Waist = { "LowerTorso", "UpperTorso" },
	Neck = { "UpperTorso", "Head" },
	LeftShoulder = { "UpperTorso", "LeftUpperArm" },
	RightShoulder = { "UpperTorso", "RightUpperArm" },
	LeftElbow = { "LeftUpperArm", "LeftLowerArm" },
	RightElbow = { "RightUpperArm", "RightLowerArm" },
	LeftWrist = { "LeftLowerArm", "LeftHand" },
	RightWrist = { "RightLowerArm", "RightHand" },
}
local R6: { [string]: { string } } = {
	Neck = { "Torso", "Head" },
	LeftShoulder = { "Torso", "Left Arm" },
	RightShoulder = { "Torso", "Right Arm" },
}

type Joint = Motor6D | AnimationConstraint
export type Hold = typeof(Carry.POSE)

type Rig = {
	joints: { [string]: Joint },
	axes: { [string]: CFrame }, -- each joint's frame in its parent part, turned only
	parts: { [string]: BasePart }, -- the part each joint moves
	chest: BasePart,
	r15: boolean,
	hold: Hold, -- the pose set this carry uses (POSE or CROSSED)
}

local function jointParts(joint: Instance): (BasePart?, BasePart?, CFrame)
	if joint:IsA("Motor6D") then
		local motor = joint :: Motor6D
		return motor.Part0, motor.Part1, motor.C0
	elseif joint:IsA("AnimationConstraint") then
		local constraint = joint :: AnimationConstraint
		local a0, a1 = constraint.Attachment0, constraint.Attachment1
		if a0 and a1 then
			local p0, p1 = a0.Parent, a1.Parent
			if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
				return p0 :: BasePart, p1 :: BasePart, a0.CFrame
			end
		end
	end
	return nil, nil, CFrame.identity
end

local function bind(character: Model, hold: Hold): Rig?
	local r15 = character:FindFirstChild("UpperTorso") ~= nil
	local names: { [string]: { string } } = if r15 then R15 else R6
	local joints: { [string]: Joint } = {}
	local axes: { [string]: CFrame } = {}
	local parts: { [string]: BasePart } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			local p0, p1, c0 = jointParts(d)
			if p0 and p1 then
				for name, pair in names do
					-- an AnimationConstraint wins over a Motor6D left beside it, as in the library
					if
						p0.Name == pair[1]
						and p1.Name == pair[2]
						and (joints[name] == nil or d:IsA("AnimationConstraint"))
					then
						joints[name] = (d :: any) :: Joint
						axes[name] = c0.Rotation
						parts[name] = p1
					end
				end
			end
		end
	end
	local chest = character:FindFirstChild(if r15 then "UpperTorso" else "Torso")
	if
		chest == nil
		or not chest:IsA("BasePart")
		or joints.LeftShoulder == nil
		or joints.RightShoulder == nil
	then
		return nil
	end
	return {
		joints = joints,
		axes = axes,
		parts = parts,
		chest = chest :: BasePart,
		r15 = r15,
		hold = hold,
	}
end

-- The folded arms' Transforms (Avatar.carryArms): waist, neck, shoulders and elbows, wrists straight.
local function armFrames(rig: Rig): { [Joint]: CFrame }
	local out: { [Joint]: CFrame } = {}
	local function set(name: string, frame: CFrame)
		local joint = rig.joints[name]
		local axes = rig.axes[name]
		if joint and axes then
			out[joint] = axes:Inverse() * frame * axes
		end
	end
	local hold = rig.hold
	local p = Carry.pose(if rig.r15 then hold.arms else hold.arms6)
	local rad = math.rad
	set("Waist", CFrame.Angles(rad(-p.waist), 0, 0))
	set("Neck", CFrame.Angles(rad(p.neck), 0, 0))
	set("LeftShoulder", CFrame.Angles(rad(p.shL), rad(-p.twL), rad(-p.spL)))
	set("RightShoulder", CFrame.Angles(rad(p.shR), rad(p.twR), rad(p.spR)))
	set("LeftElbow", CFrame.Angles(rad(p.elL), 0, 0))
	set("RightElbow", CFrame.Angles(rad(p.elR), 0, 0))
	set("LeftWrist", CFrame.identity)
	set("RightWrist", CFrame.identity)
	return out
end

-- Where the sitting cat's base goes this frame (Avatar.cradle): on top of the higher forearm, ahead of halfway
-- between the two, level with the chest, turned a little to show its face. nil without arms.
local function cradle(rig: Rig): CFrame?
	local left: BasePart? = rig.parts.LeftElbow or rig.parts.LeftShoulder
	local right: BasePart? = rig.parts.RightElbow or rig.parts.RightShoulder
	if left == nil or right == nil then
		return nil
	end
	local torso = rig.chest.CFrame
	local function top(arm: BasePart): Vector3
		local frame = torso:ToObjectSpace(arm.CFrame)
		local _, _, _, _, _, _, r10, r11, r12 = frame:GetComponents()
		local s = arm.Size
		return frame.Position
			+ Vector3.yAxis
				* 0.5
				* (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z)
	end
	local a, b = top(left :: BasePart), top(right :: BasePart)
	local c = rig.hold
	local spot = Vector3.new(
		(a.X + b.X) / 2 + c.sitSide,
		math.max(a.Y, b.Y) + c.gap,
		(a.Z + b.Z) / 2 + c.forward
	)
	return torso * CFrame.new(spot) * CFrame.Angles(0, math.rad(c.sitTurn), 0)
end

-- The cat's pivot relative to the middle of its base, so the base sits where cradle() or a target says.
local function baseOffset(cat: Model): CFrame
	local boxCF, size = cat:GetBoundingBox()
	local base = boxCF * CFrame.new(0, -size.Y / 2, 0)
	local pivot: CFrame = cat:GetPivot()
	local offset: CFrame = base:Inverse() * pivot
	return offset
end

local function ownPart(cat: Model): Instance?
	return cat.PrimaryPart or cat:FindFirstChildWhichIsA("BasePart", true)
end

-- Derek's hold when its switch is on, and always in Studio (the dev copy); else the first, crossed hold. A missing
-- switch module keeps the crossed one.
function Carry.chooseHold(switchOn: boolean, studio: boolean): Hold
	return if switchOn or studio then Carry.POSE else Carry.CROSSED
end

function Carry.holdPose(): Hold
	local on = false
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("LiveFlags")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(function(): boolean
			return (require(module) :: any).isOn(Carry.HOLD_FLAG) == true
		end)
		on = ok and result == true
	end
	return Carry.chooseHold(on, RunService:IsStudio())
end

function Carry.hold(character: Model, cat: Model): Handle
	local reduced = Effects.reducedMotion()
	local rig = bind(character, Carry.holdPose())
	local offset = baseOffset(cat)
	local from = cat:GetPivot()
	local started = os.clock()
	local weight = 0
	local holding = true
	local written: { [Joint]: CFrame } = {}
	local destroyed = false
	local purr = Audio.loop("carryPurr", ownPart(cat))
	local hop: { start: number, from: CFrame, to: Vector3, onDone: (() -> ())? }? = nil
	local connection: RBXScriptConnection? = nil

	local function writeArms(dt: number)
		weight = Carry.weight(weight, holding, dt)
		if rig == nil then
			return
		end
		local frames = armFrames(rig)
		for joint, frame in frames do
			local j = joint :: any
			if weight <= 0 then
				-- let go: put back only what this wrote and the Animator has not since replaced
				local mine = written[joint]
				if mine and (j.Transform :: CFrame):FuzzyEq(mine, 1e-4) then
					j.Transform = CFrame.identity
				end
				written[joint] = nil
			else
				local out = (j.Transform :: CFrame):Lerp(frame, weight)
				j.Transform = out
				written[joint] = out
			end
		end
	end

	local function finishHop()
		local h = hop
		if h and h.onDone then
			local done = h.onDone
			h.onDone = nil
			task.defer(done)
		end
	end

	local function step(dt: number)
		if destroyed then
			return
		end
		if cat.Parent == nil and holding then
			-- the cat was removed without destroy: let go, and stop once the arms are open
			holding = false
			purr.stop()
		end
		writeArms(dt)
		if not holding and hop == nil and weight <= 0 and connection then
			connection:Disconnect()
			connection = nil
			return
		end
		local h = hop
		if h then
			local e = os.clock() - h.start
			local along, arc = Carry.hop(e, reduced)
			local flat = (h.to - h.from.Position) * Vector3.new(1, 0, 1)
			local facing = if flat.Magnitude > 0.01 then flat.Unit else h.from.LookVector
			local pos = h.from.Position:Lerp(h.to, along) + Vector3.yAxis * arc
			cat:PivotTo(CFrame.lookAt(pos, pos + facing) * offset)
			if e >= Carry.HOP_SECONDS and h.onDone then
				Audio.play("bubblePop", { at = ownPart(cat) })
				finishHop()
			end
			if weight <= 0 and e >= Carry.HOP_SECONDS and connection then
				connection:Disconnect()
				connection = nil
			end
			return
		end
		local arms = if rig then cradle(rig) else nil
		if arms then
			local along, arc = Carry.lift(os.clock() - started, reduced)
			local base = (from * offset:Inverse()):Lerp(arms, along) + Vector3.yAxis * arc
			cat:PivotTo(base * offset)
		end
	end

	connection = RunService.PreSimulation:Connect(step)

	return {
		placeIn = function(target: Vector3, onDone: (() -> ())?)
			if destroyed or hop then
				if onDone then
					task.defer(onDone)
				end
				return
			end
			holding = false
			purr.stop()
			hop = {
				start = os.clock(),
				from = cat:GetPivot() * offset:Inverse(),
				to = target,
				onDone = onDone,
			}
		end,
		destroy = function()
			if destroyed then
				return
			end
			holding = false
			weight = 0
			writeArms(0)
			destroyed = true
			purr.stop()
			finishHop()
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end,
	}
end

return Carry
