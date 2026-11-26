--!strict
-- PetsWindow: the pets window (issue 526 item 4), from Design-Agent's pets.html "pets" state. Behind the live switch
-- petsWindow, off by default; the HUD's Pets button opens it (HUD/SideButtons).
--
--   PetsWindow.build(root)           makes the window once and returns its layer (UI registers "Pets")
--   PetsWindow.set(pets, hired)      draws the player's pets (CrateRules.Pet list) and slots (hired helpers' ids)
--   PetsWindow.onPlace(fn)           fn(petId, slot?) when a pet tile is tapped: into the picked slot, or off it
--   PetsWindow.onFuse(fn)            fn(ids) when Fuse is pressed on three of the same
--
-- Left, "Your pets": one tile per pet and star with its rarity, stars and how many (x3); a tick when one is in a slot;
-- Fuse under three of the same below the top star (free, the result is fixed: a star up). Right, "Who has a pet": you
-- and each helper, one pet each, with what it boosts; a helper not hired shows locked. Tap a slot to pick it (it
-- glows), then a pet to put in it; tap the pet in that slot again to take it off. You are picked when the window
-- opens. Nothing is timed. UI never fires remotes: PetsWindowController sends the place and the fuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))
local Window = require(script.Parent:WaitForChild("Window"))

local PetsWindow = {}

local SKY_TOP, SKY_BOTTOM = Color3.fromHex("8FD3FE"), Color3.fromHex("4DB2F0")
local PICKED = Color3.fromHex("4FCF93")
local SLOT_FILL = Color3.fromHex("E8F7FF")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 4 -- design px below the middle on a short screen (Window's default is 33)

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 1100,
		band = 72,
		title = 38,
		badge = 96,
		pad = 20,
		gap = 18,
		head = 30,
		headText = 24,
		note = 19,
		listH = 420,
		cols = 3,
		tileH = 206,
		tileGap = 10,
		pic = 76,
		name = 21,
		chip = 24,
		star = 24,
		fuse = 48,
		slotH = 84,
		slotGap = 10,
		who = 64,
		say = 19,
	},
	short = {
		width = 1000,
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		gap = 12,
		head = 26,
		headText = 21,
		note = 19,
		listH = 330,
		cols = 3,
		tileH = 184,
		tileGap = 8,
		pic = 64,
		name = 20,
		chip = 22,
		star = 22,
		fuse = 46,
		slotH = 76,
		slotGap = 6,
		who = 64,
		say = 19,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	columns: UIListLayout,
	left: Frame,
	leftHead: Frame,
	leftTitle: TextLabel,
	leftNote: TextLabel,
	scroll: ScrollingFrame,
	grid: UIGridLayout,
	empty: TextLabel,
	right: Frame,
	rightHead: Frame,
	rightTitle: TextLabel,
	rightNote: TextLabel,
	slots: Frame,
	slotList: UIListLayout,
}

local parts: Parts? = nil
local pets: { CrateRules.Pet } = {}
local hired: { [string]: boolean } = {}
local picked = CrateRules.PLAYER_SLOT
local placeListeners: { (id: number, slot: string?) -> () } = {}
local fuseListeners: { (ids: { number }) -> () } = {}

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

local function soft(name: string, parent: Instance, size: number): TextLabel
	local label = words(name, parent, size)
	label.FontFace = Kit.BODY_FACE
	label.TextColor3 = Kit.INK_SOFT
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

-- A transparent button over the whole of `parent`, so the card under it takes the tap.
local function tapArea(parent: GuiObject, label: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Tap"
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Size = UDim2.fromScale(1, 1)
	b.ZIndex = 4
	b:SetAttribute("Says", label)
	b.Parent = parent
	return b
end

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

local function stars(parent: Instance, count: number, size: number, order: number)
	local row = frame("Stars", parent)
	row.LayoutOrder = order
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, size)
	list(row, true, 2)
	for index = 1, count do
		local star = frame(`Star{index}`, row)
		star.LayoutOrder = index
		star.Size = UDim2.fromOffset(size, size)
		Icons.draw("Star", star)
	end
end

-- Fuse is at least 44 real px tall at every scale; the tile grows with it.
local function fuseHeight(s: Sizes): number
	local scale = Kit.screenScale()
	return math.max(s.fuse, math.ceil(44 / scale))
