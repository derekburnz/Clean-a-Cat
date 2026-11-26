--!strict
-- TubLife: the wash tub looks alive (Derek's playtest, 2026-11-26: "make the water actually flowing/bubbles coming off
-- and popping and foam moving or stagnant but less trying to be floating so it looks less like a stale boring dull
-- model"). Behind the switch tubLife, off by default. Client only and cosmetic: it moves the tub's own decoration
-- parts on this device, never the tub, the cat or anything that collides.
--
-- On every CleanACat_Station_Tub in Workspace (the wash tub and the station tubs):
--   foam     each foam blob is settled once onto what is under it (the water or the rim, by a ray against the tub's
--            own parts), sunk a little so it sits instead of hovering, then breathes with a slow small bob
--   bubbles  the clear bubbles no longer hang in the air: each starts on the water, rises a little with a sideways
--            wobble, then pops (a quick swell and fade) and starts again elsewhere on the water, each on its own clock
--   stream   the tap's stream wobbles in width as if running, and a ripple ring spreads where it meets the water
--
-- Phone budget: tubs further than FAR studs from the camera are left still; updates run at STEP (30 a second) with
-- one BulkMoveTo per tub; only a popping bubble changes size. Reduced Motion (Effects.reducedMotion): the foam settles
-- and the bubbles sit on the water, with no movement. The switch off puts every part back as the model had it.
--
--   TubLife.bubble(t, life) -> (rise, wobble, pop)   pure: a bubble's rise (0 to 1), sideways wobble (-1 to 1) and pop
--                                                    (0 none to 1 gone) at t seconds into a life of `life` seconds
--   TubLife.ripple(t) -> (size, seen)                pure: the ripple ring's width share (0 to 1) and how shown (0 to 1)
--   TubLife.start(isOn)                              binds once; isOn() is read every few frames
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local TubLife = {}

TubLife.TUB_NAME = "CleanACat_Station_Tub"
TubLife.FAR = 70 -- studs from the camera
TubLife.STEP = 1 / 30
TubLife.LIFE = { 2.2, 3.6 } -- seconds a bubble lives, picked per bubble
TubLife.POP = 0.14 -- seconds of the pop at the end of a life
TubLife.RISE = 1.4 -- studs a bubble rises (at tub scale 1)
TubLife.WOBBLE = 0.18 -- studs sideways
TubLife.POP_SWELL = 0.6 -- a popping bubble grows by this share as it fades
TubLife.FOAM_BOB = 0.05 -- studs
TubLife.FOAM_SINK = 0.3 -- of a foam blob's height sits below the surface it rests on
TubLife.STREAM_WOBBLE = 0.12 -- of the stream's width
TubLife.STREAM_HZ = 7
TubLife.RIPPLE_SECONDS = 0.7
TubLife.RIPPLE_WIDTH = 1.4 -- studs at tub scale 1

function TubLife.bubble(t: number, life: number): (number, number, number)
	local u = math.clamp(t / life, 0, 1)
	local riseShare = math.clamp(t / math.max(life - TubLife.POP, 0.01), 0, 1)
	local rise = 1 - (1 - riseShare) * (1 - riseShare) -- quick off the water, slowing as it climbs
	local wobble = math.sin(u * math.pi * 3)
	local pop = math.clamp((t - (life - TubLife.POP)) / TubLife.POP, 0, 1)
	return rise, wobble, pop
end

function TubLife.ripple(t: number): (number, number)
	local u = (t % TubLife.RIPPLE_SECONDS) / TubLife.RIPPLE_SECONDS
	return 0.25 + 0.75 * u, 1 - u
end

type Bubble = {
	part: BasePart,
	home: CFrame,
	size: Vector3,
	seen: number, -- the model's own transparency
	born: number,
	life: number,
	from: Vector3, -- this life's start on the water
}
type Foam = { part: BasePart, home: CFrame, rest: CFrame, phase: number }
type Tub = {
	model: Model,
	scale: number,
	waterTop: number,
	waterBox: CFrame,
	waterSize: Vector3,
	bubbles: { Bubble },
	foam: { Foam },
	stream: BasePart?,
	streamHome: Vector3?,
	ripple: BasePart?,
	rippleAt: Vector3?,
}

local rng = Random.new()
local tubs: { [Model]: Tub } = {}

local function partsIn(model: Instance?): { BasePart }
	local out: { BasePart } = {}
	if model == nil then
		return out
	end
	if model:IsA("BasePart") then
		table.insert(out, model :: BasePart)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d :: BasePart)
		end
	end
	return out
