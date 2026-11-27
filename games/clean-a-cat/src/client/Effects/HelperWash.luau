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
-- The tools touch the coat (issue 1137, Derek: "the helper should pretty much be actually touching the cat with the
-- brush make the helper lean over if needed"): each step names spots on the cat (HelperWash.target), a ray finds the
-- coat under them, and a small solve (HelperWash.solve) steps the helper in toward the tub (never into it) and sets
-- the arm's raise and sideways turn, with at most a slight bend at the waist, so the brush's bristles, the towel's
-- underside, or the hand over the back for the shampoo and shower, meet that spot (Derek, 2:28 PM ET: "stands close
-- enough that its arms can reach over and actually scrub it", not bending into the cat). CustomerMotion drives it:
-- HelperWash.pose gives the turns, the step and the lean, CustomerMotion moves and leans the figure (legs with it),
-- then HelperWash.place puts the tool at the hand and runs the effects.
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

HelperWash.REACH = math.rad(58) -- as StaffPose.REACH: where the arms start before the first solve
HelperWash.LOOK = math.rad(12)
HelperWash.FOLLOW = 20 -- per second, how fast the worked spot follows the step's (strokes stay crisp, jumps ease)

-- scrub: STROKES strokes at STROKE_HZ on one patch, then MOVE seconds lifting the brush to the next patch
HelperWash.STROKE_HZ = 2.4
HelperWash.STROKES = 5
HelperWash.MOVE = 0.7
HelperWash.STROKE_LENGTH = 0.22 -- each way along the cat, of its half length
HelperWash.PRESS = -0.04 -- studs: the bristles sink a little into the fur so the contact reads
HelperWash.LIFT = 0.3 -- studs the brush lifts between patches
HelperWash.PATCHES = table.freeze({
	table.freeze({ 0.3, 0 }),
	table.freeze({ 0.55, -0.5 }),
	table.freeze({ 0.2, 0.45 }),
	table.freeze({ 0.6, 0.3 }),
	table.freeze({ 0.35, -0.3 }),
}) -- { u, v } spots on the coat (see Target)
HelperWash.POUR_HOVER = 0.8 -- studs: the hand over the back while pouring, the cap just above the fur
HelperWash.SPRAY_HOVER = 1.1 -- the hand over the coat while rinsing, the head about a stud off
HelperWash.PAT_LIFT = 0.3 -- studs a towel pat lifts

-- The solve (issue 1137): step in toward the tub, raise and turn the arm, and bend at the waist only a little, so
-- the tool's contact point meets the spot. Derek on the first lean (2026-11-27 2:28 PM ET): "the helper bends over and
-- puts its model inside the cats face just make it so it stands close enough that its arms can reach over and actually
-- scrub it". So the helper steps up to the tub (never into it: ROOM finds how far it can go) and reaches with the arms;
-- the waist bends at most LEAN_MAX, the head stays well clear of the cat.
HelperWash.STEP_MAX = 2 -- studs the helper may step in from the server's spot
HelperWash.CLEAR = 0.3 -- studs left between the helper's front and the tub (or the cat) after stepping in
HelperWash.LEAN_MAX = math.rad(12)
HelperWash.LEAN_COST = 3 -- studs of miss one radian of lean is worth: bending is the last resort
HelperWash.STEP_COST = 0.08 -- per stud stepped in: cheap, so the helper walks up rather than bends
HelperWash.ARM_MIN = 0
HelperWash.ARM_MAX = math.rad(140)
HelperWash.SIDE_MAX = math.rad(45)
HelperWash.ROOM_SECONDS = 1 -- how often the room in front of the helper is measured again

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

-- Where the step works, as spots on the cat's coat (issue 1137, Derek 2026-11-27: "the helper should pretty much be
-- actually touching the cat with the brush make the helper lean over if needed"). `u` runs across the cat toward the
-- helper (0 the middle of the back, 1 the side facing them), `v` along it (-1 to 1 of half its length). `hover` is how
-- far above the coat the tool's contact point stays: 0 touches, below 0 presses into the fur, and the shampoo and
-- shower keep the hand up over the back. The left hand gets its own spot (lu, lv, lhover). Runtime finds the coat
-- under each spot with a ray and solves the lean and arm turns that put the tool there (HelperWash.solve).
export type Target = {
	u: number,
	v: number,
	hover: number,
	lu: number,
	lv: number,
	lhover: number,
	headPitch: number, -- positive looks down, on top of the lean
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
	local w = shifted - n * burst
	local patches = HelperWash.PATCHES
	local here = patches[n % #patches + 1]
	local nextPatch = patches[(n + 1) % #patches + 1]
	local u, v = here[1], here[2]
	local hover = HelperWash.PRESS
	local beat = false
	if not still then
		if w < strokeTime then
			-- strokes along the coat with the bristles in the fur
			local cycle = w * HelperWash.STROKE_HZ
			v += HelperWash.STROKE_LENGTH * math.sin(TAU * cycle)
			beat = landing(cycle + 0.25) or landing(cycle + 0.75)
		else
			-- the brush lifts off, moves to the next patch and comes down again
			local k = (w - strokeTime) / HelperWash.MOVE
			local e = k * k * (3 - 2 * k)
			u = here[1] + (nextPatch[1] - here[1]) * e
			v = here[2] + (nextPatch[2] - here[2]) * e
			hover = HelperWash.PRESS + HelperWash.LIFT * math.sin(math.pi * k)
		end
	end
	return {
		u = u,
		v = v,
		hover = hover,
		lu = 0.85,
		lv = if here[2] > 0 then -0.45 else 0.45, -- the free hand steadies the other end
		lhover = 0,
		headPitch = HelperWash.LOOK,
		headYaw = -v * math.rad(10),
		beat = beat,
	}
end

local function soap(t: number, seed: number, still: boolean): Target
	local hz = 1.2
	local cycle = (t + seed) * hz
	local squeeze = if still then 0 else math.max(0, math.sin(TAU * cycle)) ^ 3
	local along = if still then 0 else math.sin(TAU * 0.35 * (t + seed * 3))
	return {
		u = 0.15,
		v = 0.5 * along,
		hover = HelperWash.POUR_HOVER - 0.06 * squeeze,
		lu = 0.85,
		lv = -0.4,
		lhover = 0,
		headPitch = HelperWash.LOOK,
		headYaw = -math.rad(8) * along,
		beat = not still and landing(cycle - 0.25),
	}
end

local function rinse(t: number, seed: number, still: boolean): Target
	local sweep = if still then 0 else math.sin(TAU * 0.45 * t + seed * TAU)
	local across = if still then 0 else math.sin(TAU * 0.2 * t + seed)
	local ruffle = if still then 0 else math.sin(TAU * 3 * t + seed)
	return {
		u = 0.3 + 0.25 * across,
		v = 0.55 * sweep,
		hover = HelperWash.SPRAY_HOVER,
		lu = 0.8,
		lv = 0.55 * sweep - 0.3 + 0.08 * ruffle, -- the free hand works the water into the fur behind the spray
		lhover = 0,
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
		u = 0.45,
		v = 0.3,
		hover = HelperWash.PAT_LIFT * math.max(0, s), -- down onto the coat, then up
		lu = 0.7,
		lv = -0.3,
		lhover = HelperWash.PAT_LIFT * math.max(0, -s), -- the hands take turns
		headPitch = HelperWash.LOOK,
		headYaw = 0,
		beat = not still and (landing(cycle - 0.5) or landing(cycle)),
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

-- Solves joint angles `q` (changed in place and returned) so that `fk(q)` meets `target`, by damped least squares
-- (a few Levenberg-Marquardt steps, warm started from last frame's `q`, so each frame takes one or two). `fk` returns
-- the residual's parts as a list matching `target` (the hand's x, y, z, plus any soft wishes such as "lean little").
-- Each angle stays within lo..hi. Pure, for the specs.
function HelperWash.solve(
	q: { number },
	lo: { number },
	hi: { number },
	fk: ({ number }) -> { number },
	target: { number },
	iterations: number
): { number }
	local n, h, damping = #q, 1e-3, 1e-2
	for _ = 1, iterations do
		local f = fk(q)
		local m = #target
		local r = table.create(m, 0)
		for i = 1, m do
			r[i] = f[i] - target[i]
		end
		local jac: { { number } } = {}
		for j = 1, n do
			local was = q[j]
			q[j] = was + h
			local g = fk(q)
			q[j] = was
			local col: { number } = table.create(m, 0)
			for i = 1, m do
				col[i] = (g[i] - f[i]) / h
			end
			jac[j] = col
		end
		-- (J'J + damping) dq = -J'r, by Gaussian elimination on the small n by n system
		local a: { { number } } = {}
		for i = 1, n do
			local row: { number } = table.create(n + 1, 0)
			for j = 1, n do
				local sum = 0
				for k = 1, m do
					sum += jac[i][k] * jac[j][k]
				end
				row[j] = sum + (if i == j then damping else 0)
			end
			local rhs = 0
			for k = 1, m do
				rhs -= jac[i][k] * r[k]
			end
			row[n + 1] = rhs
			a[i] = row
		end
		for col = 1, n do
			local pivot = col
			for i = col + 1, n do
				if math.abs(a[i][col]) > math.abs(a[pivot][col]) then
					pivot = i
				end
			end
			a[col], a[pivot] = a[pivot], a[col]
			local p = a[col][col]
			if math.abs(p) < 1e-12 then
				return q
			end
			for i = col + 1, n do
				local factor = a[i][col] / p
				for j = col, n + 1 do
					a[i][j] -= factor * a[col][j]
				end
			end
		end
		local dq = table.create(n, 0)
		for i = n, 1, -1 do
			local sum = a[i][n + 1]
			for j = i + 1, n do
				sum -= a[i][j] * dq[j]
			end
			dq[i] = sum / a[i][i]
		end
		for j = 1, n do
			q[j] = math.clamp(q[j] + dq[j], lo[j], hi[j])
		end
	end
	return q
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
	spotR: Vector3?, -- the worked spots, eased (world)
	spotL: Vector3?,
	qR: { number }, -- the right side's solve: step in (studs), lean, arm raise, sideways turn (radians), warm started
	qL: { number }, -- the left arm's: raise, sideways turn (the step and lean are the right side's)
	room: number, -- studs the helper can step in before reaching the tub
	roomAt: number, -- when room was measured
	roomRay: RaycastParams?,
	contact: Vector3, -- the tool's contact point in the Grip's frame (the bristles' face, the towel's underside)
}

-- CustomerMotion's forward reach for one staff rig: the Grip's world frame (right hand, or GripL when `left`) with the
-- waist leaned `lean` and that arm raised `arm` and turned `side`; nil when the rig has no such hand.
export type Reach = {
	-- the Grip's world frame (right hand, or GripL when `left`) with the helper stepped in `step` studs, the waist
	-- leaned `lean` and that arm raised `arm` and turned `side`; nil when the rig has no such hand
	hand: (step: number, lean: number, arm: number, side: number, left: boolean) -> CFrame?,
	home: () -> CFrame, -- the Body part's frame where the server put the helper (no step, no lean)
	depth: number, -- studs from the Body part's middle to its front
}

function HelperWash.new(): State
	return {
		beatWas = false,
		strokes = 0,
		qR = { 0, 0, HelperWash.REACH, 0 },
		qL = { HelperWash.REACH, 0 },
		room = 0,
		roomAt = -math.huge,
		roomRay = nil,
		contact = Vector3.new(0, -0.25, 0),
	}
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

-- The cat's coat under spot (u, v) on the helper's side (see Target): a ray straight down onto the cat, else the top
-- of its box there.
local function coatAt(
	state: State,
	cat: Model,
	box: CFrame,
	size: Vector3,
	toward: Vector3,
	u: number,
	v: number
): Vector3
	local alongX = size.X >= size.Z
	local length = if alongX then box.RightVector else box.LookVector
	local width = if alongX then box.LookVector else box.RightVector
	local halfLength = (if alongX then size.X else size.Z) / 2
	local halfWidth = (if alongX then size.Z else size.X) / 2
	local side = if (toward - box.Position):Dot(width) >= 0 then 1 else -1
	local at = box.Position
		+ length * (math.clamp(v, -1, 1) * halfLength * 0.75)
		+ width * (side * math.clamp(u, 0, 1) * halfWidth * 0.85)
	local top = box.Position.Y + size.Y / 2
	local params = state.ray
	if params == nil then
		local made = RaycastParams.new()
		made.FilterType = Enum.RaycastFilterType.Include
		state.ray = made
		params = made
	end
	local p = params :: RaycastParams
	p.FilterDescendantsInstances = { cat }
	local hit =
		Workspace:Raycast(Vector3.new(at.X, top + 0.5, at.Z), Vector3.new(0, -(size.Y + 1), 0), p)
	return if hit then hit.Position else Vector3.new(at.X, top, at.Z)
end

local function follow(from: Vector3?, to: Vector3, dt: number): Vector3
	if from == nil then
		return to
	end
	return to + ((from :: Vector3) - to) * math.exp(-HelperWash.FOLLOW * dt)
end

local LO_R, HI_R = table.freeze({ 0, 0, 0, 0 }), table.freeze({ 0, 0, 0, 0 }) -- built on first use (no math at load)
local LO_L, HI_L = table.freeze({ 0, 0 }), table.freeze({ 0, 0 })
local bounds = false
local function setBounds()
	if not bounds then
		bounds = true
		LO_R = table.freeze({ 0, 0, HelperWash.ARM_MIN, -HelperWash.SIDE_MAX })
		HI_R = table.freeze({
			HelperWash.STEP_MAX,
			HelperWash.LEAN_MAX,
			HelperWash.ARM_MAX,
			HelperWash.SIDE_MAX,
		})
		LO_L = table.freeze({ HelperWash.ARM_MIN, -HelperWash.SIDE_MAX })
		HI_L = table.freeze({ HelperWash.ARM_MAX, HelperWash.SIDE_MAX })
	end
end

-- How far the helper can step in toward the tub: rays forward from their spot at hip and knee height (the tub's rim
-- or side, or the cat), less the body's half depth and CLEAR. Measured once a ROOM_SECONDS: the stand never moves.
local function roomOf(state: State, staff: Model, reach: Reach, now: number): number
	if now - state.roomAt < HelperWash.ROOM_SECONDS then
		return state.room
	end
	state.roomAt = now
	local params = state.roomRay
	if params == nil then
		local made = RaycastParams.new()
		made.FilterType = Enum.RaycastFilterType.Exclude
		state.roomRay = made
		params = made
	end
	local p = params :: RaycastParams
	local skip: { Instance } = { staff }
	if state.tool then
		table.insert(skip, state.tool :: Model)
	end
	p.FilterDescendantsInstances = skip
	local home = reach.home()
	local ahead = Vector3.new(home.LookVector.X, 0, home.LookVector.Z)
	if ahead.Magnitude < 1e-3 then
		state.room = 0
		return 0
	end
	ahead = ahead.Unit
	local far = HelperWash.STEP_MAX + reach.depth + HelperWash.CLEAR + 0.5
	local nearest = far
	for _, drop in { 0.6, 1.5 } do
		local from = home.Position - Vector3.yAxis * drop
		local hit = Workspace:Raycast(from, ahead * far, p)
		if hit then
			nearest = math.min(nearest, hit.Distance)
		end
	end
	state.room = math.clamp(nearest - reach.depth - HelperWash.CLEAR, 0, HelperWash.STEP_MAX)
	return state.room
end

-- Lays the step over `pose` by `amount`: the spots on the coat this frame, then the lean and arm turns that put the
-- tool and the free hand on them. Returns the arms' sideways turns (left, right) and the waist's lean for
-- CustomerMotion, or nil (leaving `pose` alone) when there is no cat to wash, so the caller keeps StaffPose.scrub.
function HelperWash.pose(
	state: State,
	staff: Model,
	pose: { armL: number, armR: number, headPitch: number, headYaw: number },
	now: number,
	seed: number,
	amount: number,
	still: boolean,
	dt: number,
	reach: Reach
): (number?, number?, number?, number?)
	local cat = catOf(staff)
	local progress = if cat then cat:GetAttribute(WorkerRules.PROGRESS_ATTRIBUTE) else nil
	if cat == nil or type(progress) ~= "number" then
		state.cat = nil
		return nil, nil, nil, nil
	end
	local catModel = cat :: Model
	state.cat = catModel
	local phase = HelperWash.phase(progress :: number)
	state.phase = phase
	local want = HelperWash.target(phase, now, seed, still)
	state.cur = want
	local box, size = catModel:GetBoundingBox()
	local from = staff:GetPivot().Position
	local spotR = coatAt(state, catModel, box, size, from, want.u, want.v)
		+ Vector3.yAxis * want.hover
	local spotL = coatAt(state, catModel, box, size, from, want.lu, want.lv)
		+ Vector3.yAxis * want.lhover
	state.spotR = follow(state.spotR, spotR, dt)
	state.spotL = follow(state.spotL, spotL, dt)
	setBounds()
	-- the right hand: the aimed tools (shampoo, shower) put the hand itself on the spot, the others their contact point
	local contact = if phase == "soap" or phase == "rinse" then Vector3.zero else state.contact
	local tr = state.spotR :: Vector3
	local hit = true
	local hi = table.clone(HI_R)
	hi[1] = roomOf(state, staff, reach, now)
	HelperWash.solve(state.qR, LO_R, hi, function(q: { number }): { number }
		local grip = reach.hand(q[1], q[2], q[3], q[4], false)
		if grip == nil then
			hit = false
			return { tr.X, tr.Y, tr.Z, 0, 0 }
		end
		local p = grip * contact
		return { p.X, p.Y, p.Z, q[1] * HelperWash.STEP_COST, q[2] * HelperWash.LEAN_COST }
	end, { tr.X, tr.Y, tr.Z, 0, 0 }, 2)
	if not hit then
		state.cat = nil
		return nil, nil, nil, nil
	end
	local stepIn, lean = state.qR[1], state.qR[2]
	local tl = state.spotL :: Vector3
	HelperWash.solve(state.qL, LO_L, HI_L, function(q: { number }): { number }
		local grip = reach.hand(stepIn, lean, q[1], q[2], true)
		if grip == nil then
			return { tl.X, tl.Y, tl.Z }
		end
		local p = grip.Position
		return { p.X, p.Y, p.Z }
	end, { tl.X, tl.Y, tl.Z }, 2)
	local a = math.clamp(amount, 0, 1)
	pose.armR += (state.qR[3] - pose.armR) * a
	pose.armL += (state.qL[1] - pose.armL) * a
	pose.headPitch += (want.headPitch - pose.headPitch) * a
	pose.headYaw += (want.headYaw - pose.headYaw) * a
	return state.qL[2] * a, state.qR[4] * a, lean * a, stepIn * a
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
	-- the brush and towel meet the coat with the far side of the tool from the palm (along the Grip's -Y, out of the
	-- hand): the solve puts that point on the spot (issue 1137)
	if phase == "scrub" or phase == "dry" then
		local inGrip = holdFor(phase) * (state.handle :: CFrame) * pivot:Inverse()
		local box, size = tool:GetBoundingBox()
		local low = math.huge
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local corner = inGrip * (box * Vector3.new(x * size.X, y * size.Y, z * size.Z))
					low = math.min(low, corner.Y)
				end
			end
		end
		local middle = inGrip * box.Position
		state.contact = Vector3.new(middle.X, low, middle.Z)
	end
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
	-- the shower lands under the hand so the spray follows the sweep; the pour aims at the middle of the back
	-- (Sync 2026-11-27: aimed under the hand, a steep pour ran down behind the cat onto the tail)
	local follow = if pour > 0 then 0 else 0.7
	local under = Vector3.new(
		centre.X + (at.X - centre.X) * follow,
		centre.Y,
		centre.Z + (at.Z - centre.Z) * follow
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
	local box, size = cat:GetBoundingBox()
	if aim and build then
		-- the pour aims high on the body with a light tip: the hand sits about level with the cat's middle, so a
		-- steep pour at the middle ran off behind it onto the tail (Sync 2026-11-27, four checks)
		local soap = phase == "soap"
		local centre = if soap then box.Position + Vector3.new(0, size.Y * 0.3, 0) else box.Position
		tool:PivotTo(aimTool(hand, centre, aim, if soap then 0.4 else 0) * build)
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
