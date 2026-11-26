--!strict
-- QueueWindow: "Who's next?" (#246), from Design-Agent's draft (queue.html). Behind the live switch queueWindow, off
-- by default; the player opens it from the HUD's waiting faces (HUD/Waiting). It is a second way into the queue pick
-- prototype (#201): the door prompts still work.
--
--   QueueWindow.build(root)                      makes the window once and returns its layer (UI registers "Queue")
--   QueueWindow.set(cards, headline, pickable)   draws the line (QueueViewRules cards, front first)
--   QueueWindow.onPick(fn)                       fn(place) when a Wash next button is pressed
--
-- One card per waiting customer: the portrait, rarity, name, what the cat needs (a lock on a need whose station is
-- not built), what it pays and, under it, Wash next. The front card is already next, so it says Up next instead;
-- before the server would take a pick (the first customer not served yet, or queuePick off) the others say Waiting.
-- A Rare or rarer customer is a VIP: a rarity glow and a crown, the same rows as everyone else, and the line under
-- the title says how often that rarity visits, with the chance board's own numbers (QueueViewRules.headline).
-- A line of more than 3 (benchGrow, up to 6 with tubs built) widens the window; past the screen's width the cards
-- scroll sideways with a bar under them, so a card never shrinks below its phone size.
-- With dirtLevels on, a dirt row (four mud drops and the step count) takes the needs' place; with heartBar on, each card
-- has its heart bar (no numbers, a tick at the quick bonus's 10%), a "Quick bonus" tag while it lasts, and the pay
-- reads as the base ("40+"). A special visitor's cat glows lilac with a gold rim and says only the player can wash it
-- (#587). Left out until the design sets them: helpers on a customer.
-- Only the X closes the window, and a pick leaves it open so the player sees the picked cat move to the front.
-- UI never fires remotes: QueueWindowController sends the pick and the server decides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local HeartRules = require(Shared:WaitForChild("HeartRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local QueueViewRules = require(Shared:WaitForChild("QueueViewRules"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))
local Window = require(script.Parent:WaitForChild("Window"))

local QueueWindow = {}

QueueWindow.FLAG = "queueWindow"

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local NEW_PINK = Color3.fromHex("FF86CF")
local VIP_TOP = Color3.fromHex("E3F0FF")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local ROW_EDGE = 12 -- design px inside the cards' row each side, for the cards' outlines and the short card's crown
local SCROLL_BAR = 8
local DROPS = 4 -- dirt levels (DirtRules): one mud drop each
local MUD = Color3.fromHex("9A6A3F")
local HEART_H = 24 -- design px: the heart bar's row
local BAR_PINK, BAR_GOLD, BAR_PEACH =
	Color3.fromHex("FF86B4"), Color3.fromHex("FFD84D"), Color3.fromHex("FFB38A")
local QUICK_TOP, QUICK_BOTTOM = Color3.fromHex("FFF4B8"), Color3.fromHex("FFD84D")
local SPECIAL_TOP = Color3.fromHex("F3E6FF")
local SPECIAL_INK = Color3.fromHex("7A3FC0")
local ONLY_H = 22 -- design px: the special card's "only you" line
local HEART_TICK = 0.5 -- seconds between heart bar redraws while the window is open
local SIDE_BY_SIDE_NEEDS = 3 -- most needs that fit beside the pay on a short card
local STACKED_SHIFT = 4 -- design px below the middle for the taller short window (Window's default is 33)
local NEED_ICON: { [string]: string } =
	{ mud = "Mud", tangles = "Tangles", wet = "Wet", smell = "Smell", claws = "Claws" }

-- Sizes in design pixels: full, then compact for a short screen (the picture beside the name).
local SIZES = {
	full = {
		band = 72,
		title = 38,
		badge = 96,
		pad = 22,
		headline = 30,
		headlineText = 22,
		room = 34, -- above the cards, for the crown and New!
		cardW = 204,
		gap = 14,
		inner = 10,
		tile = 132,
		chip = 28,
		name = 30,
		nameText = 26,
		need = 38,
		payH = 48,
		stackGap = 8,
		coin = 48,
		payText = 28,
		act = 60,
		actText = 26,
		crown = 44,
	},
	short = {
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		headline = 24,
		headlineText = 20,
		room = 10,
		cardW = 200,
		gap = 10,
		inner = 6,
		tile = 60,
		chip = 26,
		name = 28,
		nameText = 24,
		need = 32,
		payH = 40,
		stackGap = 6,
		coin = 32, -- the needs' size, so the needs and the pay share one row (Review-QA on #252)
		payText = 24,
		act = 60,
		actText = 24,
		crown = 32,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	headRow: Frame,
	headCrown: Frame,
	headText: TextLabel,
	row: ScrollingFrame,
	rowList: UIListLayout,
	rowPad: UIPadding,
}

local parts: Parts? = nil
local cards: { QueueViewRules.Card } = {}
local headline = "Pick a cat to wash"
local pickable: { [number]: boolean } = {}
local pickListeners: { (place: number) -> () } = {}

-- The heart bars on screen, redrawn each HEART_TICK while the window is open.
type Bar = { heart: HeartRules.Heart, fill: Frame, quick: GuiObject? }
local bars: { Bar } = {}

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
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

local CHIP_TEXT = 19
local CHIP_PAD = 10
local CHIP_TIGHT_PAD = 5 -- the chip's side room when even the smallest text needs more space
local CHIP_OUTLINE = 6 -- the outline's 3 px on each side of the words
local MIN_CHIP_TEXT = 14

-- How wide `text` draws at `size`, outline included, measured from the real font.
local function chipWords(text: string, size: number): number
	local bounds = TextService:GetTextSize(text, size, Kit.FONT, Vector2.new(10000, 1000))
	return math.ceil(bounds.X) + CHIP_OUTLINE
end

-- A rounded chip with outlined words: the rarity tag and New!. With `maxWidth` the words shrink (to the 14 px
-- floor) so the chip stays inside it, measured from the real font, and the side room tightens if the floor is still
-- too wide: "Uncommon" on a narrow card (issue 609; Sync's B5 found the old letter-width guess 7 px short).
local function chip(
	name: string,
	parent: Instance,
	fill: Color3,
	text: string,
	height: number,
	maxWidth: number?
): Frame
	local c = frame(name, parent)
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = fill
	c.AutomaticSize = Enum.AutomaticSize.X
	c.Size = UDim2.fromOffset(0, height)
	Kit.corner(c, UDim.new(0.5, 0))
	Kit.stroke(c, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, CHIP_PAD), UDim.new(0, CHIP_PAD)
	pad.Parent = c
	local label = Kit.outlined("Text", c)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromScale(0, 0.5)
	label.TextSize = CHIP_TEXT
	if maxWidth then
		local room = maxWidth - 2 * CHIP_PAD - 4
		local wants = chipWords(text, CHIP_TEXT)
		if wants > room then
			local size = math.max(MIN_CHIP_TEXT, math.floor(CHIP_TEXT * room / wants))
			label.TextSize = size
			if chipWords(text, size) > room then
				pad.PaddingLeft, pad.PaddingRight =
					UDim.new(0, CHIP_TIGHT_PAD), UDim.new(0, CHIP_TIGHT_PAD)
			end
		end
		local cap = Instance.new("UISizeConstraint")
		cap.MaxSize = Vector2.new(maxWidth, math.huge)
		cap.Parent = c
	end
	label.Text = text
	return c
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

local NEED_GAP = 5

-- The needs as round icons, left to right; a locked one is faded with a lock on its corner. Stacked over the pay,
-- they share the card's width: a cat with a smell and claws as well (#267) gets smaller dots, never a wider card.
local function drawNeeds(
	card: QueueViewRules.Card,
	parent: Instance,
	s: Sizes,
	stacked: boolean
): Frame
	local count = math.max(#card.needs, 1)
	local room = s.cardW - 2 * s.inner
	local size = if stacked
		then math.min(s.need, math.floor((room - (count - 1) * NEED_GAP) / count))
		else s.need
	local set = frame("Needs", parent)
	set.AutomaticSize = Enum.AutomaticSize.X
	set.Size = UDim2.fromOffset(0, size)
	local layout = list(set, true, NEED_GAP)
	layout.HorizontalAlignment = if stacked
		then Enum.HorizontalAlignment.Center
		else Enum.HorizontalAlignment.Left
	for index, need in card.needs do
		local dot = frame(`Need{index}`, set)
		dot.LayoutOrder = index
		dot.Size = UDim2.fromOffset(size, size)
		dot.BackgroundTransparency = 0
		dot.BackgroundColor3 = Kit.WHITE
		Kit.corner(dot, UDim.new(0.5, 0))
		local edge = Kit.stroke(dot, 2)
		edge.Color = Kit.LINE
		local box = frame("IconBox", dot)
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.fromScale(0.5, 0.5)
		box.Size = UDim2.fromScale(0.74, 0.74)
		local locked = card.locked[need] == true
		Icons.draw(NEED_ICON[need] or "Paw", box, locked)
		if locked then
			local lock = frame("Lock", dot)
			lock.AnchorPoint = Vector2.new(0.5, 0.5)
			lock.Position = UDim2.fromScale(0.85, 0.85)
			lock.Size = UDim2.fromScale(0.55, 0.55)
			lock.ZIndex = 2
			Icons.draw("Lock", lock)
		end
	end
	return set
end

-- The dirt row (dirtLevels): four mud drops with the level's filled, and the exact step count, since levels 2 and 3
-- look close at phone size (queue.html).
local function drawDirt(card: QueueViewRules.Card, parent: Instance, s: Sizes): Frame
	local level = card.dirt or 1
	local set = frame("Dirt", parent)
	set.Size = UDim2.new(1, 0, 0, s.need)
	set.BackgroundTransparency = 0
	set.BackgroundColor3 = Kit.CREAM
	Kit.corner(set, UDim.new(0, 12))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = set
	local drops = frame("Drops", set)
	drops.AnchorPoint = Vector2.new(0, 0.5)
	drops.Position = UDim2.fromScale(0, 0.5)
	drops.AutomaticSize = Enum.AutomaticSize.X
	local size = math.floor(s.need * 0.5)
	drops.Size = UDim2.fromOffset(0, size)
	list(drops, true, 4)
	for index = 1, DROPS do
		local drop = frame(`Drop{index}`, drops)
		drop.LayoutOrder = index
		drop.Size = UDim2.fromOffset(size, size)
		drop.BackgroundTransparency = 0
		drop.BackgroundColor3 = if index <= level then MUD else Kit.WHITE
		Kit.corner(drop, UDim.new(0.5, 0))
		Kit.stroke(drop, 2)
	end
	local steps = words("Steps", set, 19)
	steps.AnchorPoint = Vector2.new(1, 0.5)
	steps.Position = UDim2.fromScale(1, 0.5)
	steps.AutomaticSize = Enum.AutomaticSize.X
	steps.Size = UDim2.fromOffset(0, s.need)
	steps.Text = `{card.steps} steps`
	return set
end

-- How full a heart bar is now and its colour: gold while a pick still pays the quick bonus, peach once grumpy.
local function barLook(heart: HeartRules.Heart): (number, Color3, boolean)
	local fill = HeartRules.fill(heart, Workspace:GetServerTimeNow())
	local quick = fill >= 1 - HeartRules.EARLY_SHARE
	local colour = if quick
		then BAR_GOLD
		elseif fill <= HeartRules.GRUMPY_AT then BAR_PEACH
		else BAR_PINK
	return fill, colour, quick
end

-- The heart bar row (heartBar): a heart and the bar, no numbers and no warning words, with a tick at its first 10%.
local function drawHeart(heart: HeartRules.Heart, parent: Instance, order: number): Bar
	local holder = frame("Heart", parent)
	holder.LayoutOrder = order
	holder.Size = UDim2.new(1, 0, 0, HEART_H)
	local icon = frame("Icon", holder)
	icon.Size = UDim2.fromOffset(HEART_H, HEART_H)
	Icons.draw("Heart", icon)
	local bar = frame("Bar", holder)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, HEART_H + 6, 0.5, 0)
	bar.Size = UDim2.new(1, -(HEART_H + 6), 0, 14)
	bar.BackgroundTransparency = 0
	bar.BackgroundColor3 = Kit.WHITE
	Kit.corner(bar, UDim.new(0.5, 0))
	Kit.stroke(bar, 2)
	local fill = frame("Fill", bar)
	fill.BackgroundTransparency = 0
	Kit.corner(fill, UDim.new(0.5, 0))
	local tick = frame("QuickTick", bar)
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromScale(1 - HeartRules.EARLY_SHARE, 0.5)
	tick.Size = UDim2.new(0, 3, 1, 4)
	tick.BackgroundTransparency = 0.45
	tick.BackgroundColor3 = Kit.INK
	tick.ZIndex = 2
	return { heart = heart, fill = fill, quick = nil }
end

-- The "Quick bonus" tag on the picture while a pick still pays it. On a short card there is no room by the picture,
-- so a shorter "Quick!" sits at the left of the pay row (the pay moves to the right).
local function quickTag(parent: Instance, short: boolean, payH: number): Frame
	local tag = frame("Quick", parent)
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, 26)
	tag.AnchorPoint = if short then Vector2.new(0, 0.5) else Vector2.new(1, 0.5)
	tag.Position = if short then UDim2.new(0, 0, 1, -payH / 2) else UDim2.new(1, 9, 0, 2)
	tag.Rotation = if short then -4 else 8
	tag.ZIndex = 4
	tag.BackgroundTransparency = 0
	tag.BackgroundColor3 = Kit.WHITE
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new(QUICK_TOP, QUICK_BOTTOM)
	tint.Parent = tag
	Kit.corner(tag, UDim.new(0, 12))
	Kit.stroke(tag, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = tag
	local say = words("Say", tag, 19)
	say.AutomaticSize = Enum.AutomaticSize.X
	say.Size = UDim2.fromOffset(0, 26)
	say.TextColor3 = Color3.fromHex("3A2A00")
	say.Text = if short then "Quick!" else "Quick bonus"
	return tag
end

local function showBar(entry: Bar)
	local fill, colour, quick = barLook(entry.heart)
	entry.fill.Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1)
	entry.fill.BackgroundColor3 = colour
	local tag = entry.quick
	if tag then
		tag.Visible = quick
	end
end

-- Draws one customer's card in `row` and returns its height. `stacked` puts the needs over the pay: always on a
-- tall screen, and on a short one when some cat in the line has more needs than fit beside the pay.
local function drawCard(
	card: QueueViewRules.Card,
	row: GuiObject,
	s: Sizes,
	short: boolean,
	stacked: boolean
): number
	local whoW = if short then s.cardW - 2 * s.inner - s.tile - 10 else s.cardW - 2 * s.inner
	local headH = if short then s.tile else s.tile + 6 + s.chip + 4 + s.name
	local infoH = if stacked then s.need + 6 + s.payH else s.payH
	local heart = card.heart
	local cardH = 2 * s.inner
		+ headH
		+ infoH
		+ s.act
		+ 2 * s.stackGap
		+ (if heart then HEART_H + s.stackGap else 0)
		+ (if card.special then ONLY_H + s.stackGap else 0)

	local box = frame(`Customer{card.place}`, row)
	box.LayoutOrder = card.place
	box.Size = UDim2.fromOffset(s.cardW, cardH)
	box.BackgroundTransparency = 0
	box.BackgroundColor3 = Kit.WHITE
	Kit.corner(box, UDim.new(0, 18))
	local glows = card.vip or card.special
	local edge = Kit.stroke(box, if glows then 4 else 3)
	edge.Color = if glows then Kit.RARITY[card.rarity] or Kit.LINE else Kit.LINE
	-- a special visitor's cat: lilac with the Special gold rim (Kit.RARITY_RIM), so it never reads as an Epic VIP
	if card.special then
		Kit.rim(box, CatRules.SPECIAL, edge.Color)
	end
	if glows then
		local glow = Instance.new("UIGradient")
		glow.Rotation = 90
		glow.Color = ColorSequence.new(if card.special then SPECIAL_TOP else VIP_TOP, Kit.WHITE)
		glow.Parent = box
	end
	local pad = Instance.new("UIPadding")
	local inner = UDim.new(0, s.inner)
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom =
		inner, inner, inner, inner
	pad.Parent = box
	local stack = list(box, false, s.stackGap)
	stack.VerticalAlignment = Enum.VerticalAlignment.Top

	-- The picture with the name and rarity: stacked on a tall screen, side by side on a short one.
	local head = frame("Head", box)
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, headH)
	local headList = list(head, short, if short then 10 else 6)
	headList.VerticalAlignment = Enum.VerticalAlignment.Top
	if short then
		headList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
	local pic = frame("Pic", head)
	pic.LayoutOrder = 1
	pic.Size = UDim2.fromOffset(s.tile, s.tile)
	Portraits.draw(card.cat, card.rarity, pic)
	if card.isNew then
		-- on the card's top left corner, clear of the crown
		local left = if short then 10 else (s.cardW - 2 * s.inner - s.tile) / 2 + 8
		local new = chip("New", pic, NEW_PINK, "New!", 26)
		new.AnchorPoint = Vector2.new(0, 0.5)
		new.Position = UDim2.fromOffset(-left, 0)
		new.Rotation = -8
		new.ZIndex = 3
	end
	if card.vip and not short then
		-- the crown sits over the card's top edge, centred (the cards row leaves room above)
		local crown = frame("Crown", pic)
		crown.Size = UDim2.fromOffset(s.crown, s.crown)
		crown.ZIndex = 3
		crown.AnchorPoint = Vector2.new(0.5, 1)
		crown.Position = UDim2.new(0.5, 0, 0, 14)
		Icons.draw("Crown", crown)
	end
	local who = frame("Who", head)
	who.LayoutOrder = 2
	who.Size = UDim2.fromOffset(whoW, if short then s.tile else s.chip + 4 + s.name)
	local whoList = list(who, false, 4)
	if short then
		whoList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
	-- the shared pill, measured with its outline so the words stay inside it and the card (issue 609)
	local rarityChip = Kit.rarityChip(who, card.rarity, s.chip, 1, whoW)
	rarityChip.LayoutOrder = if short then 2 else 1
	local name = words("Name", who, s.nameText)
	name.LayoutOrder = if short then 1 else 2
	name.Size = UDim2.fromOffset(whoW, s.name)
	name.Text = card.cat
	name.TextXAlignment = if short then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	Kit.shrinkToFit(name, s.nameText)

	-- What the cat needs and what it pays: stacked on a tall screen, one row on a short one.
	if card.special then
		-- one plain line: workers never take a special visitor's cat (SpecialRules)
		local only = words("Only", box, 19)
		only.LayoutOrder = 2
		only.FontFace = Kit.BODY_FACE
		only.TextColor3 = SPECIAL_INK
		only.Size = UDim2.new(1, 0, 0, ONLY_H)
		only.Text = "Only you can wash"
		Kit.shrinkToFit(only, 19)
	end

	local info = frame("Info", box)
	info.LayoutOrder = 3
	info.Size = UDim2.new(1, 0, 0, infoH)
	local needs = if card.dirt then drawDirt(card, info, s) else drawNeeds(card, info, s, stacked)
	if card.vip and short then
		-- on a short card the crown tips over the card's top right corner, clear of New! on the picture's top left
		-- (Review-QA on #252). Info has no layout, so it is placed from there.
		local crown = frame("Crown", info)
		crown.Size = UDim2.fromOffset(s.crown, s.crown)
		crown.ZIndex = 3
		crown.AnchorPoint = Vector2.new(0.5, 0.5)
		crown.Position = UDim2.new(1, s.inner - 4, 0, -(headH + s.stackGap + s.inner) + 4)
		crown.Rotation = 14
		Icons.draw("Crown", crown)
	end
	local pay = frame("Pay", info)
	pay.AutomaticSize = Enum.AutomaticSize.X
	pay.Size = UDim2.fromOffset(0, s.payH)
	list(pay, true, 6)
	if not stacked then
		needs.AnchorPoint = Vector2.new(0, 0.5)
		needs.Position = UDim2.fromScale(0, 0.5)
		pay.AnchorPoint = Vector2.new(1, 0.5)
		pay.Position = UDim2.fromScale(1, 0.5)
	else
		needs.AnchorPoint = Vector2.new(0.5, 0)
		needs.Position = UDim2.fromScale(0.5, 0)
		-- a short card with a heart bar keeps the pay row's left for the "Quick!" tag
		local right = short and heart ~= nil
		pay.AnchorPoint = Vector2.new(if right then 1 else 0.5, 1)
		pay.Position = UDim2.fromScale(if right then 1 else 0.5, 1)
	end
	if not short then
		local say = words("Say", pay, 20)
		say.LayoutOrder = 1
		say.FontFace = Kit.BODY_FACE
		say.TextColor3 = Kit.INK_SOFT
		say.AutomaticSize = Enum.AutomaticSize.X
		say.Size = UDim2.fromOffset(0, s.payH)
		say.Text = "Pays"
	end
	local coin = frame("CoinIcon", pay)
	coin.LayoutOrder = 2
	coin.Size = UDim2.fromOffset(s.coin, s.coin)
	Icons.draw("Coins", coin)
	local amount = words("Amount", pay, s.payText)
	amount.LayoutOrder = 3
	amount.TextColor3 = Kit.GOLD_INK
	amount.AutomaticSize = Enum.AutomaticSize.X
	amount.Size = UDim2.fromOffset(0, s.payH)
	-- with the heart bar on, the pay is the base: speed, the quick bonus and dirt add on top (the recap shows each)
	amount.Text = if heart then `{card.pays}+` else tostring(card.pays)

	if heart then
		local entry = drawHeart(heart, box, 4)
		entry.quick = quickTag(if short then info else pic, short, s.payH)
		showBar(entry)
		table.insert(bars, entry)
	end

	-- Wash next, or what the card is waiting for.
	local act: GuiObject
	if pickable[card.place] then
		local button = Window.button("Wash", "Wash next", box, GREEN_TOP, GREEN_BOTTOM)
		button.TextSize = s.actText
		button.Activated:Connect(function()
			for _, listener in pickListeners do
				task.spawn(listener, card.place)
			end
		end)
		act = button
	else
		local say = words("Waiting", box, s.actText)
		say.BackgroundTransparency = 0
		say.BackgroundColor3 = if card.place == 1 then Color3.fromHex("DFF6E8") else Kit.CREAM
		Kit.corner(say, UDim.new(0, 14))
		local line = Kit.stroke(say, 2)
		line.Color = Kit.LINE
		say.Text = if card.place == 1 then "Up next" else "Waiting"
		act = say
	end
	act.LayoutOrder = 5
	act.Size = UDim2.new(1, 0, 0, s.act)
	return cardH
end

local function clearRow(row: GuiObject)
	for _, child in row:GetChildren() do
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
	-- the line is 3 long at first and grows to 6 with more tubs (benchGrow): the window widens to fit, and past
	-- the screen's width the cards scroll sideways
	local count = math.max(#cards, SpaRules.QUEUE_SIZE)
	local content = count * s.cardW + (count - 1) * s.gap + 2 * ROW_EDGE
	local width = math.min(content + 2 * s.pad, screenWidth(scale) - SCREEN_MARGIN)
	local scrolls = content > width - 2 * s.pad
	local most = 0
	for _, card in cards do
		most = math.max(most, #card.needs)
	end
	local dirty, tall = false, false
	for _, card in cards do
		dirty = dirty or card.dirt ~= nil
		-- a heart bar or a special card's line makes the cards taller: the window sits higher to keep its bottom on
		tall = tall or card.heart ~= nil or card.special
	end
	-- the dirt row is too wide to sit beside the pay on a short card
	local stacked = not short or most > SIDE_BY_SIDE_NEEDS or dirty
	-- a short screen with the needs stacked over the pay: the card sits higher, so its bottom stays on screen
	Window.fit(
		p.window,
		width,
		s.band,
		s.title,
		s.badge,
		if (short and stacked) or tall then STACKED_SHIFT else nil
	)
	p.pad.PaddingLeft, p.pad.PaddingRight = UDim.new(0, s.pad), UDim.new(0, s.pad)
	p.pad.PaddingTop, p.pad.PaddingBottom = UDim.new(0, s.pad - 8), UDim.new(0, s.pad - 2)

	p.headRow.Size = UDim2.new(1, 0, 0, s.headline)
	local vip = false
	for _, card in cards do
		vip = vip or card.vip
	end
	p.headCrown.Visible = vip
	p.headCrown.Size = UDim2.fromOffset(s.headline, s.headline)
	p.headText.TextSize = s.headlineText
	p.headText.Size = UDim2.fromOffset(0, s.headline)
	p.headText.Text = if #cards == 0 then "No one is waiting yet" else headline

	p.rowList.Padding = UDim.new(0, s.gap)
	clearRow(p.row)
	table.clear(bars)
	local tallest = 0
	for _, card in cards do
		tallest = math.max(tallest, drawCard(card, p.row, s, short, stacked))
	end
	local bar = if scrolls then SCROLL_BAR + 4 else 0
	p.row.Size = UDim2.new(1, 0, 0, tallest + s.room + 4 + bar)
	p.row.CanvasSize = UDim2.fromOffset(if scrolls then content else 0, 0)
	p.row.ScrollBarThickness = if scrolls then SCROLL_BAR else 0
	p.rowList.HorizontalAlignment = if scrolls
		then Enum.HorizontalAlignment.Left
		else Enum.HorizontalAlignment.Center
	p.rowPad.PaddingTop = UDim.new(0, s.room)
end

function QueueWindow.set(
	newCards: { QueueViewRules.Card },
	newHeadline: string,
	newPickable: { [number]: boolean }
)
	cards, headline, pickable = newCards, newHeadline, newPickable
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function QueueWindow.onPick(fn: (place: number) -> ())
	table.insert(pickListeners, fn)
end

function QueueWindow.build(root: Instance): Frame
	local window = Window.new("Queue", "Who's next?", "Paw", root)
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
	local stack = frame("Stack", window.body)
	stack.Size = UDim2.fromScale(1, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	local stackList = list(stack, false, 2)
	stackList.VerticalAlignment = Enum.VerticalAlignment.Top

	-- "Pick a cat to wash", or how often the VIP waiting visits.
	local headRow = frame("Headline", stack)
	headRow.LayoutOrder = 1
	list(headRow, true, 6)
	local headCrown = frame("Crown", headRow)
	headCrown.LayoutOrder = 1
	Icons.draw("Crown", headCrown)
	local headText = words("Say", headRow, 22)
	headText.LayoutOrder = 2
	headText.AutomaticSize = Enum.AutomaticSize.X

	local row = Instance.new("ScrollingFrame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.ScrollBarImageColor3 = Kit.INK_SOFT
	row.VerticalScrollBarInset = Enum.ScrollBarInset.None
	row.Parent = stack
	row.LayoutOrder = 2
	local rowList = list(row, true, 14)
	rowList.VerticalAlignment = Enum.VerticalAlignment.Top
	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingLeft, rowPad.PaddingRight = UDim.new(0, ROW_EDGE), UDim.new(0, ROW_EDGE)
	rowPad.Parent = row

	parts = {
		window = window,
		pad = pad,
		headRow = headRow,
		headCrown = headCrown,
		headText = headText,
		row = row,
		rowList = rowList,
		rowPad = rowPad,
	}
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. QueueWindow.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(QueueWindow.FLAG) then
				window.layer.Visible = false
			end
		end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	-- the heart bars drain while the window is open
	task.spawn(function()
		while true do
			task.wait(HEART_TICK)
			if window.layer.Visible then
				for _, entry in bars do
					showBar(entry)
				end
			end
		end
	end)
	redraw()
	return window.layer
end

return QueueWindow
