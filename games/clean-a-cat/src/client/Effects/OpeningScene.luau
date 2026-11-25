--!strict
-- OpeningScene: plays the opening's truck and box drop on this client only (issue #281, Design-Agent's
-- opening-and-tutorial-plan 2026-11-24). The curves and every beat live in Effects/TruckDrop; this module clones the
-- props, pivots them each frame, plays the sounds and dust, and runs the short camera shot.
--
-- Nothing here replicates: other players never see the truck. It never decides anything either. When the scene
-- plays (once per save, the resume rules) and what opening the box does on the server are Gameplay's; they call
-- play() and open().
--
-- API
--   OpeningScene.play(origin, options?) -> Handle
--       origin: the box's landing spot on the pavement (the plot's SpotBox, set to one side of the player so their
--       avatar does not hide it), LookVector across the road (the way the player faces). The box lands exactly there.
--       options.shot: true takes the camera for a framed shot until BEATS.done (Derek picked option A 2026-11-24: the default); false
--       leaves the camera the player's (option B). Reduced Motion or Less shake always leaves it the player's.
--       options.onTap: called when the player taps the box or uses its prompt, once it has landed.
--       options.bump: the speed bump's world position. Left out, the scene uses the plot's SpotBump when the player
--       is on a plot, else TruckDrop.BUMP_X. The truck's jolt is timed to it, so it hits the bump the player sees,
--       and a pothole (CleanACat_Prop_Pothole) is laid there if the road has none.
--   handle.open(onDone?)            flaps pop open, the kitten peeks out and shakes off mud; onDone when it is over
--   handle.pickUp(character, onDone?)  the player bends and reaches into the box, then lifts the kitten into their
--                                   arms (Effects/Carry), with a purr; he stays in their arms as they walk. Call it
--                                   once the player stands at the box facing it. onDone once he is in them
--                                   (Carry.settleSeconds(true) later).
--                                   He becomes the loaf body as he leaves the box, so handle.kitten changes here
--   handle.placeIn(target, onDone?, endScale?) the arms open and the carried kitten hops in, his base on `target`
--                                   (the tub's seat), easing to `endScale` (the tub body's size); onDone when he lands. Then Gameplay eases into the wash (Effects/WashCamera)
--   Derek 2026-11-24 picked the carry over the hop-out ("we should pick him up out of crate"), so the hop out of the
--   box is gone; Carry's own hop into the tub keeps TruckDrop.HOP's timing.
--   Both onDone callbacks fire exactly once, deferred, even when the call does nothing (not landed yet, already
--   opened or carried, no kitten, destroyed) or the scene is destroyed part way.
--   handle.destroy()   removes everything this scene made and gives the camera back
--
-- Props come from ReplicatedStorage.Assets by name (Model-Agent, #279 and #278); until they land, plain PH_ parts of
-- the same sizes and joint names stand in, so the scene can be checked today.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.Parent:WaitForChild("Audio"))
local Carry = require(script.Parent:WaitForChild("Carry"))
local CatMotion = require(script.Parent:WaitForChild("CatMotion"))
local Effects = require(script.Parent)
local TruckDrop = require(script.Parent:WaitForChild("TruckDrop"))

local TRUCK_ASSET = "CleanACat_Prop_DeliveryTruck"
local BOX_ASSET = "CleanACat_Prop_DeliveryBox"
local KITTEN_ASSETS = { "CleanACat_Cat_Suds_Dirty_Sit", "CleanACat_Cat_Suds_Dirty" }
local LOAF_ASSET = "CleanACat_Cat_Suds_Dirty_Loaf" -- the held body: legs tucked, carried across the arms
local FOLDER_NAME = "CleanACat_OpeningScene"
local BUMP_ASSET = "CleanACat_Prop_Pothole" -- Model-Agent's pothole (Derek: "speed bump should be changed to pothole"); long side its X
local BUMP_NAME = "CleanACat_OpeningPothole" -- the copy this client lays on the road, kept after the scene

