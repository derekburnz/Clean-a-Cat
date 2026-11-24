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
--       origin: the box's landing spot on the pavement, LookVector across the road (the way the player faces).
--       options.shot: true takes the camera for a framed shot until BEATS.done (Derek's lean, option A); false
--       leaves the camera the player's (option B). Reduced Motion or Less shake always leaves it the player's.
--       options.onTap: called when the player taps the box or uses its prompt, once it has landed.
--   handle.open(onDone?)            flaps pop open, the kitten peeks out and shakes off mud; onDone when it is over
--   handle.hopOut(toward, onDone?)  the kitten hops out of the box toward a world point; onDone when he lands
--   Both onDone callbacks fire exactly once, deferred, even when the call does nothing (not landed yet, already
--   opened or hopping, no kitten, destroyed) or the scene is destroyed part way.
--   handle.destroy()   removes everything this scene made and gives the camera back
--
-- Props come from ReplicatedStorage.Assets by name (Model-Agent, #279 and #278); until they land, plain PH_ parts of
-- the same sizes and joint names stand in, so the scene can be checked today.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.Parent:WaitForChild("Audio"))
local CatMotion = require(script.Parent:WaitForChild("CatMotion"))
local Effects = require(script.Parent)
local TruckDrop = require(script.Parent:WaitForChild("TruckDrop"))

local TRUCK_ASSET = "CleanACat_Prop_DeliveryTruck"
local BOX_ASSET = "CleanACat_Prop_DeliveryBox"
local BUMP_ASSET = "CleanACat_Prop_SpeedBump"
local KITTEN_ASSETS = { "CleanACat_Cat_Suds_Dirty_Sit", "CleanACat_Cat_Suds_Dirty" }
local ASSET_WAIT_SECONDS = 3
local FOLDER_NAME = "CleanACat_OpeningScene"

-- Signs for the hinge turns, so a prop built the other way round is a one-character fix.
local DOOR_SIGN = -1 -- the rear door is hinged on its top edge and swings out behind the truck
local WHEEL_SIGN = -1 -- wheels roll forward (the truck's front is -Z)
local FLAP_SIGN = 1 -- each flap turns outward about its hinge edge

-- The shot camera, in scene space: behind and above the player, who stands about 6 studs behind the landing spot.
local SHOT_FROM = Vector3.new(0, 6, -11)
local SHOT_LOOK_Y = 1.5
local CHEST = 0.55 -- how far up a sitting cat its chest is, as a share of its height

export type Options = { shot: boolean?, onTap: (() -> ())? }
export type Handle = {
	box: Model,
	kitten: Model?,
	open: (onDone: (() -> ())?) -> (),
	hopOut: (toward: Vector3, onDone: (() -> ())?) -> (),
	destroy: () -> (),
}

type Joint = { instance: PVInstance, rest: CFrame }
type PartRest = { part: BasePart, offset: CFrame, size: Vector3 }

local OpeningScene = {}

local function keyOf(name: string, keys: { string }): string?
	for _, key in keys do
		if name == key or string.sub(name, -(#key + 1)) == "_" .. key then
			return key
		end
	end
	return nil
end

local function findAsset(names: { string }): Model?
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
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

function OpeningScene.play(origin: CFrame, options: Options?): Handle
	local opts: Options = options or {}
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

	local truck = clone({ TRUCK_ASSET }, placeholderTruck)
	makeClientOnly(truck)
	truck:PivotTo(CFrame.new(at(TruckDrop.truckX(0), 0, TruckDrop.ROAD_Z)) * truckFacing)
	local truckJoints = joints(truck, { "Door", "FL_Wheel", "FR_Wheel", "BL_Wheel", "BR_Wheel" })
	local doorScale = attributeNumber(truck, "DoorOpenDegrees", math.deg(TruckDrop.DOOR.open))
		/ math.deg(TruckDrop.DOOR.open)
	local wheelRadius = attributeNumber(truck, "WheelRadius", TruckDrop.WHEEL_RADIUS)
	truck.Parent = folder
	local truckBody: Instance? = truck.PrimaryPart

	local bumpAsset = findAsset({ BUMP_ASSET })
	if bumpAsset then
		local bump = bumpAsset:Clone() :: Model
		makeClientOnly(bump)
		bump:PivotTo(CFrame.new(at(TruckDrop.BUMP_X, 0, TruckDrop.ROAD_Z)) * truckFacing)
		bump.Parent = folder
	end

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
	local kittenHeight = 0
	local seat = findAttachment(box, "CatSeat")
	local peek = findAttachment(box, "Peek")

	folder.Parent = Workspace

	-- Sounds: the rumble follows the truck, the rest play where they happen.
	local rumble = Audio.loop("truckRumble", truckBody)

	local camera = Workspace.CurrentCamera
	local cameraType: Enum.CameraType? = nil
	if useShot and camera then
		cameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local function giveCameraBack()
		if cameraType and camera then
			camera.CameraType = cameraType
			cameraType = nil
		end
	end

	local started = os.clock()
	local last = -1
	local landed = false
	local opened: number? = nil
	local shookOff = false
	local hopping: { start: number, from: Vector3, to: Vector3, onDone: (() -> ())? }? = nil
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
			* CFrame.Angles(state.tumble, 0, state.roll)
			* half:Inverse()
	end

	local function stepTruck(t: number)
		local state = TruckDrop.truck(t, reduced)
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
		local roll = WHEEL_SIGN * (state.x - TruckDrop.truckX(0)) / wheelRadius
		for _, key in { "FL_Wheel", "FR_Wheel", "BL_Wheel", "BR_Wheel" } do
			local wheels: { Joint } = truckJoints[key] or {}
			for _, j in wheels do
				j.instance:PivotTo(truckCF * j.rest * CFrame.Angles(roll, 0, 0))
			end
		end
	end

	local function event(name: string)
		if name == "honk" then
			Audio.play("truckHonk", { at = truckBody })
		elseif name == "frontHit" or name == "backHit" then
			local x = TruckDrop.BUMP_X
			Audio.play(
				"truckBump",
				{ at = truckBody, variant = if name == "frontHit" then 1 else 2 }
			)
			Effects.burst("roadDust", at(x, 0.3, TruckDrop.ROAD_Z))
			if name == "backHit" then
				Audio.play("truckDoor", { at = truckBody })
			end
		elseif name == "land" then
			Audio.play("boxThud", { at = boxBody })
			Effects.burst("roadDust", at(0, 0.2, 0))
		elseif name == "settle" then
			Audio.play("boxThud", { at = boxBody, pitch = 1.25 })
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
		if cat and seat and hopping == nil then
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

	local function hopStep()
		local hop = hopping
		local cat = kitten
		if hop == nil or cat == nil then
			return
		end
		local e = os.clock() - hop.start
		local along, height = TruckDrop.hop(e, reduced)
		local pos = hop.from:Lerp(hop.to, along) + up * height
		local flat = (hop.to - hop.from) * (Vector3.one - up)
		local facing = if flat.Magnitude > 0.01 then flat.Unit else -across
		cat:PivotTo(CFrame.lookAt(pos, pos + facing, up))
		if e >= TruckDrop.HOP.seconds and hop.onDone then
			local done = hop.onDone
			hop.onDone = nil
			Audio.play("boxThud", { at = cat.PrimaryPart :: Instance?, pitch = 1.6 })
			done()
		end
	end

	local function frame()
		local t = os.clock() - started
		for _, name in TruckDrop.eventsBetween(last, t) do
			event(name)
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
			hopStep()
		else
			local state = TruckDrop.box(t, reduced)
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

		if cameraType and camera then
			if t >= TruckDrop.BEATS.done then
				giveCameraBack()
			else
				local look = at(TruckDrop.lookX(t), SHOT_LOOK_Y, TruckDrop.ROAD_Z * 0.45)
				camera.CFrame = CFrame.lookAt(at(SHOT_FROM.X, SHOT_FROM.Y, SHOT_FROM.Z), look)
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
		hopOut = function(toward: Vector3, onDone: (() -> ())?)
			local cat = kitten
			if cat == nil or destroyed or hopping then
				if onDone then
					task.defer(onDone) -- nothing to hop: still answer, so a caller never hangs
				end
				return
			end
			local from = cat:GetPivot().Position
			local flat = (toward - from) * (Vector3.one - up)
			local dir = if flat.Magnitude > 0.01 then flat.Unit else -across
			-- lands on the pavement (the landing spot's height), a hop's length toward the target
			local ground = from - up * up:Dot(from - origin.Position)
			hopping = {
				start = os.clock(),
				from = from,
				to = ground + dir * TruckDrop.HOP.distance,
				onDone = onDone,
			}
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			local hop = hopping
			if hop and hop.onDone then
				task.defer(hop.onDone) -- destroyed mid-hop: the caller still hears back
				hop.onDone = nil
			end
			if connection then
				connection:Disconnect()
			end
			rumble.stop()
			giveCameraBack()
			folder:Destroy()
		end,
	}

	connection = RunService.PreRender:Connect(frame)
	return handle
end

return OpeningScene