end

local function tileHeight(s: Sizes): number
	return s.tileH - s.fuse + fuseHeight(s)
end

local function drawTile(group: CrateViewRules.Group, order: number, s: Sizes, container: Instance)
	local tile = frame(`Pet{order}`, container)
	tile.LayoutOrder = order
	tile.BackgroundTransparency = 0
	tile.BackgroundColor3 = Kit.WHITE
	Kit.corner(tile, UDim.new(0, 18))
	local edge = Kit.stroke(tile, 3)
	edge.Color = Kit.LINE
	-- the tile's words and pictures sit in their own stack, so the tap area over the tile is not laid out with them
	local body = frame("Stack", tile)
	body.Size = UDim2.fromScale(1, 1)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = body
	local stack = list(body, false, 4)
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local pic = frame("Pic", body)
	pic.LayoutOrder = 1
	pic.Size = UDim2.fromOffset(s.pic, s.pic)
	Portraits.draw(group.kind, group.rarity, pic, true)

	local name = words("Name", body, s.name)
	name.LayoutOrder = 2
	name.Size = UDim2.new(1, -8, 0, s.name + 2)
	name.Text = group.kind
	Kit.shrinkToFit(name, s.name)

	local line = frame("Line", body)
	line.LayoutOrder = 3
	line.Size = UDim2.new(1, 0, 0, s.chip)
	local lineList = list(line, true, 6)
	lineList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rarityChip(line, group.rarity, s.chip, 1)
	-- the stars sit across the bottom of the picture, so a Legendary chip and three stars never crowd one line
	local starRow = frame("StarRow", pic)
	starRow.AnchorPoint = Vector2.new(0.5, 0.8)
	starRow.Position = UDim2.fromScale(0.5, 1)
	starRow.Size = UDim2.fromOffset(s.pic + 20, s.star)
	starRow.ZIndex = 3
	local starList = list(starRow, true, 0)
	starList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stars(starRow, group.star, s.star, 1)

	-- the tap that puts this pet in the picked slot (or takes it off), under Fuse
	local tap = tapArea(tile, `Put {group.kind} with the picked slot`)
	tap.ZIndex = 2
	tap.Activated:Connect(function()
		local id, slot = CrateViewRules.placeFor(group, picked, pets)
		if id then
			for _, listener in placeListeners do
				task.spawn(listener, id, slot)
			end
		end
	end)

	if group.canFuse then
		local fuse = Window.button("Fuse", "Fuse", body, SKY_TOP, SKY_BOTTOM)
		fuse.LayoutOrder = 4
		fuse.Size = UDim2.new(1, -20, 0, fuseHeight(s))
		fuse.TextSize = 22
		fuse.ZIndex = 5
		fuse:SetAttribute(
			"Says",
			`Fuse three {group.kind} into a star {group.star + 1} {group.kind}`
		)
		fuse.Activated:Connect(function()
			local ids = CrateViewRules.fuseIds(group)
			if ids then
				for _, listener in fuseListeners do
					task.spawn(listener, ids)
				end
			end
		end)
	end

	-- how many, top right; a tick top left when one of them is in a slot
	if group.count > 1 then
		local count = words("Count", pic, 20)
		count.AnchorPoint = Vector2.new(0, 0)
		count.Position = UDim2.new(1, 0, 0, -4)
		count.AutomaticSize = Enum.AutomaticSize.X
		count.Size = UDim2.fromOffset(0, 26)
		count.BackgroundTransparency = 0
		count.BackgroundColor3 = Kit.WHITE
		count.ZIndex = 3
		count.Text = ` x{group.count} `
		Kit.corner(count, UDim.new(0, 10))
		Kit.stroke(count, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	if #group.slots > 0 then
		local tick = frame("InSlot", pic)
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.05, 0.1)
		tick.Size = UDim2.fromOffset(30, 30)
		tick.ZIndex = 3
		Icons.draw("Check", tick)
	end
end

