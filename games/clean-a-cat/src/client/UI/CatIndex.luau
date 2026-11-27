--!strict
-- CatIndex: the Cat Index window (#238), from Design-Agent's draft (catindex.html, grid and detail). Behind the live
-- switch catIndexWindow, off by default; it opens from the Index button in the HUD row (HUD/SideButtons).
--
--   CatIndex.build(root)                    makes the window once and returns its layer (UI registers "CatIndex")
--   CatIndex.set(entries, newCats, tier)    draws the stamps IndexController holds, the New! marks and the star tier
--   CatIndex.onClosed(fn)                   fn() each time the window closes (IndexController clears New! then)
--
-- The grid: All and one tab per rarity, the "Wash all 10" bar with the full-set bonus, and one card per cat. A washed
-- cat shows its portrait and name with a tick, and a house mark once it has lived in the window; an unseen cat is a
-- silhouette with the rarity word, never a name, and cannot be pressed. A washed card opens the detail: portrait,
-- name, the rarity chip with New! beside it, the Washed and Resident stamps, the chance at the player's star tier
-- (the chance board's own numbers, IndexViewRules.chanceLine) and where the cat comes from. Back returns to the grid.
-- Only the X closes the window. UI never fires remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local IndexRules = require(Shared:WaitForChild("IndexRules"))
local IndexViewRules = require(Shared:WaitForChild("IndexViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))
local Window = require(script.Parent:WaitForChild("Window"))

local CatIndex = {}

local TABS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Special" } -- Special: the visitors' own page
local NEW_PINK = Color3.fromHex("FF86CF")
local SILHOUETTE = Color3.fromHex("4A3560")
local TRACK = Color3.fromHex("F7E9DA")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local GHOST_TOP, GHOST_BOTTOM = Color3.fromHex("FFFFFF"), Color3.fromHex("F1ECE6")
local TAB_ON = Color3.fromHex("45226B")

local SIZES = {
	full = {
		width = 920,
		band = 72,
		title = 38,
		badge = 96,
		pad = 22,
		tab = 60,
		track = 180,
		cardW = 120,
		cardH = 120,
		cardTile = 88,
		cardText = 19,
		gap = 12,
		detailTile = 180,
		name = 34,
		row = 44,
		button = 60,
	},
	short = {
		width = 920,
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		tab = 60,
		track = 100,
		cardW = 120, -- room for "Uncommon" at the text floor in the real font (Sync-Agent's iPhone 14 check, #262)
		cardH = 88,
		cardTile = 56,
		cardText = 19,
		gap = 8,
		detailTile = 128,
		name = 30,
		row = 40,
		button = 60,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	stack: Frame,
	barRow: Frame,
	barText: TextLabel,
	barTrack: Frame,
	barFill: Frame,
	barCount: TextLabel,
	barCoin: Frame,
	barBonus: TextLabel,
	tabsRow: Frame,
	tabs: { [string]: TextButton },
	grid: Frame,
	gridLayout: UIGridLayout,
	detail: Frame,
	detailTile: Frame,
	right: Frame,
	detailName: TextLabel,
	detailRarity: Frame,
	detailRarityText: TextLabel,
	detailNew: Frame,
	washedChip: Frame,
	washedText: TextLabel,
	residentChip: Frame,
	residentText: TextLabel,
	chanceValue: TextLabel,
	fromValue: TextLabel,
	back: TextButton,
}

local parts: Parts? = nil
local entries: { [string]: IndexRules.Entry } = {}
local newCats: { [string]: boolean } = {}
local tier = 1
local filter = "All"
local selected: string? = nil

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function words(name: string, parent: Instance, font: Enum.Font, colour: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = colour
	label.TextSize = 20
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 24)
	Kit.minText(label)
	label.Parent = parent
	return label
end

local function hlist(parent: Instance, gap: number): UIListLayout
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	list.Parent = parent
	return list
end

-- A rounded chip with words: the rarity tag, New!, the stamps.
local function chip(name: string, parent: Instance, fill: Color3, order: number): (Frame, TextLabel)
	local c = frame(name, parent)
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = fill
	c.AutomaticSize = Enum.AutomaticSize.X
	c.Size = UDim2.fromOffset(0, 32)
	c.LayoutOrder = order
	Kit.corner(c, UDim.new(0.5, 0))
	Kit.stroke(c, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.Parent = c
	local text = Kit.outlined("Text", c)
	text.AnchorPoint = Vector2.new(0, 0.5)
	text.Position = UDim2.fromScale(0, 0.5)
	text.TextSize = 19
	return c, text
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

local redraw: () -> ()

local function clearCards(grid: Frame)
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function cornerGlyph(
	name: string,
	parent: Instance,
	glyph: string,
	anchor: Vector2,
	position: UDim2
)
	local box = Instance.new("TextLabel")
	box.Name = name
	box.BackgroundTransparency = 1
	box.AnchorPoint = anchor
	box.Position = position
	box.Size = UDim2.fromOffset(26, 26)
	box.Text = glyph
	box.TextScaled = true -- a stamp mark, not words
	box.ZIndex = 3
	box.Parent = parent
end

local function drawCard(card: IndexViewRules.Card, grid: Frame, order: number, s: Sizes)
	local holder: GuiObject
	if card.seen then
		local button = Instance.new("TextButton")
		button.Text = ""
		button.AutoButtonColor = true
		button.Activated:Connect(function()
			selected = card.cat
			redraw()
		end)
		holder = button
	else
		holder = Instance.new("Frame")
	end
	holder.Name = card.cat
	holder.LayoutOrder = order
	holder.BackgroundColor3 = Kit.WHITE
	holder.BackgroundTransparency = 0
	Kit.corner(holder, UDim.new(0, 16))
	local edge = Kit.stroke(holder, 4)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Kit.RARITY_RIM[card.rarity] or Kit.RARITY[card.rarity] or Kit.INK
	holder.Parent = grid

	local tileBox = frame("TileBox", holder)
	tileBox.AnchorPoint = Vector2.new(0.5, 0)
	tileBox.Position = UDim2.new(0.5, 0, 0, 6)
	tileBox.Size = UDim2.fromOffset(s.cardTile, s.cardTile)
	if card.seen then
		Portraits.draw(card.cat, card.rarity, tileBox)
	else
		-- A silhouette: the rarity's colour around a dark "?" and never the cat's name.
		local tile = frame("Silhouette", tileBox)
		tile.Size = UDim2.fromScale(1, 1)
		tile.BackgroundTransparency = 0
		tile.BackgroundColor3 = (Kit.RARITY[card.rarity] or Kit.RARITY.Common):Lerp(Kit.WHITE, 0.6)
		Kit.corner(tile, UDim.new(0.14, 0))
		Kit.stroke(tile, 4)
		local mark = words("Mark", tile, Kit.FONT, SILHOUETTE)
		mark.AutomaticSize = Enum.AutomaticSize.None
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
		mark.Size = UDim2.fromScale(1, 1)
		mark.TextSize = math.floor(s.cardTile * 0.6)
		mark.Text = "?"
	end

	local caption = words("Caption", holder, Kit.FONT, Kit.INK)
	caption.AutomaticSize = Enum.AutomaticSize.None
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -4)
	caption.Size = UDim2.new(1, -4, 0, s.cardText + 4)
	Kit.shrinkToFit(caption, s.cardText)
	caption.Text = if card.seen then card.cat else card.rarity

	if card.washed then
		cornerGlyph("Washed", holder, "✅", Vector2.new(1, 0), UDim2.new(1, -2, 0, 2))
	end
	if card.resident then
		cornerGlyph("Resident", holder, "🏠", Vector2.new(0, 0), UDim2.fromOffset(2, 2))
	end
	if card.isNew then
		local newChip, newText = chip("New", holder, NEW_PINK, 0)
		newChip.AnchorPoint = Vector2.new(0.5, 0.5)
		newChip.Position = UDim2.fromScale(0.5, 0)
		newChip.Size = UDim2.fromOffset(0, 26)
		newChip.ZIndex = 4
		newText.Text = "New!"
	end
end

-- A stamp the cat has is green with a tick; one it lacks is grey. Words stay white with the ink outline.
local function stampChip(chipFrame: Frame, text: TextLabel, on: boolean, say: string)
	chipFrame.BackgroundColor3 = if on then Color3.fromHex("3FA868") else Color3.fromHex("CFC2B4")
	chipFrame.BackgroundTransparency = 0
	text.Text = if on then `✓ {say}` else say
end

redraw = function()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	local width = math.min(s.width, screenWidth(scale) - SCREEN_MARGIN)
	Window.fit(p.window, width, s.band, s.title, s.badge)
	p.pad.PaddingLeft, p.pad.PaddingRight = UDim.new(0, s.pad), UDim.new(0, s.pad)
	p.pad.PaddingTop, p.pad.PaddingBottom = UDim.new(0, s.pad - 6), UDim.new(0, s.pad)

	-- The "Wash all 10" bar, in the title band.
	-- the Special page shows only while special visitors are switched on (SpecialRules.FLAG)
	local specialOn = LiveFlags.isOn("specialVisitors")
	if filter == CatRules.SPECIAL and not specialOn then
		filter = "All"
	end
	-- On the Special page the bar counts the special visitors' cats instead, with no set bonus.
	local special = filter == CatRules.SPECIAL
	local washed, total
	if special then
		washed, total = IndexViewRules.specialProgress(entries)
	else
		washed, total = IndexViewRules.progress(entries)
	end
	p.barRow.Size = UDim2.fromOffset(0, s.band)
	p.barTrack.Size = UDim2.fromOffset(s.track, 20)
	p.barText.Text = if special then "Special cats" else `Wash all {total}`
	p.barFill.Size = UDim2.fromScale(if total > 0 then washed / total else 0, 1)
	p.barCount.Text = `{washed} / {total}`
	p.barBonus.Text = if special then "" else `+{IndexRules.BONUS_COINS}`

	local cat = selected
	local showDetail = cat ~= nil and entries[cat] ~= nil and entries[cat].washed
	p.tabsRow.Visible = not showDetail
	p.grid.Visible = not showDetail
	p.detail.Visible = showDetail

	if not showDetail or cat == nil then
		selected = nil
		p.tabsRow.Size = UDim2.new(1, 0, 0, s.tab)
		for name, tab in p.tabs do
			local on = name == filter
			tab.Visible = name ~= CatRules.SPECIAL or specialOn
			tab.Size = UDim2.fromOffset(0, s.tab)
			-- seven tabs: tighter sides on a short phone so the Special tab stays on screen
			local tabPad = tab:FindFirstChildOfClass("UIPadding") :: UIPadding?
			if tabPad then
				local side = UDim.new(0, if short then 12 else 20)
				tabPad.PaddingLeft, tabPad.PaddingRight = side, side
			end
			tab.BackgroundColor3 = if on then TAB_ON else Kit.WHITE
			tab.TextColor3 = if on then Kit.WHITE else Kit.INK
		end
		p.gridLayout.CellSize = UDim2.fromOffset(s.cardW, s.cardH)
		p.gridLayout.CellPadding = UDim2.fromOffset(s.gap, s.gap + 4)
		clearCards(p.grid)
		for index, card in IndexViewRules.cards(entries, filter, newCats) do
			drawCard(card, p.grid, index, s)
		end
		return
	end

	local rarity = CatRules.rarityOf(cat) or "Common"
	local entry = entries[cat]
	p.detailTile.Size = UDim2.fromOffset(s.detailTile, s.detailTile)
	p.right.Size = UDim2.new(1, -s.detailTile - 20, 0, 0)
	Portraits.draw(cat, rarity, p.detailTile)
	p.detailName.TextSize = s.name
	p.detailName.Size = UDim2.fromOffset(0, s.name + 6)
	p.detailName.Text = cat
	p.detailRarity.BackgroundColor3 = Kit.RARITY[rarity] or Kit.RARITY.Common
	Kit.rim(p.detailRarity, rarity, Kit.INK)
	p.detailRarityText.Text = rarity
	-- New! sits beside the rarity chip, never on the portrait (Design-Agent).
	p.detailNew.Visible = newCats[cat] == true
	stampChip(p.washedChip, p.washedText, entry.washed, "Washed")
	stampChip(p.residentChip, p.residentText, entry.resident, "Resident")
	p.chanceValue.Text = IndexViewRules.chanceLine(rarity, tier)
	p.fromValue.Text = `{rarity} customers at your door`
	p.back.Size = UDim2.fromOffset(s.detailTile, s.button)
end

local function infoRow(
	name: string,
	parent: Instance,
	order: number,
	icon: string,
	say: string
): TextLabel
	local row = frame(name, parent)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundTransparency = 0
	row.BackgroundColor3 = Kit.WHITE
	Kit.corner(row, UDim.new(0, 12))
	local edge = Kit.stroke(row, 2)
	edge.Color = Kit.line()
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 14)
	pad.Parent = row
	local iconBox = frame("IconBox", row)
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	iconBox.Position = UDim2.fromScale(0, 0.5)
	iconBox.Size = UDim2.fromOffset(26, 26)
	Icons.draw(icon, iconBox)
	local label = words("Say", row, Kit.FONT, Kit.INK)
	label.FontFace = Kit.BODY_FACE
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 36, 0.5, 0)
	label.Text = say
	local value = words("Value", row, Kit.FONT, Kit.INK)
	value.FontFace = Kit.BODY_FACE
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.fromScale(1, 0.5)
	value.TextXAlignment = Enum.TextXAlignment.Right
	return value
end

function CatIndex.set(
	newEntries: { [string]: IndexRules.Entry },
	marks: { [string]: boolean },
	starTier: number
)
	entries = newEntries
	newCats = marks
	tier = starTier
	redraw()
end

function CatIndex.onClosed(fn: () -> ())
	local p = parts
	if p == nil then
		return
	end
	local layer = p.window.layer
	layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if not layer.Visible then
			fn()
		end
	end)
end

function CatIndex.build(root: Instance): Frame
	local window = Window.new("CatIndex", "Cat Index", "Index", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		-- Each opening starts on the grid with every cat.
		if window.layer.Visible then
			selected = nil
			filter = "All"
			redraw()
		end
	end)

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local stack = frame("Stack", window.body)
	stack.Size = UDim2.fromScale(1, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	local stackList = Instance.new("UIListLayout")
	stackList.SortOrder = Enum.SortOrder.LayoutOrder
	stackList.Padding = UDim.new(0, 12) -- tabs' outlines sit outside their boxes
	stackList.Parent = stack

	-- The "Wash all 10" bar with the full-set bonus, at the right of the title band (clear of the X).
	local barRow = frame("WashAll", window.band)
	barRow.AnchorPoint = Vector2.new(1, 0.5)
	barRow.Position = UDim2.new(1, -64, 0.5, 0)
	barRow.AutomaticSize = Enum.AutomaticSize.X
	barRow.ZIndex = 2
	hlist(barRow, 10)
	local gift = frame("GiftBox", barRow)
	gift.LayoutOrder = 1
	gift.Size = UDim2.fromOffset(30, 30)
	Icons.draw("Gift", gift)
	local barText = words("Say", barRow, Kit.FONT, Kit.INK)
	barText.LayoutOrder = 2
	barText.TextSize = 22
	local barGap = frame("Gap", barRow) -- more air between the words and the bar (Review-QA on #240)
	barGap.LayoutOrder = 3
	barGap.Size = UDim2.fromOffset(4, 1)
	local barTrack = frame("Track", barRow)
	barTrack.LayoutOrder = 4
	barTrack.Size = UDim2.fromOffset(180, 20)
	barTrack.BackgroundTransparency = 0
	barTrack.BackgroundColor3 = TRACK
	barTrack.ClipsDescendants = true
	Kit.corner(barTrack, UDim.new(0.5, 0))
	Kit.stroke(barTrack, 3)
	local barFill = frame("Fill", barTrack)
	barFill.BackgroundTransparency = 0
	barFill.BackgroundColor3 = Kit.GOLD
	Kit.corner(barFill, UDim.new(0.5, 0)) -- round like its track: a corner never clips a child (issue 1062)
	local barCount = words("Count", barRow, Kit.FONT, Kit.INK)
	barCount.LayoutOrder = 5
	barCount.TextSize = 22
	local barCoin = frame("CoinIcon", barRow)
	barCoin.LayoutOrder = 6
	barCoin.Size = UDim2.fromOffset(48, 48) -- model icons are never drawn under 48
	Icons.draw("Coins", barCoin)
	local barBonus = words("Bonus", barRow, Kit.FONT, Kit.GOLD_INK)
	barBonus.LayoutOrder = 7
	barBonus.TextSize = 22

	-- Tabs: All and one per rarity.
	local tabsRow = frame("Tabs", stack)
	tabsRow.LayoutOrder = 2
	hlist(tabsRow, 8)
	local tabs: { [string]: TextButton } = {}
	for index, name in TABS do
		local tab = Instance.new("TextButton")
		tab.Name = name
		tab.LayoutOrder = index
		tab.AutoButtonColor = true
		tab.AutomaticSize = Enum.AutomaticSize.X
		tab.Font = Kit.FONT
		tab.TextSize = 20
		tab.Text = name
		Kit.minText(tab)
		Kit.corner(tab, UDim.new(0.5, 0))
		local edge = Kit.stroke(tab, 3)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = if name == "All"
			then Kit.INK
			else (Kit.RARITY_RIM[name] or Kit.RARITY[name] or Kit.INK)
		local tabMin = Instance.new("UISizeConstraint")
		tabMin.MinSize = Vector2.new(64, 0) -- "All" stays a full touch target (64 design px is 48 real at the smallest scale)
		tabMin.Parent = tab
		local tabPad = Instance.new("UIPadding")
		tabPad.PaddingLeft, tabPad.PaddingRight = UDim.new(0, 20), UDim.new(0, 20)
		tabPad.Parent = tab
		tab.Activated:Connect(function()
			filter = name
			redraw()
		end)
		tab.Parent = tabsRow
		tabs[name] = tab
	end

	local grid = frame("Grid", stack)
	grid.LayoutOrder = 3
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.Parent = grid

	-- The detail: portrait on the left; name, chips, rows and Back on the right.
	local detail = frame("Detail", stack)
	detail.LayoutOrder = 4
	detail.Size = UDim2.fromScale(1, 0)
	detail.AutomaticSize = Enum.AutomaticSize.Y
	detail.Visible = false
	local detailList = hlist(detail, 20)
	detailList.VerticalAlignment = Enum.VerticalAlignment.Top
	local left = frame("Left", detail)
	left.LayoutOrder = 1
	left.AutomaticSize = Enum.AutomaticSize.XY
	local leftList = Instance.new("UIListLayout")
	leftList.SortOrder = Enum.SortOrder.LayoutOrder
	leftList.Padding = UDim.new(0, 12)
	leftList.Parent = left
	local detailTile = frame("TileBox", left)
	detailTile.LayoutOrder = 1
	local right = frame("Right", detail)
	right.LayoutOrder = 2
	right.Size = UDim2.new(1, -220, 0, 0) -- set from the portrait's size in redraw
	right.AutomaticSize = Enum.AutomaticSize.Y
	local rightList = Instance.new("UIListLayout")
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, 8)
	rightList.Parent = right
	local nameRow = frame("NameRow", right)
	nameRow.LayoutOrder = 1
	nameRow.Size = UDim2.new(1, 0, 0, 40)
	hlist(nameRow, 10)
	local detailName = words("Name", nameRow, Kit.FONT, Kit.INK)
	detailName.LayoutOrder = 1
	local detailRarity, detailRarityText = chip("Rarity", nameRow, Kit.RARITY.Common, 2)
	local detailNew, detailNewText = chip("New", nameRow, NEW_PINK, 3)
	detailNewText.Text = "New!"
	local stampRow = frame("Stamps", right)
	stampRow.LayoutOrder = 2
	stampRow.Size = UDim2.new(1, 0, 0, 34)
	hlist(stampRow, 10)
	local washedChip, washedText = chip("Washed", stampRow, Kit.CREAM, 1)
	local residentChip, residentText = chip("Resident", stampRow, Kit.CREAM, 2)
	local chanceValue = infoRow("Chance", right, 3, "Dice", "Chance")
	local fromValue = infoRow("ComesFrom", right, 4, "Paw", "Comes from")
	local back = Window.button("Back", "Back", left, GHOST_TOP, GHOST_BOTTOM)
	back.LayoutOrder = 2
	back.TextColor3 = Kit.INK
	back.TextStrokeTransparency = 1
	back.TextSize = 24
	back.Activated:Connect(function()
		selected = nil
		redraw()
	end)

	parts = {
		window = window,
		pad = pad,
		stack = stack,
		barRow = barRow,
		barText = barText,
		barTrack = barTrack,
		barFill = barFill,
		barCount = barCount,
		barCoin = barCoin,
		barBonus = barBonus,
		tabsRow = tabsRow,
		tabs = tabs,
		grid = grid,
		gridLayout = gridLayout,
		detail = detail,
		detailTile = detailTile,
		right = right,
		detailName = detailName,
		detailRarity = detailRarity,
		detailRarityText = detailRarityText,
		detailNew = detailNew,
		washedChip = washedChip,
		washedText = washedText,
		residentChip = residentChip,
		residentText = residentText,
		chanceValue = chanceValue,
		fromValue = fromValue,
		back = back,
	}
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

-- For the UI gate: show one cat's detail as if its card were pressed.
function CatIndex.showDetail(cat: string?)
	selected = cat
	redraw()
end

return CatIndex
