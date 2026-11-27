--!strict
-- ShopWindow: the shop (issue 518 and 526 item 8), from Design-Agent's shop.html "passes" page. Behind the live switch
-- passes, off by default, the same switch as PassService on the server. Opened only from its HUD button, never by
-- itself.
--
--   ShopWindow.build(root)       makes the window once and returns its layer (UI registers "Shop")
--   ShopWindow.set(cards)        draws the pass cards (ShopViewRules.cards)
--   ShopWindow.onBuy(fn)         fn(key) when a pass's price button is pressed
--
-- One card per game pass: its picture, name, what it does in plain words and its real Robux price on the button,
-- shown before Roblox's own prompt opens. An owned pass says Owned and has no button. No coins are sold and nothing
-- says "hurry". The Crates and Starter Pack pages join when bought crates (issue 514) and the starter pack (issue
-- 519) land. UI never fires remotes: ShopController asks the server, which opens Roblox's prompt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local ShopViewRules = require(Shared:WaitForChild("ShopViewRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local ShopWindow = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local PIC_TOP, PIC_BOTTOM = Color3.fromHex("FFF6D6"), Color3.fromHex("FFE7A8")
local BADGE_PINK = Color3.fromHex("FF7EB0")
local OWNED_GREEN = Color3.fromHex("2F9A63")
local SALE_RED = Color3.fromHex("E83A3A") -- the launch sale's tag (issue 1032)
local STRUCK = "#DFFFD2" -- the struck regular price on the green button: pale, so the sale price reads first
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 8 -- design px below the middle on a short screen (Window's default is 33)
local MIN_TAP = 44 -- real px

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 1080,
		band = 72,
		title = 38,
		badge = 96,
		pad = 20,
		gap = 12,
		cardH = 300,
		pic = 96,
		picIcon = 58,
		tag = 20,
		name = 21,
		text = 16,
		textLines = 3,
		buy = 52,
		buyText = 22,
	},
	short = {
		width = 980,
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		gap = 8,
		cardH = 276, -- three full lines of words on a phone (Sync's B6: 250 cut the last word)
		pic = 64,
		picIcon = 40,
		tag = 17,
		name = 19,
		text = 15,
		textLines = 3,
		buy = 52,
		buyText = 20,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	grid: Frame,
	gridLayout: UIListLayout,
	empty: TextLabel,
}

local parts: Parts? = nil
local cards: { ShopViewRules.Card } = {}
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

local function tapSize(size: number): number
	local scale = Kit.screenScale()
	return math.max(size, math.ceil(MIN_TAP / scale))
end

local function drawCard(
	card: ShopViewRules.Card,
	order: number,
	s: Sizes,
	width: number,
	parent: Frame
)
	local c = frame(card.key, parent)
	c.LayoutOrder = order
	c.Size = UDim2.fromOffset(width, s.cardH)
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = Kit.WHITE
	Kit.corner(c, UDim.new(0, 18))
	local edge = Kit.stroke(c, 3)
	edge.Color = Kit.line()
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 10)
	pad.Parent = c
	local column = list(c, false, 6)
	column.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- the picture on a warm tile, with its x2 or +1 tag
	local pic = frame("Pic", c)
	pic.LayoutOrder = 1
	pic.Size = UDim2.fromOffset(s.pic, s.pic)
	pic.BackgroundTransparency = 0
	pic.BackgroundColor3 = Kit.WHITE
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new(PIC_TOP, PIC_BOTTOM)
	tint.Parent = pic
	Kit.corner(pic, UDim.new(0, 20))
	Kit.stroke(pic, 3)
	local icon = frame("Icon", pic)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(s.picIcon, s.picIcon)
	Icons.draw(card.icon, icon)
	local badge = card.badge
	if badge then
		local tag = frame("Tag", pic)
		tag.AnchorPoint = Vector2.new(1, 1)
		tag.Position = UDim2.new(1, 8, 1, 8)
		tag.AutomaticSize = Enum.AutomaticSize.X
		tag.Size = UDim2.fromOffset(0, s.tag + 8)
		tag.BackgroundTransparency = 0
		tag.BackgroundColor3 = BADGE_PINK
		tag.ZIndex = 3
		Kit.corner(tag, UDim.new(0, 10))
		local ring = Kit.stroke(tag, 3)
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local tagPad = Instance.new("UIPadding")
		tagPad.PaddingLeft, tagPad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
		tagPad.Parent = tag
		local label = Kit.outlined("Text", tag)
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.fromScale(0, 0.5)
		label.TextSize = s.tag
		label.ZIndex = 3
		label.Text = badge
	end

	local name = words("Name", c, s.name)
	name.LayoutOrder = 2
	name.Size = UDim2.new(1, 0, 0, s.name + 6)
	Kit.shrinkToFit(name, s.name)
	name.Text = card.name

	local what = words("What", c, s.text)
	what.LayoutOrder = 3
	what.FontFace = Kit.BODY_FACE
	what.TextColor3 = Kit.INK_SOFT
	what.TextWrapped = true
	what.TextYAlignment = Enum.TextYAlignment.Top
	local buyH = tapSize(s.buy)
	-- the words take what is left between the name and the button
	what.Size = UDim2.new(1, 0, 0, s.cardH - 22 - s.pic - (s.name + 6) - buyH - 18)
	what.Text = card.text

	if card.owned then
		local owned = frame("Owned", c)
		owned.LayoutOrder = 4
		owned.Size = UDim2.new(1, 0, 0, buyH)
		local ownedList = list(owned, true, 6)
		ownedList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ownedList.VerticalAlignment = Enum.VerticalAlignment.Center
		local tick = frame("Tick", owned)
		tick.LayoutOrder = 1
		tick.Size = UDim2.fromOffset(s.buyText + 6, s.buyText + 6)
		Icons.draw("Check", tick)
		local label = words("Label", owned, s.buyText)
		label.LayoutOrder = 2
		label.TextColor3 = OWNED_GREEN
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, buyH)
		label.Text = "Owned"
	else
		local buy =
			Window.button("Buy", ShopViewRules.priceText(card.price), c, GREEN_TOP, GREEN_BOTTOM)
		buy.LayoutOrder = 4
		buy.Size = UDim2.new(1, 0, 0, buyH)
		buy.TextSize = s.buyText
		buy:SetAttribute("Says", `Buy {card.name} for {card.price} Robux`)
		local was = card.was
		if was then
			-- launchSale (issue 1032, Derek: "the classic redline cut through old pricing with the new pricing there"):
			-- the true regular price struck through before the sale price, and a red tag on the picture
			buy.RichText = true
			buy.Text =
				`<font color="{STRUCK}"><s>{was}</s></font> {ShopViewRules.priceText(card.price)}`
			buy:SetAttribute("Says", `Buy {card.name} for {card.price} Robux, was {was}`)
			buy.TextSize = s.buyText - 2 -- two prices on one button
			local sale = frame("Sale", pic)
			sale.AnchorPoint = Vector2.new(0, 0)
			sale.Position = UDim2.fromOffset(-8, -8)
			sale.AutomaticSize = Enum.AutomaticSize.X
			sale.Size = UDim2.fromOffset(0, s.tag + 8)
			sale.BackgroundTransparency = 0
			sale.BackgroundColor3 = SALE_RED
			sale.ZIndex = 3
			Kit.corner(sale, UDim.new(0, 10))
			Kit.stroke(sale, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local salePad = Instance.new("UIPadding")
			salePad.PaddingLeft, salePad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
			salePad.Parent = sale
			local saleText = Kit.outlined("Text", sale)
			saleText.AnchorPoint = Vector2.new(0, 0.5)
			saleText.Position = UDim2.fromScale(0, 0.5)
			saleText.TextSize = s.tag
			saleText.ZIndex = 3
			saleText.Text = "50% off"
		end
		local key = card.key
		buy.Activated:Connect(function()
			for _, listener in buyListeners do
				task.spawn(listener, key)
			end
		end)
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

	for _, child in p.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local columns = Passes.SHOP_CARDS -- 2x and 3x Coins never show together (Passes.offered, issue 1031)
	local cardW = math.floor((width - 2 * s.pad - (columns - 1) * s.gap) / columns)
	p.gridLayout.Padding = UDim.new(0, s.gap)
	p.grid.Size = UDim2.new(1, 0, 0, s.cardH + 10) -- the tags hang 8 px out of the pictures
	for index, card in cards do
		drawCard(card, index, s, cardW, p.grid)
	end
	p.grid.Visible = #cards > 0
	p.empty.Visible = #cards == 0
	p.empty.TextSize = s.name
	p.empty.Size = UDim2.new(1, 0, 0, s.cardH // 2)
	p.empty.Text = ShopViewRules.EMPTY
end

function ShopWindow.set(newCards: { ShopViewRules.Card })
	cards = newCards
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function ShopWindow.onBuy(fn: (key: string) -> ())
	table.insert(buyListeners, fn)
end

function ShopWindow.build(root: Instance): Frame
	local window = Window.new(ShopViewRules.WINDOW, "Shop", "Shop", root)
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
	local grid = frame("Passes", window.body)
	grid.LayoutOrder = 1
	local gridLayout = list(grid, true, 12)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local empty = words("Empty", window.body, 21)
	empty.LayoutOrder = 2
	empty.FontFace = Kit.BODY_FACE
	empty.TextColor3 = Kit.INK_SOFT

	parts = { window = window, pad = pad, grid = grid, gridLayout = gridLayout, empty = empty }
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Passes.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(Passes.FLAG) then
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

return ShopWindow
