--!strict
-- WorkerBar: the progress bar over a cat a worker is washing (issue #528; the design: a worker "shows a progress bar
-- above the cat"). Gameplay sets a WorkerProgress number attribute (0 to 1) on the worker's cat, so a late joiner
-- sees the bar too (agreed with Gameplay-Engineer for #509). This draws it: a soft rounded pastel bar that fills
-- smoothly toward the attribute (the server steps it), with a gentle shine sliding along the fill. At 1 it gives
-- one small pop and fades; when the attribute goes it hides.
--
-- Client only and cosmetic. Phone budget: one BillboardGui of a few Frames per washing cat, no images, a frame loop
-- that runs only while a bar is visible and near the camera. Reduced Motion: the fill jumps to each value and there
-- is no shine or pop.
--
-- API
--   WorkerBar.start()                       watches every cat (the `Cat` attribute) in Workspace
--   WorkerBar.ease(shown, target, dt) -> number   pure: the fill moved toward `target` this frame
--   WorkerBar.popAt(t) -> number            pure: the bar's scale `t` seconds after it filled (1 when over)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort"))

local WorkerBar = {}

WorkerBar.ATTRIBUTE = "WorkerProgress"
WorkerBar.WIDTH = 2.6 -- studs
WorkerBar.HEIGHT = 0.42
WorkerBar.OVER = 0.9 -- studs over the top of the cat
WorkerBar.RATE = 6 -- how fast the fill catches up, per second
WorkerBar.POP_SECONDS = 0.35
WorkerBar.FADE_SECONDS = 0.4 -- after the pop
WorkerBar.FAR = 60 -- studs: hidden past this (MaxDistance), and the loop skips it
local TRACK = Color3.fromRGB(255, 255, 255)
-- Kit.INK, the screens' outline (lilac means special customers in the style guide: Review-QA on #557); copied, not
-- required, so the specs can load this module without the UI kit
local EDGE = Color3.fromHex("45226B")
local FILL = Color3.fromRGB(140, 214, 170)
local SHINE = Color3.fromRGB(255, 255, 255)

function WorkerBar.ease(shown: number, target: number, dt: number): number
	local t = math.clamp(target, 0, 1)
	if t < shown then
		return t -- a new cat starts over: no draining backwards
	end
	return t + (shown - t) * math.exp(-WorkerBar.RATE * dt)
end

function WorkerBar.popAt(t: number): number
	if t <= 0 or t >= WorkerBar.POP_SECONDS then
		return 1
	end
	return 1 + 0.12 * math.sin(math.pi * t / WorkerBar.POP_SECONDS)
end

type Bar = {
	cat: Model,
	gui: BillboardGui,
	fill: Frame,
	shine: Frame,
	scale: UIScale,
	shown: number,
	doneAt: number?,
}

local bars: { [Model]: Bar } = {}
local watched: { [Model]: boolean } = {}
local stepping: RBXScriptConnection? = nil

local function corner(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = parent
end

local function make(cat: Model): Bar?
	local box, size = cat:GetBoundingBox()
	local adornee = cat.PrimaryPart or cat:FindFirstChildWhichIsA("BasePart", true)
	if adornee == nil then
		return nil
	end
	local part = adornee :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "CleanACat_Fx_WorkerBar"
	gui.Size = UDim2.fromScale(WorkerBar.WIDTH, WorkerBar.HEIGHT)
	gui.StudsOffsetWorldSpace =
		Vector3.new(0, (box.Position.Y + size.Y / 2) - part.Position.Y + WorkerBar.OVER, 0)
	gui.MaxDistance = WorkerBar.FAR
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Adornee = part
	local scale = Instance.new("UIScale")
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = TRACK
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.Size = UDim2.fromScale(1, 1)
	corner(track)
	local stroke = Instance.new("UIStroke")
	stroke.Color = EDGE
	stroke.Thickness = 2
	stroke.Parent = track
	scale.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = FILL
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ClipsDescendants = true
	corner(fill)
	fill.Parent = track
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = SHINE
	shine.BackgroundTransparency = 0.55
	shine.BorderSizePixel = 0
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Size = UDim2.new(0, 10, 0.45, 0)
	shine.Position = UDim2.fromScale(0, 0.12)
	corner(shine)
	shine.Parent = fill
	track.Parent = gui
	gui.Parent = part
	return {
		cat = cat,
		gui = gui,
		fill = fill,
		shine = shine,
		scale = scale,
		shown = 0,
		doneAt = nil,
	}
end

local function drop(cat: Model)
	local bar: Bar? = bars[cat]
	if bar then
		bars[cat] = nil
		bar.gui:Destroy()
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else nil
	local still = Comfort.reducedMotion()
	local now = os.clock()
	for cat, bar in bars do
		if cat.Parent == nil or bar.gui.Parent == nil then
			drop(cat)
			continue
		end
		local adornee = bar.gui.Adornee
		if from and adornee and adornee:IsA("BasePart") then
			if ((adornee :: BasePart).Position - from).Magnitude > WorkerBar.FAR then
				continue
			end
		end
		local value = cat:GetAttribute(WorkerBar.ATTRIBUTE)
		local target = if type(value) == "number" then value else 0
		bar.shown = if still
			then math.clamp(target, 0, 1)
			else WorkerBar.ease(bar.shown, target, dt)
		bar.fill.Size = UDim2.fromScale(bar.shown, 1)
		if not still then
			-- the shine slides along the fill about once every 1.4 s
			bar.shine.Position = UDim2.fromScale((now / 1.4) % 1, 0.12)
		end
		if target >= 1 and bar.doneAt == nil then
			bar.doneAt = now
		end
		local doneAt = bar.doneAt
		if doneAt then
			local since = now - doneAt
			if still or since >= WorkerBar.POP_SECONDS + WorkerBar.FADE_SECONDS then
				drop(cat)
				continue
			end
			bar.scale.Scale = WorkerBar.popAt(since)
			local fade = math.clamp((since - WorkerBar.POP_SECONDS) / WorkerBar.FADE_SECONDS, 0, 1)
			bar.gui.Enabled = fade < 1
			for _, d in bar.gui:GetDescendants() do
				if d:IsA("Frame") then
					local f = d :: Frame
					f.BackgroundTransparency = math.max(f.BackgroundTransparency, fade)
				end
			end
		end
	end
	if next(bars) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function refresh(cat: Model)
	local value = cat:GetAttribute(WorkerBar.ATTRIBUTE)
	if type(value) ~= "number" then
		drop(cat)
		return
	end
	local bar: Bar? = bars[cat]
	if bar and bar.doneAt and value < 1 then
		drop(cat) -- a new cat on the same model: a fresh bar
		bar = nil
	end
	if bar == nil and value < 1 then
		local made = make(cat)
		if made then
			bars[cat] = made
		end
	end
	if next(bars) ~= nil and stepping == nil then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") or instance:GetAttribute("Cat") == nil then
		return
	end
	local cat = instance :: Model
	if watched[cat] then
		return
	end
	watched[cat] = true
	cat:GetAttributeChangedSignal(WorkerBar.ATTRIBUTE):Connect(function()
		refresh(cat)
	end)
	cat.AncestryChanged:Connect(function()
		if not cat:IsDescendantOf(Workspace) then
			drop(cat)
			watched[cat] = nil
		end
	end)
	refresh(cat)
end

local started = false
function WorkerBar.start()
	if started then
		return
	end
	started = true
	for _, d in Workspace:GetDescendants() do
		watch(d)
	end
	Workspace.DescendantAdded:Connect(watch)
end

return WorkerBar
