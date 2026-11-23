--!strict
-- ScrubController: one cat's visit on the player's own device, as a prototype with placeholder parts. The server
-- (SpaService) hands out a cat; the player scrubs the mud off (80% clean pops the rest), brushes it three times,
-- taps one of three bows and taps the camera for the photo, which the server pays. Rules live in Shared.ScrubRules
-- and Shared.SpaRules; effects and sound listen to Shared.Moments. Behind the LiveFlags switch `scrubPrototype`.
--
-- Input: a finger drag or a held left mouse button on the cat scrubs and brushes; a tap or click on a bow or the
-- camera picks it. Gamepad: hold the right trigger with the cat in the middle of the screen and turn the camera
-- with the right stick; the right trigger also picks the bow or camera in the middle of the screen.
-- The client only reports what the player did. The server checks every step and alone decides the coins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScrubRules = require(Shared:WaitForChild("ScrubRules"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))

local FLAG = "scrubPrototype"
local TUB_POSITION = Vector3.new(0, 0, -12) -- in front of the placeholder spawn, on the placeholder floor
local CAT_RADIUS = 1.6 -- studs; the body ball's radius
local HEAD_DIRECTION = Vector3.new(0, 0.6, 0.8) -- from the body's center; faces the spawn (+Z) so the camera sees the face
local PATCH_SIZE = Vector3.new(0.12, 1.1, 1.1) -- a flat disc: thin along its normal
local DIRTY_COLOR = Color3.fromRGB(120, 112, 104)
local CLEAN_COLOR = Color3.fromRGB(205, 205, 210)
local FLUFFED_COLOR = Color3.fromRGB(236, 236, 240)
local MUD_COLOR = Color3.fromRGB(92, 64, 40)
local PATCH_FADE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- a cleared patch fades, not blinks
local STROKE_TRAVEL = 2.5 -- studs of drag on the cat that make one brush stroke
local NEXT_CAT_SECONDS = 3 -- after the photo pays, the next cat is asked for
local GAMEPAD_BUTTON = Enum.KeyCode.ButtonR2 -- not ButtonA, which jumps
local BOW_COLORS: { [string]: Color3 } = {
	BowPink = Color3.fromRGB(255, 120, 170),
	BowBlue = Color3.fromRGB(90, 160, 255),
	BowGold = Color3.fromRGB(255, 200, 60),
}

type Stage = "waiting" | SpaRules.Stage

