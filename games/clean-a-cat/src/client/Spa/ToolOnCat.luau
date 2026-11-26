--!strict
-- ToolOnCat: the wash step's real tool (the 3D sponge, brush or clipper) on the cat's fur where the player rubs,
-- behind the live switch toolOnCat, off by default. The owner's dev test (2026-11-24): no picture of the tool on
-- the screen ("they can see it being used"), so the tool icon under the finger (toolCursor) went off, and this
-- puts the tool itself on the cat so the player still sees what is working. Client only and cosmetic: the copy is
-- anchored and never collides, casts a shadow, catches a ray or touches anything, so the scrub's rays go through it.
--
--   ToolOnCat.show(name, at, normal, faint)  puts tool model `name` (in ReplicatedStorage.Assets) on the fur at
--       `at`, its bottom on the surface with normal `normal` and its working part (Handle) over `at`; another name
--       swaps the tool. `faint` (the touch is on the kitten's head) shows it see-through so his face stays in view
--       (Review-QA's rule from the tool icon: never cover the face)
--   ToolOnCat.hide()                  takes it away (the finger lifted or slid off the cat, the step ended)
--   ToolOnCat.modelFor(stage, step, owns)  which tool model a wash step shows (nil for a step with no tool)
--
-- The tool lies on the fur with its front (-Z, the brush's head) pointing up the screen, so its grip points down
-- toward the player's thumb. It glides to each new touch point instead of jumping between the cat's parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local ToolOnCat = {}

ToolOnCat.FLAG = "toolOnCat"
local SOAP_FLAG = "foamStep"
local SOAP_BAR = "CleanACat_Tool_SoapBar"

local SCALE = 1.1 -- the tools are drawn about twice real size for a hand; this reads on the 1.5 scale cat
local LIFT = 0.04 -- studs the tool's bottom floats off the fur, so it never sinks into a curve of the coat
local GLIDE = 30 -- per second; how fast the tool catches up with the touch point
local FAINT = 0.6 -- see-through on the kitten's head
-- (switch washScreen, issue 904) Derek on dev, 2026-11-26: "make the transparent models of stuff for cleaning a little
-- less transparent but much smaller": about half the size, so the sponge no longer covers his head, and a lighter fade
local SMALL_SCALE = 0.55
local SMALL_FAINT = 0.35
local SMALL_FLAG = "washScreen"

local function small(): boolean
	return LiveFlags.isOn(SMALL_FLAG)
end

-- The tool each wash step shows. A later step (step) wins over the stage it runs in, as in ScrubController.
-- Owned upgrades show their own model (Bubble Soap's sponge, the Pro Brush's fluffy brush).
function ToolOnCat.modelFor(stage: string?, step: string?, owns: (string) -> boolean): string?
	if step == "claws" then
		return "CleanACat_Tool_Clipper"
	elseif step == "rinse" then
		return "CleanACat_Tool_Shower" -- (washMeter) spray the foam off
	elseif step == "smell" then
		-- (switch foamStep, issue 888) "Foam up the cat" with Model-Agent's soap bar, once it is in the game
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		if LiveFlags.isOn(SOAP_FLAG) and assets and assets:FindFirstChild(SOAP_BAR) then
			return SOAP_BAR
		end
		return "CleanACat_Tool_SpongeBubble" -- the Bubble Bath ("Swirl the suds")
	elseif stage == "dirty" then
		return if owns("BubbleSoap") then "CleanACat_Tool_SpongeBubble" else "CleanACat_Tool_Sponge"
	elseif stage == "clean" then
		return if owns("ProBrush") then "CleanACat_Tool_BrushFluffy" else "CleanACat_Tool_Brush"
	end
	return nil
end

type Copy = { model: Model, offset: CFrame, parts: { BasePart }, faint: boolean }

local copies: { [string]: Copy } = {} -- one copy per tool, made on first use and kept, parented only while shown
local missing: { [string]: boolean } = {}
local shown: Copy? = nil
local target: CFrame? = nil
local current: CFrame? = nil
local follow: RBXScriptConnection? = nil

-- A client-only copy of tool `name`, scaled, with nothing that collides, shadows or catches a ray. `offset` takes
-- the surface frame (Y along the fur's normal) to the model's pivot, so the bottom of its box sits on the fur and
-- its Handle is over the touch point.
local function copyOf(name: string): Copy?
	local scale = if small() then SMALL_SCALE else SCALE
	local key = `{name}@{scale}` -- a copy per size, so the switch changing mid-session makes a new one
	local have = copies[key]
	if have then
		return have
	end
	if missing[name] then
		return nil
	end
	-- never waits: this runs inside a touch (Review-QA's nit on #404); the assets are in long before the first wash
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(name) else nil
	if not (asset and asset:IsA("Model")) then
		missing[name] = true
		warn(`ToolOnCat: ReplicatedStorage.Assets.{name} is missing`)
		return nil
	end
	local model = asset:Clone() :: Model
	model:ScaleTo(scale)
	local parts: { BasePart } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			table.insert(parts, part)
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Massless = true
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy() -- our own models ship none; a copy never runs code
		end
	end
	model:PivotTo(CFrame.identity)
	local box, size = model:GetBoundingBox()
	-- over the touch point: the working part (Handle: the sponge, the brush's head), else the middle of the box
	local handle = model:FindFirstChild("Handle", true)
	local over = if handle and handle:IsA("BasePart")
		then (handle :: BasePart).Position
		else box.Position
	local bottom = Vector3.new(over.X, box.Position.Y - size.Y / 2, over.Z)
	local copy = {
		model = model,
		offset = CFrame.new(-bottom + Vector3.new(0, LIFT, 0)),
		parts = parts,
		faint = false,
	}
	copies[key] = copy
	return copy
end

-- The frame on the fur at `at`: Y along `normal`, -Z up the screen (the camera's up laid flat on the fur).
local function surfaceFrame(at: Vector3, normal: Vector3): CFrame
	local up = if normal.Magnitude > 1e-4 then normal.Unit else Vector3.yAxis
	local camera = Workspace.CurrentCamera
	local screenUp = if camera then camera.CFrame.UpVector else Vector3.yAxis
	local forward = screenUp - up * screenUp:Dot(up)
	if forward.Magnitude < 1e-3 then
		local look = if camera then camera.CFrame.LookVector else -Vector3.zAxis
		forward = look - up * look:Dot(up)
	end
	if forward.Magnitude < 1e-3 then
		forward = up:Cross(Vector3.xAxis)
	end
	local back = -forward.Unit
	return CFrame.fromMatrix(at, up:Cross(back), up, back)
end

local function stopFollow()
	local connection = follow
	follow = nil
	if connection then
		connection:Disconnect()
	end
end

function ToolOnCat.hide()
	stopFollow()
	local copy = shown
	shown = nil
	target = nil
	current = nil
	if copy then
		copy.model.Parent = nil
	end
end

local function setFaint(copy: Copy, faint: boolean)
	if copy.faint == faint then
		return
	end
	copy.faint = faint
	for _, part in copy.parts do
		part.LocalTransparencyModifier = if faint
			then (if small() then SMALL_FAINT else FAINT)
			else 0
	end
end

function ToolOnCat.show(name: string?, at: Vector3, normal: Vector3, faint: boolean?)
	if name == nil or not LiveFlags.isOn(ToolOnCat.FLAG) then
		ToolOnCat.hide()
		return
	end
	local copy = copyOf(name)
	if copy == nil then
		ToolOnCat.hide()
		return
	end
	setFaint(copy, faint == true)
	local frame = surfaceFrame(at, normal)
	local was = shown
	if was ~= copy then
		if was then
			was.model.Parent = nil
		end
		shown = copy
		current = frame -- a new tool starts where the finger is, with no glide from the last one
		copy.model:PivotTo(frame * copy.offset)
		copy.model.Parent = Workspace
	end
	target = frame
	if follow == nil then
		follow = RunService.RenderStepped:Connect(function(dt: number)
			local goal = target
			local now = current
			local on = shown
			if goal == nil or now == nil or on == nil then
				return
			end
			local step = now:Lerp(goal, 1 - math.exp(-GLIDE * dt))
			current = step
			on.model:PivotTo(step * on.offset)
		end)
	end
end

-- the switch going off mid-drag takes the tool away at once
ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. ToolOnCat.FLAG)
	:Connect(function()
		if not LiveFlags.isOn(ToolOnCat.FLAG) then
			ToolOnCat.hide()
		end
	end)

return ToolOnCat
