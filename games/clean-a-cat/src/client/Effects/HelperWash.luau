--!strict
-- HelperWash: a helper washing a cat at their stand works through the real steps with a tool in hand (Derek,
-- 2026-11-27: "give helpers washing cats better animations can actually show them scrubbing with a brush or rinsing
-- not just moving hands back and forth over and over", issue 1135, switch helperWash). Client only and cosmetic.
--
-- The step comes from the helper's cat (WorkerService's WorkerCat_<id> beside them in the stand), whose
-- WorkerProgress runs 0 to 1 over the wash:
--   soap   the shampoo bottle tipped over the cat, squeezed now and then, moving along the back; a blue drop each squeeze
--   scrub  the brush: bursts of short strokes on one patch of coat, then a beat to move to the next patch, the head
--          following; a foam puff and the brush swish on each stroke, the left hand steadying the cat
--   rinse  the shower head sweeps slowly from side to side with a water line from the nozzle into the fur and drips
--          there; the free hand ruffles the fur under it
--   dry    the towel: pats with the hands in turn, a puff of droplets on each pat
-- The pose eases from step to step (nothing snaps) and the tool swaps at the hand as a step begins. The tools are
-- Model-Agent's CleanACat_Tool_Shampoo, _Brush, _Shower and _Towel, a client-only copy held at the staff's Grip.
--
-- CustomerMotion drives it: HelperWash.pose lays the step over the staff's pose (and gives the arms' sideways turn,
-- which the staff rig's joints take about Z), then HelperWash.place puts the tool at the hand and runs the effects.
-- Budget: effects and sounds only for helpers within NEAR studs, one small emitter and one beam each; Less sparkle
-- halves the puffs; Reduced Motion holds each step's pose with the tool still and keeps only the water line.
--
-- API (pure, for the specs)
--   HelperWash.phase(progress) -> "soap" | "scrub" | "rinse" | "dry"
--   HelperWash.target(phase, t, seed, still) -> Target   the step's pose at `t` seconds, with `beat` true on the frame
--                                                         window of a stroke, squeeze or pat (for the puffs)
-- API (runtime)
--   HelperWash.new() -> State; HelperWash.pose(state, staff, pose, now, seed, amount, still, dt);
--   HelperWash.place(state, staff, near, now); HelperWash.stop(state)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local HelperWash = {}

HelperWash.FLAG = "helperWash"
HelperWash.NEAR = 30 -- studs: tools always show, effects and sounds only this close
HelperWash.BLEND = 8 -- per second, how fast the pose eases to the next step
HelperWash.SOAP_UNTIL = 0.12
HelperWash.SCRUB_UNTIL = 0.6
HelperWash.RINSE_UNTIL = 0.85

HelperWash.REACH = math.rad(58) -- as StaffPose.REACH: both arms over the cat on the stand
HelperWash.LOOK = math.rad(16)

-- scrub: STROKES strokes at STROKE_HZ on one patch, then MOVE seconds to the next patch
HelperWash.STROKE_HZ = 2.4
HelperWash.STROKES = 5
HelperWash.MOVE = 0.7
HelperWash.STROKE = math.rad(11) -- each way, along the coat
HelperWash.PATCHES = table.freeze({ 0, -1, 0.6, 1, -0.5 }) -- sideways spots along the cat, -1 to 1
HelperWash.PATCH_SIDE = math.rad(22) -- Sync 2026-11-27: 11 moved the brush only 0.33 studs across the coat
HelperWash.PATCH_REACH = table.freeze({ 0, 12, -9, 7, -12 }) -- degrees nearer or farther along the cat, per patch

HelperWash.TOOLS = table.freeze({
	soap = "CleanACat_Tool_Shampoo",
	scrub = "CleanACat_Tool_Brush",
	rinse = "CleanACat_Tool_Shower",
	dry = "CleanACat_Tool_Towel",
} :: { [string]: string })