type Visit = {
	model: Model,
	body: BasePart,
	head: BasePart,
	bow: BasePart,
	patches: { BasePart },
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

local function makePart(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	cframe: CFrame
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
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

local function buildTub(parent: Instance)
	local tub = Instance.new("Model")
	tub.Name = "PH_Tub"
	local base = makePart(
		"Base",
		Enum.PartType.Block,
		Vector3.new(6, 1.2, 5),
		Color3.fromRGB(235, 240, 245),
		CFrame.new(TUB_POSITION + Vector3.new(0, 0.6, 0))
	)
	base.CanCollide = true
	base.Parent = tub
	local water = makePart(
		"Water",
		Enum.PartType.Block,
		Vector3.new(5.4, 0.2, 4.4),
		Color3.fromRGB(150, 200, 235),
		CFrame.new(TUB_POSITION + Vector3.new(0, 1.25, 0))
	)
	water.Transparency = 0.3
	water.CanQuery = false
	water.Parent = tub
	tub.Parent = parent
end

-- Three bow buttons in a row above the tub and a camera button beside it: placeholders for the bottom bar and the
-- camera stand in the first session plan.
local function buildButtons(parent: Instance): ({ BasePart }, BasePart)
	local buttons = Instance.new("Model")
	buttons.Name = "PH_Buttons"
	local bowButtons: { BasePart } = {}
	for index, bowId in SpaRules.BOWS do
		local x = (index - 2) * 2.2
		local button = makePart(
			bowId,
			Enum.PartType.Block,
			Vector3.new(1.6, 1.6, 0.4),
			BOW_COLORS[bowId] or CLEAN_COLOR,
			CFrame.new(TUB_POSITION + Vector3.new(x, 7, 1))
		)
		button:SetAttribute("BowId", bowId)
		show(button, false)
		button.Parent = buttons
		table.insert(bowButtons, button)
	end
	local camera = makePart(
		"Camera",
		Enum.PartType.Block,
		Vector3.new(1.4, 1, 1),
		Color3.fromRGB(40, 40, 48),
		CFrame.new(TUB_POSITION + Vector3.new(4.5, 2.5, 1))
	)
	show(camera, false)
	camera.Parent = buttons
	buttons.Parent = parent
	return bowButtons, camera
end

-- A cleared patch stops catching the sponge at once and fades out over PATCH_FADE.
local function hidePatch(patch: BasePart)
	patch.CanQuery = false
	TweenService:Create(patch, PATCH_FADE, { Transparency = 1 }):Play()
end

local function setCatColor(v: Visit, color: Color3)
	v.body.Color = color
	v.head.Color = color
end

-- A new dirty cat in the tub (the server's cat `catId`).
local function startCat(v: Visit, catId: number)
	v.catId = catId
	v.stage = "dirty"
	v.scrub = ScrubRules.newState(#v.patches)
	v.strokes = 0
	v.strokeTravel = 0
	v.lastStrokeAt = -math.huge
	setCatColor(v, DIRTY_COLOR)
	show(v.bow, false)
	v.bow.CanQuery = false
	for _, patch in v.patches do
		patch.Transparency = 0
		patch.CanQuery = true
	end
	for _, button in v.bowButtons do
		show(button, false)
	end
	show(v.camera, false)
end

local function buildVisit(parent: Instance): Visit
	local model = Instance.new("Model")
	model.Name = "PH_Cat"
	local center = TUB_POSITION + Vector3.new(0, 1.2 + CAT_RADIUS, 0)
	local body = makePart(
		"Body",
		Enum.PartType.Ball,
		Vector3.one * CAT_RADIUS * 2,
		DIRTY_COLOR,
		CFrame.new(center)
	)
	body.Parent = model
	local headCenter = center + HEAD_DIRECTION * (CAT_RADIUS + 0.5)
	local head =
		makePart("Head", Enum.PartType.Ball, Vector3.one * 1.8, DIRTY_COLOR, CFrame.new(headCenter))
	head.Parent = model
	local bow = makePart(
		"Bow",
		Enum.PartType.Block,
		Vector3.new(1, 0.5, 0.3),
		CLEAN_COLOR,
		CFrame.new(headCenter + Vector3.new(0, 0.95, 0))
	)
	bow.Parent = model
	model.PrimaryPart = body

	local patches: { BasePart } = {}
	for index, direction in ScrubRules.patchDirections(ScrubRules.PATCH_COUNT, HEAD_DIRECTION, 0.8) do
		local position = center + direction * (CAT_RADIUS + 0.02)
		-- The disc's thin X axis points along the surface normal.
		local patch = makePart(
			string.format("Mud%02d", index),
			Enum.PartType.Cylinder,
			PATCH_SIZE,
			MUD_COLOR,
			CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
		)
		patch.Material = Enum.Material.Sand
		patch:SetAttribute("PatchIndex", index)
		patch.Parent = model
		table.insert(patches, patch)
	end
	model.Parent = parent

	local bowButtons, camera = buildButtons(parent)

	local catParams = RaycastParams.new()
	catParams.FilterType = Enum.RaycastFilterType.Include
	catParams.FilterDescendantsInstances = { model }
	local buttonParams = RaycastParams.new()
	buttonParams.FilterType = Enum.RaycastFilterType.Include
	local buttonList: { Instance } = { camera }
	for _, button in bowButtons do
		table.insert(buttonList, button)
	end
	buttonParams.FilterDescendantsInstances = buttonList

	local v: Visit = {
		model = model,
		body = body,
		head = head,
		bow = bow,
		patches = patches,
		bowButtons = bowButtons,
		camera = camera,
		scrub = ScrubRules.newState(#patches),
		catParams = catParams,
		buttonParams = buttonParams,
		catId = nil,
		stage = "waiting",
		strokes = 0,
		strokeTravel = 0,
		lastStrokeAt = -math.huge,
	}
	-- Hidden until the server hands out a cat.
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			show(part :: BasePart, false)
		end
	end
	return v
end

local function showCat(v: Visit)
	show(v.body, true)
	show(v.head, true)
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
	if stroking and v and v.stage == "dirty" then
		Moments.ScrubStop:Fire(v.model, lastHit or v.body.Position)
	end
	if v then
		v.strokeTravel = 0
	end
	stroking = false
	lastHit = nil
end

local function reveal(v: Visit)
	for _, index in ScrubRules.reveal(v.scrub) do
		hidePatch(v.patches[index])
	end
	setCatColor(v, CLEAN_COLOR)
	endStroke()
	v.stage = "clean"
	Moments.CatClean:Fire(v.model)
	Remotes.event("ReportScrubbed"):FireServer(v.catId)
end

-- Rubs every patch within the sponge's reach of `point` by `travel` studs.
local function rubAt(v: Visit, point: Vector3, travel: number)
	for index, patch in v.patches do
		if
			not v.scrub.cleared[index]
			and (patch.Position - point).Magnitude <= ScrubRules.SPONGE_RADIUS
		then
			if ScrubRules.rub(v.scrub, index, travel) then
				hidePatch(patch)
				Moments.MudPatchCleared:Fire(
					v.model,
					patch.Position,
					ScrubRules.patchesLeft(v.scrub)
				)
			end
		end
	end
	if ScrubRules.shouldReveal(v.scrub) then
		reveal(v)
	end
end

-- Brush travel on the clean cat; every STROKE_TRAVEL studs is one stroke, and the last stroke fluffs the cat.
local function brushAt(v: Visit, travel: number)
	v.strokeTravel += travel
	local now = os.clock()
	if v.strokeTravel < STROKE_TRAVEL or now - v.lastStrokeAt < SpaRules.MIN_STROKE_GAP then
		return
	end
	v.strokeTravel = 0
	v.lastStrokeAt = now
	v.strokes += 1
	Moments.BrushSwipe:Fire(v.model, v.strokes)
	Remotes.event("ReportBrushStroke"):FireServer(v.catId)
	if v.strokes >= SpaRules.BRUSH_STROKES then
		v.stage = "fluffed"
		setCatColor(v, FLUFFED_COLOR)
		endStroke()
		Moments.CatFluffed:Fire(v.model)
		for _, button in v.bowButtons do
			show(button, true)
		end
	end
end

local function onPointer(input: InputObject)
	local v = visit
	if not v or (v.stage ~= "dirty" and v.stage ~= "clean") then
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
			Moments.ScrubStart:Fire(v.model, point)
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
		Moments.ScrubMove:Fire(v.model, point, result.Normal, travel / dt)
		rubAt(v, point, travel)
	else
		brushAt(v, travel)
	end
end

-- A tap on a bow or the camera. True when the press landed on one, so it does not also start a stroke.
local function tapButton(v: Visit, input: InputObject): boolean
	local ray = pointerRay(input)
	local result = if ray then cast(ray, v.buttonParams) else nil
	if not result then
		return false
	end
	local part = result.Instance
	local bowId = part:GetAttribute("BowId")
	if v.stage == "fluffed" and type(bowId) == "string" then
		v.stage = "styled"
		v.bow.Color = BOW_COLORS[bowId] or CLEAN_COLOR
		show(v.bow, true)
		v.bow.CanQuery = false
		for _, button in v.bowButtons do
			show(button, false)
		end
		show(v.camera, true)
		Moments.BowChosen:Fire(v.model, bowId)
		Remotes.event("RequestPickBow"):FireServer(v.catId, bowId)
	elseif v.stage == "styled" and part == v.camera then
		-- The camera stays until the server pays, so a tap the server refused (too soon) can be repeated.
		Remotes.event("RequestPhoto"):FireServer(v.catId)
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

local function onCatReady(rawId: unknown)
	local v = visit
	if not v or type(rawId) ~= "number" then
		return
	end
	release()
	showCat(v)
	startCat(v, rawId)
end

local function onPhotoPaid(rawId: unknown)
	local v = visit
	if not v or rawId ~= v.catId or v.stage ~= "styled" then
		return
	end
	v.stage = "done"
	show(v.camera, false)
	Moments.PhotoTaken:Fire(v.model)
	nextCatThread = task.delay(NEXT_CAT_SECONDS, function()
		nextCatThread = nil
		if visit == v then
			Remotes.event("RequestCat"):FireServer()
		end
	end)
end

local function enable()
	if enabled then
		return
	end
	enabled = true
	local folder = Instance.new("Folder")
	folder.Name = "PH_SpaPrototype"
	buildTub(folder)
	visit = buildVisit(folder)
	folder.Parent = Workspace

	table.insert(connections, Remotes.event("CatReady").OnClientEvent:Connect(onCatReady))
	table.insert(connections, Remotes.event("PhotoPaid").OnClientEvent:Connect(onPhotoPaid))
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
		local folder = v.model.Parent
		if folder then
			folder:Destroy()
		end
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
	refresh()
end

return ScrubController