local function drawSlot(row: CrateViewRules.SlotRow, order: number, s: Sizes, container: Frame)
	local card = frame(`Slot{order}`, container)
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, s.slotH)
	card.BackgroundTransparency = if row.locked then 0.45 else 0
	card.BackgroundColor3 = Kit.WHITE
	Kit.corner(card, UDim.new(0, 18))
	local edge = Kit.stroke(card, if row.slot == picked then 4 else 3)
	edge.Color = if row.slot == picked and not row.locked then PICKED else Kit.LINE
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = card

	local who = frame("Who", card)
	who.AnchorPoint = Vector2.new(0, 0.5)
	who.Position = UDim2.fromScale(0, 0.5)
	who.Size = UDim2.fromOffset(s.who, s.who)
	who.BackgroundTransparency = 0
	who.BackgroundColor3 = SLOT_FILL
	Kit.corner(who, UDim.new(0.5, 0))
	Kit.stroke(who, 3)
	local whoIcon = frame("Icon", who)
	whoIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	whoIcon.Position = UDim2.fromScale(0.5, 0.5)
	whoIcon.Size = UDim2.fromScale(0.7, 0.7)
	Icons.draw(if row.locked then "Lock" elseif row.helper then "Helper" else "Paw", whoIcon)

	local text = frame("Text", card)
	text.Position = UDim2.fromOffset(s.who + 12, 0)
	text.Size = UDim2.new(1, -(2 * s.who + 24), 1, 0)
	local textList = list(text, false, 0)
	textList.VerticalAlignment = Enum.VerticalAlignment.Center
	local t = words("Who", text, 22)
	t.LayoutOrder = 1
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, 26)
	t.Text = row.who
	local d = soft("Says", text, s.say)
	d.LayoutOrder = 2
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.Size = UDim2.new(1, 0, 0, s.say + 4)
	d.Text = row.say
	Kit.shrinkToFit(d, s.say)

	local petIn = frame("PetIn", card)
	petIn.AnchorPoint = Vector2.new(1, 0.5)
	petIn.Position = UDim2.fromScale(1, 0.5)
	petIn.Size = UDim2.fromOffset(s.who, s.who)
	petIn.BackgroundTransparency = 0
	petIn.BackgroundColor3 = Kit.WHITE
	Kit.corner(petIn, UDim.new(0, 16))
	local petEdge = Kit.stroke(petIn, 3)
	petEdge.Color = if row.pet then Kit.INK else Kit.INK_SOFT
	local pet = row.pet
	if pet then
		Portraits.draw(pet.kind, CrateRules.rarityOf(pet.kind) or "Common", petIn, true)
	else
		local icon = frame("Icon", petIn)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.6, 0.6)
		Icons.draw(if row.locked then "Lock" else "Paw", icon, true)
	end

	if not row.locked then
		local tap =
			tapArea(card, if row.helper then `Pick {row.who}'s pet slot` else "Pick your pet slot")
		tap.Activated:Connect(function()
			picked = row.slot
			PetsWindow.redraw()
		end)
	end
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function PetsWindow.redraw()
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
	p.columns.Padding = UDim.new(0, s.gap)

	local inner = width - 2 * s.pad - s.gap
	local leftW = math.floor(inner * 0.56)
	local rightW = inner - leftW
	p.left.Size = UDim2.fromOffset(leftW, 0)
	p.right.Size = UDim2.fromOffset(rightW, 0)
	for _, head in { p.leftHead, p.rightHead } do
		head.Size = UDim2.new(1, 0, 0, s.head)
	end
	for _, title in { p.leftTitle, p.rightTitle } do
		title.TextSize = s.headText
		title.Size = UDim2.fromOffset(0, s.head)
	end
	for _, note in { p.leftNote, p.rightNote } do
		note.TextSize = s.note
		note.Size = UDim2.fromOffset(0, s.head)
	end
	-- on a short screen the notes give way; the titles say enough
	p.leftNote.Visible = not short
	p.rightNote.Visible = not short

	-- the pets
	local groups = CrateViewRules.groups(pets)
	clear(p.scroll)
	local cellW = math.floor((leftW - 20 - (s.cols - 1) * s.tileGap) / s.cols) -- the bar and the list's padding
	local tileH = tileHeight(s)
	p.grid.CellSize = UDim2.fromOffset(cellW, tileH)
	p.grid.CellPadding = UDim2.fromOffset(s.tileGap, s.tileGap)
	p.scroll.Size = UDim2.new(1, 0, 0, s.listH)
	local lines = math.ceil(#groups / s.cols)
	p.scroll.CanvasSize =
		UDim2.fromOffset(0, lines * s.tileH + math.max(lines - 1, 0) * s.tileGap + 4)
	for index, group in groups do
		drawTile(group, index, s, p.scroll)
	end
	p.empty.Visible = #groups == 0
	p.scroll.Visible = #groups > 0
	p.empty.TextSize = s.say

	-- the slots
	local rows = CrateViewRules.slotRows(pets, hired)
	local pickedOk = false
	for _, row in rows do
		pickedOk = pickedOk or (row.slot == picked and not row.locked)
	end
	if not pickedOk then
		picked = CrateRules.PLAYER_SLOT
	end
	clear(p.slots)
	p.slotList.Padding = UDim.new(0, s.slotGap)
	for index, row in rows do
		drawSlot(row, index, s, p.slots)
	end
end

function PetsWindow.set(newPets: { CrateRules.Pet }, newHired: { [string]: boolean })
	pets, hired = newPets, newHired
	local p = parts
	if p and p.window.layer.Visible then
		PetsWindow.redraw()
	end
end

function PetsWindow.onPlace(fn: (id: number, slot: string?) -> ())
	table.insert(placeListeners, fn)
end

function PetsWindow.onFuse(fn: (ids: { number }) -> ())
	table.insert(fuseListeners, fn)
end

local function heading(parent: Instance, title: string, note: string): (Frame, TextLabel, TextLabel)
	local head = frame("Head", parent)
	head.LayoutOrder = 1
	local row = list(head, true, 10)
	row.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local t = words("Title", head, 24)
	t.LayoutOrder = 1
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Text = title
	local n = soft("Note", head, 19)
	n.LayoutOrder = 2
	n.AutomaticSize = Enum.AutomaticSize.X
	n.Text = note
	return head, t, n
end

function PetsWindow.build(root: Instance): Frame
	local window = Window.new("Pets", "Pets", "Paw", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			picked = CrateRules.PLAYER_SLOT
			PetsWindow.redraw()
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

	local left = frame("Own", row)
	left.LayoutOrder = 1
	left.AutomaticSize = Enum.AutomaticSize.Y
	list(left, false, 8)
	local leftHead, leftTitle, leftNote =
		heading(left, "Your pets", "Three the same fuse into a star up")
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.LayoutOrder = 2
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Kit.INK_SOFT
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = left
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local scrollPad = Instance.new("UIPadding") -- room for the tiles' outlines inside the list's edge
	scrollPad.PaddingLeft, scrollPad.PaddingTop = UDim.new(0, 4), UDim.new(0, 4)
	scrollPad.PaddingRight, scrollPad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	scrollPad.Parent = scroll
	local empty = soft("Empty", left, 19)
	empty.LayoutOrder = 3
	empty.Size = UDim2.new(1, 0, 0, 30)
	empty.Text = "No pets yet. Each crate holds one."

	local right = frame("Slots", row)
	right.LayoutOrder = 2
	right.AutomaticSize = Enum.AutomaticSize.Y
	list(right, false, 8)
	local rightHead, rightTitle, rightNote =
		heading(right, "Who has a pet", "Tap a slot, then a pet")
	local slots = frame("List", right)
	slots.LayoutOrder = 2
	slots.Size = UDim2.fromScale(1, 0)
	slots.AutomaticSize = Enum.AutomaticSize.Y
	local slotList = list(slots, false, 10)

	parts = {
		window = window,
		pad = pad,
		columns = columns,
		left = left,
		leftHead = leftHead,
		leftTitle = leftTitle,
		leftNote = leftNote,
		scroll = scroll,
		grid = grid,
		empty = empty,
		right = right,
		rightHead = rightHead,
		rightTitle = rightTitle,
		rightNote = rightNote,
		slots = slots,
		slotList = slotList,
	}
	ReplicatedStorage
		:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CrateViewRules.PETS_FLAG)
		:Connect(function()
			if not LiveFlags.isOn(CrateViewRules.PETS_FLAG) then
				window.layer.Visible = false
			end
		end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(PetsWindow.redraw)
	end
	PetsWindow.redraw()
	return window.layer
end

return PetsWindow
