--!strict
-- ScrubController: the scrub and reveal prototype on the player's own device. A placeholder grey cat sits in a
-- placeholder tub; dragging a finger (or holding the mouse) over it rubs the mud patches away, and at 80% clean
-- the rest pop off. Rules live in Shared.ScrubRules; effects and sound listen to Shared.Moments.
-- Behind the LiveFlags switch `scrubPrototype` (off by default). Nothing here touches the server or saves: the
-- cat and its mud exist only on this device until coins and saves arrive with their own server checks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local ScrubRules = require(Shared:WaitForChild("ScrubRules"))

local FLAG = "scrubPrototype"
local TUB_POSITION = Vector3.new(0, 0, -12) -- in front of the placeholder spawn, on the placeholder floor
local CAT_RADIUS = 1.6 -- studs; the body ball's radius
local HEAD_DIRECTION = Vector3.new(0, 0.6, 0.8) -- from the body's center; faces the spawn (+Z) so the camera sees the face
local PATCH_SIZE = Vector3.new(0.12, 1.1, 1.1) -- a flat disc: thin along its normal
local DIRTY_COLOR = Color3.fromRGB(120, 112, 104)
local CLEAN_COLOR = Color3.fromRGB(205, 205, 210)
local MUD_COLOR = Color3.fromRGB(92, 64, 40)
local PATCH_FADE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- a cleared patch fades, not blinks
local RESET_SECONDS = 4 -- prototype loop: the cat gets muddy again so a tester can repeat

type Scrub = {
	model: Model,
	body: BasePart,
	head: BasePart,
	patches: { BasePart },
	state: ScrubRules.State,
	raycastParams: RaycastParams,
}

local ScrubController = {}

local current: Scrub? = nil
local enabled = false
local activeInput: InputObject? = nil -- the one press (mouse button or finger) that scrubs
local scrubbing = false
local lastHit: Vector3? = nil
local lastMoveTime = 0
local savedCameraType: Enum.CameraType? = nil
local connections: { RBXScriptConnection } = {}
local resetThread: thread? = nil

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

-- A cleared patch stops catching the sponge at once and fades out over PATCH_FADE.
local function hidePatch(patch: BasePart)
	patch.CanQuery = false
	TweenService:Create(patch, PATCH_FADE, { Transparency = 1 }):Play()
end

local function setDirty(scrub: Scrub)
	scrub.state = ScrubRules.newState(#scrub.patches)
	scrub.body.Color = DIRTY_COLOR
	scrub.head.Color = DIRTY_COLOR
	for _, patch in scrub.patches do
		patch.Transparency = 0
		patch.CanQuery = true
	end
end

local function buildCat(parent: Instance): Scrub
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
	local head = makePart(
		"Head",
		Enum.PartType.Ball,
		Vector3.one * 1.8,
		DIRTY_COLOR,
		CFrame.new(center + HEAD_DIRECTION * (CAT_RADIUS + 0.5))
	)
	head.Parent = model
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

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { model }

	local scrub: Scrub = {
		model = model,
		body = body,
		head = head,
		patches = patches,
		state = ScrubRules.newState(#patches),
		raycastParams = raycastParams,
	}
	setDirty(scrub)
	return scrub
end

-- Where the pointer at screen position `screen` touches the cat, if it does.
local function hitCat(scrub: Scrub, screen: Vector3): RaycastResult?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	return Workspace:Raycast(ray.Origin, ray.Direction * 200, scrub.raycastParams)
end

local function holdCamera(hold: boolean)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if hold and savedCameraType == nil then
		-- A finger dragging on the world spins the default camera; hold it still while the finger scrubs.
		savedCameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
	elseif not hold and savedCameraType ~= nil then
		camera.CameraType = savedCameraType :: Enum.CameraType
		savedCameraType = nil
	end
end

local function stopScrub()
	if scrubbing and current then
		Moments.ScrubStop:Fire(current.model, lastHit or current.body.Position)
	end
	scrubbing = false
	lastHit = nil
end

local function reveal(scrub: Scrub)
	for _, index in ScrubRules.reveal(scrub.state) do
		hidePatch(scrub.patches[index])
	end
	scrub.body.Color = CLEAN_COLOR
	scrub.head.Color = CLEAN_COLOR
	stopScrub()
	Moments.CatClean:Fire(scrub.model)

	resetThread = task.delay(RESET_SECONDS, function()
		resetThread = nil
		if current == scrub then
			setDirty(scrub)
		end
	end)
end

-- Rubs every patch within the sponge's reach of `point` by `travel` studs.
local function rubAt(scrub: Scrub, point: Vector3, travel: number)
	for index, patch in scrub.patches do
		if
			not scrub.state.cleared[index]
			and (patch.Position - point).Magnitude <= ScrubRules.SPONGE_RADIUS
		then
			if ScrubRules.rub(scrub.state, index, travel) then
				hidePatch(patch)
				Moments.MudPatchCleared:Fire(
					scrub.model,
					patch.Position,
					ScrubRules.patchesLeft(scrub.state)
				)
			end
		end
	end
	if ScrubRules.shouldReveal(scrub.state) then
		reveal(scrub)
	end
end

local function onPointer(screen: Vector3, isTouch: boolean)
	local scrub = current
	if not scrub or scrub.state.revealed then
		return
	end
	local result = hitCat(scrub, screen)
	if not result then
		-- The finger slid off the cat: the stroke ends, and a new one starts if it slides back on. The camera stays
		-- held until the finger lifts, so it does not jump mid-drag.
		if scrubbing then
			stopScrub()
		end
		return
	end
	local point = result.Position
	if not scrubbing then
		scrubbing = true
		lastHit = point
		lastMoveTime = os.clock()
		holdCamera(isTouch)
		Moments.ScrubStart:Fire(scrub.model, point)
		return
	end
	local previous = lastHit or point
	local travel = (point - previous).Magnitude
	lastHit = point
	if travel <= 0 then
		return
	end
	local now = os.clock()
	local dt = math.max(now - lastMoveTime, 1 / 240)
	lastMoveTime = now
	Moments.ScrubMove:Fire(scrub.model, point, result.Normal, travel / dt)
	rubAt(scrub, point, travel)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function enable()
	if enabled then
		return
	end
	enabled = true
	local folder = Instance.new("Folder")
	folder.Name = "PH_ScrubPrototype"
	buildTub(folder)
	current = buildCat(folder)
	folder.Parent = Workspace

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			-- `processed` is true for taps on buttons, the thumbstick and the jump button: those never scrub.
			if processed or activeInput ~= nil or not isPress(input) then
				return
			end
			-- Only a press that lands on the cat scrubs; a press anywhere else stays a normal camera drag.
			local scrub = current
			if not scrub or scrub.state.revealed or not hitCat(scrub, input.Position) then
				return
			end
			activeInput = input
			onPointer(input.Position, input.UserInputType == Enum.UserInputType.Touch)
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
				-- Only the finger that started the scrub; a second finger on the thumbstick is someone walking.
				if input == active then
					onPointer(input.Position, true)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				onPointer(input.Position, false)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input == activeInput then
				activeInput = nil
				stopScrub()
				holdCamera(false)
			end
		end)
	)
end

local function disable()
	if not enabled then
		return
	end
	enabled = false
	stopScrub()
	holdCamera(false)
	activeInput = nil
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if resetThread then
		task.cancel(resetThread)
		resetThread = nil
	end
	local scrub = current
	current = nil
	if scrub then
		local folder = scrub.model.Parent
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
