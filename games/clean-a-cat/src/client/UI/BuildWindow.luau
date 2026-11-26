--!strict
-- BuildWindow: "Build and upgrades" (issue 751), behind the live switch buildWindow, off by default. Opened only from
-- its HUD button, never by itself. Two lists from BuildViewRules: the builds (price and time with Build, a countdown
-- while building, what it waits for, or Built) and the upgrades (each tool, then the next bow). The lists scroll when
-- they are taller than the screen allows. The buttons ask; a row changes only when the server's state comes back.
-- UI never fires remotes: BuildWindowController asks the server. No Robux here: Finish now stays on the board.
--
--   BuildWindow.build(root)          makes the window once and returns its layer (UI registers "Build")
--   BuildWindow.set(builds, upgrades)  the rows (BuildViewRules.builds and .upgrades)
--   BuildWindow.onPress(fn)          fn(kind, id) when a row's button is pressed
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildViewRules = require(Shared:WaitForChild("BuildViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local BuildWindow = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local ICON_FILL = Color3.fromHex("FFF1C2")
local DONE_FILL = Color3.fromHex("E7F6EF")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 8
local MIN_TAP = 44 -- real px
local BUTTON_PAD = 28
local TOPBAR = 58 -- real px of Roblox's top bar
local TEXT_FLOOR = 19
local MEASURE_SLACK = 1.08
local EDGE_ROOM = 4 -- design px inside the scrolling list for the rows' outlines

local SIZES = {
	full = {
		width = 760,
		band = 72,
		title = 38,
		badge = 96,
		pad = 18,
		gap = 10,
		rowH = 84,
		icon = 60,
		name = 24,
		say = 18,
		head = 24,
		button = 56,
		buttonText = 22,
		room = 130, -- design px of screen height kept for the X and margins
	},
	short = {
		width = 700,
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		gap = 6,
		rowH = 76,
		icon = 64, -- 48 real px at the smallest scale: model icons never under 48
		name = 21,
		say = 16,
		head = 21,
		button = 52,
		buttonText = 20,
		room = 50,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	scroller: ScrollingFrame,
	stack: UIListLayout,
}

local parts: Parts? = nil
local buildRows: { BuildViewRules.Row } = {}
local upgradeRows: { BuildViewRules.Row } = {}
local pressListeners: { (kind: string, id: string) -> () } = {}
-- Each drawn row's words and button by "<kind>_<id>", so a ticking countdown changes only its words (issue 822): a
-- row rebuilt every second costs a phone a full redraw and can drop a tap whose button is replaced mid press.
local drawnSays: { [string]: TextLabel } = {}
local drawnButtons: { [string]: GuiButton } = {}

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function words(name: string, parent: Instance, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Kit.FONT
	label.TextColor3 = Kit.INK
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	Kit.minText(label)
	label.Parent = parent
	return label
end

local function screenSize(scale: number): Vector2
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return size / scale
end

local function measure(text: string, size: number): number
	local drawn = math.max(size, TEXT_FLOOR)
	return TextService:GetTextSize(text, drawn, Kit.FONT, Vector2.new(2000, 200)).X * MEASURE_SLACK
end

local function heading(text: string, order: number, s: Sizes, parent: Instance): number
	local label = words(`Head{order}`, parent, s.head)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, s.head + 8)
	label.Text = text
	return s.head + 8
end

local function drawRow(row: BuildViewRules.Row, order: number, s: Sizes, parent: Instance): number
	local scale = Kit.screenScale()
	local buttonH = math.max(s.button, math.ceil(MIN_TAP / scale))
	local height = math.max(s.rowH, buttonH + 12)
	local card = frame(`{row.kind}_{row.id}`, parent)
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, height)
	card.BackgroundTransparency = if row.state == "locked" then 0.35 else 0
	card.BackgroundColor3 = if row.state == "done" then DONE_FILL else Kit.WHITE
	Kit.corner(card, UDim.new(0, 18))
	local edge = Kit.stroke(card, 3)
	edge.Color = Kit.LINE
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = card

	local icon = frame("Icon", card)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Size = UDim2.fromOffset(s.icon, s.icon)
	icon.BackgroundTransparency = 0
	icon.BackgroundColor3 = ICON_FILL
	Kit.corner(icon, UDim.new(0, 14))
	Kit.stroke(icon, 3)
	local art = frame("Art", icon)
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.9, 0.9)
	Icons.draw(row.icon, art)

	local used = 0
	local action = row.action
	if row.state == "buy" and action then
		local width = math.ceil(measure(action, s.buttonText)) + BUTTON_PAD
		width = math.max(width, buttonH + 24)
		local button = Window.button("Action", action, card, GREEN_TOP, GREEN_BOTTOM)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		button.Size = UDim2.fromOffset(width, buttonH)
		button.TextSize = s.buttonText
		button:SetAttribute("Says", `{action} {row.name}, {row.say}`)
		drawnButtons[card.Name] = button
		local kind, id = row.kind, row.id
		button.Activated:Connect(function()
			for _, listener in pressListeners do
				task.spawn(listener, kind, id)
			end
		end)
		used = width + 8
	elseif row.state == "done" then
		local tick = words("Tick", card, s.name + 6)
		tick.AnchorPoint = Vector2.new(1, 0.5)
		tick.Position = UDim2.fromScale(1, 0.5)
		tick.Size = UDim2.fromOffset(s.name + 10, s.name + 10)
		tick.TextXAlignment = Enum.TextXAlignment.Center
		tick.TextColor3 = Color3.fromHex("3FA868")
		tick.Text = "✓"
		used = s.name + 18
	end

	local text = frame("Text", card)
	text.Position = UDim2.fromOffset(s.icon + 12, 0)
	text.Size = UDim2.new(1, -(s.icon + 12 + used + 4), 1, 0)
	local textList = Instance.new("UIListLayout")
	textList.SortOrder = Enum.SortOrder.LayoutOrder
	textList.VerticalAlignment = Enum.VerticalAlignment.Center
	textList.Parent = text
	local name = words("Name", text, s.name)
	name.LayoutOrder = 1
	name.Size = UDim2.new(1, 0, 0, s.name + 6)
	Kit.shrinkToFit(name, s.name)
	name.Text = row.name
	local say = words("Says", text, s.say)
	say.LayoutOrder = 2
	say.FontFace = Kit.BODY_FACE
	say.TextColor3 = Kit.INK_SOFT
	say.Size = UDim2.new(1, 0, 0, s.say + 6)
	Kit.shrinkToFit(say, s.say)
	say.Text = row.say
	drawnSays[card.Name] = say
	return height
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	local screen = screenSize(scale)
	local width = math.min(s.width, screen.X - SCREEN_MARGIN)
	Window.fit(p.window, width, s.band, s.title, s.badge, if short then SHORT_SHIFT else nil)
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad - 4), pad
	p.stack.Padding = UDim.new(0, s.gap)
	for _, child in p.scroller:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(drawnSays)
	table.clear(drawnButtons)
	local total = 0
	local order = 0
	local function add(height: number)
		total += height + (if order > 1 then s.gap else 0)
	end
	if #buildRows > 0 then
		order += 1
		add(heading("Builds", order, s, p.scroller))
		for _, row in buildRows do
			order += 1
			add(drawRow(row, order, s, p.scroller))
		end
	end
	if #upgradeRows > 0 then
		order += 1
		add(heading("Upgrades", order, s, p.scroller))
		for _, row in upgradeRows do
			order += 1
			add(drawRow(row, order, s, p.scroller))
		end
	end
	-- as tall as the rows, but never past the room under Roblox's top bar; past that it scrolls
	local room = screen.Y - TOPBAR / scale - s.room - s.band - s.pad * 2
	local shown = math.max(s.rowH, math.min(total, room))
	p.scroller.Size = UDim2.new(1, 0, 0, shown + EDGE_ROOM * 2)
	p.scroller.CanvasSize = UDim2.fromOffset(0, total + EDGE_ROOM * 2)
	p.scroller.ScrollingEnabled = total > shown
