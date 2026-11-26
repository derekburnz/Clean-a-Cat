--!strict
-- SudsBubble: Suds's help bubble (BubbleRules, switch sudsBubble, off by default). A cream card with the ink outline
-- at the bottom of the screen, Suds's round face poking up over its top edge so it reads as him talking, a title,
-- one short line that says why, one chunky mint button and a small X. Design-Agent's look (2026-11-24).
--
--   SudsBubble.build(root)              makes it once
--   SudsBubble.show(bubble, onPress, onGone)  shows one bubble; onPress() runs when the player presses its button,
--                                       then onGone(closed) once the card goes for any reason (button, X, hide, or
--                                       another bubble taking its place); closed is true only for the player's X
--   SudsBubble.hide()
--   SudsBubble.isShown(), SudsBubble.current()   whether a bubble shows, and which
--
-- The button and the X only close the card; whatever "Show me" does is the caller's (it points the way and never
-- opens a window). The card never takes a press anywhere else, so walking and washing go on under it.
--
-- Placement: centred at the bottom when it fits, else moved sideways, and never over Roblox's touch controls: on a
-- touch screen it stays right of the thumbstick (the dynamic stick's resting circle reaches x 160; the classic stick
-- is 70 px at x 25 on a phone, 120 px at x 50 on a tablet) and left of the jump button (x W-95 on a phone, W-170 on a
-- tablet), with the X's overhang counted. At most 560 design px wide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

local Comfort = require(script.Parent:WaitForChild("Comfort"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))

local SudsBubble = {}

SudsBubble.FLAG = BubbleRules.FLAG

local MINT_TOP, MINT_BOTTOM = Color3.fromHex("8CF0C4"), Color3.fromHex("3FC48A")
local FACE_FILL = Color3.fromHex("E7DBFF")

