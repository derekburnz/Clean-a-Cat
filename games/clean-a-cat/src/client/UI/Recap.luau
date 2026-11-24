--!strict
-- Recap: the card after a customer's cat goes home (#224), from Design-Agent's draft (recap.html, full and compact).
-- Behind the live switch recapCard, off by default: while it is off nothing here shows.
--
--   Recap.build(root)            makes the card and the strip once, inside the starter HUD's root
--   Recap.show(recap, onClose)   shows a RecapRules.Recap: the full card or the slim strip, as recap.full says
--   Recap.close()                hides it and calls that show's onClose once
--   Recap.isOpen()
--   Recap.setHidden(on)          hides the card or strip while a window is open over it, without closing it: opening
--                                the Cat Index or Settings is not "Next cat" (Review-QA); UI shows it again once
--                                that window closes
--   Recap.sideShown()            true while the full card shows in its side place (switch recapSide)
--   Recap.onShownChanged(fn)     fn runs each time the card or strip shows, hides or moves
--
-- The full card: the cat's portrait, name, rarity chip and a New! chip beside it (never on the star badge), the spa
-- stars it earned, one row per coin source (rows worth 0 are left out) and the total, then Next cat. The strip is the
-- same news in one line at the bottom centre. Only Next cat or the X closes it: no countdown, nothing closes by
-- itself, so it is a natural place to stop. Both are laid out in design pixels and scaled like the HUD (Kit).
--
-- With the switch recapSide on (off by default, Design-Agent's recap.html "side"), the full card is a narrow column
-- at the left, vertically centred under Roblox's top bar, with no dim, so the clean cat stays in view in the middle:
-- the portrait with the name, stars and chips beside it, then the rows, the total and a full-width Next cat. On a
-- short screen it is narrower, with the total and Next cat side by side, and it waits for the close-up wash camera's
-- slide (Recap.sideOnPhones) before a phone uses it. It stays on the left on every screen, away
-- from the bottom right corner where Roblox's badge note shows, and UI hides the phone's thumbstick and jump button
-- while it shows, so its button is never under them. The strip is unchanged.
-- UI never fires remotes: the caller's onClose does (RecapController asks for the next cat).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))

local Recap = {}

Recap.FLAG = "recapCard"
Recap.SIDE_FLAG = "recapSide"
-- True once the close-up wash camera slides the cat clear of the side card on a phone (Design-Agent); the UI gate
-- sets it to check the phone layout.
Recap.sideOnPhones = false

local MAX_STARS_SHOWN = 5
local ROW_ICONS = { wash = "Paw", tip = "Heart", bonus = "Station" } :: { [string]: string }
local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local RED_TOP, RED_BOTTOM = Color3.fromHex("FF7062"), Color3.fromHex("E83A3A")
local NEW_PINK = Color3.fromHex("FF86CF")
local TOTAL_FILL, TOTAL_LINE = Color3.fromHex("FFF1C7"), Color3.fromHex("F0CF6B")
local BACKDROP = Color3.fromRGB(36, 16, 56)
local BODY_GAP = 22 -- design px between the portrait column and the rows
local STRIP_LIFT = 28 -- design px from the bottom
local STRIP_SHIFT = 34 -- design px right on a short screen: clear of the touch thumbstick (Review-QA on #229)
local CHIP_GAP = 6 -- design px between the rarity and New! chips
local TITLE = "Great job!"
local NEXT_CAT = "Next cat"
local WELCOME = "He's your spa cat now!" -- the naming card only (#285)
local OPEN_SPA = "Open the spa!" -- the naming card's button: the first customer comes next
local TOPBAR_SHIFT = 33 -- real px: the card sits a little below the middle, clear of Roblox's top bar
local SIDE_LEFT = { side = 22, sideShort = 14 } -- design px from the left edge
-- design px under Roblox's top bar and above the bottom edge (recap.html): the side card is centred between them.
-- The HUD's root already starts under the top bar.
local SIDE_TOP_GAP, SIDE_BOTTOM_GAP = 12, 18

-- Sizes in design pixels: full, then compact for a short screen.
local SIZES = {
	full = {
		width = 760,
		band = 72,
		title = 38,
		badge = 96,
		who = 230,
		tile = 210,
		name = 30,
		chip = 30,
		chipText = 19,
		star = 60,
		starText = 30,
		row = 40,
		rowText = 20,
		rowIcon = 26,
		rowValue = 22,
		total = 34,
		totalIcon = 48,
		button = 64,
		buttonText = 28,
		pad = 22,
	},
	short = {
		width = 700,
		band = 56,
		title = 32,
		badge = 80,
		who = 150,
		tile = 128,
		name = 26,
		chip = 28,
		chipText = 19,
		star = 40,
		starText = 26,
		row = 34,
		rowText = 19,
		rowIcon = 24,
		rowValue = 22,
		total = 30,
		totalIcon = 48,
		button = 60,
		buttonText = 26,
		pad = 14,
	},
	-- The side column (switch recapSide): the who row is the portrait (tile) with the name, stars and chips beside it.
	side = {
		width = 430,
		band = 62,
		title = 32,
		badge = 0,
		who = 14, -- the gap between the portrait and the words beside it
		tile = 112,
		name = 30,
		chip = 28,
		chipText = 17,
		star = 30,
		starText = 22,
		row = 36,
		rowText = 18,
		rowIcon = 24,
		rowValue = 20,
		total = 30,
		totalIcon = 48,
		button = 60,
		buttonText = 28,
		pad = 16,
	},
	sideShort = {
		width = 330, -- a phone held sideways (recap.html): it fits under the top bar on the smallest one
		band = 46,
		title = 27,
		badge = 0,
		who = 10,
		tile = 76,
		name = 24,
		chip = 22,
		chipText = 15,
		star = 22,
		starText = 17,
		row = 28,
		rowText = 15,
		rowIcon = 22,
		rowValue = 19,
		total = 24,
		totalIcon = 48,
		button = 60, -- 45 real px on a phone: the tap minimum is 44
		buttonText = 22,
		pad = 10,
	},
}
type Sizes = typeof(SIZES.full)
local SIDE_GAP = { side = 8, sideShort = 6 } -- design px between the side card's parts

local STRIP =
	{ tile = 64, star = 30, starText = 22, got = 28, gotIcon = 48, button = 60, buttonText = 24 }

type Parts = {
	layer: Frame,
	backdrop: Frame,
	cardHolder: Frame,
	cardScale: UIScale,
	card: Frame,
	band: Frame,
	title: TextLabel,
	badge: Frame,
	close: TextButton,
	body: Frame,
	bodyPad: UIPadding,
	bodyList: UIListLayout,
	who: Frame,
	whoList: UIListLayout,
	info: Frame,
	tileBox: Frame,
	name: TextLabel,
	chipRow: Frame,
	chipList: UIListLayout,
	rarityChip: Frame,
	rarityText: TextLabel,
	newChip: Frame,
	newText: TextLabel,
	right: Frame,
	stars: Frame,
	starsList: UIListLayout,
	welcome: TextLabel,
	rows: Frame,
	rowsList: UIListLayout,
	foot: Frame,
	footList: UIListLayout,
	total: Frame,
	totalIcon: Frame,
	totalText: TextLabel,
	next: TextButton,
	stripScale: UIScale,
	strip: Frame,
	stripTile: Frame,
	stripStars: Frame,
	stripGotIcon: Frame,
	stripGot: TextLabel,
	stripNext: TextButton,
}

local parts: Parts? = nil
local shown: RecapRules.Recap? = nil
local onClosed: (() -> ())? = nil
local hidden = false -- a window is open over it (Recap.setHidden)
local wasShown: string? = nil -- what onShownChanged last told: nil, "card", "side" or "strip"
local shownListeners: { () -> () } = {}

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function list(
	parent: Instance,
	horizontal: boolean,
	gap: number,
	centre: boolean?
): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	layout.HorizontalAlignment = if centre
		then Enum.HorizontalAlignment.Center
		else Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

local function padding(parent: Instance, x: number, y: number): UIPadding
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, x), UDim.new(0, x)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, y), UDim.new(0, y)
	pad.Parent = parent
	return pad
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

-- Ink words on cream, or gold-ink numbers (no outline: they sit on a light card).
local function words(name: string, parent: Instance, font: Enum.Font, colour: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = colour
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	Kit.minText(label)
	label.Parent = parent
	return label
end

-- A chunky button: ink outline, a two-tone face and outlined words (the screens' .btn).
local function chunky(
	name: string,
	text: string,
	parent: Instance,
	top: Color3,
	bottom: Color3
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.BackgroundColor3 = Kit.WHITE
	b.Font = Kit.FONT
	b.Text = text
	b.TextColor3 = Kit.WHITE
	b.TextStrokeColor3 = Kit.INK
	b.TextStrokeTransparency = 0 -- a solid ink edge: white on bright green or red needs it to read on a phone
	Kit.minText(b)
	gradient(b, top, bottom)
	Kit.corner(b, UDim.new(0, 16))
	local s = Kit.stroke(b, 4)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Parent = parent
	Motion.press(b) -- trial springs, switch springUi (#183)
	return b
end

local function chip(name: string, parent: Instance, fill: Color3, order: number): (Frame, TextLabel)
	local c = frame(name, parent)
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = fill
	c.AutomaticSize = Enum.AutomaticSize.X
	c.LayoutOrder = order
	Kit.corner(c, UDim.new(0.5, 0))
	Kit.stroke(c, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.Parent = c
	local text = Kit.outlined("Text", c)
	text.AnchorPoint = Vector2.new(0, 0.5)
	text.Position = UDim2.fromScale(0, 0.5)
	return c, text
end

-- Fills `holder` with `count` stars of `size` design px, then "+N stars"; a `score` (the opening's kitten, #285)
-- adds nothing to the spa, so it says "N stars".
local function drawStars(
	holder: Frame,
	count: number,
	size: number,
	textSize: number,
	score: boolean?
)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index = 1, math.clamp(count, 1, MAX_STARS_SHOWN) do
		local box = frame(`Star{index}`, holder)
		box.Size = UDim2.fromOffset(size, size)
		box.LayoutOrder = index
		Icons.draw("Star", box)
	end
	local caption = words("Earned", holder, Kit.FONT, Kit.GOLD_INK)
	caption.LayoutOrder = MAX_STARS_SHOWN + 1
	caption.TextSize = textSize
	caption.Text = `{if score then "" else "+"}{count} {if count == 1 then "star" else "stars"}`
end

local function drawRows(holder: Frame, recap: RecapRules.Recap, s: Sizes)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, row in RecapRules.rows(recap) do
		local line = frame(`Row_{row.key}`, holder)
		line.LayoutOrder = index
		line.BackgroundTransparency = 0
		line.BackgroundColor3 = Kit.WHITE
		line.Size = UDim2.new(1, 0, 0, s.row)
		Kit.corner(line, UDim.new(0, 12))
		local edge = Kit.stroke(line, 2)
		edge.Color = Kit.LINE
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
		pad.Parent = line
		local icon = frame("IconBox", line)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.fromScale(0, 0.5)
		icon.Size = UDim2.fromOffset(s.rowIcon, s.rowIcon)
		Icons.draw(ROW_ICONS[row.key] or "Paw", icon)
		local say = words("Say", line, Kit.FONT, Kit.INK)
		say.FontFace = Kit.BODY_FACE
		say.AnchorPoint = Vector2.new(0, 0.5)
		say.Position = UDim2.new(0, s.rowIcon + 10, 0.5, 0)
		say.TextSize = s.rowText
		say.Text = row.say
		local value = words("Value", line, Kit.FONT, Kit.GOLD_INK)
		value.AnchorPoint = Vector2.new(1, 0.5)
		value.Position = UDim2.fromScale(1, 0.5)
		value.TextSize = s.rowValue
		value.Text = `+{row.value}`
	end
end

-- What shows now: nil, the full card in the middle ("card"), at the side ("side"), or the strip.
local function shownAs(): string?
	local recap = shown
	if recap == nil or hidden or not LiveFlags.isOn(Recap.FLAG) then
		return nil
	end
	if not recap.full then
		return "strip"
	end
	-- On a phone the 330 px column would cover the cat until the close-up wash camera slides him right (Design-Agent):
	-- until that is wired, a phone keeps the card in the middle even with the switch on.
	local _, short = Kit.screenScale()
	return if LiveFlags.isOn(Recap.SIDE_FLAG) and (Recap.sideOnPhones or not short)
		then "side"
		else "card"
end

local function tellShown()
	local now = shownAs()
	if now ~= wasShown then
		wasShown = now
		for _, fn in shownListeners do
			task.spawn(fn)
		end
	end
end

-- The card's place and the order of its parts: in the middle with the portrait column beside the rows, or the side
-- column with the portrait, name, stars and chips in one row above the rows (switch recapSide). Returns the width of
-- the side card's words beside the portrait.
local function arrange(p: Parts, side: boolean, short: boolean, s: Sizes): number
	local gap = if short then SIDE_GAP.sideShort else SIDE_GAP.side
	if side then
		p.cardHolder.AnchorPoint = Vector2.new(0, 0.5)
		p.cardHolder.Position = UDim2.fromScale(0, 0.5)
		p.card.AnchorPoint = Vector2.new(0, 0.5)
		-- centred in the space from under the top bar down to the bottom gap
		local shift = (SIDE_TOP_GAP - SIDE_BOTTOM_GAP) / 2
		p.card.Position =
			UDim2.new(0, if short then SIDE_LEFT.sideShort else SIDE_LEFT.side, 0.5, shift)
	else
		p.cardHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		p.cardHolder.Position = UDim2.fromScale(0.5, 0.5)
		p.card.AnchorPoint = Vector2.new(0.5, 0.5)
		p.card.Position = UDim2.new(0.5, 0, 0.5, TOPBAR_SHIFT)
	end
	p.badge.Visible = not side
	p.title.Position = UDim2.new(0, if side then 20 else s.badge + 4, 0.5, 0)

	p.bodyList.FillDirection = if side
		then Enum.FillDirection.Vertical
		else Enum.FillDirection.Horizontal
	p.bodyList.Padding = UDim.new(0, if side then gap else BODY_GAP)
	p.whoList.FillDirection = if side
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	p.whoList.HorizontalAlignment = if side
		then Enum.HorizontalAlignment.Left
		else Enum.HorizontalAlignment.Center
	p.whoList.VerticalAlignment = if side
		then Enum.VerticalAlignment.Center
		else Enum.VerticalAlignment.Top
	p.whoList.Padding = UDim.new(0, if side then s.who else 8)
	p.rowsList.Padding = UDim.new(0, if side and short then 4 else 6)
	p.starsList.Padding = UDim.new(0, if side then 4 else 8) -- five stars and "+5 stars" fit beside the portrait
	p.name.TextXAlignment = if side then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	p.chipList.HorizontalAlignment = if side
		then Enum.HorizontalAlignment.Left
		else Enum.HorizontalAlignment.Center
	local inner = s.width - 2 * s.pad
	local beside = inner - s.tile - s.who
	if side then
		p.who.Size = UDim2.fromOffset(inner, 0)
		p.info.Parent = p.who
		p.name.Parent, p.name.LayoutOrder = p.info, 1
		p.stars.Parent, p.stars.LayoutOrder = p.info, 2
		p.chipRow.Parent, p.chipRow.LayoutOrder = p.info, 3
		p.name.Size = UDim2.fromOffset(beside, s.name + 6)
		p.stars.Size = UDim2.fromOffset(beside, s.star)
		p.right.Size = UDim2.fromOffset(inner, 0)
	else
		p.who.Size = UDim2.fromOffset(s.who, 0)
		p.info.Parent = nil
		p.name.Parent, p.name.LayoutOrder = p.who, 2
		p.chipRow.Parent, p.chipRow.LayoutOrder = p.who, 3
		p.stars.Parent, p.stars.LayoutOrder = p.right, 1
		p.name.Size = UDim2.new(1, 0, 0, s.name + 8)
		p.stars.Size = UDim2.new(1, 0, 0, s.star)
		p.right.Size = UDim2.fromOffset(inner - s.who - BODY_GAP, 0)
	end

	-- The side card's foot: the total above a full-width Next cat, or side by side on a short screen.
	local stackedFoot = side and not short
	p.footList.FillDirection = if stackedFoot
		then Enum.FillDirection.Vertical
		else Enum.FillDirection.Horizontal
	p.footList.Padding = UDim.new(0, if side then gap else 12)
	local footHeight = if stackedFoot then 2 * s.button + gap + 6 else s.button + 6 -- room for the outline
	p.foot.Size = UDim2.new(1, 0, 0, footHeight)
	if stackedFoot then
		p.next.AutomaticSize = Enum.AutomaticSize.None
		p.next.Size = UDim2.new(1, 0, 0, s.button)
	else
		p.next.AutomaticSize = Enum.AutomaticSize.X
		p.next.Size = UDim2.fromOffset(0, s.button)
	end
	return beside
end

-- Sizes, scale and contents for the recap on show.
local function redraw()
	local p = parts
	local recap = shown
	if p == nil then
		return
	end
	local as = shownAs()
	p.layer.Visible = as ~= nil
	if recap == nil or as == nil then
		tellShown()
		return
	end
	local scale, short = Kit.screenScale()
	p.cardScale.Scale = scale
	p.stripScale.Scale = scale
	local side = as == "side"
	p.backdrop.Visible = as == "card" -- no dim at the side: the clean cat stays in view
	p.card.Visible = recap.full
	p.strip.Visible = not recap.full

	local total = `+{RecapRules.total(recap)}`
	if not recap.full then
		-- On a phone held sideways the strip moves a little right, clear of the thumbstick at the bottom left.
		p.strip.Position = UDim2.new(0.5, if short then STRIP_SHIFT else 0, 1, -STRIP_LIFT)
		Portraits.draw(recap.cat, recap.rarity, p.stripTile)
		drawStars(p.stripStars, recap.stars, STRIP.star, STRIP.starText)
		p.stripGot.Text = total
		tellShown()
		return
	end

	local s: Sizes = if side
		then (if short then SIZES.sideShort else SIZES.side)
		else (if short then SIZES.short else SIZES.full)
	local beside = arrange(p, side, short, s)
	p.card.Size = UDim2.fromOffset(s.width, 0)
	p.band.Size = UDim2.new(1, 0, 0, s.band)
	p.title.TextSize = s.title
	-- The opening's kitten's naming card (#285, Design-Agent): Meet Suds!, his line, and Open the spa!
	p.title.Text = if recap.mascot then `Meet {recap.cat}!` else TITLE
	-- out of the column on a customer's card, so its list gap never pushes the card taller
	p.welcome.Parent = if recap.mascot then p.right else nil
	p.welcome.TextSize = s.starText
	p.next.Text = if recap.mascot then OPEN_SPA else NEXT_CAT
	p.badge.Size = UDim2.fromOffset(s.badge, s.badge)
	local bodyPad = p.bodyPad
	bodyPad.PaddingLeft, bodyPad.PaddingRight = UDim.new(0, s.pad), UDim.new(0, s.pad)
	bodyPad.PaddingTop, bodyPad.PaddingBottom = UDim.new(0, s.pad - 4), UDim.new(0, s.pad)
	p.tileBox.Size = UDim2.fromOffset(s.tile, s.tile)
	Portraits.draw(recap.cat, recap.rarity, p.tileBox)
	Kit.shrinkToFit(p.name, s.name)
	p.name.Text = recap.cat
	-- The short card's column is narrower than "Legendary" plus "New!" side by side (Sync-Agent on an iPhone 14), so
	-- there the New! chip goes under the rarity chip. The side card's words beside the portrait fit both in a row.
	local stacked = short and recap.isNew and not side
	p.chipList.FillDirection = if stacked
		then Enum.FillDirection.Vertical
		else Enum.FillDirection.Horizontal
	local chipHeight = if stacked then 2 * s.chip + CHIP_GAP else s.chip
	p.chipRow.Size = if side
		then UDim2.fromOffset(beside, chipHeight)
		else UDim2.new(1, 0, 0, chipHeight)
	p.rarityChip.Size = UDim2.fromOffset(0, s.chip)
	p.rarityChip.BackgroundColor3 = Kit.RARITY[recap.rarity] or Kit.RARITY.Common
	p.rarityText.TextSize = s.chipText
	p.rarityText.Text = recap.rarity
	p.newChip.Visible = recap.isNew
	-- The opening's kitten (#285) has no rarity and pays nothing: his card is his name and his stars.
	p.chipRow.Visible = not recap.mascot
	p.newChip.Size = UDim2.fromOffset(0, s.chip)
	p.newText.TextSize = s.chipText
	drawStars(p.stars, recap.stars, s.star, s.starText, recap.mascot)
	drawRows(p.rows, recap, s)
	p.total.Size = UDim2.fromOffset(0, s.button)
	p.totalIcon.Size = UDim2.fromOffset(s.totalIcon, s.totalIcon)
	p.totalText.TextSize = s.total
	p.totalText.Text = total
	p.total.Visible = not recap.mascot
	p.next.TextSize = s.buttonText
	tellShown()
end

function Recap.setHidden(on: boolean)
	if hidden ~= on then
		hidden = on
		redraw()
	end
end

function Recap.isOpen(): boolean
	return shown ~= nil
end

function Recap.sideShown(): boolean
	return shownAs() == "side"
end

function Recap.onShownChanged(fn: () -> ())
	table.insert(shownListeners, fn)
end

function Recap.close()
	if shown == nil then
		return
	end
	shown = nil
	redraw()
	local closed = onClosed
	onClosed = nil
	if closed then
		closed()
	end
end

function Recap.show(recap: RecapRules.Recap, onClose: (() -> ())?)
	if shown ~= nil then
		Recap.close()
	end
	shown = recap
	onClosed = onClose
	redraw()
	local p = parts
	if p then
		Motion.popIn(if recap.full then p.card else p.strip) -- trial springs, switch springUi (#183)
	end
end

function Recap.build(root: Frame)
	local layer = frame("Recap", root)
	layer.Size = UDim2.fromScale(1, 1)
	layer.Visible = false
	layer.ZIndex = 10

	-- The dim behind the full card; large enough to cover the TV inset around the root too. It takes presses, so a tap
	-- beside the card does not reach the world, but it does not close the card.
	local backdrop = frame("Backdrop", layer)
	backdrop.AnchorPoint = Vector2.new(0.5, 0.5)
	backdrop.Position = UDim2.fromScale(0.5, 0.5)
	backdrop.Size = UDim2.fromScale(1.5, 1.5)
	backdrop.BackgroundTransparency = 0.58
	backdrop.BackgroundColor3 = BACKDROP
	backdrop.Active = true

	-- The screen scale goes on a see-through holder the size of the layer, scaled about the point the piece is
	-- anchored to, so Motion.popIn can use its own UIScale on the piece itself (one UIScale per object).
	local function scaledHolder(name: string, anchor: Vector2): (Frame, UIScale)
		local holder = frame(name, layer)
		holder.AnchorPoint = anchor
		holder.Position = UDim2.fromScale(anchor.X, anchor.Y)
		holder.Size = UDim2.fromScale(1, 1)
		local scale = Instance.new("UIScale")
		scale.Name = "RecapScale"
		scale.Parent = holder
		return holder, scale
	end

	-- The full card.
	local cardHolder, cardScale = scaledHolder("CardHolder", Vector2.new(0.5, 0.5))
	local card = frame("Card", cardHolder)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, TOPBAR_SHIFT)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundTransparency = 0
	card.BackgroundColor3 = Kit.CREAM
	Kit.corner(card, UDim.new(0, 26))
	Kit.stroke(card, 4)

	local stack = frame("Stack", card)
	stack.Size = UDim2.fromScale(1, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	list(stack, false, 0)

	local band = frame("Band", stack)
	band.LayoutOrder = 1
	band.BackgroundTransparency = 0
	band.BackgroundColor3 = Kit.WHITE
	gradient(band, Color3.fromHex("E7DBFF"), Color3.fromHex("F6A9C9"))
	Kit.corner(band, UDim.new(0, 22))
	local title = Kit.outlined("Title", band)
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Text = TITLE

	local body = frame("Body", stack)
	body.LayoutOrder = 2
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	local bodyPad = padding(body, 22, 18)
	local bodyList = list(body, true, BODY_GAP)
	bodyList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	bodyList.VerticalAlignment = Enum.VerticalAlignment.Top

	local who = frame("Who", body)
	who.LayoutOrder = 1
	who.AutomaticSize = Enum.AutomaticSize.Y
	local whoList = list(who, false, 8, true)
	whoList.VerticalAlignment = Enum.VerticalAlignment.Top
	local tileBox = frame("TileBox", who)
	tileBox.LayoutOrder = 1
	-- The side card's words beside the portrait (switch recapSide): the name, stars and chips move in here.
	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.BorderSizePixel = 0
	info.LayoutOrder = 2
	info.AutomaticSize = Enum.AutomaticSize.XY
	local infoList = list(info, false, 4)
	infoList.VerticalAlignment = Enum.VerticalAlignment.Top
	local name = words("Name", who, Kit.FONT, Kit.INK)
	name.LayoutOrder = 2
	name.AutomaticSize = Enum.AutomaticSize.None -- one line: names are at most 11 letters (Design-Agent)
	local chipRow = frame("Tags", who)
	chipRow.LayoutOrder = 3
	chipRow.Size = UDim2.fromScale(1, 0)
	local chipList = list(chipRow, true, CHIP_GAP, true)
	-- New! sits beside the rarity tag under the name, never on the star badge (decisions.md 2026-11-24).
	local rarityChip, rarityText = chip("Rarity", chipRow, Kit.RARITY.Common, 1)
	local newChip, newText = chip("New", chipRow, NEW_PINK, 2)
	newText.Text = "New!"

	local right = frame("Right", body)
	right.LayoutOrder = 2
	right.AutomaticSize = Enum.AutomaticSize.Y
	local rightList = list(right, false, 8)
	rightList.VerticalAlignment = Enum.VerticalAlignment.Top
	local stars = frame("Stars", right)
	stars.LayoutOrder = 1
	stars.Size = UDim2.fromScale(1, 0)
	local starsList = list(stars, true, 8)
	-- The naming card's line under the stars (the opening's kitten, #285); hidden on a customer's card.
	local welcome = words("Welcome", right, Kit.FONT, Kit.INK)
	welcome.LayoutOrder = 2
	welcome.Text = WELCOME
	welcome.Parent = nil -- in the column only on the naming card (redraw)
	local rows = frame("Rows", right)
	rows.LayoutOrder = 3
	rows.Size = UDim2.fromScale(1, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	local rowsList = list(rows, false, 6)
	local foot = frame("Foot", right)
	foot.LayoutOrder = 4
	foot.Size = UDim2.fromScale(1, 0)
	local footList = list(foot, true, 12)
	local total = frame("Total", foot)
	total.LayoutOrder = 1
	total.AutomaticSize = Enum.AutomaticSize.X
	total.BackgroundTransparency = 0
	total.BackgroundColor3 = TOTAL_FILL
	Kit.corner(total, UDim.new(0, 14))
	local totalEdge = Kit.stroke(total, 3)
	totalEdge.Color = TOTAL_LINE
	local totalPad = Instance.new("UIPadding")
	totalPad.PaddingLeft, totalPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 16)
	totalPad.Parent = total
	list(total, true, 8)
	local totalIcon = frame("CoinIcon", total)
	totalIcon.LayoutOrder = 1
	Icons.draw("Coins", totalIcon)
	local totalText = words("Amount", total, Kit.FONT, Kit.GOLD_INK)
	totalText.LayoutOrder = 2
	local nextButton = chunky("NextCat", NEXT_CAT, foot, GREEN_TOP, GREEN_BOTTOM)
	nextButton.LayoutOrder = 2
	nextButton.AutomaticSize = Enum.AutomaticSize.X
	local nextPad = Instance.new("UIPadding")
	nextPad.PaddingLeft, nextPad.PaddingRight = UDim.new(0, 28), UDim.new(0, 28)
	nextPad.Parent = nextButton

	local badge = frame("Badge", card)
	badge.Position = UDim2.fromOffset(-6, -14)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Kit.CREAM
	badge.ZIndex = 2
	Kit.corner(badge, UDim.new(0.5, 0))
	Kit.stroke(badge, 4)
	local badgeStar = frame("StarBox", badge)
	badgeStar.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeStar.Position = UDim2.fromScale(0.5, 0.5)
	badgeStar.Size = UDim2.fromScale(0.6, 0.6)
	Icons.draw("Star", badgeStar)

	local close = chunky("Close", "X", card, RED_TOP, RED_BOTTOM)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 20, 0, -20)
	close.Size = UDim2.fromOffset(64, 64)
	close.TextSize = 34
	close.ZIndex = 3

	-- The strip: the same news in one line, bottom centre, no backdrop.
	local stripHolder, stripScale = scaledHolder("StripHolder", Vector2.new(0.5, 1))
	local strip = frame("Strip", stripHolder)
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.new(0.5, 0, 1, -STRIP_LIFT)
	strip.AutomaticSize = Enum.AutomaticSize.XY
	strip.BackgroundTransparency = 0
	strip.BackgroundColor3 = Kit.CREAM
	Kit.corner(strip, UDim.new(0, 22))
	Kit.stroke(strip, 4)
	local stripPad = Instance.new("UIPadding")
	stripPad.PaddingLeft, stripPad.PaddingRight = UDim.new(0, 10), UDim.new(0, 12)
	stripPad.PaddingTop, stripPad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	stripPad.Parent = strip
	list(strip, true, 12) -- kept narrow: clear of the thumbstick on a small phone
	local stripTile = frame("TileBox", strip)
	stripTile.LayoutOrder = 1
	stripTile.Size = UDim2.fromOffset(STRIP.tile, STRIP.tile)
	local stripStars = frame("Stars", strip)
	stripStars.LayoutOrder = 2
	stripStars.AutomaticSize = Enum.AutomaticSize.XY
	list(stripStars, true, 4)
	local got = frame("Got", strip)
	got.LayoutOrder = 3
	got.AutomaticSize = Enum.AutomaticSize.XY
	list(got, true, 6)
	local stripGotIcon = frame("CoinIcon", got)
	stripGotIcon.LayoutOrder = 1
	stripGotIcon.Size = UDim2.fromOffset(STRIP.gotIcon, STRIP.gotIcon)
	Icons.draw("Coins", stripGotIcon)
	local stripGot = words("Amount", got, Kit.FONT, Kit.GOLD_INK)
	stripGot.LayoutOrder = 2
	stripGot.TextSize = STRIP.got
	local stripNext = chunky("NextCat", "Next cat", strip, GREEN_TOP, GREEN_BOTTOM)
	stripNext.LayoutOrder = 4
	stripNext.AutomaticSize = Enum.AutomaticSize.X
	stripNext.Size = UDim2.fromOffset(0, STRIP.button)
	stripNext.TextSize = STRIP.buttonText
	local stripNextPad = Instance.new("UIPadding")
	stripNextPad.PaddingLeft, stripNextPad.PaddingRight = UDim.new(0, 20), UDim.new(0, 20)
	stripNextPad.Parent = stripNext

	parts = {
		layer = layer,
		backdrop = backdrop,
		cardHolder = cardHolder,
		cardScale = cardScale,
		card = card,
		band = band,
		title = title,
		badge = badge,
		close = close,
		body = body,
		bodyPad = bodyPad,
		bodyList = bodyList,
		who = who,
		whoList = whoList,
		info = info,
		tileBox = tileBox,
		name = name,
		chipRow = chipRow,
		chipList = chipList,
		rarityChip = rarityChip,
		rarityText = rarityText,
		newChip = newChip,
		newText = newText,
		right = right,
		stars = stars,
		starsList = starsList,
		welcome = welcome,
		rows = rows,
		rowsList = rowsList,
		foot = foot,
		footList = footList,
		total = total,
		totalIcon = totalIcon,
		totalText = totalText,
		next = nextButton,
		stripScale = stripScale,
		strip = strip,
		stripTile = stripTile,
		stripStars = stripStars,
		stripGotIcon = stripGotIcon,
		stripGot = stripGot,
		stripNext = stripNext,
	}

	nextButton.Activated:Connect(Recap.close)
	close.Activated:Connect(Recap.close)
	stripNext.Activated:Connect(Recap.close)
	-- Switched off while open: close it, so the next cat still comes.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Recap.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(Recap.FLAG) then
				Recap.close()
			end
		end)
	-- The side switch moves an open card.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Recap.SIDE_FLAG)
		:Connect(redraw)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

return Recap
