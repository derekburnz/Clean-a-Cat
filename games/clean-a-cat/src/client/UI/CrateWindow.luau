--!strict
-- CrateWindow: the crate window (issue 526 item 4), from Design-Agent's pets.html "crate" and "goodcrate" states.
-- Behind the live switch crateWindow, off by default; with it on, a tap on the crate by the tub opens this window
-- instead of opening the crate at once (CrateWindowController).
--
--   CrateWindow.build(root)                makes the window once and returns its layer (UI registers "Crate")
--   CrateWindow.set(kind, count, rows)     draws crate `kind` (CrateViewRules.rows), `count` of them held
--   CrateWindow.onOpen(fn)                 fn(kind) when Open crate is pressed
--   CrateWindow.setShop(rows)              the Robux rows (CrateViewRules.shopRows), {} for none
--   CrateWindow.onBuy(fn)                  fn(key) when a Robux row's price button is pressed
--
-- Every pet in the crate with its chance and its boost, before anything is opened: the same list the server rolls
-- from (CrateRules.odds), adding to 100. A pet the player has not got yet draws as a shadow. The good crate (the day
-- 2 gift) has its own title and its own chances, so it is never mixed up with the normal one. Bought crates (issue
-- 514, switch crateShop) sit under Open crate as plain rows ("5 crates", "199 Robux"), on the normal crate only and
-- only where PolicyService allows paid random items; the chance list is beside them on the same screen, seen before
-- any tap, and Roblox's own prompt is the confirm. Open crate closes the window, so the player sees the lid open in
-- the world; a buy leaves it open, so the count goes up in front of them. UI never fires remotes:
-- CrateWindowController sends the open and the buy, and the server rolls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))
local Window = require(script.Parent:WaitForChild("Window"))

local CrateWindow = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local BOX_TOP, BOX_EDGE = Color3.fromHex("FFF6D6"), Color3.fromHex("F0CF6B")
local BUY_TOP, BUY_BOTTOM = Color3.fromHex("8FD8FF"), Color3.fromHex("4FB3F0") -- quieter than Open crate's green
local MIN_TAP = 44 -- real px
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 4 -- design px below the middle on a short screen (Window's default is 33)

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 1040,
		band = 72,
		title = 38,
		badge = 96,
		pad = 20,
		gap = 18,
		boxW = 220,
		gift = 110,
		have = 20,
		open = 60,
		openText = 26,
		rowH = 80,
		rowGap = 8,
		pic = 64, -- 48 real px at the smallest scale (Portraits' floor)
		name = 24,
		chip = 26,
		boost = 19,
		chance = 30,
		sum = 19,
		buyH = 52,
		buyText = 20,
		buyLabel = 20,
	},
	short = {
		width = 980,
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		gap = 12,
		boxW = 190,
		gift = 72,
		have = 19,
		open = 60,
		openText = 24,
		rowH = 68,
		rowGap = 6,
		pic = 64,
		name = 21,
		chip = 24,
		boost = 19,
		chance = 26,
		sum = 19,
		buyH = 46,
		buyText = 17,
		buyLabel = 18,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	columns: UIListLayout,
	box: Frame,
	boxList: UIListLayout,
	gift: Frame,
	have: TextLabel,
	open: TextButton,
	shop: Frame,
	shopTitle: TextLabel,
	right: Frame,
	grid: Frame,
	gridLayout: UIGridLayout,
	sum: TextLabel,
}

local parts: Parts? = nil
local shownKind = "normal"
local held = 0
local rows: { CrateViewRules.Row } = {}
local openListeners: { (kind: string) -> () } = {}
local shopRows: { CrateViewRules.ShopRow } = {}
local buyListeners: { (key: string) -> () } = {}

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

-- The rarity tag beside a pet's name.
local function rarityChip(parent: Instance, rarity: string, height: number, order: number)
	local c = frame("Rarity", parent)
	c.LayoutOrder = order
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = Kit.RARITY[rarity] or Kit.RARITY.Common
	c.AutomaticSize = Enum.AutomaticSize.X
	c.Size = UDim2.fromOffset(0, height)
	Kit.corner(c, UDim.new(0.5, 0))
	Kit.stroke(c, 2)
	Kit.rim(c, rarity, Kit.INK)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 9), UDim.new(0, 9)
	pad.Parent = c
	local label = Kit.outlined("Text", c)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromScale(0, 0.5)
	label.TextSize = 19
	label.Text = rarity
end

