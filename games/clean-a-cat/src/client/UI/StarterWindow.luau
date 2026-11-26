--!strict
-- StarterWindow: the Spa Starter Pack (issue 519), from Design-Agent's starterpack.html "bundle" state. Behind the live
-- switch starterPack (with passes on too, since the pack gives passes). It opens only when the player taps the HUD's
-- Starter button, never by itself.
--
--   StarterWindow.build(root)                        makes the window once and returns its layer ("Starter")
--   StarterWindow.set(items, pack, endsAt)           the three cards (StarterViewRules.items), the pack's price or
--                                                    nil, and the server's end time (os.time) for the clock
--   StarterWindow.onBuy(fn)                          fn() when Get pack is pressed
--
-- Three item cards joined by plus signs, each with its own shop price; the total struck through and the saving, both
-- from the live prices and left out if any price is missing; one green Get pack button with the pack's price, shown
-- before Roblox's own prompt; "Nothing random. All three are yours to keep." The clock in the title band ticks
-- seconds only while the window is open, and nothing changes near the end: no red, no flash. UI never fires remotes:
-- StarterController asks the server, which opens Roblox's prompt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local StarterRules = require(Shared:WaitForChild("StarterRules"))
local StarterViewRules = require(Shared:WaitForChild("StarterViewRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local StarterWindow = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local PLUS_TOP, PLUS_BOTTOM = Color3.fromHex("FFE98F"), Color3.fromHex("FFC94D")
local SAVE_TOP, SAVE_BOTTOM = Color3.fromHex("FFF4B8"), Color3.fromHex("FFD84D")
local STRIKE = "#E0475B"
local PIC_FILLS: { [string]: { Color3 } } = {
	GoldenSponge = { Color3.fromHex("C9F5E5"), Color3.fromHex("A8E6CF") },
	SecondPetSlot = { Color3.fromHex("FFD3DF"), Color3.fromHex("FFB3C7") },
	DoubleCoins = { Color3.fromHex("FFE98F"), Color3.fromHex("FFD35E") },
}
local BADGE_PINK, BADGE_GREEN = Color3.fromHex("FF86B0"), Color3.fromHex("3FB071")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 8
local CLOSE_ROOM = 84 -- design px at the band's right for the X
local MIN_TAP = 44 -- real px

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 900,
		band = 72,
		title = 34,
		badge = 96,
		pad = 18,
		gap = 14,
		itemW = 230,
		picH = 160,
		picIcon = 104,
		tag = 30,
		name = 24,
		what = 16,
		each = 20,
		plus = 52,
		buyH = 80,
		buyText = 34,
		was = 26,
		save = 20,
		fine = 16,
		timer = 20,
	},
	short = {
		width = 760,
		band = 56,
		title = 28,
		badge = 80,
		pad = 10,
		gap = 10,
		itemW = 196,
		picH = 104,
		picIcon = 70,
		tag = 24,
		name = 21,
		what = 0, -- no "what" line on a short screen
		each = 19,
		plus = 44,
		buyH = 64,
		buyText = 28,
		was = 22,
		save = 17,
		fine = 0,
		timer = 18,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	stack: UIListLayout,
	items: Frame,
	buyRow: Frame,
	was: TextLabel,
	buy: TextButton,
	save: Frame,
	saveLabel: TextLabel,
	fine: TextLabel,
	timer: TextLabel,
}

local parts: Parts? = nil
local items: { StarterViewRules.Item } = {}
local pack: number? = nil
local endsAt: number? = nil
local buyListeners: { () -> () } = {}

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

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

local function clear(holder: Instance)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function drawItem(
	item: StarterViewRules.Item,
	order: number,
	s: Sizes,
	width: number,
	parent: Frame
)
	local card = frame(item.key, parent)
	card.LayoutOrder = order
	card.Size = UDim2.fromOffset(width, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundTransparency = 0
	card.BackgroundColor3 = Kit.WHITE
	Kit.corner(card, UDim.new(0, 18))
	Kit.stroke(card, 4)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 10)
	pad.Parent = card
	local column = list(card, false, 4)
	column.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local pic = frame("Pic", card)
	pic.LayoutOrder = 1
	pic.Size = UDim2.new(1, 0, 0, s.picH)
	pic.BackgroundTransparency = 0
	pic.BackgroundColor3 = Kit.WHITE
	local fills = PIC_FILLS[item.key] or { Kit.CREAM, Kit.CREAM }
	gradient(pic, fills[1], fills[2])
	Kit.corner(pic, UDim.new(0, 16))
	Kit.stroke(pic, 3)
	local icon = frame("Icon", pic)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(s.picIcon, s.picIcon)
	Icons.draw(item.icon, icon)
	local badge = item.badge
	if badge then
		local tag = frame("Tag", pic)
		tag.AnchorPoint = Vector2.new(1, 1)
		tag.Position = UDim2.new(1, -12, 1, -10)
		tag.AutomaticSize = Enum.AutomaticSize.X
		tag.Size = UDim2.fromOffset(0, s.tag + 8)
		tag.Rotation = -8
		tag.BackgroundTransparency = 0
		tag.BackgroundColor3 = if badge == "+1" then BADGE_GREEN else BADGE_PINK
		tag.ZIndex = 3
		Kit.corner(tag, UDim.new(0, 12))
		local ring = Kit.stroke(tag, 3)
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local tagPad = Instance.new("UIPadding")
		tagPad.PaddingLeft, tagPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		tagPad.Parent = tag
		local label = Kit.outlined("Text", tag)
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.fromScale(0, 0.5)
		label.TextSize = s.tag
		label.ZIndex = 3
		label.Text = badge
	end

	local name = words("Name", card, s.name)
	name.LayoutOrder = 2
	name.Size = UDim2.new(1, 0, 0, s.name + 4)
	Kit.shrinkToFit(name, s.name)
	name.Text = item.name
	if s.what > 0 then
		local what = words("What", card, s.what)
		what.LayoutOrder = 3
		what.FontFace = Kit.BODY_FACE
		what.TextColor3 = Kit.INK_SOFT
		what.TextWrapped = true
		what.Size = UDim2.new(1, 0, 0, s.what * 2 + 4)
		what.Text = item.what
	end
	local price = item.price
	if price then
		local each = words("Each", card, s.each)
		each.LayoutOrder = 4
		each.TextColor3 = Kit.INK_SOFT
		each.Size = UDim2.new(1, 0, 0, s.each + 4)
		each.Text = `{price} Robux`
	end
end

local function drawPlus(order: number, s: Sizes, parent: Frame)
	local plus = frame(`Plus{order}`, parent)
	plus.LayoutOrder = order
	plus.Size = UDim2.fromOffset(s.plus, s.plus)
	plus.BackgroundTransparency = 0
	plus.BackgroundColor3 = Kit.WHITE
	gradient(plus, PLUS_TOP, PLUS_BOTTOM)
	Kit.corner(plus, UDim.new(0.5, 0))
	Kit.stroke(plus, 4)
	local mark = Kit.outlined("Mark", plus)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.TextSize = math.floor(s.plus * 0.7)
	mark.Text = "+"
end

local function tick()
	local p = parts
	local ends = endsAt
	if p == nil then
		return
	end
	p.timer.Visible = ends ~= nil
	if ends then
		p.timer.Text = StarterViewRules.windowText(StarterViewRules.left(ends, os.time()))
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
		pad, pad, UDim.new(0, s.pad + 4), pad
	p.stack.Padding = UDim.new(0, s.gap)
	p.timer.TextSize = s.timer
	p.timer.Size = UDim2.fromOffset(0, s.timer + 8)
	p.timer.Position = UDim2.new(1, -CLOSE_ROOM, 0.5, 0)

	-- the three cards with plus signs between them, fitted to the window
	clear(p.items)
	local inner = width - 2 * s.pad
	local itemW = math.min(s.itemW, math.floor((inner - 2 * s.plus - 4 * 10) / 3))
	for index, item in items do
		if index > 1 then
			drawPlus(index * 2 - 1, s, p.items)
		end
		drawItem(item, index * 2, s, itemW, p.items)
	end

	-- the struck total, Get pack and the saving: the saving only when every price is known and it is real
	local total, percent = StarterViewRules.saving(items, pack)
	p.was.Visible = total ~= nil
	p.was.TextSize = s.was
	p.was.Size = UDim2.fromOffset(0, s.buyH)
	p.was.Text = if total then `<s><font color="{STRIKE}">{total} Robux</font></s>` else ""
	local price = pack
	p.buy.Visible = price ~= nil
	p.buy.Text = if price then StarterViewRules.buyText(price) else ""
	p.buy.TextSize = s.buyText
	p.buy.Size = UDim2.fromOffset(0, math.max(s.buyH, math.ceil(MIN_TAP / scale)))
	p.save.Visible = percent ~= nil
	p.saveLabel.TextSize = s.save
	p.saveLabel.Text = if percent then StarterViewRules.saveText(percent) else ""
	p.save.Size = UDim2.fromOffset(0, s.save + 10)
	p.buyRow.Size = UDim2.new(1, 0, 0, s.buyH + 8)

	p.fine.Visible = s.fine > 0
	p.fine.TextSize = math.max(s.fine, 14)
	p.fine.Size = UDim2.new(1, 0, 0, s.fine + 6)
	tick()
end

function StarterWindow.set(
	newItems: { StarterViewRules.Item },
	newPack: number?,
	newEndsAt: number?
)
	items, pack, endsAt = newItems, newPack, newEndsAt
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function StarterWindow.onBuy(fn: () -> ())
	table.insert(buyListeners, fn)
end

function StarterWindow.build(root: Instance): Frame
	local window = Window.new(StarterViewRules.WINDOW, StarterViewRules.TITLE, "Gift", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)

	-- the clock in the title band, right of the title: seconds tick only while the window is open
	local timer = words("Timer", window.band, 20)
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.AutomaticSize = Enum.AutomaticSize.X
	timer.BackgroundTransparency = 0
	timer.BackgroundColor3 = Kit.WHITE
	Kit.corner(timer, UDim.new(0, 12))
	local timerEdge = Kit.stroke(timer, 3)
	timerEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	timerEdge.Color = Kit.LINE
	local timerPad = Instance.new("UIPadding")
	timerPad.PaddingLeft, timerPad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	timerPad.Parent = timer

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local stack = list(window.body, false, 14)
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local itemRow = frame("Items", window.body)
	itemRow.LayoutOrder = 1
	itemRow.AutomaticSize = Enum.AutomaticSize.XY
	local itemList = list(itemRow, true, 10)
	itemList.VerticalAlignment = Enum.VerticalAlignment.Center

	local buyRow = frame("BuyRow", window.body)
	buyRow.LayoutOrder = 2
	local buyList = list(buyRow, true, 16)
	buyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buyList.VerticalAlignment = Enum.VerticalAlignment.Center
	local was = words("Was", buyRow, 26)
	was.LayoutOrder = 1
	was.RichText = true
	was.TextColor3 = Kit.INK_SOFT
	was.AutomaticSize = Enum.AutomaticSize.X
	local buy = Window.button("Buy", "", buyRow, GREEN_TOP, GREEN_BOTTOM)
	buy.LayoutOrder = 2
	buy.AutomaticSize = Enum.AutomaticSize.X
	local buyPad = Instance.new("UIPadding")
	buyPad.PaddingLeft, buyPad.PaddingRight = UDim.new(0, 30), UDim.new(0, 30)
	buyPad.Parent = buy
	buy.Activated:Connect(function()
		if pack == nil then
			return
		end
		window.layer.Visible = false
		for _, listener in buyListeners do
			task.spawn(listener)
		end
	end)
	local save = frame("Save", buyRow)
	save.LayoutOrder = 3
	save.AutomaticSize = Enum.AutomaticSize.X
	save.Rotation = 6
	save.BackgroundTransparency = 0
	save.BackgroundColor3 = Kit.WHITE
	gradient(save, SAVE_TOP, SAVE_BOTTOM)
	Kit.corner(save, UDim.new(0, 12))
	local saveEdge = Kit.stroke(save, 3)
	saveEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local savePad = Instance.new("UIPadding")
	savePad.PaddingLeft, savePad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	savePad.Parent = save
	local saveLabel = words("Text", save, 20)
	saveLabel.AutomaticSize = Enum.AutomaticSize.X
	saveLabel.Size = UDim2.fromScale(0, 1)

	local fine = words("Fine", window.body, 16)
	fine.LayoutOrder = 3
	fine.FontFace = Kit.BODY_FACE
	fine.TextColor3 = Kit.INK_SOFT
	fine.Text = StarterViewRules.FINE

	parts = {
		window = window,
		pad = pad,
		stack = stack,
		items = itemRow,
		buyRow = buyRow,
		was = was,
		buy = buy,
		save = save,
		saveLabel = saveLabel,
		fine = fine,
		timer = timer,
	}
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
			-- the window's clock ticks each second while it is open, and stops when it closes
			task.spawn(function()
				while window.layer.Visible do
					tick()
					task.wait(1)
				end
			end)
		end
	end)
	for _, flag in { StarterRules.FLAG, "passes" } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				if not LiveFlags.isOn(flag) then
					window.layer.Visible = false
				end
			end)
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

return StarterWindow