end

local function child(model: Model, suffix: string): Instance?
	return model:FindFirstChild(model.Name .. suffix)
end

-- A spot on the water for a new bubble: anywhere inside the middle of the water's top, in its own frame.
local function waterSpot(tub: Tub, radius: number): Vector3
	local half = tub.waterSize * 0.38
	local local_ = Vector3.new(rng:NextNumber(-half.X, half.X), 0, rng:NextNumber(-half.Z, half.Z))
	local p = tub.waterBox:PointToWorldSpace(local_)
	return Vector3.new(p.X, tub.waterTop + radius * 0.6, p.Z)
end

local function newLife(tub: Tub, b: Bubble, now: number)
	b.born = now
	b.life = rng:NextNumber(TubLife.LIFE[1], TubLife.LIFE[2])
	b.from = waterSpot(tub, b.size.Y / 2)
end

local function build(model: Model): Tub?
	local water = partsIn(child(model, "_Water"))
	if #water == 0 then
		return nil
	end
	-- the water's surface: the widest water part's top
	local widest = water[1]
	for _, p in water do
		if p.Size.X * p.Size.Z > widest.Size.X * widest.Size.Z then
			widest = p
		end
	end
	local tub: Tub = {
		model = model,
		scale = model:GetScale(),
		waterTop = widest.Position.Y + widest.Size.Y / 2,
		waterBox = widest.CFrame,
		waterSize = widest.Size,
		bubbles = {},
		foam = {},
		stream = nil,
		streamHome = nil,
		ripple = nil,
		rippleAt = nil,
	}
	local now = os.clock()
	for _, p in partsIn(child(model, "_Bubbles")) do
		local b: Bubble = {
			part = p,
			home = p.CFrame,
			size = p.Size,
			seen = p.Transparency,
			born = now,
			life = 1,
			from = p.Position,
		}
		newLife(tub, b, now)
		b.born = now - rng:NextNumber(0, b.life) -- start each partway through, so they never pop together
		table.insert(tub.bubbles, b)
	end
	-- foam settles onto whatever of the tub is under it (not other foam or the bubbles)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local solid: { Instance } = {}
	for _, p in partsIn(model) do
		local name = (p.Parent :: Instance).Name
		if
			not (
				string.match(name, "_Foam$")
				or string.match(name, "_Bubbles$")
				or string.match(name, "_Stream$")
			)
		then
			table.insert(solid, p)
		end
	end
	params.FilterDescendantsInstances = solid
	for _, p in partsIn(child(model, "_Foam")) do
		local rest = p.CFrame
		local hit = Workspace:Raycast(p.Position, Vector3.new(0, -6 * tub.scale, 0), params)
		if hit then
			local bottom = p.Position.Y - p.Size.Y / 2
			local goal = hit.Position.Y - p.Size.Y * TubLife.FOAM_SINK
			if bottom > goal then
				rest = rest - Vector3.new(0, bottom - goal, 0)
			end
		end
		table.insert(
			tub.foam,
			{ part = p, home = p.CFrame, rest = rest, phase = rng:NextNumber(0, math.pi * 2) }
		)
	end
	local stream = partsIn(child(model, "_Stream"))[1]
	if stream then
		tub.stream = stream
		tub.streamHome = stream.Size
		local ring = Instance.new("Part")
		ring.Name = "CleanACat_Fx_TubRipple"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.SmoothPlastic
		ring.Color = Color3.fromHex("E9FBFF")
		ring.Transparency = 1
		ring.Size = Vector3.new(0.05, 0.1, 0.1)
		local rippleAt = Vector3.new(stream.Position.X, tub.waterTop + 0.03, stream.Position.Z)
		tub.rippleAt = rippleAt
		ring.CFrame = CFrame.new(rippleAt) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = model
		tub.ripple = ring
	end
	return tub