-- Signs for the hinge turns, so a prop built the other way round is a one-character fix.
local DOOR_SIGN = -1 -- the rear door is hinged on its top edge and swings out behind the truck
local WHEEL_SIGN = -1 -- wheels roll forward (the truck's front is -Z)
local FLAP_SIGN = 1 -- each flap turns outward about its hinge edge

-- The shot camera, in scene space: behind and above the player, who stands about 6 studs behind the landing spot.
local SHOT_FROM = Vector3.new(0, 6, -11)
local SHOT_LOOK_Y = 1.5
local MAX_STEP = 0.1 -- the most the scene's clock moves on in one frame
local STALL = 0.25 -- a frame longer than this is a stall (nothing drawn): the clock does not move on at all
local CHEST = 0.55 -- how far up a sitting cat its chest is, as a share of its height

export type Options = { shot: boolean?, onTap: (() -> ())?, bump: Vector3? }
export type Handle = {
	box: Model,
	kitten: Model?,
	open: (onDone: (() -> ())?) -> (),
	pickUp: (character: Model, onDone: (() -> ())?) -> (),
	placeIn: (target: Vector3, onDone: (() -> ())?, endScale: number?) -> (),
	destroy: () -> (),
}

type Joint = { instance: PVInstance, rest: CFrame }
type PartRest = { part: BasePart, offset: CFrame, size: Vector3 }

local OpeningScene = {}

OpeningScene.BUMP_NAME = BUMP_NAME -- Gameplay clears it once Suds is inside

local function keyOf(name: string, keys: { string }): string?
	for _, key in keys do
		if name == key or string.sub(name, -(#key + 1)) == "_" .. key then
			return key
		end
	end
	return nil
end

-- Never waits: the scene starts the moment the save loads, so a prop not replicated yet is a PH_ stand-in at once
-- (the props are plain Parts, so they are normally there with the place).
local function findAsset(names: { string }): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end
	for _, name in names do
		local found = assets:FindFirstChild(name, true)
		if found and found:IsA("Model") then
			return found :: Model
		end
	end
	return nil
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function hinged(parent: Instance, name: string, pivot: CFrame): Model
	local m = Instance.new("Model")
	m.Name = name
	m.WorldPivot = pivot
	m.Parent = parent
	return m
end

-- Placeholders with Model-Agent's sizes and joint names (front -Z, pivot on the ground under the middle).
local function placeholderTruck(): Model
	local truck = Instance.new("Model")
	truck.Name = "PH_DeliveryTruck"
	local cream = Color3.fromRGB(250, 236, 214)
	local mint = Color3.fromRGB(170, 222, 200)
	local body = part(truck, "PH_Body", Vector3.new(6, 5.6, 9), CFrame.new(0, 4.6, 2), cream)
	part(truck, "PH_Cab", Vector3.new(6, 4.2, 3.6), CFrame.new(0, 3.3, -4.7), mint)
	truck.PrimaryPart = body
	local tailgate = Instance.new("Attachment")
	tailgate.Name = "Tailgate"
	tailgate.Position = Vector3.new(0, 1.9 - 4.6, 4.5)
	tailgate.Parent = body
	local door = hinged(truck, "PH_Door", CFrame.new(0, 7.4, 6.55))
	part(door, "PH_DoorPanel", Vector3.new(5.6, 5.4, 0.15), CFrame.new(0, 4.7, 6.55), mint)
	local wheels = {
		{ name = "FL", x = -2.6, z = -4 },
		{ name = "FR", x = 2.6, z = -4 },
		{ name = "BL", x = -2.6, z = 4 },
		{ name = "BR", x = 2.6, z = 4 },
	}
	for _, w in wheels do
		local axle = CFrame.new(w.x, 1.1, w.z)
		local wheel = hinged(truck, "PH_" .. w.name .. "_Wheel", axle)
		local tyre =
			part(wheel, "PH_Tyre", Vector3.new(0.8, 2.2, 2.2), axle, Color3.fromRGB(70, 66, 74))
		tyre.Shape = Enum.PartType.Cylinder
	end
	truck.WorldPivot = CFrame.identity
	return truck
end

local function placeholderBox(): Model
	local box = Instance.new("Model")
	box.Name = "PH_DeliveryBox"
	local brown = Color3.fromRGB(196, 150, 104)
	local body = part(box, "PH_Body", Vector3.new(2.4, 1.8, 2.4), CFrame.new(0, 0.9, 0), brown)
	box.PrimaryPart = body
	for _, spot in { { name = "CatSeat", y = -0.85 }, { name = "Peek", y = 0.9 } } do
		local a = Instance.new("Attachment")
		a.Name = spot.name
		a.Position = Vector3.new(0, spot.y, 0)
		a.Parent = body
	end
	local flapColor = Color3.fromRGB(206, 162, 116)
	-- Each flap's pivot sits on its hinge edge with local Z along the hinge and local +X pointing into the box, so
	-- turning about local Z swings it up and out.
	for _, f in { { name = "FlapL", x = -1.2 }, { name = "FlapR", x = 1.2 } } do
		local hinge = CFrame.new(f.x, 1.8, 0) * CFrame.Angles(0, if f.x < 0 then 0 else math.pi, 0)
		local flap = hinged(box, "PH_" .. f.name, hinge)
		part(
			flap,
			"PH_FlapPanel",
			Vector3.new(1.2, 0.08, 2.4),
			hinge * CFrame.new(0.6, 0.04, 0),
			flapColor
		)
	end
	box.WorldPivot = CFrame.identity
	return box
end

local function placeholderKitten(): Model
	local cat = Instance.new("Model")
	cat.Name = "PH_Kitten"
	local black = Color3.fromRGB(46, 44, 52)
	local body = part(cat, "PH_Body", Vector3.new(1.1, 1, 1.4), CFrame.new(0, 0.5, 0), black)
	local head = hinged(cat, "PH_Head", CFrame.new(0, 1.1, -0.5))
	part(head, "PH_HeadBall", Vector3.new(1, 0.9, 0.9), CFrame.new(0, 1.35, -0.55), black)
	cat.PrimaryPart = body
	cat.WorldPivot = CFrame.identity
	cat:SetAttribute("Cat", "Suds")
	return cat
end

local function clone(names: { string }, fallback: () -> Model): Model
	local asset = findAsset(names)
	return if asset then asset:Clone() :: Model else fallback()
end

local function makeClientOnly(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

-- Joints by name suffix, with rest offsets from the model's pivot, taken before anything moves.
local function joints(model: Model, keys: { string }): { [string]: { Joint } }
	local found: { [string]: { Joint } } = {}
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if
			d:IsA("PVInstance") and not d:IsA("BasePart")
			or (d:IsA("BasePart") and d.Parent == model)
		then
			local key = keyOf(d.Name, keys)
			if key and key ~= "Body" then
				local list = found[key] or {}
				found[key] = list
				table.insert(list, {
					instance = d :: PVInstance,
					rest = pivot:ToObjectSpace((d :: PVInstance):GetPivot()),
				})
			end
		end
	end
	return found
end

local function partRests(model: Model): { PartRest }
	local list: { PartRest } = {}
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			table.insert(list, { part = p, offset = pivot:ToObjectSpace(p.CFrame), size = p.Size })
		end
	end
	return list
end

local function attributeNumber(model: Model, name: string, default: number): number
	local value = model:GetAttribute(name)
	return if type(value) == "number" and value > 0 then value else default
end

local function findAttachment(model: Model, name: string): Attachment?
	local a = model:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a :: Attachment else nil
end

-- Writes each box part squashed about the box's pivot (its bottom centre). Volume is kept: the width grows as the
-- height falls. Only called while the flaps are shut, when every part is aligned with the box.
local function squashBox(rests: { PartRest }, boxCF: CFrame, squash: number)
	local wide = 1 / math.sqrt(squash)
	for _, r in rests do
		local o = r.offset
		r.part.Size = Vector3.new(r.size.X * wide, r.size.Y * squash, r.size.Z * wide)
		r.part.CFrame = boxCF * CFrame.new(o.X * wide, o.Y * squash, o.Z * wide) * o.Rotation
	end
end

-- The plot's SpotBump (a CFrame: on the road top, its X across the lane) while the player is on a plot, else nil.
-- Read lazily and guarded, so the scene still plays (with BUMP_X) if the layout module is missing.
local function plotBump(): CFrame?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("SpaLayout")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, found = pcall(function(): CFrame?
		local SpaLayout = require(module) :: any
		if SpaLayout.onPlot() and SpaLayout.PLOT_SPOTS.SpotBump then
			return SpaLayout.spot("SpotBump") :: CFrame
		end
		return nil
	end)
	return if ok then found else nil
end

-- How far along the road (scene +X) the bump sits from the box's landing spot, or nil when there is no bump.
local function bumpOffset(origin: CFrame, bump: Vector3?): number?
	local spot = plotBump()
	local world = bump or (if spot then spot.Position else nil)
	if world == nil then
		return nil
	end
	return (world - origin.Position):Dot(origin.RightVector)
end

-- Lays the pothole on the road where the truck jolts (Derek's dev tests: "no bump in road was there", then "speed
-- bump should be changed to pothole"). Nothing in the world places one yet, so this client puts its own copy there
-- once and keeps it after the scene; one already on the road (the last play's copy) is moved, not doubled. `cframe`
-- is its place: on the road top, its X across the lane.
local function layBump(cframe: CFrame)
	local existing = Workspace:FindFirstChild(BUMP_NAME)
	if existing and existing:IsA("Model") then
		existing:PivotTo(cframe)
		return
	end
	local bump: Model
	local asset = findAsset({ BUMP_ASSET })
	if asset then
		bump = asset:Clone() :: Model
	else
		bump = Instance.new("Model")
		local hole = part(
			bump,
			"PH_Pothole",
			Vector3.new(3.2, 0.04, 2.2),
			CFrame.new(0, 0.02, 0),
			Color3.fromRGB(46, 42, 48)
		)
		bump.PrimaryPart = hole
		bump.WorldPivot = CFrame.identity
	end
	makeClientOnly(bump)
	bump.Name = BUMP_NAME
	bump:PivotTo(cframe)
	bump.Parent = Workspace
end

function OpeningScene.play(origin: CFrame, options: Options?): Handle
	local opts: Options = options or {}
	Audio.start() -- safe to call twice; the truck's sounds play even before AudioController has started
	local reduced = Effects.reducedMotion()
	local useShot = opts.shot == true and not reduced

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	-- Scene space to world: +X the way the truck drives, +Y up, +Z across the road.
	local right, up, across = origin.RightVector, origin.UpVector, origin.LookVector
	local function at(x: number, y: number, z: number): Vector3
		return origin.Position + right * x + up * y + across * z
	end
	-- Facing +X for the truck (its front is -Z), facing the player for the box.
	local truckFacing = CFrame.lookAt(Vector3.zero, right, up)
	local boxFacing = CFrame.lookAt(Vector3.zero, across, up)

	local bumpX = TruckDrop.bumpAt(bumpOffset(origin, opts.bump))
	local spot = if opts.bump == nil then plotBump() else nil
	if spot and math.abs((spot.Position - origin.Position):Dot(right) - bumpX) < 0.01 then
		layBump(spot)
	else
		-- on the road under the truck's lane, its X across the road
		layBump(CFrame.fromMatrix(at(bumpX, 0, TruckDrop.ROAD_Z), across, up))
	end

	local truck = clone({ TRUCK_ASSET }, placeholderTruck)
	makeClientOnly(truck)
	truck:PivotTo(CFrame.new(at(TruckDrop.truckX(0, bumpX), 0, TruckDrop.ROAD_Z)) * truckFacing)
	local truckJoints = joints(truck, { "Door", "FL_Wheel", "FR_Wheel", "BL_Wheel", "BR_Wheel" })
	local doorScale = attributeNumber(truck, "DoorOpenDegrees", math.deg(TruckDrop.DOOR.open))
		/ math.deg(TruckDrop.DOOR.open)
	local wheelRadius = attributeNumber(truck, "WheelRadius", TruckDrop.WHEEL_RADIUS)
	truck.Parent = folder
	local truckBody: Instance? = truck.PrimaryPart

	local box = clone({ BOX_ASSET }, placeholderBox)
	makeClientOnly(box)
	box:PivotTo(CFrame.new(at(0, -50, 0)) * boxFacing)
	local boxRests = partRests(box)
	local flaps = joints(box, { "FlapL", "FlapR", "FlapF", "FlapB" })
	-- The props can carry their own open angles and wheel size (Model-Agent's root attributes); the curves keep
	-- their shape and are scaled to them.
	local flapScale = attributeNumber(box, "FlapOpenDegrees", math.deg(TruckDrop.OPEN.flap))
		/ math.deg(TruckDrop.OPEN.flap)
	local _, boxSize = box:GetBoundingBox()
	local boxHeight = boxSize.Y
	local boxBody: Instance? = box.PrimaryPart

	local kitten: Model? = nil
	local carry: Carry.Handle? = nil
	local kittenHeight = 0
	local seat = findAttachment(box, "CatSeat")
	local peek = findAttachment(box, "Peek")

	folder.Parent = Workspace

	-- Sounds: the rumble follows the truck, the rest play where they happen.
	local rumble = Audio.loop("truckRumble", truckBody)

	-- The shot can start before the player's first spawn, so it never trusts what it found: it holds the camera
	-- (re-taking it if a spawn resets it mid-shot) and always hands back the default Custom camera on the player's
	-- own Humanoid (Review-QA on #314).
	-- The scene's own clock: it moves on by at most MAX_STEP a frame, so a long first frame while the place streams in
	-- (Sync-Agent measured up to 0.86 s on a phone-like run) pauses the scene instead of skipping its beats.
	local clock = 0
	local lastFrame = os.clock()
	-- It also holds at 0 until the game has finished loading: Sync-Agent saw short frames with nothing drawn for up to
	-- 1.46 s after the start, the truck model already there, so the first frame seen had it 12 studs into its drive.
	local loaded = game:IsLoaded()
	local holdingShot = useShot and Workspace.CurrentCamera ~= nil
	local function shotCamera(): Camera?
		local cam = Workspace.CurrentCamera -- re-read: a respawn can replace it
		if cam and cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable
		end
		return cam
	end
	if holdingShot then
		shotCamera()
	end
	-- `why` names what ended the shot (it went to the output for Sync-Agent's speed runs; taken out before live).
	local function giveCameraBack(_why: string)
		if not holdingShot then
			return
		end
		holdingShot = false
		local cam = Workspace.CurrentCamera
		if cam == nil then
			return
		end
		local player = Players.LocalPlayer
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			cam.CameraSubject = humanoid :: Humanoid
		end
		cam.CameraType = Enum.CameraType.Custom
	end

	local last = -1
	local landed = false
	local opened: number? = nil
	local shookOff = false
	local lastWiggle: number? = nil
	local destroyed = false
	local connection: RBXScriptConnection? = nil

	local prompt: ProximityPrompt? = nil
	local click: ClickDetector? = nil
	local function tapped()
		if landed and opened == nil and opts.onTap then
			opts.onTap()
		end
	end

	local function boxCFrame(state: TruckDrop.Box): CFrame
		local half = CFrame.new(0, boxHeight / 2, 0)
		return CFrame.new(at(state.x, state.y, state.z))
			* boxFacing
			* half
			-- TruckDrop's roll turns the top toward +X (the way it travels); the box faces across the road, so its own
			-- X is the scene's +X and a turn about its Z by -roll does that (by +roll it spun backwards, Derek's dev
			-- test: "bounces backwards when it should tumble forwards")
			* CFrame.Angles(state.tumble, 0, -state.roll)
			* half:Inverse()
	end

	local function stepTruck(t: number)
		local state = TruckDrop.truck(t, reduced, bumpX)
		local truckCF = CFrame.new(at(state.x, state.lift, TruckDrop.ROAD_Z))
			* truckFacing
			* CFrame.Angles(state.pitch, 0, 0)
		truck:PivotTo(truckCF)
		local doors: { Joint } = truckJoints.Door or {}
		for _, j in doors do
			j.instance:PivotTo(
				truckCF * j.rest * CFrame.Angles(DOOR_SIGN * state.door * doorScale, 0, 0)
			)
		end
		local roll = WHEEL_SIGN * (state.x - TruckDrop.truckX(0, bumpX)) / wheelRadius
		for _, key in { "FL_Wheel", "FR_Wheel", "BL_Wheel", "BR_Wheel" } do
			local wheels: { Joint } = truckJoints[key] or {}
			for _, j in wheels do
				j.instance:PivotTo(truckCF * j.rest * CFrame.Angles(roll, 0, 0))
			end
		end
	end

	local function event(name: string, t: number)
		if name == "honk" then
			Audio.play("truckHonk", { at = truckBody })
		elseif name == "frontHit" or name == "backHit" then
			local x = bumpX
			Audio.play(
				"truckBump",
				{ at = truckBody, variant = if name == "frontHit" then 1 else 2 }
			)
			Effects.burst("roadDust", at(x, 0.3, TruckDrop.ROAD_Z))
			if name == "frontHit" then
				Audio.play("truckDoor", { at = truckBody }) -- the jolt kicks the back door open
			end
		elseif name == "doorSlam" then
			Audio.play("truckDoor", { at = truckBody, pitch = 0.8 })
		elseif name == "land" or name == "tumble" or name == "settle" then
			-- a thud and a puff where it comes down: hard on the first hit, lighter as it rolls, a slap as it stops
			local state = TruckDrop.box(t, reduced, bumpX)
			local pitch = if name == "land" then 1 elseif name == "tumble" then 1.1 else 1.25
			Audio.play("boxThud", { at = boxBody, pitch = pitch })
			if name ~= "tumble" then
				Effects.burst("roadDust", at(state.x, 0.2, state.z))
			end
		end
	end

	local function openStep(e: number)
		local flap, rise = TruckDrop.open(e, reduced)
		local under = TruckDrop.open(e - TruckDrop.OPEN.stagger, reduced)
		local boxCF =
			boxCFrame({ x = 0, y = 0, z = 0, tumble = 0, roll = 0, squash = 1, visible = true })
		for key, list in flaps do
			local angle = FLAP_SIGN
				* flapScale
				* (if key == "FlapF" or key == "FlapB" then under else flap)
			for _, j in list do
				j.instance:PivotTo(boxCF * j.rest * CFrame.Angles(0, 0, angle))
			end
		end
		local cat = kitten
		if cat and seat and carry == nil then
			-- The chest (about CHEST of the cat's height) rises to the rim's Peek point.
			local rim = if peek
				then (peek.WorldPosition - seat.WorldPosition).Magnitude
				else boxHeight
			local lift = math.max(0, rim - kittenHeight * CHEST)
			cat:PivotTo(
				CFrame.new(seat.WorldPosition + up * lift * rise)
					* CFrame.lookAt(Vector3.zero, -across, up)
			)
		end
		if not shookOff and e >= TruckDrop.openSeconds() then
			shookOff = true
			if cat then
				CatMotion.shake(cat)
				Audio.play("catShake", { at = cat.PrimaryPart :: Instance? })
				Effects.burst("mudChunks", (cat:GetBoundingBox()).Position)
			end
		end
	end

	local function frame()
		local now = os.clock()
		if not loaded then
			loaded = game:IsLoaded()
			lastFrame = now
		end
		local dt = now - lastFrame
		if dt <= STALL then
			clock += math.min(dt, MAX_STEP)
		end
		lastFrame = now
		local t = clock
		for _, name in TruckDrop.eventsBetween(last, t) do
			event(name, t)
		end
		last = t
		if t <= TruckDrop.BEATS.done + 0.5 then
			stepTruck(t)
		elseif truck.Parent then
			truck.Parent = nil
			rumble.stop()
		end

		if opened then
			openStep(os.clock() - opened)
		else
			local state = TruckDrop.box(t, reduced, bumpX)
			if state.visible then
				if box.Parent == nil then
					box.Parent = folder -- only once it leaves the truck
				end
				local cf = boxCFrame(state)
				if state.squash ~= 1 or not landed then
					squashBox(boxRests, cf, state.squash)
				else
					box:PivotTo(cf)
				end
			end
			if not landed and t >= TruckDrop.BEATS.settle then
				landed = true
				squashBox(boxRests, boxCFrame(state), 1)
				local p = Instance.new("ProximityPrompt")
				p.ActionText = "Open!"
				p.ObjectText = ""
				p.HoldDuration = 0
				p.RequiresLineOfSight = false
				p.MaxActivationDistance = 14
				p.Triggered:Connect(tapped)
				p.Parent = boxBody or box
				prompt = p
				local c = Instance.new("ClickDetector")
				c.MaxActivationDistance = 40
				c.MouseClick:Connect(tapped)
				c.Parent = box
				click = c
			end
			local n = TruckDrop.wiggleIndex(t)
			if n and n ~= lastWiggle then
				lastWiggle = n
				Audio.play("boxRustle", { at = boxBody })
				if TruckDrop.wiggleMeows(n) then
					Audio.play("meow", { at = boxBody, variant = 2 })
				end
			end
		end

		if holdingShot then
			local cam = if t >= TruckDrop.BEATS.done then nil else shotCamera()
			if cam == nil then
				giveCameraBack(if t >= TruckDrop.BEATS.done then "shot over" else "no camera")
			else
				local look = at(TruckDrop.lookX(t, bumpX), SHOT_LOOK_Y, TruckDrop.ROAD_Z * 0.45)
				cam.CFrame = CFrame.lookAt(at(SHOT_FROM.X, SHOT_FROM.Y, SHOT_FROM.Z), look)
			end
		end
	end

	local handle: Handle
	handle = {
		box = box,
		kitten = nil :: Model?,
		open = function(onDone: (() -> ())?)
			-- onDone always fires exactly once, even when there is nothing to open, so a caller never hangs.
			if opened or destroyed or not landed then
				if onDone then
					task.defer(onDone)
				end
				return
			end
			if onDone then
				task.delay(TruckDrop.openDoneSeconds(), onDone)
			end
			opened = os.clock()
			if prompt then
				prompt:Destroy()
			end
			if click then
				click:Destroy()
			end
			local cat = clone(KITTEN_ASSETS, placeholderKitten)
			makeClientOnly(cat)
			cat.Parent = folder
			local _, catSize = cat:GetBoundingBox()
			kittenHeight = catSize.Y
			kitten = cat
			handle.kitten = cat
			openStep(0)
			Audio.play("meow", { at = cat.PrimaryPart :: Instance?, variant = 2 })
		end,
		pickUp = function(character: Model, onDone: (() -> ())?)
			local cat = kitten
			if cat == nil or destroyed or carry then
				if onDone then
					task.defer(onDone) -- nothing to pick up: still answer, so a caller never hangs
				end
				return
			end
			-- He leaves the box as the loaf body (Model-Agent's #323) when it is there, base where the sitting one's was,
			-- so the lift starts in the box; the sitting body (and anything parented to it) goes. Else he stays sitting.
			-- Only under Derek's hold (its switch): the first, crossed hold stays as tested, with the sitting body.
			local loafAsset = if Carry.holdPose() == Carry.POSE
				then findAsset({ LOAF_ASSET })
				else nil
			local held: Carry.Held = "sit"
			if loafAsset then
				local loaf = loafAsset:Clone() :: Model
				makeClientOnly(loaf)
				loaf:PivotTo(cat:GetPivot())
				local sitBox, sitSize = cat:GetBoundingBox()
				local loafBox, loafSize = loaf:GetBoundingBox()
				local drop = (sitBox.Position.Y - sitSize.Y / 2)
					- (loafBox.Position.Y - loafSize.Y / 2)
				loaf:PivotTo(cat:GetPivot() + Vector3.yAxis * drop)
				loaf.Parent = folder
				cat:Destroy()
				cat = loaf
				kitten = loaf
				handle.kitten = loaf
				held = "loaf"
			end
			-- he bends and reaches into the box first, then lifts Suds into his arms (Derek's dev test)
			carry = Carry.hold(character, cat, held, true)
			if onDone then
				task.delay(Carry.settleSeconds(true), onDone)
			end
		end,
		placeIn = function(target: Vector3, onDone: (() -> ())?, endScale: number?)
			local held = carry
			if held == nil or destroyed then
				if onDone then
					task.defer(onDone)
				end
				return
			end
			held.placeIn(target, onDone, endScale)
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			if carry then
				carry.destroy() -- the arms go back and a pending placeIn still hears back
			end
			if connection then
				connection:Disconnect()
			end
			rumble.stop()
			giveCameraBack("scene ended early")
			folder:Destroy()
		end,
	}

	connection = RunService.PreRender:Connect(frame)
	return handle
end

return OpeningScene
