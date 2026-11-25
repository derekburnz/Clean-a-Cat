--!strict
-- Spotlight: the tutorial's dim step, from Design-Agent's draft (tutorial.html, state "dim"). The screen dims except
-- a gold ring around one HUD button, a gold arrow nudges toward it and a few words say what to do. Behind the live
-- switch tutorialDim, off by default (rule 16: every first-session change ships behind its own switch).
--
--   Spotlight.build(root)               makes it once, over the HUD and under the windows
--   Spotlight.point(target, say, done)  lights `target` with the words `say`; done() once the player presses it
--   Spotlight.clear()                   takes it away without calling done
--   Spotlight.isOn()
--
-- It never presses anything, opens a window or moves the player: the step ends only on the player's own tap of the
-- lit button. The dim does not take presses either, so a player who would rather keep washing can, and the arrow
-- waits. It follows the button if the screen resizes. When the step happens is the first session's call (issue #5);
-- nothing here starts it by itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Comfort = require(script.Parent:WaitForChild("Comfort"))
local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Spotlight = {}

Spotlight.FLAG = "tutorialDim"

local DIM = Color3.fromRGB(36, 16, 56)
local DIM_SHOW = 0.38 -- the draft's 62% dim
local RING_PAD = Vector2.new(16, 16) -- real px of room around the button
local RING_PAD_BOTTOM = 38 -- more under it: the button's caption sits below its face
local RING_STROKE = 5 -- real px: the gold ring
local RING_INK = 4 -- real px: its ink edge, outside the gold
local RING_GOLD = Color3.fromHex("FFD84D") -- the step pill's count chip gold (HUD/TipLine)
local RING_CORNER = 14 -- real px: a small round, so little of the square hole shows past the ring's corners
local GAP = 26 -- design px between the ring and the arrow
local NUDGE = 10 -- design px the arrow nudges toward the button
local SIZES = { full = { arrow = 66, say = 40 }, short = { arrow = 60, say = 36 } }

type Parts = {
	layer: Frame,
	dims: { Frame },
	ring: Frame,
	callout: Frame,
	calloutScale: UIScale,
	nudge: Frame,
	arrow: Frame,
	say: TextLabel,
}

local parts: Parts? = nil
local target: GuiObject? = nil
local onDone: (() -> ())? = nil
local watching: { RBXScriptConnection } = {}
local nudgeTween: Tween? = nil

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function stopWatching()
	for _, connection in watching do
		connection:Disconnect()
	end
	watching = {}
	local tween = nudgeTween
	if tween then
		tween:Cancel()
		nudgeTween = nil
	end
end

-- Puts the dim around the target's ring and the callout to its right.
local function place()
	local p, lit = parts, target
	if p == nil or lit == nil then
		return
	end
	local origin = p.layer.AbsolutePosition
	local size = p.layer.AbsoluteSize
	local at = lit.AbsolutePosition - origin - RING_PAD
	local hole = lit.AbsoluteSize + RING_PAD * 2 + Vector2.new(0, RING_PAD_BOTTOM - RING_PAD.Y)
	-- whole pixels, rounded outward, so no lighter seam runs between the panels (Review-QA on #256)
	local width, height = math.ceil(size.X), math.ceil(size.Y)
	local left, top = math.max(math.floor(at.X), 0), math.max(math.floor(at.Y), 0)
	local right, bottom =
		math.min(math.ceil(at.X + hole.X), width), math.min(math.ceil(at.Y + hole.Y), height)
	-- four panels around the hole: above, below, left and right of it; the root's edges are padded past the screen
	local over = 200
	local above, below, beside, after = p.dims[1], p.dims[2], p.dims[3], p.dims[4]
	above.Position = UDim2.fromOffset(-over, -over)
	above.Size = UDim2.fromOffset(width + 2 * over, top + over)
	below.Position = UDim2.fromOffset(-over, bottom)
	below.Size = UDim2.fromOffset(width + 2 * over, height - bottom + over)
	beside.Position = UDim2.fromOffset(-over, top)
	beside.Size = UDim2.fromOffset(left + over, bottom - top)
	after.Position = UDim2.fromOffset(right, top)
	after.Size = UDim2.fromOffset(width - right + over, bottom - top)
	-- the ring stays on screen, just inside the hole's edges
	local edge = RING_STROKE / 2
	p.ring.Position = UDim2.fromOffset(left + edge, top + edge)
	p.ring.Size = UDim2.fromOffset(right - left - 2 * edge, bottom - top - 2 * edge)

	local scale, short = Kit.screenScale()
	local s = if short then SIZES.short else SIZES.full
	p.calloutScale.Scale = scale
	p.arrow.Size = UDim2.fromOffset(s.arrow, s.arrow)
	p.nudge.Size = UDim2.fromOffset(s.arrow + NUDGE, s.arrow)
	p.say.TextSize = s.say
	-- level with the button's face, just right of the ring
	local face = lit.AbsolutePosition - origin
	p.callout.Position = UDim2.fromOffset(right + GAP * scale, face.Y + lit.AbsoluteSize.Y / 2)
end

local function startNudge()
	local p = parts
	if p == nil or Comfort.reducedMotion() then
		return
	end
	p.arrow.Position = UDim2.fromOffset(NUDGE, 0)
	local tween = TweenService:Create(
		p.arrow,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(0, 0) }
	)
	nudgeTween = tween
	tween:Play()
