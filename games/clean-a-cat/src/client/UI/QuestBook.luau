--!strict
-- QuestBook: the quest book (issue 516), from Design-Agent's quests.html. Behind the live switch quests, off by
-- default, the same switch as QuestService on the server.
--
--   QuestBook.build(root)                        makes the window once and returns its layer (UI registers "Quests")
--   QuestBook.set(entries, crateTaken, chances)  draws the quests (QuestViewRules.clean), the weekly crate taken or
--                                                not, and `chances` true when the crate window can show its list
--   QuestBook.onChances(fn)                      fn(kind) when the weekly crate's chance button is pressed
--
-- Two columns: Today (the daily quests, and the weekly crate under them, where there is room) and This week (the
-- weekly quests). Each quest: what to do in plain words, a bar with the count, and the coins it pays, or a tick once
-- paid. A quest pays itself the moment it is done (the server's notice says so), so there is no Claim button. The
-- resets are said in plain words, never a clock. Only the X closes it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local QuestRules = require(Shared:WaitForChild("QuestRules"))
local QuestViewRules = require(Shared:WaitForChild("QuestViewRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local QuestBook = {}

local BIG_TOP, BIG_EDGE = Color3.fromHex("FFF6D6"), Color3.fromHex("F0CF6B")
local DONE_FILL, DONE_EDGE = Color3.fromHex("F1FBF4"), Color3.fromHex("9ED9B2")
local BAR_FILL = Color3.fromHex("4FCF93")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 8 -- design px below the middle on a short screen (Window's default is 33)
local MIN_TAP = 44 -- real px

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 1060,
		band = 72,
		title = 38,
		badge = 96,
		pad = 20,
		colGap = 18,
		rowGap = 10,
		head = 26,
		headNote = 16,
		rowH = 92,
		icon = 52,
		say = 19,
		bar = 18,
		count = 18,
		pays = 22,
		paysW = 92,
		crateH = 104,
		crateIcon = 66,
		crateTitle = 22,
		crateLine = 16,
		pip = 22,
		chances = 52,
	},
	short = {
		width = 880,
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		colGap = 12,
		rowGap = 6,
		head = 22,
		headNote = 0, -- no note beside the heads on a short screen
		rowH = 68,
		icon = 36,
		say = 16,
		bar = 14,
		count = 16,
		pays = 19,
		paysW = 80,
		crateH = 72,
		crateIcon = 42,
		crateTitle = 19,
		crateLine = 0,
		pip = 18,
		chances = 52,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	columns: UIListLayout,
	today: Frame,
	week: Frame,
}

local parts: Parts? = nil
local entries: { QuestViewRules.Entry } = {}
local crateTaken = false
local canSeeChances = false
local chanceListeners: { (kind: string) -> () } = {}

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
	Kit.minText(label)
	label.Parent = parent
	return label
end

local function list(parent: Instance, horizontal: boolean, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

local function tapSize(size: number): number
	local scale = Kit.screenScale()
	return math.max(size, math.ceil(MIN_TAP / scale))
end

local function clear(holder: Frame)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function card(
	name: string,
	parent: Instance,
	order: number,
	height: number
): (Frame, UIStroke)
	local c = frame(name, parent)
	c.LayoutOrder = order
	c.Size = UDim2.new(1, 0, 0, height)
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = Kit.WHITE
	Kit.corner(c, UDim.new(0, 16))
	local edge = Kit.stroke(c, 3)
	edge.Color = Kit.LINE
	return c, edge
end

-- A column's head: "Today" with its note on the right.
local function head(parent: Frame, title: string, note: string, s: Sizes)
	local h = frame("Head", parent)
	h.LayoutOrder = 0
	h.Size = UDim2.new(1, 0, 0, s.head + 6)
	local t = words("Title", h, s.head)
	t.Size = UDim2.fromScale(1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = title
	if s.headNote > 0 then
		local n = words("Note", h, s.headNote)
		n.FontFace = Kit.BODY_FACE
		n.TextColor3 = Kit.INK_SOFT
		n.Size = UDim2.fromScale(1, 1)
		n.TextXAlignment = Enum.TextXAlignment.Right
		n.Text = note
	end
end

local function drawQuest(entry: QuestViewRules.Entry, parent: Frame, order: number, s: Sizes)
	local row, edge = card(`Quest{order}`, parent, order, s.rowH)
	if entry.done then
		row.BackgroundColor3 = DONE_FILL
		edge.Color = DONE_EDGE
	end
	local inset = 10
	local pic = frame("Pic", row)
	pic.AnchorPoint = Vector2.new(0, 0.5)
	pic.Position = UDim2.new(0, inset, 0.5, 0)
	pic.Size = UDim2.fromOffset(s.icon, s.icon)
	Icons.draw(QuestViewRules.icon(entry.id), pic)

	-- the coins it pays, or the tick once paid
	local pays = frame("Pays", row)
	pays.AnchorPoint = Vector2.new(1, 0.5)
	pays.Position = UDim2.new(1, -inset, 0.5, 0)
	pays.Size = UDim2.fromOffset(s.paysW, s.rowH - 12)
	local paysList = list(pays, true, 4)
	paysList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	paysList.VerticalAlignment = Enum.VerticalAlignment.Center
	if entry.done then
		local tick = frame("Tick", pays)
		tick.Size = UDim2.fromOffset(s.icon, s.icon)
		Icons.draw("Check", tick)
	else
		local coin = frame("Coin", pays)
		coin.LayoutOrder = 1
		coin.Size = UDim2.fromOffset(s.pays + 2, s.pays + 2)
		Icons.draw("Coins", coin)
		local amount = words("Amount", pays, s.pays)
		amount.LayoutOrder = 2
		amount.TextColor3 = Kit.GOLD_INK
		amount.AutomaticSize = Enum.AutomaticSize.X
		amount.Size = UDim2.fromOffset(0, s.pays + 4)
		amount.Text = tostring(entry.coins)
	end

	-- what to do, and the bar with the count under it
	local left = inset + s.icon + 10
	local mid = frame("Middle", row)
	mid.Position = UDim2.fromOffset(left, 0)
	mid.Size = UDim2.new(1, -(left + s.paysW + inset + 8), 1, 0)
	local midList = list(mid, false, if s.headNote > 0 then 6 else 2)
	midList.VerticalAlignment = Enum.VerticalAlignment.Center
	local say = words("Say", mid, s.say)
	say.LayoutOrder = 1
	say.FontFace = Kit.BODY_FACE
	say.TextXAlignment = Enum.TextXAlignment.Left
	say.Size = UDim2.new(1, 0, 0, s.say + 4)
	Kit.shrinkToFit(say, s.say)
	say.Text = entry.text
	if entry.done then
		say.TextColor3 = Kit.INK_SOFT
	end
	local prog = frame("Progress", mid)
	prog.LayoutOrder = 2
	prog.Size = UDim2.new(1, 0, 0, math.max(s.bar, s.count + 2))
	local n = words("Count", prog, s.count)
	n.AnchorPoint = Vector2.new(1, 0.5)
	n.Position = UDim2.fromScale(1, 0.5)
	n.AutomaticSize = Enum.AutomaticSize.X
	n.Size = UDim2.fromOffset(0, s.count + 2)
	n.TextColor3 = Kit.INK_SOFT
	n.Text = QuestViewRules.progressText(entry)
	local track = frame("Bar", prog)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.fromScale(0, 0.5)
	track.Size = UDim2.new(1, -(s.count * 4 + 10), 0, s.bar) -- room for "20 / 20"
	track.BackgroundTransparency = 0
	track.BackgroundColor3 = Kit.WHITE
	Kit.corner(track, UDim.new(0.5, 0))
	Kit.stroke(track, 2)
	local fill = frame("Fill", track)
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = BAR_FILL
	fill.Size = UDim2.fromScale(QuestViewRules.fill(entry), 1)
	Kit.corner(fill, UDim.new(0.5, 0))
end

local function drawCrate(parent: Frame, order: number, s: Sizes, weekly: { QuestViewRules.Entry })
	local box, edge = card("Crate", parent, order, s.crateH)
	box.BackgroundColor3 = Kit.WHITE
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new(BIG_TOP, Kit.WHITE)
	tint.Parent = box
	edge.Color = BIG_EDGE
	local inset = 10
	local gift = frame("Pic", box)
	gift.AnchorPoint = Vector2.new(0, 0.5)
	gift.Position = UDim2.new(0, inset, 0.5, 0)
	gift.Size = UDim2.fromOffset(s.crateIcon, s.crateIcon)
	Icons.draw("Gift", gift, crateTaken)

	local buttonW = 0
	if crateTaken then
		-- this week's crate is taken: a tick where the chance button was
		buttonW = s.crateIcon + inset
		local tick = frame("Tick", box)
		tick.AnchorPoint = Vector2.new(1, 0.5)
		tick.Position = UDim2.new(1, -inset, 0.5, 0)
		tick.Size = UDim2.fromOffset(s.crateIcon, s.crateIcon)
		Icons.draw("Check", tick)
	elseif canSeeChances then
		local size = tapSize(s.chances)
		buttonW = size + inset
		local chances = Instance.new("TextButton")
		chances.Name = "Chances"
		chances.AnchorPoint = Vector2.new(1, 0.5)
		chances.Position = UDim2.new(1, -inset, 0.5, 0)
		chances.Size = UDim2.fromOffset(size, size)
		chances.BackgroundColor3 = Kit.WHITE
		chances.AutoButtonColor = true
		chances.Text = ""
		Kit.corner(chances, UDim.new(0, 14))
		local ring = Kit.stroke(chances, 3)
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		chances:SetAttribute("Hint", "See the chances in the crate")
		chances.Parent = box
		local dice = frame("Pic", chances)
		dice.AnchorPoint = Vector2.new(0.5, 0.5)
		dice.Position = UDim2.fromScale(0.5, 0.5)
		dice.Size = UDim2.fromScale(0.7, 0.7)
		Icons.draw("Dice", dice)
		chances.Activated:Connect(function()
			for _, listener in chanceListeners do
				task.spawn(listener, QuestRules.WEEK_CRATE)
			end
		end)
	end

	local left = inset + s.crateIcon + 12
	local mid = frame("Middle", box)
	mid.Position = UDim2.fromOffset(left, 0)
	mid.Size = UDim2.new(1, -(left + buttonW + inset), 1, 0)
	local midList = list(mid, false, 4)
	midList.VerticalAlignment = Enum.VerticalAlignment.Center
	local title = words("Title", mid, s.crateTitle)
	title.LayoutOrder = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, 0, 0, s.crateTitle + 4)
	title.Text = QuestViewRules.CRATE_TITLE
	if s.crateLine > 0 then
		local line = words("Line", mid, s.crateLine)
		line.LayoutOrder = 2
		line.FontFace = Kit.BODY_FACE
		line.TextColor3 = Kit.INK_SOFT
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Size = UDim2.new(1, 0, 0, s.crateLine + 4)
		Kit.shrinkToFit(line, s.crateLine)
		line.Text = QuestViewRules.crateLine(crateTaken)
	end
	-- one pip per weekly quest, green once done
	local pips = frame("Pips", mid)
	pips.LayoutOrder = 3
	pips.Size = UDim2.new(1, 0, 0, s.pip)
	list(pips, true, 6)
	for index, entry in weekly do
		local pip = frame(`Pip{index}`, pips)
		pip.LayoutOrder = index
		pip.Size = UDim2.fromOffset(s.pip, s.pip)
		pip.BackgroundTransparency = 0
		pip.BackgroundColor3 = if entry.done or crateTaken then BAR_FILL else Kit.WHITE
		Kit.corner(pip, UDim.new(0.5, 0))
		Kit.stroke(pip, 3)
	end
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	local width = math.min(s.width, screenWidth(scale) - SCREEN_MARGIN)
	Window.fit(p.window, width, s.band, s.title, s.badge, if short then SHORT_SHIFT else nil)
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad - 4), pad
	p.columns.Padding = UDim.new(0, s.colGap)
	local colW = math.floor((width - 2 * s.pad - s.colGap) / 2)

	local daily, weekly = QuestViewRules.split(entries)
	for _, col in { p.today, p.week } do
		clear(col)
		col.Size = UDim2.fromOffset(colW, 0)
		local layout = list(col, false, s.rowGap)
		layout.Name = "List"
	end
	head(p.today, QuestViewRules.TODAY, QuestViewRules.TODAY_NOTE, s)
	for index, entry in daily do
		drawQuest(entry, p.today, index, s)
	end
	head(p.week, QuestViewRules.WEEK, QuestViewRules.weekNote(weekly), s)
	for index, entry in weekly do
		drawQuest(entry, p.week, index, s)
	end
	p.week.Visible = #weekly > 0
	if #weekly > 0 then
		drawCrate(p.today, #daily + 1, s, weekly)
	end
end

function QuestBook.set(newEntries: { QuestViewRules.Entry }, taken: boolean, chances: boolean)
	entries, crateTaken, canSeeChances = newEntries, taken, chances
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function QuestBook.onChances(fn: (kind: string) -> ())
	table.insert(chanceListeners, fn)
end

function QuestBook.build(root: Instance): Frame
	local window = Window.new(QuestViewRules.WINDOW, "Quests", "Quests", root)
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
	local row = frame("Columns", window.body)
	row.Size = UDim2.fromScale(1, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	local columns = list(row, true, 18)
	columns.VerticalAlignment = Enum.VerticalAlignment.Top
	local today = frame("Today", row)
	today.LayoutOrder = 1
	today.AutomaticSize = Enum.AutomaticSize.Y
	local week = frame("Week", row)
	week.LayoutOrder = 2
	week.AutomaticSize = Enum.AutomaticSize.Y

	parts = { window = window, pad = pad, columns = columns, today = today, week = week }
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. QuestRules.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(QuestRules.FLAG) then
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

return QuestBook