end

local function restore(tub: Tub)
	for _, b in tub.bubbles do
		if b.part.Parent then
			b.part.CFrame, b.part.Size, b.part.Transparency = b.home, b.size, b.seen
		end
	end
	for _, f in tub.foam do
		if f.part.Parent then
			f.part.CFrame = f.home
		end
	end
	local stream, home = tub.stream, tub.streamHome
	if stream and home and stream.Parent then
		stream.Size = home
	end
	if tub.ripple then
		tub.ripple:Destroy()
		tub.ripple = nil
	end
end

local function update(tub: Tub, now: number, still: boolean)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, f in tub.foam do
		local bob = if still
			then 0
			else TubLife.FOAM_BOB * tub.scale * math.sin(now * 1.3 + f.phase)
		table.insert(parts, f.part)
		table.insert(frames, f.rest + Vector3.new(0, bob, 0))
	end
	for _, b in tub.bubbles do
		local t = now - b.born
		if t >= b.life then
			newLife(tub, b, now)
			t = 0
		end
		local rise, wobble, pop = TubLife.bubble(t, b.life)
		if still then
			rise, wobble, pop = 0, 0, 0
		end
		local side = b.home.RightVector * (TubLife.WOBBLE * tub.scale * wobble)
		table.insert(parts, b.part)
		table.insert(
			frames,
			CFrame.new(b.from + Vector3.new(0, TubLife.RISE * tub.scale * rise, 0) + side)
		)
		if pop > 0 then
			b.part.Size = b.size * (1 + TubLife.POP_SWELL * pop)
			b.part.Transparency = b.seen + (1 - b.seen) * pop
		elseif b.part.Transparency ~= b.seen then
			b.part.Size = b.size
			b.part.Transparency = b.seen
		end
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	local stream, home = tub.stream, tub.streamHome
	if stream and home and not still then
		local k = 1 + TubLife.STREAM_WOBBLE * math.sin(now * math.pi * 2 * TubLife.STREAM_HZ)
		stream.Size = Vector3.new(home.X * k, home.Y, home.Z * k)
	end
	local ring, at = tub.ripple, tub.rippleAt
	if ring and at then
		if still then
			ring.Transparency = 1
		else
			local size, seen = TubLife.ripple(now)
			local w = TubLife.RIPPLE_WIDTH * tub.scale * size
			ring.Size = Vector3.new(0.04, w, w)
			ring.Transparency = 1 - 0.55 * seen
		end
	end
end

local started = false

function TubLife.start(isOn: () -> boolean)
	if started then
		return
	end
	started = true
	local function watch(d: Instance)
		if d.Name ~= TubLife.TUB_NAME or not d:IsA("Model") or tubs[d :: Model] then
			return
		end
		local model = d :: Model
		task.defer(function() -- its children arrive with it; wait a frame for the whole model
			if model.Parent == nil or tubs[model] then
				return
			end
			local tub = build(model)
			if tub then
				tubs[model] = tub
				model.Destroying:Once(function()
					tubs[model] = nil
				end)
			end
		end)
	end
	Workspace.DescendantAdded:Connect(watch)
	for _, d in Workspace:GetDescendants() do
		watch(d)
	end

	local was = false
	local clock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < TubLife.STEP then
			return
		end
		clock = 0
		local on = isOn()
		if not on then
			if was then
				was = false
				for _, tub in tubs do
					restore(tub)
				end
			end
			return
		end
		was = true
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		local still = Effects.reducedMotion()
		for model, tub in tubs do
			if model.Parent == nil then
				tubs[model] = nil
			elseif (model:GetPivot().Position - eye).Magnitude <= TubLife.FAR then
				if tub.ripple == nil and tub.stream then
					-- the switch went off and on: rebuild the ripple
					local fresh = build(model)
					if fresh then
						tubs[model] = fresh
						tub = fresh
					end
				end
				update(tub, now, still)
			end
		end
	end)
end

return TubLife
