--!strict
-- StarterAd: the starter pack's small ad on the right of the HUD (issue 739, Derek's ask of 2026-11-26: "a little ad on
-- the side for the starter pack" in place of a gift button), behind the switch hudTidy with starterPack and passes. A
-- card under the coins: a "Starter Pack" ribbon, the three things in the pack, the shop total struck through beside the
-- pack's price, a "Save N%" tag and a calm time-left chip. A tap opens the Spa Starter Pack window, which breaks the
-- pack down item by item.
--
--   StarterAd.build(root, open)   makes the card once, hidden; open() runs when it is pressed
--   StarterAd.onBuy(fn)           with starterCard: fn runs when the card itself is tapped (the purchase prompt)
--   StarterAd.set(items, pack)    the three items (StarterViewRules) and the pack's price, or nil while unknown
--   StarterAd.setNote(text)       the time-left chip (StarterViewRules.hudText), nil hides it
--   StarterAd.setAside(on)        hides it with the side buttons during a wash
--   StarterAd.button()            the pressable card (StarterController's bob, the tutorial's pointer)
--
-- The numbers are always true: the struck total and the saving come from StarterViewRules.saving, from the live shop
-- prices, and both hide when any price is missing. No words say "hurry" or "limited", and nothing opens by itself.
-- Its size follows the HUD's screen scale with a smaller card on a short screen, so it never crowds a phone, and it
-- stays well above the jump button.
--
-- Switch starterCard (issue 1080, Derek 2026-11-27: "the bobbing of the starter pack is a little too insane make it
-- show one thing cool maybe with a dark background no bobbing, remove the little sparkle at top and show the cost give
-- an info button to have it popup with more detailed breakdown but if they click the card just prompt them to
-- purchase"): a dark card with one big picture (the Golden Sponge on a gold glow) in place of the three small ones,
-- the true price (struck shop total beside it when known), no time chip, and a round "i" in its top-right corner that
-- opens the Spa Starter Pack window with the item by item breakdown. A tap anywhere else on the card asks the server
-- for Roblox's purchase prompt (StarterController, RequestStarter), which shows the price again before any charge.
-- StarterController does not bob it (the bob's sparkles were the "little sparkle at top").
--
-- Switch starterPet (issue 1090, Derek 2026-11-27: "don't use a sponge as the image make it like a golden flashing pet
-- or crate or something crazy"): the big picture is Midas, the golden pet the pack gives (found nowhere else), with gold
-- rays turning slowly behind him and his glow pulsing. With Reduced Motion, Less screen shake or Less sparkle the rays
-- and the glow stand still. The card itself never moves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local StarterRules = require(Shared:WaitForChild("StarterRules"))
local StarterViewRules = require(Shared:WaitForChild("StarterViewRules"))

local Comfort = require(script.Parent.Parent:WaitForChild("Comfort"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent.Parent:WaitForChild("Motion"))

local StarterAd = {}

StarterAd.FLAG = "hudTidy"
StarterAd.CARD_FLAG = "starterCard"
StarterAd.HERO = "Sponge" -- the one big picture: the Golden Sponge, the pack's best item
local FLAGS = { "gameHud", "hudTidy", StarterRules.FLAG, "passes" }
local MIN_REACH = 48 -- design px: the "i" button's tap area, at least REACH_REAL real px however small the card is drawn
local REACH_REAL = 46

local EDGE = 22 -- design px from the root's right edge, as the coins
local TOP = 108 -- design px from the root's top: under the coin pill and the friend tag
-- Issue 857: in a small Studio window or on a short phone the card ran off the bottom of the screen. It shrinks to fit
-- the room between TOP and the bottom edge (on a touch screen, above the jump button's corner), and hides when even
-- MIN_FIT of its size would not fit; the Shop still sells the pack.
local BOTTOM_ROOM = 120 -- design px kept clear above the bottom edge on a touch screen: the jump button's top
local BOTTOM_EDGE = 16 -- design px kept clear with a mouse or a controller, where no jump button is drawn
local CHIP_HANG = 13 -- design px: the time chip hangs half its height under the card
local MIN_FIT = 0.6
local RED = Color3.fromHex("E0475B")
local GREEN = Color3.fromHex("2E9E46")
local RIBBON_TOP, RIBBON_BOTTOM = Color3.fromHex("FF9CC6"), Color3.fromHex("FF6FA8")
local TAG_TOP, TAG_BOTTOM = Color3.fromHex("FFE98F"), Color3.fromHex("FFC94D")
-- starterCard: the dark card, its gold edge and glow, and price colours that read on it (contrast 4.5 or more)
local DARK_TOP, DARK_BOTTOM = Color3.fromHex("4A2B78"), Color3.fromHex("2A1745")
local DARK_RED = Color3.fromHex("FF9AA8")
local DARK_GREEN = Color3.fromHex("8CF06B")
-- starterPet: the rays behind Midas and his glow's pulse
local RAY_COUNT = 6 -- bars through the middle, so 12 rays
local RAY_TURN = 18 -- degrees a second: one turn in 20 s, slow enough to read as a shine, not a spin
local PULSE_SECONDS = 1.6
local GLOW_STILL = 0.55 -- the glow's see-through amount when still; the pulse swings it from 0.4 to 0.7
local INFO_SIZE = 34 -- design px: the round "i"; its button around it keeps a 46 real px tap area

-- Design px: a short screen (a phone held sideways, drawn at 0.75) and a full one. Model icons stay 48 real px or
-- more: 64 design px at 0.75, 52 at 1.0.
local SIZES = {
	short = {
		width = 232,
		ribbon = 30,
		ribbonText = 20,
		icon = 64,
		gap = 6,
		price = 26,
		was = 21,
		tag = 20,
		hero = 96,
	},
	full = {
		width = 204,
		ribbon = 28,
		ribbonText = 19,
		icon = 52,
		gap = 6,
		price = 26,
		was = 20,
		tag = 19,
		hero = 84,
	},
}
type Sizes = typeof(SIZES.short)

type Parts = {
	holder: Frame,
	scale: UIScale,
	card: TextButton,
	ribbon: TextLabel,
	icons: Frame,
	boxes: { Frame },
	prices: Frame,
	was: TextLabel,
	now: TextLabel,
	tag: TextLabel,
	note: TextLabel,
	hero: Frame,
	glow: Frame,
	rays: Frame,
	picture: Frame,
	info: TextButton,
	tint: UIGradient,
	edge: UIStroke,
}

local parts: Parts? = nil
local items: { StarterViewRules.Item } = {}
local pack: number? = nil
local noteText: string? = nil
local aside = false
local drawn: { string } = {}
local tooSmall = false -- true while the card would not fit even at MIN_FIT
local buyHandlers: { () -> () } = {}
local heroDrawn = "" -- the Icons name the big picture shows now
local shine: RBXScriptConnection? = nil -- starterPet: turns the rays and pulses the glow while the card shows

-- The big picture's Icons name: Midas with starterPet, else the Golden Sponge.
function StarterAd.heroIcon(): string
	return if LiveFlags.isOn(StarterViewRules.PET_FLAG)
		then StarterViewRules.PET_ICON
		else StarterAd.HERO
end

local function allOn(): boolean
	for _, name in FLAGS do
		if not LiveFlags.isOn(name) then
			return false
		end
	end
	local ends = Players.LocalPlayer:GetAttribute(StarterRules.ENDS_ATTRIBUTE)
	return ends ~= nil and ends ~= false
end

-- Whether the dark card with one picture and the buy tap is on (switch starterCard).
function StarterAd.calm(): boolean
	return LiveFlags.isOn(StarterAd.CARD_FLAG)
end

function StarterAd.onBuy(fn: () -> ())
	table.insert(buyHandlers, fn)
end

function StarterAd.isOn(): boolean
	return LiveFlags.isOn("gameHud") and LiveFlags.isOn(StarterAd.FLAG)
end

local function label(name: string, parent: Instance, size: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.Font = Kit.FONT
	l.TextColor3 = colour
	l.TextSize = size
	l.Text = ""
	Kit.minText(l)
	l.Parent = parent
	return l
end

-- Shrinks the card so it ends above BOTTOM_ROOM, or hides it when it would have to go under MIN_FIT (issue 857).
-- The card's own height in design px is its drawn height over the scale it is drawn at, so a new scale never feeds
-- back into the next measure.
local function fit()
	local p = parts
	if p == nil then
		return
	end
	local root = p.holder.Parent
	if root == nil or not root:IsA("GuiObject") then
		return
	end
	local scale = Kit.screenScale()
	local drawnAt = math.max(p.scale.Scale, 0.01)
	local natural = p.card.AbsoluteSize.Y / drawnAt + CHIP_HANG
	if natural <= CHIP_HANG then
		return -- not laid out yet
	end
	local bottom = root.AbsolutePosition.Y + root.AbsoluteSize.Y
	local clear = if UserInputService.TouchEnabled then BOTTOM_ROOM else BOTTOM_EDGE
	local room = (bottom - root.AbsolutePosition.Y) / scale - TOP - clear
	local k = math.min(1, room / natural)
	local small = k < MIN_FIT
	if small ~= tooSmall then
		tooSmall = small
		p.holder.Visible = allOn() and not aside and not tooSmall
	end
	local want = scale * math.max(k, MIN_FIT)
	if math.abs(p.scale.Scale - want) > 0.001 then
		p.scale.Scale = want
	end
	-- the "i" keeps a real 46 px tap area when the card is drawn small (a short phone, issue 857's shrink)
	local reach = math.max(MIN_REACH, math.ceil(REACH_REAL / math.max(want, 0.01)))
	p.info.Size = UDim2.fromOffset(reach, reach)
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	p.holder.Visible = allOn() and not aside and not tooSmall
	p.holder.Position = UDim2.new(1, -EDGE * scale, 0, TOP * scale)
	p.holder.Size = UDim2.fromOffset(s.width, 0)
	p.card.Size = UDim2.fromOffset(s.width, 0)

	p.ribbon.Size = UDim2.new(1, 0, 0, s.ribbon)
	p.ribbon.TextSize = s.ribbonText

	local calm = StarterAd.calm()
	p.icons.Visible = not calm
	p.hero.Visible = calm
	p.hero.Size = UDim2.fromOffset(s.hero, s.hero)
	local heroName = StarterAd.heroIcon()
	if heroName ~= heroDrawn then
		heroDrawn = heroName
		local drawnHero = Icons.draw(heroName, p.picture)
		drawnHero.ZIndex = 3
	end
	local pet = heroName == StarterViewRules.PET_ICON
	p.rays.Visible = pet
	local moving = pet and calm and p.holder.Visible and not Comfort.reducedMotion()
	local running: RBXScriptConnection? = shine
	if moving and not running then
		local started = os.clock()
		local glow, rays = p.glow, p.rays
		shine = RunService.Heartbeat:Connect(function()
			local t = os.clock() - started
			rays.Rotation = (t * RAY_TURN) % 360
			local wave = math.sin(t * 2 * math.pi / PULSE_SECONDS)
			glow.BackgroundTransparency = GLOW_STILL + 0.15 * wave
			local grow = 1.1 + 0.06 * wave
			glow.Size = UDim2.fromScale(grow, grow)
		end)
	elseif not moving and running then
		shine = nil
		running:Disconnect()
	end
	if not moving then
		p.rays.Rotation = 0
		p.glow.BackgroundTransparency = GLOW_STILL
		p.glow.Size = UDim2.fromScale(1.1, 1.1)
	end
	p.info.Visible = calm
	p.info.Position = UDim2.new(1, -8, 0, 6 + s.ribbon + 8) -- inside the card, under the ribbon's right end
	p.tint.Enabled = calm
	p.card.BackgroundColor3 = if calm then Kit.WHITE else Kit.CREAM
	p.edge.Color = if calm then Kit.GOLD else Kit.line()

	-- the three things in the pack, redrawn only when they change
	local keys: { string } = {}
	for _, item in items do
		table.insert(keys, item.icon)
	end
	local same = #keys == #drawn
	for index, key in keys do
		same = same and drawn[index] == key
	end
	for index, box in p.boxes do
		local key = keys[index]
		box.Visible = key ~= nil
		box.Size = UDim2.fromOffset(s.icon, s.icon)
		if key and not same then
			for _, child in box:GetChildren() do
				if not child:IsA("UICorner") and not child:IsA("UIStroke") then
					child:Destroy()
				end
			end
			Icons.draw(key, box)
		end
	end
	drawn = keys
	local list = p.icons:FindFirstChildOfClass("UIListLayout") :: UIListLayout?
	if list then
		list.Padding = UDim.new(0, s.gap)
	end

	-- the struck total and the saving, only when every price is known and the pack saves
	local total, percent = StarterViewRules.saving(items, pack)
	p.was.Visible = total ~= nil
	p.was.Text = if total then tostring(total) else ""
	p.was.TextSize = s.was
	p.was.TextColor3 = if calm then DARK_RED else RED
	local strike = p.was:FindFirstChild("Strike") :: Frame?
	if strike then
		strike.BackgroundColor3 = if calm then DARK_RED else RED
	end
	p.now.Text = if pack then `{pack} Robux` else "See the pack"
	p.now.TextSize = s.price
	p.now.TextColor3 = if calm
		then (if pack then DARK_GREEN else Kit.WHITE)
		elseif pack then GREEN
		else Kit.INK
	p.tag.Visible = percent ~= nil
	p.tag.Text = if percent then `SAVE {percent}%` else ""
	p.tag.TextSize = s.tag

	p.note.Visible = noteText ~= nil and not calm -- starterCard: no clock on the card (Derek's plan answer, 1069)
	p.note.Text = noteText or ""
	p.card:SetAttribute(
		"Says",
		if total
				and percent
				and pack
			then `Starter Pack: {pack} Robux instead of {total}, save {percent} percent`
			else "Starter Pack"
	)
	fit()
end

function StarterAd.set(newItems: { StarterViewRules.Item }, newPack: number?)
	items, pack = newItems, newPack
	redraw()
end

function StarterAd.setNote(text: string?)
	noteText = text
	redraw()
end

function StarterAd.setAside(on: boolean)
	if aside ~= on then
		aside = on
		redraw()
	end
end

function StarterAd.button(): TextButton?
	local p = parts
	return if p then p.card else nil
end

function StarterAd.shown(): boolean
	local p = parts
	return p ~= nil and p.holder.Visible
end

-- The ad's card and its SAVE tag (which sticks out past the card's left) while they show, so a notice card can sit
-- clear of them (ToastCard, issue 925).
function StarterAd.boxes(): { GuiObject }
	local p = parts
	if p == nil or not p.holder.Visible then
		return {}
	end
	return { p.card, p.tag }
end

function StarterAd.build(root: Instance, open: () -> ())
	-- the holder carries the screen scale; the card inside keeps its own UIScale free for the attention bob
	local holder = Instance.new("Frame")
	holder.Name = "StarterAd"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Visible = false
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = holder

	local card = Instance.new("TextButton")
	card.Name = "Card"
	card.Text = ""
	card.AutoButtonColor = true
	card.BackgroundColor3 = Kit.CREAM
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Selectable = true
	Kit.corner(card, UDim.new(0, 18))
	local edge = Kit.stroke(card, 4)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	-- starterCard: the dark plum fill (the card's white background through this gradient)
	local tint = Instance.new("UIGradient")
	tint.Name = "Dark"
	tint.Rotation = 90
	tint.Color = ColorSequence.new(DARK_TOP, DARK_BOTTOM)
	tint.Enabled = false
	tint.Parent = card
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 6)
	stack.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight =
		UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 18) -- room for the time chip on the bottom edge
	pad.Parent = card

	-- the ribbon across the top
	local ribbon = Instance.new("TextLabel")
	ribbon.Name = "Ribbon"
	ribbon.LayoutOrder = 1
	ribbon.BackgroundColor3 = Kit.WHITE
	ribbon.Font = Kit.FONT
	ribbon.Text = "STARTER PACK"
	ribbon.TextColor3 = Kit.WHITE
	Kit.minText(ribbon)
	Kit.corner(ribbon, UDim.new(0, 14))
	local ribbonTint = Instance.new("UIGradient")
	ribbonTint.Rotation = 90
	ribbonTint.Color = ColorSequence.new(RIBBON_TOP, RIBBON_BOTTOM)
	ribbonTint.Parent = ribbon
	local ribbonInk = Kit.stroke(ribbon, 2)
	ribbonInk.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ribbon.Parent = card

	-- the three things in the pack
	local icons = Instance.new("Frame")
	icons.Name = "Items"
	icons.LayoutOrder = 2
	icons.BackgroundTransparency = 1
	icons.AutomaticSize = Enum.AutomaticSize.XY
	icons.Size = UDim2.fromOffset(0, 0)
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = icons
	icons.Parent = card
	local boxes: { Frame } = {}
	for index = 1, #StarterRules.CONTENTS do
		local box = Instance.new("Frame")
		box.Name = `Item{index}`
		box.LayoutOrder = index
		box.BackgroundTransparency = 1
		box.Parent = icons
		boxes[index] = box
	end

	-- starterCard: one big picture on a soft gold glow, in place of the three small ones
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.LayoutOrder = 2
	hero.BackgroundTransparency = 1
	hero.Visible = false
	hero.Parent = card
	-- starterPet: gold rays behind the glow, each bar fading out at both ends
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1, 1)
	rays.Visible = false
	rays.ZIndex = 1
	rays.Parent = hero
	for index = 1, RAY_COUNT do
		local bar = Instance.new("Frame")
		bar.Name = `Ray{index}`
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(1.4, 0.12)
		bar.Rotation = (index - 1) * 180 / RAY_COUNT
		bar.BackgroundColor3 = Kit.GOLD
		bar.BackgroundTransparency = 0.35
		bar.ZIndex = 1
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.4),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = bar
		bar.Parent = rays
	end
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.1, 1.1)
	glow.BackgroundColor3 = Kit.GOLD
	glow.BackgroundTransparency = GLOW_STILL
	glow.ZIndex = 2
	Kit.corner(glow, UDim.new(0.5, 0))
	glow.Parent = hero
	local picture = Instance.new("Frame")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	picture.Size = UDim2.fromScale(0.86, 0.86)
	picture.ZIndex = 3
	picture.Parent = hero

	-- the struck shop total, then the pack's price
	local prices = Instance.new("Frame")
	prices.Name = "Prices"
	prices.LayoutOrder = 3
	prices.BackgroundTransparency = 1
	prices.AutomaticSize = Enum.AutomaticSize.XY
	prices.Size = UDim2.fromOffset(0, 0)
	local priceRow = Instance.new("UIListLayout")
	priceRow.FillDirection = Enum.FillDirection.Horizontal
	priceRow.VerticalAlignment = Enum.VerticalAlignment.Center
	priceRow.SortOrder = Enum.SortOrder.LayoutOrder
	priceRow.Padding = UDim.new(0, 8)
	priceRow.Parent = prices
	prices.Parent = card
	local was = label("Was", prices, 20, RED)
	was.LayoutOrder = 1
	was.RichText = false
	local strike = Instance.new("Frame")
	strike.Name = "Strike"
	strike.BorderSizePixel = 0
	strike.BackgroundColor3 = RED
	strike.AnchorPoint = Vector2.new(0.5, 0.5)
	strike.Position = UDim2.fromScale(0.5, 0.52)
	strike.Size = UDim2.new(1, 6, 0, 3)
	strike.Rotation = -12
	strike.Parent = was
	local now = label("Now", prices, 28, GREEN)
	now.LayoutOrder = 2

	-- the saving: a sunny tag on the card's top-left corner
	local tag = Instance.new("TextLabel")
	tag.Name = "Save"
	tag.AnchorPoint = Vector2.new(0, 0.5)
	tag.Position = UDim2.fromOffset(-12, 0)
	tag.AutomaticSize = Enum.AutomaticSize.XY
	tag.Size = UDim2.fromOffset(0, 0)
	tag.BackgroundColor3 = Kit.WHITE
	tag.Font = Kit.FONT
	tag.TextColor3 = Kit.GOLD_INK
	tag.ZIndex = 3
	Kit.minText(tag)
	Kit.corner(tag, UDim.new(0, 10))
	local tagTint = Instance.new("UIGradient")
	tagTint.Rotation = 90
	tagTint.Color = ColorSequence.new(TAG_TOP, TAG_BOTTOM)
	tagTint.Parent = tag
	local tagEdge = Kit.stroke(tag, 3)
	tagEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local tagPad = Instance.new("UIPadding")
	tagPad.PaddingLeft, tagPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	tagPad.PaddingTop, tagPad.PaddingBottom = UDim.new(0, 2), UDim.new(0, 2)
	tagPad.Parent = tag
	tag.Parent = holder -- outside the card's list, on its top-left corner

	-- the time left: a calm white chip on the bottom edge (days, hours and minutes, never seconds)
	local note = Instance.new("TextLabel")
	note.Name = "Note"
	note.AnchorPoint = Vector2.new(0.5, 0.5)
	note.Position = UDim2.fromScale(0.5, 1)
	note.AutomaticSize = Enum.AutomaticSize.X
	note.Size = UDim2.fromOffset(0, 26)
	note.BackgroundColor3 = Kit.WHITE
	note.Font = Kit.FONT
	note.TextColor3 = Kit.INK
	note.TextSize = 19
	note.ZIndex = 3
	note.Visible = false
	Kit.minText(note)
	Kit.corner(note, UDim.new(0.5, 0))
	local noteEdge = Kit.stroke(note, 3)
	noteEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local notePad = Instance.new("UIPadding")
	notePad.PaddingLeft, notePad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	notePad.Parent = note
	note.Parent = holder

	-- starterCard: the round "i" in the top-right corner opens the breakdown; the rest of the card buys
	-- The tap area is the button itself (at least REACH_REAL real px, fit() sizes it), hanging from the card's top-right
	-- corner just under the ribbon so it never leaves the screen; the round "i" sits in its top-right corner.
	local info = Instance.new("TextButton")
	info.Name = "Info"
	info.Text = ""
	info.AutoButtonColor = false
	info.BackgroundTransparency = 1
	info.AnchorPoint = Vector2.new(1, 0)
	info.Size = UDim2.fromOffset(MIN_REACH, MIN_REACH)
	info.ZIndex = 4
	info.Visible = false
	info:SetAttribute("Says", "Starter Pack: what's inside")
	local dot = Instance.new("TextLabel")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(1, 0)
	dot.Position = UDim2.fromScale(1, 0)
	dot.Size = UDim2.fromOffset(INFO_SIZE, INFO_SIZE)
	dot.BackgroundColor3 = Kit.WHITE
	dot.Font = Kit.FONT
	dot.Text = "i"
	dot.TextColor3 = Kit.INK
	dot.TextSize = 24
	dot.ZIndex = 5
	Kit.corner(dot, UDim.new(0.5, 0))
	local infoEdge = Kit.stroke(dot, 3)
	infoEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	infoEdge.Color = Kit.GOLD
	dot.Parent = info
	info.Parent = holder
	Motion.press(info)
	info.Activated:Connect(function()
		open()
	end)

	card.Parent = holder
	holder.Parent = root
	Motion.press(card)
	card.Activated:Connect(function()
		if StarterAd.calm() and pack ~= nil and #buyHandlers > 0 then
			for _, fn in buyHandlers do
				fn()
			end
		else
			open() -- the price is not known yet: the window explains the pack instead
		end
	end)

	parts = {
		holder = holder,
		scale = scale,
		card = card,
		ribbon = ribbon,
		icons = icons,
		boxes = boxes,
		prices = prices,
		was = was,
		now = now,
		tag = tag,
		note = note,
		hero = hero,
		glow = glow,
		rays = rays,
		picture = picture,
		info = info,
		tint = tint,
		edge = edge,
	}
	for _, name in FLAGS do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name)
			:Connect(redraw)
	end
	for _, name in { StarterAd.CARD_FLAG, StarterViewRules.PET_FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name)
			:Connect(redraw)
	end
	Players.LocalPlayer:GetAttributeChangedSignal(StarterRules.ENDS_ATTRIBUTE):Connect(redraw)
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit) -- the pictures and prices settle after a redraw
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

return StarterAd
