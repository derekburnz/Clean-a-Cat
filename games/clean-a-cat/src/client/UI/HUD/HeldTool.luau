--!strict
-- HeldTool: the wash step's tool under the finger (switch toolCursor, off by default). Derek's dev test (2026-11-24):
-- no tool tray, the tool changes by itself as in the salon game he played (switch autoTool, #394); this shows which
-- tool is at work right where the player is rubbing. From Design-Agent's mock (assets/clean-a-cat/ui/screens/
-- wash.html, states finger and water, #395): the tool's icon, tilted, up and to the left of the touch so the thumb
-- never hides it, over a soft white ring on the touch point; it pops in on the first touch and shrinks away on lift.
-- Review-QA's note on the mock (iPhone 12): the sponge covered the kitten's face near his head, so the tool goes up
-- and to the RIGHT when the touch is on the left half of the cat or when the left side would cover his head, and it
-- is 84 design px on a touch screen (104 with a mouse).
--
--   HeldTool.build(playerGui)             makes it once, hidden, in its own ScreenGui in GUI space (the top bar left
--                                         out, like InputObject.Position)
--   HeldTool.set(icon, at, centre, head)  shows `icon` (an Icons name) at `at`, kept off `head`; nil icon or at hides
--
-- It only shows; it is not pressable and never takes a touch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("Icons"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local HeldTool = {}

HeldTool.FLAG = "toolCursor"

local TOUCH_SIZE = 84 -- design px, the tool on a touch screen (Review-QA)
local MOUSE_SIZE = 104 -- design px, with a mouse (the mock)
local RING = 54 -- design px, the touch point's ring
local TILT = 14 -- degrees the tool leans away from the finger
local NUDGE = 6 -- design px the tool's corner sits off the touch point
local POP_IN = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

type Parts = { gui: ScreenGui, tool: Frame, box: Frame, ring: Frame, pop: UIScale, ringPop: UIScale }

local parts: Parts? = nil
local shownIcon: string? = nil
local showing = false
local hideTurn = 0

local function popTo(p: Parts, value: number, info: TweenInfo)
	TweenService:Create(p.pop, info, { Scale = value }):Play()
	TweenService:Create(p.ringPop, info, { Scale = value }):Play()
end

local function hide()
	local p = parts
	if p == nil or not showing then
		return
	end
	showing = false
	hideTurn += 1
	local turn = hideTurn
	popTo(p, 0.6, POP_OUT)
	task.delay(POP_OUT.Time, function()
		if turn == hideTurn and not showing then
			p.tool.Visible = false
			p.ring.Visible = false
		end
	end)
end

-- Which side of the touch the tool goes: true for up and to the right. Left (the mock's side) unless the touch is on
-- the cat's left half, or the left side would cover the head; then right, unless the right side would cover it too.
local function goesRight(at: Vector2, size: number, centre: Vector2?, head: Vector2?): boolean
	local right = centre ~= nil and at.X < centre.X
	if head then
		local above = head.Y <= at.Y + size * 0.25 and head.Y >= at.Y - size * 1.25
		local onLeft = head.X <= at.X + size * 0.25 and head.X >= at.X - size * 1.25
		local onRight = head.X >= at.X - size * 0.25 and head.X <= at.X + size * 1.25
		if above and not right and onLeft then
			right = true
		elseif above and right and onRight and not onLeft then
			right = false
		end
	end
	return right
end

function HeldTool.set(icon: string?, at: Vector2?, centre: Vector2?, head: Vector2?)
	local p = parts
	if p == nil then
		return
	end
	if icon == nil or at == nil or not LiveFlags.isOn(HeldTool.FLAG) then
		hide()
		return
	end
	local point = at :: Vector2
	if icon ~= shownIcon then
		shownIcon = icon
		Icons.draw(icon, p.box)
	end
	local scale = Kit.screenScale()
	local size = (if UserInputService.TouchEnabled then TOUCH_SIZE else MOUSE_SIZE) * scale
	local right = goesRight(point, size, centre, head)
	local nudge = NUDGE * scale
	-- never cut off by the screen's edge (Review-QA's nit on #396): the other side when this one runs off, and never
	-- above the top
	local screen = p.gui.AbsoluteSize
	if not right and point.X - nudge - size < 0 then
		right = true
	elseif right and point.X + nudge + size > screen.X then
		right = false
	end
	local top = math.max(point.Y - nudge, size)
	p.tool.Size = UDim2.fromOffset(size, size)
	p.tool.AnchorPoint = if right then Vector2.new(0, 1) else Vector2.new(1, 1)
	p.tool.Rotation = if right then TILT else -TILT
	p.tool.Position = UDim2.fromOffset(point.X + (if right then nudge else -nudge), top)
	local ring = RING * scale
	p.ring.Size = UDim2.fromOffset(ring, ring)
	p.ring.Position = UDim2.fromOffset(point.X, point.Y)
	if not showing then
		showing = true
		hideTurn += 1
		p.tool.Visible = true
		p.ring.Visible = true
		p.pop.Scale = 0.8
		p.ringPop.Scale = 0.8
		popTo(p, 1, POP_IN)
	end
end

function HeldTool.build(playerGui: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HeldTool"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- GUI space, as InputObject.Position and Camera:WorldToScreenPoint
	gui.DisplayOrder = 3 -- over the world and the HUD's step line, under windows and the Walk bar
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundColor3 = Kit.WHITE
	ring.BackgroundTransparency = 0.65
	ring.Active = false
	ring.Visible = false
	Kit.corner(ring, UDim.new(0.5, 0))
	local edge = Instance.new("UIStroke")
	edge.Color = Kit.WHITE
	edge.Thickness = 4
	edge.Transparency = 0.1
	edge.Parent = ring
	local ringPop = Instance.new("UIScale")
	ringPop.Parent = ring
	ring.Parent = gui

	local tool = Instance.new("Frame")
	tool.Name = "Tool"
	tool.BackgroundTransparency = 1
	tool.Active = false
	tool.Visible = false
	tool.ZIndex = 2
	local pop = Instance.new("UIScale")
	pop.Parent = tool
	local box = Instance.new("Frame")
	box.Name = "IconBox"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.Parent = tool
	tool.Parent = gui

	gui.Parent = playerGui
	parts = { gui = gui, tool = tool, box = box, ring = ring, pop = pop, ringPop = ringPop }
	-- the switch going off mid-drag takes it away at once
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. HeldTool.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(HeldTool.FLAG) then
				hide()
			end
		end)
end

return HeldTool