end

-- Changes only the words of rows already drawn; false when one is missing and the window must draw again.
local function retext(rows: { BuildViewRules.Row }): boolean
	for _, row in rows do
		local key = `{row.kind}_{row.id}`
		local say = drawnSays[key]
		if say == nil or say.Parent == nil then
			return false
		end
		say.Text = row.say
		local button = drawnButtons[key]
		local action = row.action
		if button and action then
			button:SetAttribute("Says", `{action} {row.name}, {row.say}`)
		end
	end
	return true
end

function BuildWindow.set(builds: { BuildViewRules.Row }, upgrades: { BuildViewRules.Row })
	local same = BuildViewRules.sameShape(buildRows, builds)
		and BuildViewRules.sameShape(upgradeRows, upgrades)
	buildRows, upgradeRows = builds, upgrades
	local p = parts
	if p and p.window.layer.Visible then
		if not (same and retext(builds) and retext(upgrades)) then
			redraw()
		end
	end
end

function BuildWindow.onPress(fn: (kind: string, id: string) -> ())
	table.insert(pressListeners, fn)
end

function BuildWindow.build(root: Instance): Frame
	local window = Window.new(BuildViewRules.WINDOW, BuildViewRules.TITLE, "Build", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
		end
	end)
	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Rows"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 8
	scroller.ScrollBarImageColor3 = Kit.INK_SOFT
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.Size = UDim2.fromScale(1, 0)
	scroller.Parent = window.body
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 10)
	stack.Parent = scroller
	-- room inside the list's edge for the rows' outlines (the list clips what crosses it)
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft, inset.PaddingRight = UDim.new(0, EDGE_ROOM), UDim.new(0, EDGE_ROOM + 10)
	inset.PaddingTop, inset.PaddingBottom = UDim.new(0, EDGE_ROOM), UDim.new(0, EDGE_ROOM)
	inset.Parent = scroller

	parts = { window = window, pad = pad, scroller = scroller, stack = stack }
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. BuildViewRules.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(BuildViewRules.FLAG) then
				window.layer.Visible = false
			end
		end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

return BuildWindow