end

function Spotlight.isOn(): boolean
	return target ~= nil
end

function Spotlight.clear()
	stopWatching()
	target, onDone = nil, nil
	local p = parts
	if p then
		p.layer.Visible = false
	end
end

function Spotlight.point(lit: GuiObject, say: string, done: (() -> ())?)
	Spotlight.clear()
	local p = parts
	if p == nil or not LiveFlags.isOn(Spotlight.FLAG) then
		return
	end
	target, onDone = lit, done
	p.say.Text = say
	p.layer.Visible = true
	place()
	startNudge()
	table.insert(watching, lit:GetPropertyChangedSignal("AbsolutePosition"):Connect(place))
	table.insert(watching, lit:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
	table.insert(watching, p.layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
	-- the button went away (its switch went off): no step to finish
	table.insert(
		watching,
		lit:GetPropertyChangedSignal("Visible"):Connect(function()
			if not lit.Visible then
				Spotlight.clear()
			end
		end)
	)
	if lit:IsA("GuiButton") then
		table.insert(
			watching,
			(lit :: GuiButton).Activated:Connect(function()
				local finished = onDone
				Spotlight.clear()
				if finished then
					finished()
				end
			end)
		)
	end
end

function Spotlight.build(root: Instance)
	local layer = frame("Spotlight", root)
	layer.Size = UDim2.fromScale(1, 1)
	layer.Visible = false
	layer.ZIndex = 8 -- over the HUD, under the windows (10) and the recap (10)

	local dims: { Frame } = {}
	for index = 1, 4 do
		local dim = frame(`Dim{index}`, layer)
		dim.BackgroundTransparency = DIM_SHOW
		dim.BackgroundColor3 = DIM
		dim.ZIndex = 8
		table.insert(dims, dim)
	end

	-- a gold ring with an ink edge and a soft gold glow around the lit button (Design-Agent's draft after the owner's
	-- Pet Store Tycoon note, #425: the button to press reads at once)
	local ring = frame("Ring", layer)
	ring.ZIndex = 9
	Kit.corner(ring, UDim.new(0, RING_CORNER))
	local gold = Kit.stroke(ring, RING_STROKE)
	gold.Color = RING_GOLD
	local inkEdge = frame("Edge", ring)
	inkEdge.AnchorPoint = Vector2.new(0.5, 0.5)
	inkEdge.Position = UDim2.fromScale(0.5, 0.5)
	inkEdge.Size = UDim2.new(1, 2 * RING_STROKE, 1, 2 * RING_STROKE)
	inkEdge.ZIndex = 9
	Kit.corner(inkEdge, UDim.new(0, RING_CORNER + RING_STROKE))
	Kit.stroke(inkEdge, RING_INK)
	local glow = frame("Glow", ring)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	local out = 2 * (RING_STROKE + RING_INK)
	glow.Size = UDim2.new(1, out + 8, 1, out + 8)
	glow.ZIndex = 9
	Kit.corner(glow, UDim.new(0, RING_CORNER + RING_STROKE + RING_INK + 4))
	local warm = Kit.stroke(glow, 8)
	warm.Color = RING_GOLD
	warm.Transparency = 0.45

	-- the arrow and the words, scaled like the HUD, anchored at their left middle
	local callout = frame("Callout", layer)
	callout.AnchorPoint = Vector2.new(0, 0.5)
	callout.AutomaticSize = Enum.AutomaticSize.XY
	callout.Size = UDim2.fromOffset(0, 0)
	callout.ZIndex = 9
	local calloutScale = Instance.new("UIScale")
	calloutScale.Name = "HudScale"
	calloutScale.Parent = callout
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 12)
	list.Parent = callout
	local nudge = frame("Nudge", callout)
	nudge.LayoutOrder = 1
	local arrow = frame("Arrow", nudge)
	arrow.ZIndex = 9
	Icons.draw("Pointer", arrow)
	local say = Kit.outlined("Say", callout)
	say.LayoutOrder = 2
	say.ZIndex = 9

	parts = {
		layer = layer,
		dims = dims,
		ring = ring,
		callout = callout,
		calloutScale = calloutScale,
		nudge = nudge,
		arrow = arrow,
		say = say,
	}
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Spotlight.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(Spotlight.FLAG) then
				Spotlight.clear()
			end
		end)
end

return Spotlight