local function drawRow(row: CrateViewRules.Row, grid: Frame, order: number, s: Sizes, cellW: number)
	local card = frame(`Pet{order}`, grid)
	card.LayoutOrder = order
	card.BackgroundTransparency = 0
	card.BackgroundColor3 = Kit.WHITE
	Kit.corner(card, UDim.new(0, 16))
	local edge = Kit.stroke(card, 3)
	edge.Color = Kit.LINE
	local inset = math.floor((s.rowH - s.pic) / 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, inset), UDim.new(0, 12)
	pad.Parent = card

	local pic = frame("Pic", card)
	pic.AnchorPoint = Vector2.new(0, 0.5)
	pic.Position = UDim2.fromScale(0, 0.5)
	pic.Size = UDim2.fromOffset(s.pic, s.pic)
	Portraits.draw(row.pet, row.rarity, pic, true)
	if not row.owned then
		-- not got yet: a shadow over the face, the same as the Index's unseen cats
		local shade = frame("Shade", pic)
		shade.Size = UDim2.fromScale(1, 1)
		shade.BackgroundTransparency = 0.35
		shade.BackgroundColor3 = Kit.INK
		shade.ZIndex = 3
		Kit.corner(shade, UDim.new(0.5, 0))
	end

	local chance = words("Chance", card, s.chance)
	chance.AnchorPoint = Vector2.new(1, 0.5)
	chance.Position = UDim2.fromScale(1, 0.5)
	chance.AutomaticSize = Enum.AutomaticSize.X
	chance.Size = UDim2.fromOffset(0, s.rowH - 8)
	chance.TextXAlignment = Enum.TextXAlignment.Right
	chance.Text = row.chance

	local whoX = s.pic + 10
	local whoW = cellW - inset - 12 - whoX - 78
	local who = frame("Who", card)
	who.Position = UDim2.fromOffset(whoX, 0)
	who.Size = UDim2.new(0, whoW, 1, 0)
	local whoList = list(who, false, 2)
	whoList.VerticalAlignment = Enum.VerticalAlignment.Center
	local top = frame("Top", who)
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, math.max(s.name + 4, s.chip))
	local topList = list(top, true, 8)
	topList.VerticalAlignment = Enum.VerticalAlignment.Center
	local name = words("Name", top, s.name)
	name.LayoutOrder = 1
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.fromOffset(0, s.name + 4)
	name.Text = row.pet
	rarityChip(top, row.rarity, s.chip, 2)
	local boost = words("Boost", who, s.boost)
	boost.LayoutOrder = 2
	boost.FontFace = Kit.BODY_FACE
	boost.TextColor3 = Kit.INK_SOFT
	boost.TextXAlignment = Enum.TextXAlignment.Left
	boost.Size = UDim2.new(1, 0, 0, s.boost + 4)
	boost.Text = `{row.boost} boost`
end