-- How each tool sits in the hand, from the Grip's frame (the arm's length is the Grip's -Y). The tool's Handle part
-- goes to the Grip; this turns it so it points along the arm into the work. Tuned on Sync's Studio pictures (the
-- brush and towel read right). The shampoo and shower are aimed instead (see aimTool): their grip at the hand and
-- their business end pointed at the cat, since fixed angles had the bottle sideways and the shower back to front.
local hold: { [string]: CFrame }? = nil -- built on first use (the specs' runner has no CFrame)
local function holdFor(phase: string): CFrame
	if hold == nil then
		hold = {
			scrub = CFrame.Angles(-math.pi / 2, 0, 0), -- the brush's length along the arm, bristles at the coat
			dry = CFrame.new(0, -0.15, 0), -- the towel flat in the palm
		}
	end
	return (hold :: { [string]: CFrame })[phase] or CFrame.identity
end

export type Phase = string

function HelperWash.phase(progress: number): Phase
	if progress < HelperWash.SOAP_UNTIL then
		return "soap"
	elseif progress < HelperWash.SCRUB_UNTIL then
		return "scrub"
	elseif progress < HelperWash.RINSE_UNTIL then
		return "rinse"
	end
	return "dry"
end

export type Target = {
	armL: number,
	armR: number,
	sideL: number, -- sideways turn, positive across the body (toward the other arm)
	sideR: number,
	headPitch: number, -- positive looks down
	headYaw: number,
	beat: boolean, -- a stroke, squeeze or pat lands now
}

local TAU = 2 * math.pi
local BEAT_WINDOW = 0.06 -- share of a cycle counted as the landing

-- True when `cycle` (a running count of cycles) is within the landing window of a whole cycle.
local function landing(cycle: number): boolean
	local f = cycle % 1
	return f < BEAT_WINDOW
end

local function scrub(t: number, seed: number, still: boolean): Target
	local strokeTime = HelperWash.STROKES / HelperWash.STROKE_HZ
	local burst = strokeTime + HelperWash.MOVE
	local shifted = t + seed * burst
	local n = math.floor(shifted / burst)
	local u = shifted - n * burst
	local patches = HelperWash.PATCHES
	local i = n % #patches + 1
	local j = (n + 1) % #patches + 1
	local here = patches[i]
	local nextPatch = patches[j]
	local reach = HelperWash.PATCH_REACH[i]
	local side = here
	local stroke = 0
	local beat = false
	if still then
		side = here
	elseif u < strokeTime then
		local cycle = u * HelperWash.STROKE_HZ
		stroke = math.sin(TAU * cycle)
		beat = landing(cycle + 0.25) -- the push forward peaks a quarter in
	else
		local k = (u - strokeTime) / HelperWash.MOVE
		local e = k * k * (3 - 2 * k)
		side = here + (nextPatch - here) * e
		reach += (HelperWash.PATCH_REACH[j] - reach) * e
	end
	return {
		armR = HelperWash.REACH + math.rad(6 + reach) + HelperWash.STROKE * stroke,
		sideR = side * HelperWash.PATCH_SIDE + math.rad(3) * stroke * stroke,
		armL = HelperWash.REACH - math.rad(6),
		sideL = math.rad(4),
		headPitch = HelperWash.LOOK + math.rad(2) * math.abs(stroke),
		headYaw = -side * math.rad(12),
		beat = beat,
	}
end

local function soap(t: number, seed: number, still: boolean): Target
	local hz = 1.2
	local cycle = (t + seed) * hz
	local squeeze = if still then 0 else math.max(0, math.sin(TAU * cycle)) ^ 3
	local along = if still then 0 else math.sin(TAU * 0.35 * (t + seed * 3))
	return {
		armR = HelperWash.REACH + math.rad(22) - math.rad(5) * squeeze,
		sideR = math.rad(8) * along,
		armL = HelperWash.REACH - math.rad(4),
		sideL = math.rad(3),
		headPitch = HelperWash.LOOK,
		headYaw = -math.rad(8) * along,
		beat = not still and landing(cycle - 0.25),
	}
end

local function rinse(t: number, seed: number, still: boolean): Target
	local sweep = if still then 0 else math.sin(TAU * 0.45 * t + seed * TAU)
	local lift = if still then 0 else math.sin(TAU * 1.1 * t)
	local ruffle = if still then 0 else math.sin(TAU * 3 * t + seed)
	return {
		armR = HelperWash.REACH + math.rad(14) + math.rad(3) * lift,
		sideR = math.rad(14) * sweep,
		armL = HelperWash.REACH - math.rad(2) + math.rad(5) * ruffle,
		sideL = math.rad(4) + math.rad(3) * (if still then 1 else math.cos(TAU * 3 * t)),
		headPitch = HelperWash.LOOK,
		headYaw = -math.rad(9) * sweep,
		beat = false,
	}
end

local function dry(t: number, seed: number, still: boolean): Target
	local hz = 1.8
	local cycle = (t + seed) * hz
	local s = if still then 0 else math.sin(TAU * cycle)
	return {
		armR = HelperWash.REACH - math.rad(4) + math.rad(9) * math.max(0, s),
		sideR = math.rad(6),
		armL = HelperWash.REACH - math.rad(4) + math.rad(9) * math.max(0, -s),
		sideL = math.rad(6),
		headPitch = HelperWash.LOOK - math.rad(2) * math.abs(s),
		headYaw = 0,
		beat = not still and (landing(cycle - 0.25) or landing(cycle - 0.75)),
	}
end

function HelperWash.target(phase: Phase, t: number, seed: number, still: boolean): Target
	if phase == "soap" then
		return soap(t, seed, still)
	elseif phase == "rinse" then
		return rinse(t, seed, still)
	elseif phase == "dry" then
		return dry(t, seed, still)
	end
	return scrub(t, seed, still)
end

-- Runtime ----------------------------------------------------------------------------------------------------------

export type State = {
	phase: Phase?,
	cur: Target?, -- the eased pose
	tool: Model?,
	toolPhase: Phase?,
	handle: CFrame?, -- the tool's pivot from its Handle
	aim: CFrame?, -- aimed tools: the frame of the business end (X) and its up side (Y), in the model's build space
	build: CFrame?, -- aimed tools: the model's pivot in its build space (the grip is the build origin)
	ray: RaycastParams?,
	emitter: ParticleEmitter?,
	beam: Beam?,
	a0: Attachment?,
	a1: Attachment?,
	cat: Model?,
	beatWas: boolean,
	strokes: number,
}

function HelperWash.new(): State
	return { beatWas = false, strokes = 0 }
end

function HelperWash.on(): boolean
	return LiveFlags.OFF_BY_DEFAULT[HelperWash.FLAG] == true and LiveFlags.isOn(HelperWash.FLAG)
end

-- The helper's cat in their stand, or nil.
local function catOf(staff: Model): Model?
	local parent = staff.Parent
	local prefix = "CleanACat_NPC_Staff_"
	if parent == nil or string.sub(staff.Name, 1, #prefix) ~= prefix then
		return nil
	end
	local found = parent:FindFirstChild(`WorkerCat_{string.sub(staff.Name, #prefix + 1)}`)
	return if found and found:IsA("Model") then found :: Model else nil
end

local function approach(from: number, to: number, rate: number, dt: number): number
	return to + (from - to) * math.exp(-rate * dt)
end

-- Lays the step's pose over `pose` by `amount` and returns the arms' sideways turns (left, right) for CustomerMotion.
-- Returns nil (and leaves `pose` alone) when there is no cat to wash, so the caller keeps StaffPose.scrub.
function HelperWash.pose(
	state: State,
	staff: Model,
	pose: { armL: number, armR: number, headPitch: number, headYaw: number },
	now: number,
	seed: number,
	amount: number,
	still: boolean,
	dt: number
): (number?, number?)
	local cat = catOf(staff)
	local progress = if cat then cat:GetAttribute(WorkerRules.PROGRESS_ATTRIBUTE) else nil
	if cat == nil or type(progress) ~= "number" then
		state.cat = nil
		return nil, nil
	end
	state.cat = cat
	local phase = HelperWash.phase(progress :: number)
	state.phase = phase
	local want = HelperWash.target(phase, now, seed, still)
	local cur = state.cur
	if cur == nil then
		cur = table.clone(want)
		state.cur = cur
	end
	local c = cur :: Target
	for _, key in { "armL", "armR", "sideL", "sideR", "headPitch", "headYaw" } do
		(c :: any)[key] = approach((c :: any)[key], (want :: any)[key], HelperWash.BLEND, dt)
	end
	c.beat = want.beat
	local a = math.clamp(amount, 0, 1)
	pose.armL += (c.armL - pose.armL) * a
	pose.armR += (c.armR - pose.armR) * a
	pose.headPitch += (c.headPitch - pose.headPitch) * a
	pose.headYaw += (c.headYaw - pose.headYaw) * a
	return c.sideL * a, c.sideR * a
end

local function dropTool(state: State)
	local tool = state.tool
	state.tool = nil
	state.toolPhase = nil
	state.handle = nil
	state.aim = nil
	state.build = nil
	state.emitter = nil
	state.a0 = nil
	if tool then
		tool:Destroy()
	end
end

local function hideBeam(state: State)
	local beam = state.beam
	if beam and beam.Enabled then
		beam.Enabled = false
	end
end

local function makeTool(state: State, phase: Phase)
	dropTool(state)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(HelperWash.TOOLS[phase]) else nil
	if asset == nil or not asset:IsA("Model") then
		state.toolPhase = phase -- try again on the next step, not every frame
		return
	end
	local tool = asset:Clone() :: Model
	tool.Name = "CleanACat_Fx_HelperTool"
	for _, item in tool:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	local handle = tool:FindFirstChild("Handle")
	local pivot = tool:GetPivot()
	state.handle = if handle and handle:IsA("BasePart")
		then (handle :: BasePart).CFrame:ToObjectSpace(pivot)
		else CFrame.identity
	-- the puffs come from the business end: the shower's Nozzle, else the tool's middle
	local nozzle = tool:FindFirstChild("Nozzle", true)
	-- aimed tools, read while the copy still sits where Model-Agent built it (its grip at the origin): the shower
	-- sprays out of its Nozzle (the head's +X), the shampoo bottle pours out of its cap (+Y)
	local spray: Vector3? = nil
	if phase == "rinse" and nozzle and nozzle:IsA("Attachment") then
		spray = ((nozzle :: Attachment).Parent :: any).CFrame.RightVector
	elseif phase == "soap" then
		spray = Vector3.yAxis
	end
	if spray then
		local a = (spray :: Vector3).Unit
		local up = if math.abs(a.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
		local b = (up - a * a:Dot(up)).Unit
		state.aim = CFrame.fromMatrix(Vector3.zero, a, b, a:Cross(b))
		state.build = pivot
	end
	local at: Attachment
	if nozzle and nozzle:IsA("Attachment") then
		at = nozzle :: Attachment
	else
		at = Instance.new("Attachment")
		at.Name = "CleanACat_Fx_HelperTip"
		at.Parent = if handle and handle:IsA("BasePart") then handle else tool.PrimaryPart
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CleanACat_Fx_HelperPuff"
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.45, 0.7)
	emitter.Speed = NumberRange.new(0.6, 1.4)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.4, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.2
	emitter.Color = ColorSequence.new(
		if phase == "soap"
			then Color3.fromRGB(150, 200, 255)
			elseif phase == "scrub" then Color3.fromRGB(250, 252, 255)
			else Color3.fromRGB(190, 225, 255)
	)
	emitter.Parent = at
	state.emitter = emitter
	state.a0 = at
	state.tool = tool
	state.toolPhase = phase
	tool.Parent = Workspace
end

-- The water line from the nozzle into the fur while rinsing (as ShowerStream, one per helper).
local function showBeam(state: State, from: Attachment, to: Vector3, now: number)
	local beam = state.beam
	local a1 = state.a1
	if beam == nil or a1 == nil then
		local endAt = Instance.new("Attachment")
		endAt.Name = "CleanACat_Fx_HelperWaterEnd"
		endAt.Parent = Workspace.Terrain
		local b = Instance.new("Beam")
		b.Name = "CleanACat_Fx_HelperWater"
		b.Color = ColorSequence.new(Color3.fromRGB(190, 225, 255))
		b.Transparency = NumberSequence.new(0.35)
		b.LightEmission = 0.3
		b.FaceCamera = true
		b.Segments = 6
		b.Parent = Workspace.Terrain
		beam = b
		a1 = endAt
		state.beam = b
		state.a1 = endAt
	end
	local line = beam :: Beam
	local endAt = a1 :: Attachment
	line.Attachment0 = from
	endAt.WorldPosition = to
	line.Attachment1 = endAt
	local k = 1 + 0.15 * math.sin(now * math.pi * 2 * 9)
	line.Width0 = 0.08 * k
	line.Width1 = 0.15 * k
	if not line.Enabled then
		line.Enabled = true
	end
end

-- The client's Audio module (Sound-Agent's cues), found once; nil if it is not there.
local audioLoaded = false
local audio: any = nil
local function audioModule(): any
	if not audioLoaded then
		audioLoaded = true
		local effects = script.Parent
		local client = if effects then effects.Parent else nil
		local folder = if client then client:FindFirstChild("Audio") else nil
		if folder and folder:IsA("ModuleScript") then
			local ok, found = pcall(require, folder)
			audio = if ok then found else nil
		end
	end
	return audio
end

-- Where an aimed tool goes: its grip at the hand and its business end pointed down onto the cat under the hand (so
-- the pour and the spray follow the arm's sweep), its up side kept up. `aim` is from makeTool.
-- `pour` tips the end further down (the shampoo: the cat's middle is about level with the hand, so aiming at it
-- alone held the bottle level, Sync 2026-11-27).
local function aimTool(hand: CFrame, centre: Vector3, aim: CFrame, pour: number): CFrame
	local at = hand.Position
	local under = Vector3.new(
		centre.X + (at.X - centre.X) * 0.7,
		centre.Y,
		centre.Z + (at.Z - centre.Z) * 0.7
	)
	local toward = under - at
	local A = if toward.Magnitude > 1e-3 then toward.Unit else -hand.UpVector
	if pour > 0 then
		A = (A - Vector3.yAxis * pour).Unit
	end
	local B = Vector3.yAxis - A * A:Dot(Vector3.yAxis)
	if B.Magnitude < 0.1 then
		B = hand.LookVector - A * A:Dot(hand.LookVector)
	end
	B = B.Unit
	local world = CFrame.fromMatrix(Vector3.zero, A, B, A:Cross(B))
	return CFrame.new(at) * world * aim:Inverse()
end

-- Where the water meets the fur: the first point on the cat along the spray (Sync 2026-11-27: aiming at the
-- middle put the line's end half a stud inside the coat), else the middle.
local function waterEnd(state: State, cat: Model, from: Vector3, centre: Vector3): Vector3
	local params = state.ray
	if params == nil then
		local made = RaycastParams.new()
		made.FilterType = Enum.RaycastFilterType.Include
		state.ray = made
		params = made
	end
	local p = params :: RaycastParams
	p.FilterDescendantsInstances = { cat }
	local toward = centre - from
	local hit = Workspace:Raycast(from, toward.Unit * (toward.Magnitude + 1), p)
	return if hit then hit.Position else centre
end

-- Puts the tool at the staff's right hand and runs the step's effects. `near`: within NEAR studs of the camera.
function HelperWash.place(
	state: State,
	staff: Model,
	near: boolean,
	now: number,
	lessSparkle: boolean
)
	local phase = state.phase
	local cat = state.cat
	if phase == nil or cat == nil then
		HelperWash.stop(state)
		return
	end
	if state.toolPhase ~= phase then
		makeTool(state, phase)
		state.beatWas = false
	end
	local tool = state.tool
	local grip = staff:FindFirstChild("Grip", true)
	if tool == nil or grip == nil or not grip:IsA("Attachment") then
		hideBeam(state)
		return
	end
	local hand = (grip :: Attachment).WorldCFrame
	local aim, build = state.aim, state.build
	local box = cat:GetBoundingBox()
	if aim and build then
		tool:PivotTo(aimTool(hand, box.Position, aim, if phase == "soap" then 2 else 0) * build)
	else
		tool:PivotTo(hand * holdFor(phase) * (state.handle or CFrame.identity))
	end
	local tip = state.a0
	if phase == "rinse" and tip then
		showBeam(state, tip, waterEnd(state, cat, tip.WorldPosition, box.Position), now)
	else
		hideBeam(state)
	end
	local emitter = state.emitter
	if emitter == nil or not near then
		return
	end
	if phase == "rinse" then
		-- drips where the water meets the fur, a steady light trickle
		emitter.Rate = if lessSparkle then 4 else 8
		if not emitter.Enabled then
			emitter.Enabled = true
		end
		return
	end
	if emitter.Enabled then
		emitter.Enabled = false
	end
	local beat = state.cur ~= nil and (state.cur :: Target).beat
	if beat and not state.beatWas then
		emitter:Emit(if lessSparkle then 1 else 3)
		if phase == "scrub" then
			state.strokes += 1
			local audio = audioModule()
			if audio then
				audio.play("brushSwish", { at = tool.PrimaryPart, variant = state.strokes % 3 + 1 })
			end
		end
	end
	state.beatWas = beat
end

-- Takes the tool, puffs and water away (the wash ended, the helper walked off or went out of range).
function HelperWash.stop(state: State)
	dropTool(state)
	local beam = state.beam
	local a1 = state.a1
	state.beam = nil
	state.a1 = nil
	if beam then
		beam:Destroy()
	end
	if a1 then
		a1:Destroy()
	end
	state.phase = nil
	state.cur = nil
	state.cat = nil
	state.beatWas = false
end

return HelperWash
