--!strict
-- CheckinCard: the seven day check in card (issue 517), from Design-Agent's checkin.html. Behind the live switch
-- checkinCard, off by default, the same switch as CheckinService on the server.
--
--   CheckinCard.build(root)          makes the window once and returns its layer (UI registers "Checkin")
--   CheckinCard.set(ready, days, chances)   draws the card: `ready` the day waiting (1 to 7) or nil, `days` days
--                                    taken, `chances` true when the crate window can show the good crate's list
--   CheckinCard.onClaim(fn)          fn() when Claim is pressed
--   CheckinCard.onChances(fn)        fn(kind) when a crate day's chance button is pressed
--
-- Seven tiles, one per day PLAYED: no streak, no flame, nothing lost by missing a day. Today's tile glows, the days
-- taken have a tick, and day 2 (the good crate) is drawn bigger with a button for its chance list. Claim takes today's
-- gift and closes the card, so the player sees the server's notice; with nothing waiting the button hides and the
-- line says when the next gift comes. Only the X or Claim closes it. UI never fires remotes: CheckinController sends
-- the claim and decides when the card opens by itself (between washes only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheckinRules = require(Shared:WaitForChild("CheckinRules"))
local CheckinViewRules = require(Shared:WaitForChild("CheckinViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local CheckinCard = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local BIG_TOP, BIG_EDGE = Color3.fromHex("FFF6D6"), Color3.fromHex("F0CF6B")
local GOT_FILL, GOT_EDGE = Color3.fromHex("F1FBF4"), Color3.fromHex("9ED9B2")
local TODAY_EDGE = Color3.fromHex("4FCF93")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 8 -- design px below the middle on a short screen (Window's default is 33)
local MIN_TAP = 44 -- real px

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 1040,
		band = 72,
		title = 38,
		badge = 96,
		pad = 20,
		lead = 19,
		gap = 10,
		tileH = 204,
		n = 20,
		icon = 54,
		bigIcon = 64,
		what = 20,
		chances = 46,
		foot = 60,
		note = 17,
		claimW = 300,
		claimText = 26,
	},
	short = {
		width = 900,
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		lead = 0, -- no lead line on a short screen
		gap = 8,
		tileH = 186, -- day 2 holds its chance button too: 59 design px for a 44 px tap at the phone's 0.75
		n = 17,
		icon = 38,
		bigIcon = 38,
		what = 17,
		chances = 46,
		foot = 60,
		note = 15,
		claimW = 280,
		claimText = 24,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	stack: UIListLayout,
	lead: TextLabel,
	days: Frame,
	daysLayout: UIListLayout,
	foot: Frame,
	note: TextLabel,
	claim: TextButton,
}

local parts: Parts? = nil
local ready: number? = nil
local taken = 0
local canSeeChances = false
local claimListeners: { () -> () } = {}
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

-- A button stays at least MIN_TAP real px at the current scale.
local function tapSize(size: number): number
	local scale = Kit.screenScale()
	return math.max(size, math.ceil(MIN_TAP / scale))
end

local function drawTile(tile: CheckinViewRules.Tile, parent: Frame, s: Sizes, width: number)
	local card = frame(`Day{tile.day}`, parent)
	card.LayoutOrder = tile.day
	card.Size = UDim2.fromOffset(width, s.tileH)
	card.BackgroundTransparency = 0
	card.BackgroundColor3 = if tile.got then GOT_FILL else Kit.WHITE
	Kit.corner(card, UDim.new(0, 16))
	local edge = Kit.stroke(card, if tile.today then 5 else 3)
	edge.Color = if tile.today
		then TODAY_EDGE
		elseif tile.got then GOT_EDGE
		elseif tile.big then BIG_EDGE
		else Kit.LINE
	if tile.big and not tile.got then
		local tint = Instance.new("UIGradient")
		tint.Rotation = 90
		tint.Color = ColorSequence.new(BIG_TOP, Kit.WHITE)
		tint.Parent = card
	end

	-- the words and the icon in a column of their own, so the tick can sit over them
	local column = frame("Stack", card)
	column.Size = UDim2.fromScale(1, 1)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 10)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = column
	local layout = list(column, false, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top -- every tile's "Day N" on one line

	local n = words("Day", column, s.n)
	n.LayoutOrder = 1
	n.TextColor3 = Kit.INK_SOFT
	n.Size = UDim2.new(1, 0, 0, s.n + 4)
	n.Text = `Day {tile.day}`

	local iconSize = if tile.big then s.bigIcon else s.icon
	local icon = frame("Pic", column)
	icon.LayoutOrder = 2
	icon.Size = UDim2.fromOffset(iconSize, iconSize)
	Icons.draw(tile.icon, icon, tile.got)

	local what = words("What", column, s.what)
	what.LayoutOrder = 3
	what.TextWrapped = true
	what.Size = UDim2.new(1, 0, 0, s.what * 2 + 2) -- room for "Good crate" on two lines
	what.TextYAlignment = Enum.TextYAlignment.Top
	what.TextTransparency = if tile.got then 0.45 else 0
	what.Text = tile.what

	local kind = tile.crate
	if tile.big and kind and canSeeChances then
		-- the chance list for the good crate, before it is ever taken
		local size = tapSize(s.chances)
		what.Size = UDim2.new(1, 0, 0, s.what + 4)
		local chances = Instance.new("TextButton")
		chances.Name = "Chances"
		chances.LayoutOrder = 4
		chances.Size = UDim2.fromOffset(size, size)
		chances.BackgroundColor3 = Kit.WHITE
		chances.AutoButtonColor = true
		chances.Text = ""
		Kit.corner(chances, UDim.new(0, 12))
		local ring = Kit.stroke(chances, 3)
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		chances:SetAttribute("Hint", "See the chances in the good crate")
		chances.Parent = column
		local dice = frame("Pic", chances)
		dice.AnchorPoint = Vector2.new(0.5, 0.5)
		dice.Position = UDim2.fromScale(0.5, 0.5)
		dice.Size = UDim2.fromScale(0.7, 0.7)
		Icons.draw("Dice", dice)
		chances.Activated:Connect(function()
			for _, listener in chanceListeners do
				task.spawn(listener, kind)
			end
		end)
	end

	if tile.got then
		-- the tick over the faded gift (inside the picture's box, so it sits wherever the column puts it)
		local tick = frame("Tick", icon)
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5, 0.5)
		tick.Size = UDim2.fromScale(1, 1)
		tick.ZIndex = 3
		Icons.draw("Check", tick)
	end
end

local function clearDays(days: Frame)
	for _, child in days:GetChildren() do
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
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad - 4), pad
	p.stack.Padding = UDim.new(0, if short then 8 else 12)

	p.lead.Visible = s.lead > 0
	p.lead.TextSize = math.max(s.lead, 14)
	p.lead.Size = UDim2.new(1, 0, 0, s.lead + 6)
	p.lead.Text = CheckinViewRules.LEAD

	local inner = width - 2 * s.pad
	local tileW = math.floor((inner - (CheckinRules.DAYS - 1) * s.gap) / CheckinRules.DAYS)
	p.daysLayout.Padding = UDim.new(0, s.gap)
	clearDays(p.days)
	for _, tile in CheckinViewRules.tiles(ready, taken) do
		drawTile(tile, p.days, s, tileW)
	end
	p.days.Size = UDim2.new(1, 0, 0, s.tileH + 6) -- the glow's 5 px outside the tile

	local claimText = CheckinViewRules.claimText(ready)
	local claimH = tapSize(s.foot)
	p.foot.Size = UDim2.new(1, 0, 0, claimH)
	p.claim.Visible = claimText ~= nil
	p.claim.Text = claimText or ""
	p.claim.TextSize = s.claimText
	p.claim.Size = UDim2.fromOffset(s.claimW, claimH)
	p.note.TextSize = s.note
	p.note.Size = UDim2.new(1, if claimText then -(s.claimW + 16) else 0, 1, 0)
	p.note.Text = CheckinViewRules.note(ready, taken)
end

function CheckinCard.set(newReady: number?, days: number, chances: boolean)
	ready, taken, canSeeChances = newReady, days, chances
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function CheckinCard.onClaim(fn: () -> ())
	table.insert(claimListeners, fn)
end

function CheckinCard.onChances(fn: (kind: string) -> ())
	table.insert(chanceListeners, fn)
end

function CheckinCard.build(root: Instance): Frame
	local window = Window.new("Checkin", "Check in", "Gift", root)
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
	local stack = list(window.body, false, 12)

	local lead = words("Lead", window.body, 19)
	lead.LayoutOrder = 1
	lead.FontFace = Kit.BODY_FACE
	lead.TextColor3 = Kit.INK_SOFT
	lead.TextXAlignment = Enum.TextXAlignment.Left
	lead.TextWrapped = true

	local days = frame("Days", window.body)
	days.LayoutOrder = 2
	local daysLayout = list(days, true, 10)
	daysLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	daysLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local foot = frame("Foot", window.body)
	foot.LayoutOrder = 3
	local note = words("Note", foot, 17)
	note.FontFace = Kit.BODY_FACE
	note.TextColor3 = Kit.INK_SOFT
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextWrapped = true
	local claim = Window.button("Claim", "Claim", foot, GREEN_TOP, GREEN_BOTTOM)
	claim.AnchorPoint = Vector2.new(1, 0)
	claim.Position = UDim2.fromScale(1, 0)
	claim.Activated:Connect(function()
		if ready == nil then
			return
		end
		window.layer.Visible = false
		for _, listener in claimListeners do
			task.spawn(listener)
		end
	end)

	parts = {
		window = window,
		pad = pad,
		stack = stack,
		lead = lead,
		days = days,
		daysLayout = daysLayout,
		foot = foot,
		note = note,
		claim = claim,
	}
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheckinRules.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(CheckinRules.FLAG) then
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

return CheckinCard