-- One Robux row: "5 crates" on the left, its price on a button filling the rest.
local function drawBuy(
	row: CrateViewRules.ShopRow,
	order: number,
	s: Sizes,
	scale: number,
	parent: Frame
)
	local line = frame(row.key, parent)
	line.LayoutOrder = order
	local height = math.max(s.buyH, math.ceil(MIN_TAP / scale))
	line.Size = UDim2.new(1, 0, 0, height)
	local label = words("Label", line, s.buyLabel)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromScale(0, 0.5)
	label.Size = UDim2.new(0.46, -4, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Kit.shrinkToFit(label, s.buyLabel)
	label.Text = row.label
	local button = Window.button("Buy", `{row.price} Robux`, line, BUY_TOP, BUY_BOTTOM)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(1, 0.5)
	button.Size = UDim2.new(0.54, 0, 1, 0)
	button.TextSize = s.buyText
	local key = row.key
	button.Activated:Connect(function()
		for _, listener in buyListeners do
			task.spawn(listener, key)
		end
	end)
end

local function clearGrid(grid: Frame)
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
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
	p.window.title.Text = CrateViewRules.title(shownKind)
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad - 4), pad
	p.columns.Padding = UDim.new(0, s.gap)

	-- the crate, how many the player holds and Open crate
	p.box.Size = UDim2.fromOffset(s.boxW, 0)
	p.boxList.Padding = UDim.new(0, if short then 6 else 10)
	p.gift.Size = UDim2.fromOffset(s.gift, s.gift)
	p.have.TextSize = s.have
	p.have.Size = UDim2.new(1, 0, 0, s.have + 6) -- AutomaticSize grows it when larger text wraps
	p.have.Text = CrateViewRules.haveLine(shownKind, held)
	p.open.Visible = held > 0
	p.open.Size = UDim2.new(1, 0, 0, s.open)
	p.open.TextSize = s.openText

	-- the Robux rows, only when the controller passed some (normal crate, allowed, priced)
	for _, child in p.shop:GetChildren() do
		if child:IsA("Frame") then -- the rows; the title is a TextLabel and stays
			child:Destroy()
		end
	end
	p.shop.Visible = #shopRows > 0
	p.shopTitle.TextSize = s.have
	p.shopTitle.Size = UDim2.new(1, 0, 0, s.have + 6)
	for index, row in shopRows do
		drawBuy(row, index + 1, s, scale, p.shop)
	end

	-- every pet with its chance, two to a line
	local rightW = width - 2 * s.pad - s.boxW - s.gap
	p.right.Size = UDim2.fromOffset(rightW, 0)
	local cellW = math.floor((rightW - s.rowGap) / 2)
	p.gridLayout.CellSize = UDim2.fromOffset(cellW, s.rowH)
	p.gridLayout.CellPadding = UDim2.fromOffset(s.rowGap, s.rowGap)
	clearGrid(p.grid)
	for index, row in rows do
		drawRow(row, p.grid, index, s, cellW)
	end
	local lines = math.ceil(#rows / 2)
	p.grid.Size = UDim2.new(1, 0, 0, lines * s.rowH + math.max(lines - 1, 0) * s.rowGap)
	p.sum.TextSize = s.sum
	p.sum.Text = CrateViewRules.SUM_LINE
end

function CrateWindow.set(kind: string, count: number, newRows: { CrateViewRules.Row })
	shownKind, held, rows = kind, count, newRows
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function CrateWindow.onOpen(fn: (kind: string) -> ())
	table.insert(openListeners, fn)
end

function CrateWindow.setShop(newRows: { CrateViewRules.ShopRow })
	shopRows = newRows
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function CrateWindow.onBuy(fn: (key: string) -> ())
	table.insert(buyListeners, fn)
end

function CrateWindow.build(root: Instance): Frame
	local window = Window.new("Crate", "Crate", "Gift", root)
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

	local box = frame("Box", row)
	box.LayoutOrder = 1
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundTransparency = 0
	box.BackgroundColor3 = Kit.WHITE
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new(BOX_TOP, Kit.WHITE)
	tint.Parent = box
	Kit.corner(box, UDim.new(0, 18))
	local edge = Kit.stroke(box, 3)
	edge.Color = BOX_EDGE
	local boxPad = Instance.new("UIPadding")
	boxPad.PaddingLeft, boxPad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	boxPad.PaddingTop, boxPad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
	boxPad.Parent = box
	local boxList = list(box, false, 10)
	boxList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local gift = frame("Gift", box)
	gift.LayoutOrder = 1
	Icons.draw("Gift", gift)
	local have = words("Have", box, 20)
	have.LayoutOrder = 2
	have.FontFace = Kit.BODY_FACE
	have.TextColor3 = Kit.INK_SOFT
	have.TextWrapped = true
	have.AutomaticSize = Enum.AutomaticSize.Y
	local open = Window.button("Open", "Open crate", box, GREEN_TOP, GREEN_BOTTOM)
	open.LayoutOrder = 3
	open.Activated:Connect(function()
		if held <= 0 then
			return
		end
		window.layer.Visible = false
		for _, listener in openListeners do
			task.spawn(listener, shownKind)
		end
	end)

	local shop = frame("Shop", box)
	shop.LayoutOrder = 4
	shop.Size = UDim2.fromScale(1, 0)
	shop.AutomaticSize = Enum.AutomaticSize.Y
	shop.Visible = false
	list(shop, false, 6)
	local shopTitle = words("Title", shop, 20)
	shopTitle.LayoutOrder = 1
	shopTitle.Text = CrateViewRules.SHOP_TITLE

	local right = frame("Chances", row)
	right.LayoutOrder = 2
	right.AutomaticSize = Enum.AutomaticSize.Y
	list(right, false, 8)
	local grid = frame("Pets", right)
	grid.LayoutOrder = 1
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.Parent = grid
	local sum = words("Sum", right, 19)
	sum.LayoutOrder = 2
	sum.FontFace = Kit.BODY_FACE
	sum.TextColor3 = Kit.INK_SOFT
	sum.TextWrapped = true
	sum.TextXAlignment = Enum.TextXAlignment.Left
	sum.Size = UDim2.fromScale(1, 0)
	sum.AutomaticSize = Enum.AutomaticSize.Y
	local sumPad = Instance.new("UIPadding")
	sumPad.PaddingRight = UDim.new(0, 10) -- the words keep clear of the window's edge
	sumPad.Parent = sum

	parts = {
		window = window,
		pad = pad,
		columns = columns,
		box = box,
		boxList = boxList,
		gift = gift,
		have = have,
		open = open,
		shop = shop,
		shopTitle = shopTitle,
		right = right,
		grid = grid,
		gridLayout = gridLayout,
		sum = sum,
	}
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CrateViewRules.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(CrateViewRules.FLAG) then
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

return CrateWindow
