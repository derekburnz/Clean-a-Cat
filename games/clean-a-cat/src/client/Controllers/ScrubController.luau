--!strict
-- ScrubController: one cat's visit on the player's own device. The server (SpaService) hands out a cat; the player
-- scrubs the mud off (80% clean pops the rest), brushes the tangles out in three strokes, taps one of three bows
-- and taps the camera for the photo, which the server pays. Rules live in Shared.ScrubRules and Shared.SpaRules;
-- effects and sound listen to Shared.Moments. Behind the LiveFlags switch `scrubPrototype`.
--
-- The cat is Model-Agent's dirty cat from ReplicatedStorage.Assets (see assets/clean-a-cat/blender/README.md):
-- every nested Model named `..._MudNN` is one scrub patch and every `..._TangleNN` is brushed out. It sits on
-- the wash tub's CatSeat attachment. The bow and the buttons are still placeholders.
--
-- Input: a finger drag or a held left mouse button on the cat scrubs and brushes; a tap or click on a bow or the
-- camera picks it. Gamepad: hold the right trigger with the cat in the middle of the screen and turn the camera
-- with the right stick; the right trigger also picks the bow or camera in the middle of the screen.
-- The client only reports what the player did. The server checks every step and alone decides the coins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BowFit = require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("BowFit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScrubRules = require(Shared:WaitForChild("ScrubRules"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))

local FLAG = "scrubPrototype"
local TOOLS_FLAG = "toolsBoard" -- owned tools (Bubble Soap) widen the sponge only while this is on
local TURN_FLAG = "scrubTurn" -- the cat turns to show its muddy side when too little faces the camera
local TURN_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local DRY_FLAG = "stations" -- with the Blow Dryer built, a fluffed cat sits on its stool before the bows
local DRY_SECONDS = 2.5
local CAT_ASSET = "CleanACat_Cat_Smudge_Dirty_Sit" -- the prototype's cat; a customer's cat uses its own kind
local TUB_ASSET = "CleanACat_Station_Tub"
local CAT_SCALE = 1.5 -- Model-Agent's size for a cat sitting in the tub
local ASSET_WAIT_SECONDS = 5
local WET_DARKEN = 0.3 -- used when the cat has no WetDarken attribute
local SEAT_HEIGHT = 1.2 -- the tub's inner floor, used when the tub has no CatSeat attachment
local BOW_SIZE = Vector3.new(0.5, 0.25, 0.15) -- studs at scale 1; the stand-in when a bow model is missing
local PIECE_FADE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- mud and tangles fade, not blink
local STROKE_TRAVEL = 2.5 -- studs of drag on the cat that make one brush stroke
local NEXT_CAT_SECONDS = 3 -- after the photo pays, the next cat is asked for
local LEAVE_SECONDS = 1.2 -- after the photo, the cat leaves: home with its owner or into the window
local RESEND_SECONDS = 2 -- the newest report is sent again when the server has not answered it by then
local RESEND_TRIES = 3
local GAMEPAD_BUTTON = Enum.KeyCode.ButtonR2 -- not ButtonA, which jumps
local BUTTON_COLOR = Color3.fromRGB(205, 205, 210)
local BOW_COLORS: { [string]: Color3 } = {
	BowPink = Color3.fromRGB(255, 150, 190),
	BowMint = Color3.fromRGB(150, 225, 190),
	BowSky = Color3.fromRGB(140, 195, 245),
}

type Stage = "waiting" | SpaRules.Stage

-- One mud blob or tangle: a nested Model of the cat.
type Piece = {
	model: Model,
	parts: { BasePart },
	position: Vector3,
}

-- The cat in the tub, cloned fresh for every visit.
type Cat = {
	model: Model,
	mud: { Piece }, -- in name order; patch index i is mud[i]
	tangles: { Piece }, -- in name order; brushed out from the first
	fluff: { Piece }, -- fur puffs, hidden until the cat is fluffed; never caught by a ray
	coat: { [BasePart]: Color3 }, -- dry colours of the coat, to undo the wet look
	wetDarken: number,
	bow: BasePart, -- the stand-in bow, shown only when the picked bow's model cannot be worn
}

type Visit = {
	folder: Folder,
	seat: CFrame?, -- where the cat sits, once the tub is in
	cat: Cat?,
	bowButtons: { BasePart },
	camera: BasePart,
	scrub: ScrubRules.State,
	catParams: RaycastParams,
	buttonParams: RaycastParams,
	catId: number?,
	stage: Stage,
	strokes: number,
	strokeTravel: number,
	lastStrokeAt: number,
}

type Args = { n: number, [number]: any }

local ScrubController = {}

local visit: Visit? = nil
local enabled = false
local activeInput: InputObject? = nil -- the one press (mouse button, finger or trigger) on the cat
local stroking = false -- the active press is on the cat right now
local lastHit: Vector3? = nil
local lastMoveTime = 0
local savedCameraType: Enum.CameraType? = nil
local connections: { RBXScriptConnection } = {}
local nextCatThread: thread? = nil
local reportedScrub = false -- the funnel's first_scrub was sent this session
local turningCat: Model? = nil -- the cat turning in the tub; the sponge waits until it stops
local reportSeq = 0 -- numbers each spa report; the server echoes it in CatStage
local answeredSeq = 0 -- the newest report the server has answered
local warnedMissing: { [string]: boolean } = {}

-- Sends one numbered spa report. If the server has not answered it after RESEND_SECONDS (its rate limit may have
-- dropped it) and nothing newer was sent, it is sent again under a new number, up to RESEND_TRIES times.
local function send(name: string, catId: number?, args: Args, triesLeft: number)
	reportSeq += 1
	local seq = reportSeq
	Remotes.event(name):FireServer(catId, seq, table.unpack(args, 1, args.n))
	if triesLeft <= 0 then
		return
	end
	task.delay(RESEND_SECONDS, function()
		local v = visit
		if reportSeq == seq and answeredSeq < seq and v and v.catId == catId then
			send(name, catId, args, triesLeft - 1)
		end
	end)
end

-- Sends one spa report for the visit's cat; only the server's answer to the newest report is acted on.
local function report(name: string, v: { catId: number? }, ...: any)
	send(name, v.catId, table.pack(...), RESEND_TRIES)
end

local function makePart(name: string, size: Vector3, color: Color3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function show(part: BasePart, visible: boolean)
	part.Transparency = if visible then 0 else 1
	part.CanQuery = visible
end

local function partsOf(model: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant :: BasePart)
		end
	end
	return parts
end

-- The wash tub at SpotTub, facing the spawn. Returns where the cat sits: the tub's CatSeat attachment.
local function buildTub(asset: Model, parent: Instance): CFrame
	local tub = asset:Clone() :: Model
	tub:PivotTo(SpaLayout.spot("SpotTub")) -- the pivot is the base centre on the floor
	for _, part in partsOf(tub) do
		part.Anchored = true
	end
	-- Water and foam never catch a ray, so only the cat is scrubbed.
	for _, descendant in tub:GetDescendants() do
		if
			descendant:IsA("Model")
			and (
				string.match(descendant.Name, "_Water$") or string.match(descendant.Name, "_Foam$")
			)
		then
			for _, part in partsOf(descendant) do
				part.CanQuery = false
			end
		end
	end
	tub.Parent = parent
	local seat = tub:FindFirstChild("CatSeat", true)
	if seat and seat:IsA("Attachment") then
		return (seat :: Attachment).WorldCFrame
	end
	return tub:GetPivot() * CFrame.new(0, SEAT_HEIGHT, 0)
end

-- Three bow buttons in a row above the tub and a camera button beside it: placeholders for the bottom bar and the
-- camera stand in the first session plan.
-- Offsets are in the tub's frame (its front, -Z, faces the player), so the first bow is on the player's left.
local function buildButtons(parent: Instance): ({ BasePart }, BasePart)
	local tub = SpaLayout.spot("SpotTub")
	local buttons = Instance.new("Model")
	buttons.Name = "PH_Buttons"
	local bowButtons: { BasePart } = {}
	for index, bowId in SpaRules.BOWS do
		local x = (2 - index) * 2.2
		local button = makePart(
			bowId,
			Vector3.new(1.6, 1.6, 0.4),
			BOW_COLORS[bowId] or BUTTON_COLOR,
			tub * CFrame.new(x, 7, -1)
		)
		button:SetAttribute("BowId", bowId)
		show(button, false)
		button.Parent = buttons
		table.insert(bowButtons, button)
	end
	local camera = makePart(
		"Camera",
		Vector3.new(1.4, 1, 1),
		Color3.fromRGB(40, 40, 48),
		tub * CFrame.new(-4.5, 2.5, -1)
	)
	show(camera, false)
	camera.Parent = buttons
	buttons.Parent = parent
	return bowButtons, camera
end

-- The cat's nested Models named `..._<kind>NN`, in number order.
local function collectPieces(model: Model, kind: string): { Piece }
	type Found = { order: number, model: Model }
	local found: { Found } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") then
			local order = ScrubRules.pieceNumber(descendant.Name, kind)
			if order then
				table.insert(found, { order = order, model = descendant :: Model })
			end
		end
	end
	table.sort(found, function(a: Found, b: Found): boolean
		return a.order < b.order
	end)
	local pieces: { Piece } = {}
	for _, entry in found do
		local box = entry.model:GetBoundingBox()
		table.insert(
			pieces,
			{ model = entry.model, parts = partsOf(entry.model), position = box.Position }
		)
	end
	return pieces
end

-- True when `part` sits inside one of the cat's eye Models, which keep their colour when the coat is wet.
local function inEye(part: Instance, root: Instance): boolean
	local node = part.Parent
	while node and node ~= root do
		if string.match(node.Name, "_Eye%d*$") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function findHead(model: Model): BasePart?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") and string.match(descendant.Name, "_Head$") then
			return (descendant :: Model).PrimaryPart
		end
	end
	return nil
end

local function findAsset(name: string): Model?
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	local asset = if assets then assets:FindFirstChild(name) else nil
	if asset and asset:IsA("Model") then
		return asset :: Model
	end
	if not warnedMissing[name] then
		warnedMissing[name] = true
		warn(`ScrubController: ReplicatedStorage.Assets.{name} is missing`)
	end
	return nil
end

-- A fresh copy of the dirty cat, sitting on `seat` (which faces the spawn).
local function buildCat(asset: Model, parent: Instance, seat: CFrame): Cat
	local model = asset:Clone() :: Model
	model:ScaleTo(CAT_SCALE)
	model:PivotTo(seat) -- the pivot is the base centre
	-- A part that ships hidden (the long claws, #100, and anything added later) stays as shipped: it never
	-- catches the sponge and is not coat, until code that owns it shows it.
	local shippedHidden: { [BasePart]: boolean } = {}
	for _, part in partsOf(model) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		if part.Transparency >= 1 then
			shippedHidden[part] = true
			part.CanQuery = false
		else
			part.CanQuery = true
		end
	end

	local mud = collectPieces(model, "Mud")
	-- Blobs past the cap are removed, so every blob on the cat can be scrubbed.
	while #mud > ScrubRules.MAX_PATCHES do
		local extra = table.remove(mud) :: Piece
		extra.model:Destroy()
	end
	local tangles = collectPieces(model, "Tangle")
	local fluff = collectPieces(model, "Fluff")
	for _, piece in fluff do
		for _, part in piece.parts do
			part.CanQuery = false
			part.Transparency = 1
		end
	end

	local pieceParts: { [BasePart]: boolean } = {}
	for _, list in { mud, tangles, fluff } do
		for _, piece in list do
			for _, part in piece.parts do
				pieceParts[part] = true
			end
		end
	end
	local coat: { [BasePart]: Color3 } = {}
	for _, part in partsOf(model) do
		if not pieceParts[part] and not shippedHidden[part] and not inEye(part, model) then
			coat[part] = part.Color
		end
	end

	-- Placeholder bow on top of the head, shown once the player picks one.
	local head = findHead(model)
	local bowSize = BOW_SIZE * CAT_SCALE
	local bowCFrame = if head
		then head.CFrame * CFrame.new(0, (head.Size.Y + bowSize.Y) / 2, 0)
		else model:GetPivot() * CFrame.new(0, 2 * CAT_SCALE, 0)
	local bow = makePart("PH_Bow", bowSize, BUTTON_COLOR, bowCFrame)
	show(bow, false)
	bow.Parent = model

	local rawDarken = model:GetAttribute("WetDarken")
	local wetDarken = if type(rawDarken) == "number"
		then math.clamp(rawDarken, 0, 1)
		else WET_DARKEN
	model.Parent = parent
	return {
		model = model,
		mud = mud,
		tangles = tangles,
		fluff = fluff,
		coat = coat,
		wetDarken = wetDarken,
		bow = bow,
	}
end

-- A cleared piece stops catching the sponge at once and fades out over PIECE_FADE.
local function hidePiece(piece: Piece)
	for _, part in piece.parts do
		part.CanQuery = false
		TweenService:Create(part, PIECE_FADE, { Transparency = 1 }):Play()
	end
end

-- Fades a piece in: a tangle put back (the server was behind) catches rays again, fur puffs never do. The new
-- tween replaces a fade still running.
local function showPiece(piece: Piece, catchRays: boolean)
	for _, part in piece.parts do
		part.CanQuery = catchRays
		TweenService:Create(part, PIECE_FADE, { Transparency = 0 }):Play()
	end
end

-- Fur puffs show once the cat is fluffed and hide again if it falls back to clean.
local function showFluff(cat: Cat, visible: boolean)
	for _, piece in cat.fluff do
		if visible then
			showPiece(piece, false)
		else
			hidePiece(piece)
		end
	end
end

-- The wet look after the scrub: the coat darkens by the cat's WetDarken until the brush fluffs it dry.
local function setWet(cat: Cat, wet: boolean)
	local keep = 1 - cat.wetDarken
	for part, dry in cat.coat do
		part.Color = if wet then Color3.new(dry.R * keep, dry.G * keep, dry.B * keep) else dry
	end
end

-- The ray under the pointer: the touch or mouse position, or the middle of the screen for a gamepad.
local function pointerRay(input: InputObject): Ray?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local kind = input.UserInputType
	if
		kind == Enum.UserInputType.Touch
		or kind == Enum.UserInputType.MouseButton1
		or kind == Enum.UserInputType.MouseMovement
	then
		return camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	end
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

local function cast(ray: Ray, params: RaycastParams): RaycastResult?
	return Workspace:Raycast(ray.Origin, ray.Direction * 200, params)
end

local function holdCamera(hold: boolean)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if hold and savedCameraType == nil then
		-- A finger dragging on the world spins the default camera; hold it still while the finger is on the cat.
		savedCameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
	elseif not hold and savedCameraType ~= nil then
		camera.CameraType = savedCameraType :: Enum.CameraType
		savedCameraType = nil
	end
end

-- The press left the cat or lifted: a scrub stroke ends (ScrubStop) and brush travel starts over.
local function endStroke()
	local v = visit
	local cat = if v then v.cat else nil
	if stroking and v and cat and v.stage == "dirty" then
		Moments.ScrubStop:Fire(cat.model, lastHit or cat.model:GetPivot().Position)
	end
	if v then
		v.strokeTravel = 0
	end
	stroking = false
	lastHit = nil
end

local function reveal(v: Visit, cat: Cat)
	for _, index in ScrubRules.reveal(v.scrub) do
		hidePiece(cat.mud[index])
	end
	setWet(cat, true)
	endStroke()
	v.stage = "clean"
	Moments.CatClean:Fire(cat.model)
	report("ReportScrubbed", v)
end

local function ownsTool(id: string): boolean
	return Players.LocalPlayer:GetAttribute(ToolRules.ATTRIBUTE_PREFIX .. id) == true
end

-- How far the sponge reaches: wider with Bubble Soap. The server sets the owned-tool attributes.
local function spongeRadius(): number
	if not LiveFlags.isOn(TOOLS_FLAG) then
		return ScrubRules.SPONGE_RADIUS
	end
	return ToolRules.spongeRadius(ScrubRules.SPONGE_RADIUS, ownsTool)
end

-- Rubs every mud blob within the sponge's reach of `point` by `travel` studs.
local function rubAt(v: Visit, cat: Cat, point: Vector3, travel: number)
	if turningCat == cat.model then
		return
	end
	local radius = spongeRadius()
	for index, piece in cat.mud do
		if not v.scrub.cleared[index] and (piece.position - point).Magnitude <= radius then
			if not reportedScrub then
				-- The funnel's first_scrub: only the client sees the first rub. Once a session; the server keeps it
				-- once per save.
				reportedScrub = true
				Remotes.event("ReportStep"):FireServer("first_scrub")
			end
			if ScrubRules.rub(v.scrub, index, travel) then
				hidePiece(piece)
				Moments.MudPatchCleared:Fire(
					cat.model,
					piece.position,
					ScrubRules.patchesLeft(v.scrub)
				)
			end
		end
	end
	if ScrubRules.shouldReveal(v.scrub) then
		reveal(v, cat)
	end
end

-- After the fluff: with the Blow Dryer built (StationService places it in this player's plot), the cat sits on
-- the dryer's stool for DRY_SECONDS (DryStart and DryStop, for the air and hum), then goes back to the tub. Then
-- the bows show. Only a look: the server pays the dryer's bonus from the save, not from this.
local function dryThenBows(v: Visit, cat: Cat)
	local dryer = if LiveFlags.isOn(DRY_FLAG) then SpaLayout.station("Dryer") else nil
	local stool = if dryer then dryer:FindFirstChild("CatSeat", true) else nil
	local seat = v.seat
	if dryer and stool and stool:IsA("Attachment") and seat then
		local scale = dryer:GetAttribute("CatScale")
		local dryScale = if type(scale) == "number" and scale > 0 then scale else CAT_SCALE
		if dryScale ~= CAT_SCALE then
			cat.model:ScaleTo(dryScale)
		end
		cat.model:PivotTo((stool :: Attachment).WorldCFrame)
		Moments.DryStart:Fire(cat.model, dryer)
		task.wait(DRY_SECONDS)
		-- Always stop the dry, even for a cat that is gone: the hum loops until DryStop.
		Moments.DryStop:Fire(cat.model)
		if visit ~= v or v.cat ~= cat then
			return
		end
		if dryScale ~= CAT_SCALE then
			cat.model:ScaleTo(CAT_SCALE)
		end
		cat.model:PivotTo(seat :: CFrame)
	end
	if visit == v and v.cat == cat and v.stage == "fluffed" then
		for _, button in v.bowButtons do
			show(button, true)
		end
	end
end

-- Brush travel on the clean cat; every STROKE_TRAVEL studs is one stroke, which brushes out a share of the
-- tangles, and the last stroke fluffs the cat dry.
local function brushAt(v: Visit, cat: Cat, travel: number)
	v.strokeTravel += travel
	local now = os.clock()
	if v.strokeTravel < STROKE_TRAVEL or now - v.lastStrokeAt < SpaRules.MIN_STROKE_GAP then
		return
	end
	v.strokeTravel = 0
	v.lastStrokeAt = now
	local before = SpaRules.tanglesGone(v.strokes, #cat.tangles)
	v.strokes += 1
	for index = before + 1, SpaRules.tanglesGone(v.strokes, #cat.tangles) do
		hidePiece(cat.tangles[index])
	end
	Moments.BrushSwipe:Fire(cat.model, v.strokes)
	report("ReportBrushStroke", v)
	if v.strokes >= SpaRules.BRUSH_STROKES then
		v.stage = "fluffed"
		setWet(cat, false)
		showFluff(cat, true)
		endStroke()
		Moments.CatFluffed:Fire(cat.model)
		task.spawn(dryThenBows, v, cat)
	end
end

local function onPointer(input: InputObject)
	local v = visit
	local cat = if v then v.cat else nil
	if not v or not cat or (v.stage ~= "dirty" and v.stage ~= "clean") then
		return
	end
	local ray = pointerRay(input)
	local result = if ray then cast(ray, v.catParams) else nil
	if not result then
		-- The pointer slid off the cat: the stroke ends, and a new one starts if it slides back on. The camera
		-- stays held until the finger lifts, so it does not jump mid-drag.
		if stroking then
			endStroke()
		end
		return
	end
	local point = result.Position
	if not stroking then
		stroking = true
		lastHit = point
		lastMoveTime = os.clock()
		if v.stage == "dirty" then
			Moments.ScrubStart:Fire(cat.model, point)
		end
		return
	end
	local previous = lastHit or point
	local travel = (point - previous).Magnitude
	lastHit = point
	if travel <= 0 then
		return
	end
	if v.stage == "dirty" then
		local now = os.clock()
		local dt = math.max(now - lastMoveTime, 1 / 240)
		lastMoveTime = now
		Moments.ScrubMove:Fire(cat.model, point, result.Normal, travel / dt)
		rubAt(v, cat, point, travel)
	else
		brushAt(v, cat, travel)
	end
end

-- A tap on a bow or the camera. True when the press landed on one, so it does not also start a stroke.
local function tapButton(v: Visit, input: InputObject): boolean
	local cat = v.cat
	local ray = pointerRay(input)
	local result = if ray and cat then cast(ray, v.buttonParams) else nil
	if not result or not cat then
		return false
	end
	local part = result.Instance
	local bowId = part:GetAttribute("BowId")
	if v.stage == "fluffed" and type(bowId) == "string" then
		v.stage = "styled"
		if not BowFit.wear(cat.model, bowId, CAT_SCALE) then
			cat.bow.Color = BOW_COLORS[bowId] or BUTTON_COLOR
			show(cat.bow, true)
			cat.bow.CanQuery = false
		end
		for _, button in v.bowButtons do
			show(button, false)
		end
		show(v.camera, true)
		Moments.BowChosen:Fire(cat.model, bowId)
		report("RequestPickBow", v, bowId)
	elseif v.stage == "styled" and part == v.camera then
		-- The camera hides while the photo develops; the server pays once the visit is long enough, or hands the
		-- camera back (CatStage) when it could not pay.
		show(v.camera, false)
		report("RequestPhoto", v)
	end
	return true
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == GAMEPAD_BUTTON
end

local function release()
	activeInput = nil
	endStroke()
	holdCamera(false)
end

-- When the finger lifts and less mud faces the camera than the reveal still needs, the cat turns in the tub
-- (about its seat) so the middle of the remaining mud faces the camera. Then the first scrub finishes from the
-- spawn side without walking round the tub. Behind the switch scrubTurn.
local function turnToShow(v: Visit, cat: Cat)
	local camera = Workspace.CurrentCamera
	if
		not LiveFlags.isOn(TURN_FLAG)
		or v.stage ~= "dirty"
		or turningCat ~= nil
		or camera == nil
	then
		return
	end
	local model = cat.model
	local pivot = model:GetPivot()
	local centre = pivot.Position
	local offsets: { Vector3 } = {}
	for index, piece in cat.mud do
		if not v.scrub.cleared[index] then
			table.insert(offsets, piece.position - centre)
		end
	end
	local yaw = ScrubRules.turnToShow(
		offsets,
		camera.CFrame.Position - centre,
		ScrubRules.patchesNeeded(v.scrub)
	)
	if yaw == nil then
		return
	end
	-- A turn about the up axis through the pivot (the base centre): the pieces' remembered positions move with it.
	local turn = CFrame.new(centre) * CFrame.Angles(0, yaw, 0) * CFrame.new(-centre)
	for _, list in { cat.mud, cat.tangles, cat.fluff } do
		for _, piece in list do
			piece.position = turn * piece.position
		end
	end
	local goal = turn * pivot
	local alpha = Instance.new("NumberValue")
	alpha.Changed:Connect(function(value: number)
		if model.Parent then
			model:PivotTo(pivot:Lerp(goal, value))
		end
	end)
	turningCat = model
	local tween = TweenService:Create(alpha, TURN_TWEEN, { Value = 1 })
	tween.Completed:Connect(function()
		if model.Parent then
			model:PivotTo(goal)
		end
		alpha:Destroy()
		if turningCat == model then
			turningCat = nil
		end
	end)
	tween:Play()
end

-- A new dirty cat in the tub (the server's cat `catId`): the last cat goes and a fresh copy sits down.
local function startCat(v: Visit, asset: Model, seat: CFrame, catId: number)
	local old = v.cat
	if old then
		old.model:Destroy()
	end
	local cat = buildCat(asset, v.folder, seat)
	v.cat = cat
	v.catParams.FilterDescendantsInstances = { cat.model }
	v.catId = catId
	v.stage = "dirty"
	v.scrub = ScrubRules.newState(#cat.mud)
	v.strokes = 0
	v.strokeTravel = 0
	v.lastStrokeAt = -math.huge
	for _, button in v.bowButtons do
		show(button, false)
	end
	show(v.camera, false)
	if #cat.mud == 0 then
		reveal(v, cat) -- a cat with no mud goes straight to the brush
	end
end

-- Needs as one comma separated attribute ("mud,tangles,wet") for need icons to read; only known needs pass.
local function needList(raw: unknown): string
	local out: { string } = {}
	if type(raw) == "table" then
		for _, need in raw :: { unknown } do
			if type(need) == "string" and CatRules.NEED_STATION[need] then
				table.insert(out, need)
			end
		end
	end
	return table.concat(out, ",")
end

local function onCatReady(
	rawId: unknown,
	rawKind: unknown,
	rawNeeds: unknown,
	rawLocked: unknown,
	rawStray: unknown
)
	local v = visit
	if not v or type(rawId) ~= "number" then
		return
	end
	-- A customer's cat is its own kind; anything else is the prototype's cat.
	local kind = if type(rawKind) == "string" and CatRules.rarityOf(rawKind) then rawKind else nil
	local asset = findAsset(if kind then `CleanACat_Cat_{kind}_Dirty_Sit` else CAT_ASSET)
	if not asset or visit ~= v then
		return
	end
	local seat = v.seat
	if seat == nil then
		local tub = findAsset(TUB_ASSET)
		seat = if tub
			then buildTub(tub, v.folder)
			else SpaLayout.spot("SpotTub") * CFrame.new(0, SEAT_HEIGHT, 0)
		v.seat = seat
	end
	release()
	startCat(v, asset, seat :: CFrame, rawId)
	local cat = v.cat
	if cat and kind then
		-- For the need icons (UI): which cat, what it needs and which needs wait on a station not built yet.
		cat.model:SetAttribute("Customer", rawStray ~= true)
		cat.model:SetAttribute("Stray", rawStray == true)
		cat.model:SetAttribute("Needs", needList(rawNeeds))
		cat.model:SetAttribute("LockedNeeds", needList(rawLocked))
	end
end

-- Puts the cat back to the server's stage after a step the server refused or never got, so the player can redo
-- that step instead of being stuck.
local function rollBack(v: Visit, cat: Cat, stage: SpaRules.Stage, strokes: number)
	release()
	v.stage = stage
	v.strokes = math.clamp(strokes, 0, SpaRules.BRUSH_STROKES)
	v.strokeTravel = 0
	local gone = SpaRules.tanglesGone(v.strokes, #cat.tangles)
	for index, piece in cat.tangles do
		if index > gone then
			showPiece(piece, true)
		end
	end
	setWet(cat, stage == "clean")
	showFluff(cat, stage ~= "clean")
	BowFit.remove(cat.model)
	show(cat.bow, false)
	cat.bow.CanQuery = false
	show(v.camera, false)
	for _, button in v.bowButtons do
		show(button, stage == "fluffed")
	end
end

-- The server's view of the cat after a report.
local function onCatStage(
	rawId: unknown,
	rawSeq: unknown,
	rawStage: unknown,
	rawStrokes: unknown,
	rawWaiting: unknown
)
	local v = visit
	-- An answer to an older report says nothing about the newer ones still on their way.
	if not v or rawSeq ~= reportSeq then
		return
	end
	answeredSeq = reportSeq
	local cat = v.cat
	if rawId ~= v.catId or not cat then
		-- The server has another cat or none: ask for one. RequestCat has its own rate limit on the server.
		release()
		Remotes.event("RequestCat"):FireServer()
		return
	end
	if type(rawStage) ~= "string" then
		return
	end
	local serverRank = SpaRules.STAGE_ORDER[rawStage]
	local clientRank = SpaRules.STAGE_ORDER[v.stage]
	if serverRank == nil or clientRank == nil then
		return
	end
	if rawStage == "styled" and v.stage == "styled" and rawWaiting == false then
		show(v.camera, true) -- the server could not pay yet; tap again
		return
	end
	if serverRank >= clientRank then
		return
	end
	if rawStage == "dirty" then
		release()
		Remotes.event("RequestCat"):FireServer()
		return
	end
	rollBack(
		v,
		cat,
		rawStage :: SpaRules.Stage,
		if type(rawStrokes) == "number" then rawStrokes else 0
	)
end

local function onPhotoPaid(rawId: unknown)
	local v = visit
	local cat = if v then v.cat else nil
	if not v or not cat or rawId ~= v.catId or v.stage ~= "styled" then
		return
	end
	v.stage = "done"
	show(v.camera, false)
	Moments.PhotoTaken:Fire(cat.model)
	nextCatThread = task.delay(LEAVE_SECONDS, function()
		if visit ~= v or v.cat ~= cat then
			return
		end
		-- A stray hops into the window; a customer's cat goes home. The prototype's cat just waits.
		if cat.model:GetAttribute("Stray") == true then
			Moments.CatToWindow:Fire(cat.model)
		elseif cat.model:GetAttribute("Customer") == true then
			Moments.CatReturned:Fire(cat.model)
		end
		task.wait(NEXT_CAT_SECONDS - LEAVE_SECONDS)
		nextCatThread = nil
		if visit == v then
			Remotes.event("RequestCat"):FireServer()
		end
	end)
end

local function buildVisit(folder: Folder): Visit
	local bowButtons, camera = buildButtons(folder)
	local catParams = RaycastParams.new()
	catParams.FilterType = Enum.RaycastFilterType.Include
	catParams.FilterDescendantsInstances = {}
	local buttonParams = RaycastParams.new()
	buttonParams.FilterType = Enum.RaycastFilterType.Include
	local buttonList: { Instance } = { camera }
	for _, button in bowButtons do
		table.insert(buttonList, button)
	end
	buttonParams.FilterDescendantsInstances = buttonList
	return {
		folder = folder,
		seat = nil,
		cat = nil,
		bowButtons = bowButtons,
		camera = camera,
		scrub = ScrubRules.newState(1),
		catParams = catParams,
		buttonParams = buttonParams,
		catId = nil,
		stage = "waiting",
		strokes = 0,
		strokeTravel = 0,
		lastStrokeAt = -math.huge,
	}
end

local function enable()
	if enabled then
		return
	end
	enabled = true
	local folder = Instance.new("Folder")
	folder.Name = "PH_SpaPrototype"
	visit = buildVisit(folder)
	folder.Parent = Workspace

	table.insert(connections, Remotes.event("CatReady").OnClientEvent:Connect(onCatReady))
	table.insert(connections, Remotes.event("PhotoPaid").OnClientEvent:Connect(onPhotoPaid))
	table.insert(connections, Remotes.event("CatStage").OnClientEvent:Connect(onCatStage))
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			-- `processed` is true for taps on buttons, the thumbstick and the jump button: those never scrub.
			local v = visit
			if processed or activeInput ~= nil or not isPress(input) or not v then
				return
			end
			if tapButton(v, input) then
				return
			end
			-- Only a press that lands on the cat scrubs or brushes; a press anywhere else stays a camera drag.
			local ray = pointerRay(input)
			if
				(v.stage ~= "dirty" and v.stage ~= "clean")
				or not ray
				or not cast(ray, v.catParams)
			then
				return
			end
			activeInput = input
			holdCamera(input.UserInputType == Enum.UserInputType.Touch)
			onPointer(input)
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local active = activeInput
			if active == nil then
				return
			end
			if active.UserInputType == Enum.UserInputType.Touch then
				-- Only the finger that started; a second finger on the thumbstick is someone walking.
				if input == active then
					onPointer(input)
				end
			elseif
				active.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement
			then
				onPointer(input)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input == activeInput then
				release()
				local v = visit
				local cat = if v then v.cat else nil
				if v and cat then
					turnToShow(v, cat)
				end
			end
		end)
	)
	-- A held trigger has no pointer movement: the middle of the screen moves as the camera turns.
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			local active = activeInput
			if active and active.KeyCode == GAMEPAD_BUTTON then
				onPointer(active)
			end
		end)
	)

	Remotes.event("RequestCat"):FireServer()
end

local function disable()
	if not enabled then
		return
	end
	enabled = false
	release()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if nextCatThread then
		task.cancel(nextCatThread)
		nextCatThread = nil
	end
	local v = visit
	visit = nil
	if v then
		v.folder:Destroy()
	end
end

local function refresh()
	if LiveFlags.isOn(FLAG) then
		enable()
	else
		disable()
	end
end

function ScrubController.Init(_controllers: { [string]: any }) end

function ScrubController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	-- The plot placed or taken away: the tub moves to its new spot the way a switch flip does, by starting the
	-- visit again (the server resends a dirty cat as it is).
	SpaLayout.changed(function()
		if enabled then
			disable()
			refresh()
		end
	end)
	refresh()
end

return ScrubController
