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
--
-- Later steps (#267, drafts in Shared.WashDraft): after the fluff (and the dryer) and before the bows, a cat that
-- needs them takes the Bubble Bath (swirl on the cat until the suds are gone, switch bubbleBath) and the Pawdicure
-- (hold on each front paw until its long claws clip, switch pawdicure), each only once its station is built. Like the
-- dryer they are only a look: the server pays the stations' bonus from the save.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BowFit = require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("BowFit"))
local BrushShine = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("BrushShine"))
local ControlHold = require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("ControlHold"))
local Icons =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons"))
local WashView = require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("WashView"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local LaterStepRules = require(Shared:WaitForChild("LaterStepRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScrubRules = require(Shared:WaitForChild("ScrubRules"))
local Signal = require(Shared:WaitForChild("Signal"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))
local Trove = require(Shared:WaitForChild("Vendor"):WaitForChild("Trove"))
local WashDraft = require(Shared:WaitForChild("WashDraft"))

local FLAG = "scrubPrototype"
local TOOLS_FLAG = "toolsBoard" -- owned tools (Bubble Soap) widen the sponge only while this is on
local TURN_FLAG = "scrubTurn" -- the cat turns to show its muddy side when too little faces the camera
local FEEL_FLAG = "scrubFeel" -- a patch takes a few strokes, and a finger on the cat never walks the player
local WASH_FLAG = "washView" -- every cat in the tub is washed in the close-up wash view, the avatar hidden
local WASH_REASON = "scrub" -- this controller's hold on Spa/WashView
local OPENING_REASON = "opening" -- the opening's own hold on the view (OpeningController): no Walk button then
local MARKER_UP = 3.6 -- studs over the cat's seat where the paw marker bobs while the player has stepped out
local MARKER_BOB = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local WASH_PROMPT_REACH = 12 -- studs: the tub's "Wash" prompt while the player has stepped out
local TURN_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local DRY_FLAG = "stations" -- with the Blow Dryer built, a fluffed cat sits on its stool before the bows
local DRY_SECONDS = 2.5
local CAT_ASSET = "CleanACat_Cat_Smudge_Dirty_Sit" -- the prototype's cat; a customer's cat uses its own kind
local TUB_ASSET = "CleanACat_Station_Tub"
local PHOTO_FLAG = "photoCamera" -- Model-Agent's photo camera on its stand instead of the pink placeholder block
local PHOTO_ASSET = "CleanACat_Prop_PhotoCamera" -- pivot at the base centre, lens on its front (-Z)
-- The photo camera stands here in the tub's frame (its front, -Z, faces the player): beside the tub, on the floor.
local PHOTO_SPOT = CFrame.new(-4.5, 0, -1)
-- The tap target over the camera model: its body is only about 1.4 by 0.9 studs, so an invisible box over the
-- whole camera and stand takes the tap, wide enough for a thumb on a phone (Review-QA on #359).
local PHOTO_HIT_SIZE = Vector3.new(2.2, 3.4, 2.2)
local PLACEHOLDER_SIZE = Vector3.new(1.4, 1, 1)
local PLACEHOLDER_SPOT = CFrame.new(-4.5, 2.5, -1)
local CAT_SCALE = 1.5 -- Model-Agent's size for a cat sitting in the tub
local ASSET_WAIT_SECONDS = 5
local WET_DARKEN = 0.3 -- used when the cat has no WetDarken attribute
local SEAT_HEIGHT = 1.5 -- the tub's inner floor (Model-Agent #171), used when the tub has no CatSeat attachment
local BOW_SIZE = Vector3.new(0.5, 0.25, 0.15) -- studs at scale 1; the stand-in when a bow model is missing
local PIECE_FADE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- mud and tangles fade, not blink
local STROKE_TRAVEL = 2.5 -- studs of drag on the cat that make one brush stroke
local NEXT_CAT_SECONDS = 3 -- after the photo pays, the next cat is asked for
local LEAVE_SECONDS = 1.2 -- after the photo, the cat leaves: home with its owner or into the window
local RESEND_SECONDS = 2 -- the newest report is sent again when the server has not answered it by then
local RESEND_TRIES = 3
local GAMEPAD_BUTTON = Enum.KeyCode.ButtonR2 -- not ButtonA, which jumps
local BUTTON_COLOR = Color3.fromRGB(205, 205, 210)
local SUDS_COLOR = Color3.fromRGB(250, 252, 255)
local SUDS_POP = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- a puff shrinks as it fades
local SNIP = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- a claw shortens as it fades
local RING_COLOR = Color3.fromHex("FFC94D") -- the outline on the paw to press next
-- The HUD's name for each later step (stageChanged): a step bar entry for each comes with the HUD's part of #267.
local LATER_STAGE: { [string]: string } = { smell = "bath", claws = "claws" }
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

-- A front paw and its long claws (#267): the leg Model the claws ride on. Its claws clip together.
type Paw = {
	leg: Model,
	claws: { Piece },
	sizes: { [BasePart]: Vector3 }, -- each claw part's long size at tub scale, to put it back after a roll back
	clipped: boolean,
}

-- The cat in the tub, cloned fresh for every visit.
type Cat = {
	model: Model,
	mud: { Piece }, -- in name order; patch index i is mud[i]
	tangles: { Piece }, -- in name order; brushed out from the first
	fluff: { Piece }, -- fur puffs, hidden until the cat is fluffed; never caught by a ray
	paws: { Paw }, -- the front paws' long claws, hidden unless this cat takes the Pawdicure
	coat: { [BasePart]: Color3 }, -- dry colours of the coat, to undo the wet look
	wetDarken: number,
	bow: BasePart, -- the stand-in bow, shown only when the picked bow's model cannot be worn
}

type Visit = {
	folder: Folder,
	seat: CFrame?, -- where the cat sits, once the tub is in
	cat: Cat?,
	bowButtons: { BasePart },
	camera: BasePart, -- the photo tap target: the placeholder block, or the invisible box over the camera model
	cameraModel: Model?, -- Model-Agent's photo camera (switch photoCamera), shown with the tap target
	scrub: ScrubRules.State,
	catParams: RaycastParams,
	buttonParams: RaycastParams,
	catId: number?,
	stage: Stage,
	strokes: number,
	brushStrokes: number, -- strokes this cat's brushing takes, as the server said (fewer with the Pro Brush)
	strokeTravel: number,
	lastStrokeAt: number,
	needs: { string }, -- this cat's needs and the ones still locked, as the server said (CatReady)
	locked: { string },
	later: { string }, -- later steps still to come (LaterStepRules.steps), front first
	plan: { string }, -- all of this cat's later steps, as the HUD names them
	step: string?, -- the later step under way: "smell" (the Bubble Bath) or "claws" (the Pawdicure)
	suds: { BasePart }, -- the bath's puffs (PH_Suds), cleared in order
	swirl: number, -- studs swirled on the cat in this bath
	away: boolean, -- the cat sits at a later step's station, not in the tub
	hold: Paw?, -- the paw under the press in the Pawdicure, held since holdSince
	holdSince: number,
	ring: Highlight?, -- the outline on the paw to press next
	mascot: boolean, -- the opening's kitten (SudsRules, #285): no bows, and his collar pops on at the naming
	steppedOut: boolean, -- the player pressed Walk: the cat waits in the tub, the close-up is let go (washView)
	marker: BasePart?, -- while stepped out: the paw marker over the cat and the tub's "Wash" prompt
}

type Args = { n: number, [number]: any }

local ScrubController = {}

-- Fires (stage) each time the visit moves to another step, and (nil) when the visit ends. The HUD's step bar and
-- tool tray listen (HudController, #210). Read-only for listeners, like Moments.
ScrubController.stageChanged = Signal.new() :: Signal.Signal<string?>
-- Fires (later) when the cat's later steps are known: their HUD names in order ("bath", "claws"), maybe none.
ScrubController.planChanged = Signal.new() :: Signal.Signal<{ string }>
-- Fires (shown) when the Walk button (UI/HUD/WalkButton) should show or hide: while a customer's cat is washed in
-- the close-up wash view (switch washView), never during Suds's opening. Pressing it calls ScrubController.stepOut.
ScrubController.walkChanged = Signal.new() :: Signal.Signal<boolean>

-- The recap card (#224, switch recapCard): RecapController sets a handler that shows the card after a customer's cat
-- goes home and calls `nextCat` once when the player closes it. With no handler, or the switch off, the next cat
-- comes by itself as before.
export type RecapHandler = (recap: RecapRules.Recap, nextCat: () -> ()) -> ()
local RECAP_FLAG = "recapCard"
local recapHandler: RecapHandler? = nil

function ScrubController.setRecapHandler(handler: RecapHandler?)
	recapHandler = handler
end

local visit: Visit? = nil
local enabled = false
local activeInput: InputObject? = nil -- the one press (mouse button, finger or trigger) on the cat
local stroking = false -- the active press is on the cat right now
local lastHit: Vector3? = nil
local lastMoveTime = 0
local savedCameraType: Enum.CameraType? = nil
local trove = Trove.new() -- everything a visit makes; one Clean ends it
local nextCatThread: thread? = nil
local reportedScrub = false -- the funnel's first_scrub was sent this session
local turningCat: Model? = nil -- the cat turning in the tub; the sponge waits until it stops
local reportSeq = 0 -- numbers each spa report; the server echoes it in CatStage
local answeredSeq = 0 -- the newest report the server has answered
local warnedMissing: { [string]: boolean } = {}

-- The step the HUD shows: a later step under way, or the next one while the cat dries before it (so the bar never
-- says "Pick a bow" before the bath), else the stage.
local function hudStage(v: Visit): string
	if v.step then
		return LATER_STAGE[v.step]
	end
	if v.stage == "fluffed" and #v.later > 0 then
		return LATER_STAGE[v.later[1]]
	end
	return v.stage
end

-- Every step change goes through here, so the HUD hears each one.
-- The close-up wash view (Spa/WashView) is held while a cat is being washed: from the moment it sits down dirty
-- until its photo is taken, framed on the tub or on the later step's station it sits at (seatAt). Behind the switch
-- washView; the opening holds the same view for Suds on its own.
-- With the player stepped out (the Walk button), the cat waits in the tub and the view is let go until they come
-- back (a tap on the cat, or the tub's "Wash" prompt). The Walk button shows only while this controller's hold is
-- what keeps the view up: never for Suds, whose opening holds it on its own.
local walkShown = false
local function updateWashView(v: {
	stage: Stage,
	away: boolean,
	cat: Cat?,
	steppedOut: boolean,
	mascot: boolean,
}?)
	local washing = v ~= nil
		and v.cat ~= nil
		and v.stage ~= "waiting"
		and v.stage ~= "done"
		and LiveFlags.isOn(WASH_FLAG)
	WashView.set(WASH_REASON, washing and v ~= nil and not v.steppedOut)
	local walk = washing
		and v ~= nil
		and not v.steppedOut
		and not v.mascot
		and not WashView.holds(OPENING_REASON)
	if walk ~= walkShown then
		walkShown = walk
		ScrubController.walkChanged:Fire(walk)
	end
end

local function setStage(v: Visit, stage: Stage)
	v.stage = stage
	ScrubController.stageChanged:Fire(hudStage(v))
	if visit == v then
		updateWashView(v)
	end
end

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

-- Shows or hides the photo camera. With the switch photoCamera on and the model in, the model stands beside the
-- tub and an invisible box over it takes the tap; otherwise the pink placeholder block shows, as before. The switch
-- is read at each show, so turning it off goes back to the block at the next photo.
local function showCamera(v: { camera: BasePart, cameraModel: Model? }, visible: boolean)
	local target = v.camera
	local model = v.cameraModel
	local useModel = model ~= nil and LiveFlags.isOn(PHOTO_FLAG)
	local tub = SpaLayout.tubSpot()
	if useModel then
		target.Size = PHOTO_HIT_SIZE
		target.CFrame = tub * PHOTO_SPOT * CFrame.new(0, PHOTO_HIT_SIZE.Y / 2, 0)
		target.Transparency = 1
		target.CanQuery = visible
	else
		target.Size = PLACEHOLDER_SIZE
		target.CFrame = tub * PLACEHOLDER_SPOT
		show(target, visible)
	end
	if model then
		model.Parent = if useModel and visible then target.Parent else nil
	end
end

-- The wash tub at SpaLayout.tubSpot, facing the spawn. Returns where the cat sits: the tub's CatSeat attachment.
local function buildTub(asset: Model, parent: Instance): CFrame
	local tub = asset:Clone() :: Model
	tub:PivotTo(SpaLayout.tubSpot()) -- the pivot is the base centre on the floor
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

-- Where bow button `index` sits, in the tub's frame (its front, -Z, faces the player, so +X is the player's left).
-- Above the tub in a row, or with the close-up wash view on (washView) in a column at the screen's left, beside the
-- cat and inside the shot: the row was off the top of the close-up (Sync-Agent's run on f01718c). The photo camera
-- stands on the other side.
local function bowSpot(index: number): CFrame
	if LiveFlags.isOn(WASH_FLAG) then
		return CFrame.new(3.6, 4.1 - (index - 1) * 1.35, -1.5)
	end
	return CFrame.new((2 - index) * 2.2, 7, -1)
end

-- Three bow buttons (bowSpot) and a camera button beside the tub: placeholders for the bottom bar and the camera
-- stand in the first session plan.
local function buildButtons(parent: Instance): ({ BasePart }, BasePart)
	local tub = SpaLayout.tubSpot()
	local buttons = Instance.new("Model")
	buttons.Name = "PH_Buttons"
	local bowButtons: { BasePart } = {}
	for index, bowId in SpaRules.BOWS do
		local button = makePart(
			bowId,
			Vector3.new(1.6, 1.6, 0.4),
			BOW_COLORS[bowId] or BUTTON_COLOR,
			tub * bowSpot(index)
		)
		button:SetAttribute("BowId", bowId)
		show(button, false)
		button.Parent = buttons
		table.insert(bowButtons, button)
	end
	local camera = makePart(
		"Camera",
		PLACEHOLDER_SIZE,
		-- pastel, not a black block (Derek's dev test); with the switch photoCamera on, the camera model shows instead
		Color3.fromRGB(255, 205, 222),
		tub * PLACEHOLDER_SPOT
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

local function hasAsset(name: string): boolean
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	return assets ~= nil and assets:FindFirstChild(name) ~= nil
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

	-- The long claws ship hidden; they are grouped by the front paw (leg Model) they ride on.
	local paws: { Paw } = {}
	local pawOf: { [Model]: Paw } = {}
	for _, claw in collectPieces(model, "Claw") do
		local leg = claw.model.Parent
		if leg and leg:IsA("Model") then
			local paw = pawOf[leg :: Model]
			if paw == nil then
				paw = {
					leg = leg :: Model,
					claws = {},
					sizes = {},
					clipped = false,
				}
				pawOf[leg :: Model] = paw
				table.insert(paws, paw)
			end
			table.insert(paw.claws, claw)
			for _, part in claw.parts do
				paw.sizes[part] = part.Size
			end
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
	-- Effects/BrushShine owns the coat's colours from here: the wet look, its gradual way back to dry under the
	-- brush, and the shine (Motion-FX's #372, Derek's dev test).
	BrushShine.track(model, coat, wetDarken)
	return {
		model = model,
		mud = mud,
		tangles = tangles,
		fluff = fluff,
		paws = paws,
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

-- The fur puffs stay hidden now (Derek 2026-11-24: "the brush the fur makes random circle bubbles of furr appear
-- on the side of their models no need for that"): a fluffed cat shows by its dry coat and the sparkle instead.
local function hideFluff(cat: Cat)
	for _, piece in cat.fluff do
		hidePiece(piece)
	end
end

-- How wet the coat looks: 1 just scrubbed (darkened by the cat's WetDarken), 0 dry. Each brush stroke dries a share
-- of it, so the colour comes back gradually (BrushShine).
local function setWet(cat: Cat, amount: number)
	BrushShine.setWet(cat.model, math.clamp(amount, 0, 1))
end

-- The wet share left after `strokes` of this cat's brush strokes.
local function wetAfter(v: Visit, strokes: number): number
	return 1 - strokes / math.max(v.brushStrokes, 1)
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

-- On a phone the default thumbstick also reads a finger that lands in its corner, so a scrub that starts near the
-- lower left would walk the player away from the tub (issue #149). While a finger scrubs, the default controls
-- are paused; they come back when it lifts. Needs the scrubFeel switch, and does nothing when the game has no
-- default PlayerModule.
local function holdControls(hold: boolean)
	-- ControlHold owns the state, so a reset (which clears every reason) leaves nothing stale here
	if hold == ControlHold.holds("scrub") or (hold and not LiveFlags.isOn(FEEL_FLAG)) then
		return
	end
	ControlHold.set("scrub", hold)
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
	setWet(cat, 1)
	endStroke()
	setStage(v, "clean")
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

-- Rubs every mud piece within the sponge's reach of `point`, and the piece the sponge is touching (`hit`), so a
-- big or deep blob is never out of reach just because its middle is.
local function rubAt(v: Visit, cat: Cat, point: Vector3, travel: number, hit: Instance?)
	if turningCat == cat.model then
		return
	end
	local radius = spongeRadius()
	local toClear = if LiveFlags.isOn(FEEL_FLAG)
		then ScrubRules.RUB_TO_CLEAR_PACED
		else ScrubRules.RUB_TO_CLEAR
	for index, piece in cat.mud do
		local touched = hit ~= nil and hit:IsDescendantOf(piece.model)
		if
			not v.scrub.cleared[index] and (touched or (piece.position - point).Magnitude <= radius)
		then
			if not reportedScrub then
				-- The funnel's first_scrub: only the client sees the first rub. Once a session; the server keeps it
				-- once per save.
				reportedScrub = true
				Remotes.event("ReportStep"):FireServer("first_scrub")
			end
			if ScrubRules.rub(v.scrub, index, travel, toClear) then
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

-- The later step under way, or none; the HUD hears it as a stage of its own.
local function setStep(v: Visit, step: string?)
	v.step = step
	ScrubController.stageChanged:Fire(hudStage(v))
end

local function nextPaw(cat: Cat): Paw?
	for _, paw in cat.paws do
		if not paw.clipped then
			return paw
		end
	end
	return nil
end

-- Outlines the paw to press next (Design-Agent), or nothing.
local function ringPaw(v: Visit, paw: Paw?)
	local ring = v.ring
	if paw == nil then
		if ring then
			ring.Enabled = false
		end
		return
	end
	if ring == nil then
		local made = Instance.new("Highlight")
		made.Name = "PH_PawRing"
		made.FillTransparency = 1
		made.OutlineColor = RING_COLOR
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.Parent = v.folder
		v.ring = made
		ring = made
	end
	local r = ring :: Highlight
	r.Adornee = paw.leg
	r.Enabled = true
end

-- Long claws show on a cat that will take the Pawdicure; clipped or not needed, they stay hidden. Never in the way
-- of a ray: the paw itself is what the player holds.
local function showClaws(cat: Cat, long: boolean)
	for _, paw in cat.paws do
		paw.clipped = not long
		for _, claw in paw.claws do
			for _, part in claw.parts do
				part.Size = paw.sizes[part] or part.Size
				part.CanQuery = false
				part.Transparency = if long then 0 else 1
			end
		end
	end
end

-- Sits the cat on the CatSeat of station `id` in the player's plot (at the station's CatScale), or back in the tub
-- when `id` is nil or that station is not standing: a later step then happens in the tub. A cat that never left the
-- tub is not moved, so with the later steps off nothing changes (a cat turned to show its mud stays turned).
local function seatAt(v: Visit, cat: Cat, id: string?)
	local station = if id then SpaLayout.station(id) else nil
	local point = if station then station:FindFirstChild("CatSeat", true) else nil
	local target = v.seat
	local scale = CAT_SCALE
	if station and point and point:IsA("Attachment") then
		local raw = station:GetAttribute("CatScale")
		scale = if type(raw) == "number" and raw > 0 then raw else CAT_SCALE
		target = (point :: Attachment).WorldCFrame
		v.away = true
	elseif not v.away then
		return
	else
		v.away = false
	end
	if target == nil then
		return
	end
	if cat.model:GetScale() ~= scale then
		cat.model:ScaleTo(scale)
	end
	cat.model:PivotTo(target :: CFrame)
	if visit == v then
		-- the close-up follows the cat: framed on the station's seat, dropped to about the floor (the tub's shot is
		-- framed from its floor spot) and turned like the tub, so the camera stays on the player's side; or back on
		-- the tub
		local tub = SpaLayout.tubSpot()
		local seat = (target :: CFrame).Position - Vector3.new(0, SEAT_HEIGHT, 0)
		WashView.frame(if v.away then CFrame.new(seat) * tub.Rotation else nil)
		updateWashView(v)
	end
end

-- The later steps this cat takes, from its needs, the stations built and the switches; long claws show for the
-- Pawdicure. Called when the cat arrives and when the server puts it back before the fluff.
local function armLater(v: Visit, cat: Cat)
	for _, puff in v.suds do
		puff:Destroy()
	end
	v.suds = {}
	v.swirl = 0
	v.hold = nil
	v.step = nil
	ringPaw(v, nil)
	seatAt(v, cat, nil)
	v.later = LaterStepRules.steps(v.needs, v.locked, LiveFlags.isOn)
	showClaws(cat, table.find(v.later, "claws") ~= nil)
	local plan: { string } = {}
	for _, need in v.later do
		table.insert(plan, LATER_STAGE[need])
	end
	if v.mascot then
		table.insert(plan, SudsRules.NO_BOWS) -- the step bar leaves the bows out for the kitten
	end
	v.plan = plan
	ScrubController.planChanged:Fire(table.clone(plan))
end

-- The Bubble Bath's puffs: WashDraft.SUDS placeholder balls round the cat, never in the way of a ray.
local function makeSuds(v: Visit, cat: Cat)
	local size = cat.model:GetExtentsSize()
	local pivot = cat.model:GetPivot()
	local reach = math.max(size.X, size.Z)
	for index = 1, WashDraft.SUDS do
		local angle = (index - 1) / WashDraft.SUDS * 2 * math.pi
		local high = size.Y * (if index % 2 == 0 then 0.55 else 0.35)
		local at = pivot * CFrame.Angles(0, angle, 0) * CFrame.new(0, high, -reach * 0.42)
		local puff = makePart(`PH_Suds{index}`, Vector3.one * reach * 0.32, SUDS_COLOR, at)
		puff.Shape = Enum.PartType.Ball
		puff.Material = Enum.Material.SmoothPlastic
		puff.Transparency = 0.1
		puff.CanQuery = false
		puff.CanTouch = false
		puff.Parent = cat.model
		table.insert(v.suds, puff)
	end
end

-- Shows the bows once the later steps are done. The kitten skips them (his collar is his style moment), so the
-- camera shows instead; the server already moved him on to styled with his last brush stroke.
local function showBows(v: Visit, cat: Cat)
	if visit == v and v.cat == cat and v.stage == "fluffed" then
		if v.mascot then
			setStage(v, "styled")
			showCamera(v, true)
			return
		end
		local tub = SpaLayout.tubSpot()
		for index, button in v.bowButtons do
			button.CFrame = tub * bowSpot(index) -- the switch is read as they show
			show(button, true)
		end
	end
end

-- Starts the next later step, or shows the bows when none is left.
local function nextLater(v: Visit, cat: Cat)
	if visit ~= v or v.cat ~= cat or v.stage ~= "fluffed" then
		return
	end
	endStroke()
	v.hold = nil
	local step = table.remove(v.later, 1)
	-- each step at its own station when it stands in the plot (Model-Agent's CatSeat), else in the tub
	seatAt(v, cat, if step then CatRules.NEED_STATION[step] else nil)
	if step == "smell" then
		v.swirl = 0
		makeSuds(v, cat)
		setStep(v, "smell")
		Moments.BathStart:Fire(cat.model)
	elseif step == "claws" and nextPaw(cat) ~= nil then
		setStep(v, "claws")
		ringPaw(v, nextPaw(cat))
		Moments.ClawsStart:Fire(cat.model)
	elseif step ~= nil then
		nextLater(v, cat) -- a cat model with no claws: nothing to clip
	else
		if v.step ~= nil then
			setStep(v, nil)
		end
		ringPaw(v, nil)
		showBows(v, cat)
	end
end

-- Swirl travel on the cat in the Bubble Bath: the puffs pop in order, the last one ends the bath.
local function swirlAt(v: Visit, cat: Cat, travel: number)
	local count = #v.suds
	local before = LaterStepRules.sudsGone(v.swirl, count)
	v.swirl += travel
	local gone = LaterStepRules.sudsGone(v.swirl, count)
	for index = before + 1, gone do
		local puff = v.suds[index]
		TweenService:Create(puff, SUDS_POP, { Transparency = 1, Size = puff.Size * 0.3 }):Play()
		Moments.SudsPopped:Fire(cat.model, puff.Position, count - index)
	end
	if gone >= count then
		Moments.BathDone:Fire(cat.model)
		nextLater(v, cat)
	end
end

-- The front paw under the pointer, while it still has long claws.
local function pawAt(cat: Cat, hit: Instance): Paw?
	for _, paw in cat.paws do
		if not paw.clipped and hit:IsDescendantOf(paw.leg) then
			return paw
		end
	end
	return nil
end

-- A held paw clips: its claws shorten and fade one after another, SNIP_GAP apart, so one hold reads as four trims.
local function clipPaw(v: Visit, cat: Cat, paw: Paw)
	paw.clipped = true
	v.hold = nil
	local left = 0
	for _, other in cat.paws do
		if not other.clipped then
			left += 1
		end
	end
	ringPaw(v, nextPaw(cat))
	Moments.PawClipped:Fire(cat.model, paw.leg:GetPivot().Position, left)
	task.spawn(function()
		for index, claw in paw.claws do
			if index > 1 then
				task.wait(WashDraft.SNIP_GAP)
			end
			if visit ~= v or v.cat ~= cat or not paw.clipped then
				return
			end
			for _, part in claw.parts do
				local size = part.Size -- the claw's long side shrinks to a third
				local short = if size.X >= size.Y and size.X >= size.Z
					then Vector3.new(size.X * 0.35, size.Y, size.Z)
					elseif size.Y >= size.Z then Vector3.new(size.X, size.Y * 0.35, size.Z)
					else Vector3.new(size.X, size.Y, size.Z * 0.35)
				TweenService:Create(part, SNIP, { Size = short, Transparency = 1 }):Play()
			end
			local first = claw.parts[1]
			Moments.ClawSnipped:Fire(
				cat.model,
				if first then first.Position else paw.leg:GetPivot().Position
			)
		end
	end)
	if left == 0 then
		Moments.ClawsDone:Fire(cat.model)
		-- the bar moves on once the last paw's snips have played out, not before
		task.delay((#paw.claws - 1) * WashDraft.SNIP_GAP + SNIP.Time, function()
			if visit == v and v.cat == cat and v.step == "claws" then
				nextLater(v, cat)
			end
		end)
	end
end

-- A later step's switch went off mid-visit (the rollback, Review-QA on #267): the step is dropped at once. Its suds or
-- long claws go, the bar loses it, and a cat at that station moves on to the next step, or back to the tub and the
-- bows. A step still to come is just taken out.
local function dropLater(need: string)
	local v = visit
	local cat = if v then v.cat else nil
	local flag = WashDraft.NEED_FLAG[need]
	if not v or not cat or flag == nil or LiveFlags.isOn(flag) then
		return
	end
	local waiting = table.find(v.later, need)
	if waiting then
		table.remove(v.later, waiting)
	end
	local shown = table.find(v.plan, LATER_STAGE[need])
	if shown == nil then
		return -- this cat never took that step
	end
	table.remove(v.plan, shown)
	ScrubController.planChanged:Fire(table.clone(v.plan))
	if need == "claws" then
		showClaws(cat, false)
	end
	if v.step ~= need then
		ScrubController.stageChanged:Fire(hudStage(v))
		return
	end
	for _, puff in v.suds do
		puff:Destroy()
	end
	v.suds = {}
	v.hold = nil
	ringPaw(v, nil)
	setStep(v, nil)
	nextLater(v, cat)
end

-- After the fluff: with the Blow Dryer built (StationService places it in this player's plot), the cat sits on
-- the dryer's stool for DRY_SECONDS (DryStart and DryStop, for the air and hum), then goes back to the tub. Then
-- the later steps (the Bubble Bath, the Pawdicure) and the bows. Only a look: the server pays the dryer's bonus
-- from the save, not from this.
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
	nextLater(v, cat)
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
	local before = SpaRules.tanglesGone(v.strokes, #cat.tangles, v.brushStrokes)
	v.strokes += 1
	for index = before + 1, SpaRules.tanglesGone(v.strokes, #cat.tangles, v.brushStrokes) do
		hidePiece(cat.tangles[index])
	end
	setWet(cat, wetAfter(v, v.strokes)) -- before the swipe's shine, so the shine runs over the new colour
	Moments.BrushSwipe:Fire(cat.model, v.strokes)
	report("ReportBrushStroke", v)
	if v.strokes >= v.brushStrokes then
		setStage(v, "fluffed")
		setWet(cat, 0)
		endStroke()
		Moments.CatFluffed:Fire(cat.model)
		task.spawn(dryThenBows, v, cat)
	end
end

local function onPointer(input: InputObject)
	local v = visit
	local cat = if v then v.cat else nil
	if not v or not cat or (v.stage ~= "dirty" and v.stage ~= "clean" and v.step == nil) then
		return
	end
	local ray = pointerRay(input)
	local result = if ray then cast(ray, v.catParams) else nil
	if v.step == "claws" then
		-- the Pawdicure: a press resting on a paw with long claws starts its hold; sliding to another paw restarts.
		-- A paw is small on a phone and the far one hides behind the body, so a press anywhere else on the cat holds
		-- the outlined paw (Sync-Agent's playtest of #267).
		local paw = if result then pawAt(cat, result.Instance) or nextPaw(cat) else nil
		if paw ~= v.hold then
			v.hold = paw
			v.holdSince = os.clock()
		end
		return
	end
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
		rubAt(v, cat, point, travel, result.Instance)
	elseif v.step == "smell" then
		swirlAt(v, cat, travel)
	elseif v.stage == "clean" then
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
		setStage(v, "styled")
		if not BowFit.wear(cat.model, bowId, CAT_SCALE) then
			cat.bow.Color = BOW_COLORS[bowId] or BUTTON_COLOR
			show(cat.bow, true)
			cat.bow.CanQuery = false
		end
		for _, button in v.bowButtons do
			show(button, false)
		end
		showCamera(v, true)
		Moments.BowChosen:Fire(cat.model, bowId)
		report("RequestPickBow", v, bowId)
	elseif v.stage == "styled" and part == v.camera then
		-- The camera hides while the photo develops; the server pays once the visit is long enough, or hands the
		-- camera back (CatStage) when it could not pay.
		showCamera(v, false)
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
	local v = visit
	if v then
		v.hold = nil
	end
	endStroke()
	holdCamera(false)
	holdControls(false)
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
		BrushShine.untrack(old.model)
		old.model:Destroy()
	end
	local cat = buildCat(asset, v.folder, seat)
	v.cat = cat
	v.away = false -- a new cat sits in the tub
	WashView.frame(nil)
	v.steppedOut = false
	local marker = v.marker
	v.marker = nil
	if marker then
		marker:Destroy()
	end
	v.catParams.FilterDescendantsInstances = { cat.model }
	v.catId = catId
	setStage(v, "dirty")
	v.scrub = ScrubRules.newState(#cat.mud)
	v.strokes = 0
	v.strokeTravel = 0
	v.lastStrokeAt = -math.huge
	v.needs, v.locked = {}, {}
	v.mascot = false
	armLater(v, cat)
	for _, button in v.bowButtons do
		show(button, false)
	end
	showCamera(v, false)
	if #cat.mud == 0 then
		reveal(v, cat) -- a cat with no mud goes straight to the brush
	end
end

-- The known needs in a list from the server, in order.
local function needArray(raw: unknown): { string }
	local out: { string } = {}
	if type(raw) == "table" then
		for _, need in raw :: { unknown } do
			if
				type(need) == "string"
				and CatRules.NEED_STATION[need]
				and not table.find(out, need)
			then
				table.insert(out, need)
			end
		end
	end
	return out
end

-- Needs as one comma separated attribute ("mud,tangles,wet") for need icons to read; only known needs pass.
local function needList(raw: unknown): string
	return table.concat(needArray(raw), ",")
end

-- A fresh copy of Model-Agent's photo camera, standing beside the tub with its lens on the tub's middle, not yet
-- shown (showCamera parents it). Nil when the model is missing: the placeholder block stays.
local function buildPhotoCamera(): Model?
	local asset = ReplicatedStorage:FindFirstChild("Assets")
	local found = if asset then asset:FindFirstChild(PHOTO_ASSET) else nil
	if found == nil or not found:IsA("Model") then
		return nil
	end
	local model = (found :: Model):Clone() :: Model
	model.Name = "PhotoCamera"
	local tub = SpaLayout.tubSpot()
	local base = (tub * PHOTO_SPOT).Position
	local middle = Vector3.new(tub.Position.X, base.Y, tub.Position.Z)
	model:PivotTo(CFrame.lookAt(base, middle))
	for _, part in partsOf(model) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false -- only the tap box over it takes the tap
	end
	return model
end

-- The tub, built once per visit: as the spa opens, so the opening's trail leads to a tub and not an empty rug
-- (Sync-Agent's playtest of Derek's dev notes), or with the first cat. Returns where a cat sits in it.
local function ensureTub(v: Visit): CFrame
	local built = v.seat
	if built then
		return built
	end
	local tub = findAsset(TUB_ASSET) -- may wait for the asset
	local already = v.seat
	if already then
		return already -- the other caller built it while this one waited
	end
	if visit ~= v then
		return SpaLayout.tubSpot() * CFrame.new(0, SEAT_HEIGHT, 0) -- the visit ended while waiting: build nothing
	end
	local seat = if tub
		then buildTub(tub, v.folder)
		else SpaLayout.tubSpot() * CFrame.new(0, SEAT_HEIGHT, 0)
	v.seat = seat
	v.cameraModel = buildPhotoCamera()
	return seat
end

local function onCatReady(
	rawId: unknown,
	rawKind: unknown,
	rawNeeds: unknown,
	rawLocked: unknown,
	rawStray: unknown,
	rawStrokes: unknown
)
	local v = visit
	if not v or type(rawId) ~= "number" then
		return
	end
	-- A customer's cat is its own kind, the opening's kitten is Suds (or his stand-in until his models are in);
	-- anything else is the prototype's cat.
	local mascot = rawKind == SudsRules.NAME
	local kind = if type(rawKind) == "string" and (mascot or CatRules.rarityOf(rawKind))
		then rawKind
		else nil
	local asset = findAsset(
		if mascot
			then SudsRules.asset("_Dirty_Sit", hasAsset)
			elseif kind then `CleanACat_Cat_{kind}_Dirty_Sit`
			else CAT_ASSET
	)
	if not asset or visit ~= v then
		return
	end
	local seat = ensureTub(v)
	if visit ~= v then
		return
	end
	release()
	startCat(v, asset, seat, rawId)
	-- the server's count; anything odd falls back to the hand brush's
	v.brushStrokes = if type(rawStrokes) == "number"
			and rawStrokes == math.floor(rawStrokes)
			and rawStrokes >= 1
			and rawStrokes <= SpaRules.BRUSH_STROKES
		then rawStrokes
		else SpaRules.BRUSH_STROKES
	local cat = v.cat
	if cat then
		v.needs, v.locked = needArray(rawNeeds), needArray(rawLocked)
		v.mascot = mascot
		armLater(v, cat)
		if visit == v then
			updateWashView(v) -- now that it is known whether this is Suds: the Walk button never shows for him
		end
	end
	if cat and kind then
		-- For the need icons (UI): which cat, what it needs and which needs wait on a station not built yet.
		cat.model:SetAttribute("Customer", rawStray ~= true and not mascot)
		cat.model:SetAttribute("Stray", rawStray == true)
		cat.model:SetAttribute("Mascot", mascot)
		cat.model:SetAttribute("Needs", needList(rawNeeds))
		cat.model:SetAttribute("LockedNeeds", needList(rawLocked))
	end
end

-- Puts the cat back to the server's stage after a step the server refused or never got, so the player can redo
-- that step instead of being stuck.
local function rollBack(v: Visit, cat: Cat, stage: SpaRules.Stage, strokes: number)
	release()
	setStage(v, stage)
	v.strokes = math.clamp(strokes, 0, v.brushStrokes)
	v.strokeTravel = 0
	local gone = SpaRules.tanglesGone(v.strokes, #cat.tangles, v.brushStrokes)
	for index, piece in cat.tangles do
		if index > gone then
			showPiece(piece, true)
		end
	end
	setWet(cat, if stage == "clean" then wetAfter(v, v.strokes) else 0)
	hideFluff(cat)
	if stage ~= "fluffed" then
		armLater(v, cat) -- back before the fluff: the bath and the claws come again after it
	end
	BowFit.remove(cat.model)
	show(cat.bow, false)
	cat.bow.CanQuery = false
	showCamera(v, false)
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
		showCamera(v, true) -- the server could not pay yet; tap again
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

-- The naming moment (#285): the clean Suds model's collar (a child Model ending _Collar, Model-Agent) goes onto the
-- kitten in the same place, scaled like the cat. Nothing to wear while only the stand-in is in the place.
local function wearCollar(cat: Cat)
	local clean = findAsset(SudsRules.asset("_Sit", hasAsset))
	if clean == nil then
		return
	end
	local source: Model? = nil
	for _, child in clean:GetDescendants() do
		if child:IsA("Model") and string.sub(child.Name, -7) == "_Collar" then
			source = child :: Model
			break
		end
	end
	if source == nil then
		return
	end
	local offset = clean:GetPivot():ToObjectSpace(source:GetPivot())
	local scale = cat.model:GetScale() / clean:GetScale()
	local collar = source:Clone()
	collar:ScaleTo(collar:GetScale() * scale)
	collar:PivotTo(cat.model:GetPivot() * (offset - offset.Position + offset.Position * scale))
	for _, part in partsOf(collar) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
	end
	collar.Parent = cat.model
end

local function onPhotoPaid(rawId: unknown, _coins: unknown, _total: unknown, rawRecap: unknown)
	local v = visit
	local cat = if v then v.cat else nil
	if not v or not cat or rawId ~= v.catId or v.stage ~= "styled" then
		return
	end
	local recap = RecapRules.clean(rawRecap)
	setStage(v, "done")
	showCamera(v, false)
	Moments.PhotoTaken:Fire(cat.model)
	if v.mascot then
		wearCollar(cat)
		Moments.SudsNamed:Fire(cat.model)
	end
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
		local asked = false
		local function nextCat()
			if not asked and visit == v then
				asked = true
				Remotes.event("RequestCat"):FireServer()
			end
		end
		local handler = recapHandler
		if recap ~= nil and handler ~= nil and LiveFlags.isOn(RECAP_FLAG) then
			-- The tub stays empty until the player closes the card: a natural place to stop, with no countdown.
			-- If the card fails to show, the next cat comes anyway so the tub is never left empty for good.
			local failure = ""
			local ok = xpcall(handler, function(err: unknown)
				failure = tostring(err)
			end, recap, nextCat)
			if not ok then
				-- Leave a trace: a card that vanishes and a cat that comes early should never be silent (Review-QA).
				warn(`ScrubController: the recap card failed to show, next cat now: {failure}`)
				nextCat()
			end
		else
			nextCat()
		end
	end)
end

-- Back into the close-up from a step out: the marker and the prompt go and the view comes back.
local function stepIn(v: Visit)
	if not v.steppedOut then
		return
	end
	v.steppedOut = false
	local marker = v.marker
	v.marker = nil
	if marker then
		marker:Destroy()
	end
	updateWashView(v)
end

-- The paw marker bobbing over the waiting cat and the tub's "Wash" prompt, on one invisible part over the seat.
local function buildMarker(v: Visit): BasePart
	-- over the cat where it sits: in the tub, or at a later step's station
	local cat = v.cat
	local seat = if cat
		then cat.model:GetPivot()
		else v.seat or SpaLayout.tubSpot() * CFrame.new(0, SEAT_HEIGHT, 0)
	local anchor =
		makePart("WashMarker", Vector3.new(1, 1, 1), BUTTON_COLOR, CFrame.new(seat.Position))
	anchor.Transparency = 1
	anchor.CanQuery = false
	anchor.CanTouch = false
	local board = Instance.new("BillboardGui")
	board.Name = "Paw"
	board.Size = UDim2.fromOffset(56, 56)
	board.StudsOffset = Vector3.new(0, MARKER_UP, 0)
	board.AlwaysOnTop = true
	board.Parent = anchor
	local box = Instance.new("Frame")
	box.Name = "IconBox"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.Parent = board
	Icons.draw("Paw", box)
	TweenService:Create(board, MARKER_BOB, { StudsOffset = Vector3.new(0, MARKER_UP + 0.5, 0) })
		:Play()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Wash"
	prompt.ActionText = "Wash"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = WASH_PROMPT_REACH
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		if visit == v then
			stepIn(v)
		end
	end)
	prompt.Parent = anchor
	anchor.Parent = v.folder
	return anchor
end

-- The Walk button: the close-up is let go and the player has their camera and walking back, while the cat waits
-- in the tub with its stage kept. Nothing is sent to the server, and it never cancels or costs anything.
function ScrubController.stepOut()
	local v = visit
	if v == nil or not walkShown then
		return
	end
	release()
	v.steppedOut = true
	if v.marker == nil then
		v.marker = buildMarker(v)
	end
	updateWashView(v)
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
		cameraModel = nil,
		scrub = ScrubRules.newState(1),
		catParams = catParams,
		buttonParams = buttonParams,
		catId = nil,
		stage = "waiting",
		strokes = 0,
		brushStrokes = SpaRules.BRUSH_STROKES,
		strokeTravel = 0,
		lastStrokeAt = -math.huge,
		needs = {},
		locked = {},
		later = {},
		plan = {},
		step = nil,
		suds = {},
		swirl = 0,
		away = false,
		hold = nil,
		holdSince = 0,
		ring = nil,
		mascot = false,
		steppedOut = false,
		marker = nil,
	}
end

local function enable()
	if enabled then
		return
	end
	enabled = true
	local folder: Folder = trove:Add(Instance.new("Folder"))
	folder.Name = "PH_SpaPrototype"
	local v = buildVisit(folder)
	visit = v
	folder.Parent = Workspace
	task.spawn(function()
		if visit == v then
			ensureTub(v)
		end
	end)

	trove:Connect(Remotes.event("CatReady").OnClientEvent, onCatReady)
	trove:Connect(Remotes.event("PhotoPaid").OnClientEvent, onPhotoPaid)
	trove:Connect(Remotes.event("CatStage").OnClientEvent, onCatStage)
	trove:Connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
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
		if v.steppedOut then
			-- stepped out (the Walk button): a tap on the waiting cat brings the close-up back, and does not scrub
			if ray and cast(ray, v.catParams) then
				stepIn(v)
			end
			return
		end
		if
			(v.stage ~= "dirty" and v.stage ~= "clean" and v.step == nil)
			or not ray
			or not cast(ray, v.catParams)
		then
			return
		end
		activeInput = input
		holdCamera(input.UserInputType == Enum.UserInputType.Touch)
		holdControls(input.UserInputType == Enum.UserInputType.Touch)
		onPointer(input)
	end)
	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		local active = activeInput
		if active == nil then
			return
		end
		if active.UserInputType == Enum.UserInputType.Touch then
			-- Only the finger that started. A second finger on the thumbstick walks, unless scrubFeel pauses
			-- walking while a finger scrubs.
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
	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		if input == activeInput then
			release()
			local v = visit
			local cat = if v then v.cat else nil
			if v and cat then
				turnToShow(v, cat)
			end
		end
	end)
	-- When the app loses focus mid-scrub (a call, a swipe home), Roblox can skip that touch's InputEnded. Let go
	-- here so the camera and the controls are never left held and the next press can scrub.
	trove:Connect(UserInputService.WindowFocusReleased, release)
	-- A held trigger has no pointer movement: the middle of the screen moves as the camera turns.
	for _, need in CatRules.LATER_NEEDS do
		trove:Connect(
			ReplicatedStorage:GetAttributeChangedSignal(
				LiveFlags.ATTRIBUTE_PREFIX .. WashDraft.NEED_FLAG[need]
			),
			function()
				dropLater(need)
			end
		)
	end
	trove:Connect(RunService.Heartbeat, function()
		local active = activeInput
		if active and active.KeyCode == GAMEPAD_BUTTON then
			onPointer(active)
		end
		-- the Pawdicure: a press held on a paw for CLAW_HOLD clips it
		local v = visit
		local cat = if v then v.cat else nil
		local paw = if v then v.hold else nil
		if
			v
			and cat
			and paw
			and active
			and v.step == "claws"
			and LaterStepRules.held(v.holdSince, os.clock())
		then
			clipPaw(v, cat, paw)
		end
	end)

	trove:Add(function()
		if nextCatThread then
			task.cancel(nextCatThread)
			nextCatThread = nil
		end
	end)

	Remotes.event("RequestCat"):FireServer()
end

local function disable()
	if not enabled then
		return
	end
	enabled = false
	release()
	local ending = visit
	if ending and ending.cat then
		BrushShine.untrack(ending.cat.model) -- the folder and the cat go with the trove below
	end
	visit = nil
	WashView.set(WASH_REASON, false)
	WashView.frame(nil)
	updateWashView(nil)
	trove:Clean()
	ScrubController.stageChanged:Fire(nil)
end

local function refresh()
	if LiveFlags.isOn(FLAG) then
		enable()
	else
		disable()
	end
end

-- The HUD names of this cat's later steps, in order (none with no visit).
function ScrubController.plan(): { string }
	local v = visit
	return if v then table.clone(v.plan) else {}
end

-- The current visit's step (a later step's HUD name while one is under way), or nil with no visit (the switch is off).
function ScrubController.stage(): string?
	local v = visit
	return if v then hudStage(v) else nil
end

-- Where a cat sits in the tub: the tub's CatSeat once a cat has come, else its usual height over the tub's spot
-- (the opening's carried kitten is set down here, OpeningController).
function ScrubController.seatSpot(): CFrame
	local v = visit
	local seat = if v then v.seat else nil
	return seat or SpaLayout.tubSpot() * CFrame.new(0, SEAT_HEIGHT, 0)
end

-- The size a cat sits at in the tub (the sit body is scaled to it), so the opening's carried kitten lands at it and
-- never pops bigger as the tub's kitten appears (Sync-Agent's run on 0f020c9).
function ScrubController.seatScale(): number
	return CAT_SCALE
end

function ScrubController.Init(_controllers: { [string]: any }) end

function ScrubController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	-- The plot placed or taken away: the tub moves to its new spot the way a switch flip does, by starting the
	-- visit again (the server resends a dirty cat as it is).
	local function restart()
		if enabled then
			disable()
			refresh()
		end
	end
	SpaLayout.changed(restart)
	-- The wash view's switch takes effect at once, on or off, for the cat in the tub now.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. WASH_FLAG)
		:Connect(function()
			updateWashView(visit)
		end)
	-- A reset clears every hold on the view (Spa/WashView); a cat still in the tub takes it back, once the new
	-- character is in (deferred, after WashView and ControlHold have cleared). Review-QA on #368.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(function()
			updateWashView(visit)
		end)
	end)
	-- spawnView turns the tub (SpaLayout.tubSpot): start the visit again so the tub and buttons turn with it.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. SpaLayout.VIEW_FLAG)
		:Connect(restart)
	refresh()
end

return ScrubController