-- Design px (the card's UIScale takes them to the screen), full then compact for a short screen.
local SIZES = {
	full = {
		height = 112,
		face = 96,
		poke = 34,
		title = 30,
		line = 23,
		button = 64,
		buttonWidth = 156,
	},
	short = {
		height = 100,
		face = 84,
		poke = 30,
		title = 26,
		line = 21,
		button = 60,
		buttonWidth = 140,
	},
}
local MAX_WIDTH = 560
local PAD = 14 -- design px inside the card's edge
local LINE_SLACK = 1.12 -- the body font draws a little taller than the measuring font
local GAP = 12 -- design px between the face, the words and the button
local CLOSE = 60 -- design px: the X's press area (45 real px at the smallest scale, over the 44 px floor)
local CLOSE_DOT = 40 -- design px: the X's drawn circle inside it
local BOTTOM_GAP = 12 -- real px between the card and the screen's bottom
local EDGE = 16 -- real px from the side with no touch controls
-- Real px each side keeps clear on a touch screen: the thumbstick's right edge and the jump button's left edge, plus
-- a margin (TouchThumbstick and TouchJump in Roblox's PlayerModule; the UI gate's zones are the same).
local SMALL_SIDE = 500 -- real px: a screen whose short side is this or less gets the phone's smaller controls
local STICK_CLEAR = { small = 168, large = 180 }
local JUMP_CLEAR = { small = 103, large = 178 }

type Parts = {
	card: Frame,
	scale: UIScale,
	face: Frame,
	title: TextLabel,
	line: TextLabel,
	button: TextButton,
	close: TextButton,
}

local parts: Parts? = nil
local shown: BubbleRules.Bubble? = nil
local pressed: (() -> ())? = nil
local gone: ((closed: boolean) -> ())? = nil

function SudsBubble.isShown(): boolean
	return shown ~= nil and LiveFlags.isOn(SudsBubble.FLAG)
end

function SudsBubble.current(): BubbleRules.Bubble?
	return shown
end

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

-- Where the card goes: its centre x and width in real px, from the screen and its touch controls.
local function span(screen: Vector2, scale: number): (number, number)
	local lo, hi = EDGE, screen.X - EDGE
	if Comfort.input() == Enum.PreferredInput.Touch then
		local small = math.min(screen.X, screen.Y) <= SMALL_SIDE
		lo = if small then STICK_CLEAR.small else STICK_CLEAR.large
		hi = screen.X - (if small then JUMP_CLEAR.small else JUMP_CLEAR.large)
	end
	hi -= CLOSE / 2 * scale -- the X hangs half over the card's right edge
	local width = math.max(0, math.min(MAX_WIDTH * scale, hi - lo))
	-- at join the viewport can still be 0 wide (issue 608): then hi is below lo, and the card just centres
	local left, right = lo + width / 2, hi - width / 2
	local centre = if right >= left then math.clamp(screen.X / 2, left, right) else screen.X / 2
	return centre, width
end

local lift = 0 -- real px the card sits higher, over the compact recap strip (issue 626)

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local current = shown
	local on = current ~= nil and LiveFlags.isOn(SudsBubble.FLAG)
	p.card.Visible = on
	if not on or current == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s = if short then SIZES.short else SIZES.full
	local screen = viewport()
	local centre, width = span(screen, scale)
	local designWidth = width / scale
	p.scale.Scale = scale
	local wordsLeft = PAD + s.face + GAP
	local wordsWidth = math.max(0, designWidth - wordsLeft - GAP - s.buttonWidth - PAD)
	-- the card grows to hold the whole line when it wraps past two rows on a narrow phone (#835)
	local lineH = TextService:GetTextSize(
		current.line,
		s.line,
		Kit.FONT,
		Vector2.new(math.max(wordsWidth, 1), 2000)
	).Y * LINE_SLACK
	local height = math.max(s.height, math.ceil(PAD * 2 + s.title + 4 + lineH))
	p.card.Size = UDim2.fromOffset(designWidth, height)
	p.card.Position = UDim2.new(0, centre, 1, -BOTTOM_GAP - lift)

	p.face.Size = UDim2.fromOffset(s.face, s.face)
	-- The face sits on the card's left with its top s.poke above the card's top edge.
	p.face.Position = UDim2.fromOffset(PAD, -s.poke)

	p.title.Position = UDim2.fromOffset(wordsLeft, PAD - 2)
	p.title.Size = UDim2.fromOffset(wordsWidth, s.title + 6)
	p.title.Text = current.title
	Kit.shrinkToFit(p.title, s.title)
	p.line.Position = UDim2.fromOffset(wordsLeft, PAD + s.title + 4)
	p.line.Size = UDim2.fromOffset(wordsWidth, height - PAD * 2 - s.title - 4)
	p.line.Text = current.line
	p.line.TextSize = s.line

	p.button.Size = UDim2.fromOffset(s.buttonWidth, s.button)
	p.button.Position = UDim2.fromOffset(designWidth - PAD - s.buttonWidth, height - PAD - s.button)
	p.button.Text = current.button or if current.showMe then BubbleRules.SHOW_ME else BubbleRules.OK
	p.button.TextSize = if short then 24 else 26
end

-- Takes the card away and runs the gone callback of the bubble that was up, once.
local function takeAway(closed: boolean)
	local after = gone
	shown, pressed, gone = nil, nil, nil
	redraw()
	if after then
		after(closed)
	end
end

function SudsBubble.hide()
	if shown ~= nil then
		takeAway(false)
	end
end

function SudsBubble.show(
	bubble: BubbleRules.Bubble,
	onPress: (() -> ())?,
	onGone: ((closed: boolean) -> ())?
)
	SudsBubble.hide()
	shown = bubble
	pressed = onPress
	gone = onGone
	redraw()
	local p = parts
	if p and SudsBubble.isShown() then
		Motion.popIn(p.card) -- trial springs, switch springUi (#183)
	end
end

local function chunky(name: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.BackgroundColor3 = Kit.WHITE
	b.Font = Kit.FONT
	b.TextColor3 = Kit.WHITE
	b.TextStrokeColor3 = Kit.INK
	b.TextStrokeTransparency = 0 -- a solid ink edge: white on bright mint needs it to read on a phone
	Kit.minText(b)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(MINT_TOP, MINT_BOTTOM)
	g.Parent = b
	Kit.corner(b, UDim.new(0, 16))
	local stroke = Kit.stroke(b, 4)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Parent = parent
	Motion.press(b) -- trial springs, switch springUi (#183)
	return b
end

function SudsBubble.build(root: Frame)
	local card = Instance.new("Frame")
	card.Name = "SudsBubble"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.BackgroundColor3 = Kit.CREAM
	card.BorderSizePixel = 0
	card.Visible = false
	Comfort.backdrop(card, 0.04)
	Kit.corner(card, UDim.new(0, 24))
	Kit.stroke(card, 4)
	local scale = Instance.new("UIScale")
	scale.Name = "BubbleScale"
	scale.Parent = card

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundColor3 = FACE_FILL
	face.BorderSizePixel = 0
	Kit.corner(face, UDim.new(0.5, 0))
	Kit.stroke(face, 4)
	face.Parent = card
	Portraits.draw(SudsRules.NAME, "Common", face, true)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Kit.FONT
	title.TextColor3 = Kit.INK
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = card

	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.FontFace = Kit.BODY_FACE
	line.TextColor3 = Kit.INK_SOFT
	line.TextWrapped = true
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.Parent = card

	local button = chunky("Go", card)
	button.Activated:Connect(function()
		local fn = pressed
		pressed = nil
		if fn then
			fn() -- the press first (it points the way), then whatever waits for the card to go
		end
		SudsBubble.hide()
	end)

	-- The small X: a 40 px ink-edged circle centred on the card's top right corner, in a 60 px press area.
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(CLOSE, CLOSE)
	close.BackgroundTransparency = 1
	close.Text = ""
	close.Parent = card
	local dot = Instance.new("TextLabel")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(CLOSE_DOT, CLOSE_DOT)
	dot.BackgroundColor3 = Kit.WHITE
	dot.Font = Kit.FONT
	dot.Text = "X"
	dot.TextColor3 = Kit.INK
	dot.TextSize = 22
	Kit.corner(dot, UDim.new(0.5, 0))
	local ring = Kit.stroke(dot, 3)
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- the ring round the dot, not round the X
	dot.Parent = close
	close.Activated:Connect(function()
		if shown ~= nil then
			takeAway(true)
		end
	end)

	parts = {
		card = card,
		scale = scale,
		face = face,
		title = title,
		line = line,
		button = button,
		close = close,
	}
	card.Parent = root

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	Comfort.onInputChanged(function()
		redraw()
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. SudsBubble.FLAG)
		:Connect(redraw)
end

-- Lifts the card `px` real px higher, so it sits above the compact recap strip and never over it (issue 626).
function SudsBubble.setLift(px: number)
	local value = math.max(0, math.floor(px))
	if value ~= lift then
		lift = value
		redraw()
	end
end

return SudsBubble
