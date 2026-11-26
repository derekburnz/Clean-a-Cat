--!strict
-- HUD: the game's heads-up display, built from Design-Agent's draft screens (assets/clean-a-cat/ui/screens/hud.html
-- and wash.html, drafts, not a locked design). Issue #210. Behind the live switch gameHud, off by default: while it
-- is off nothing here shows and the starter HUD is unchanged.
--
--   HUD.build(root)      makes the pieces once, inside the starter HUD's root (so the #209 TV inset applies)
--   HUD.setCoins(n)      the coin counter, top right: the save's coins as the server mirrored them
--   HUD.setStage(stage)  the wash step bar (top centre) and tool tray (bottom centre) for a ScrubController stage;
--                        nil, "waiting" or "done" hides them
--   HUD.setPlan(later)   which later steps ("bath", "claws"; #267) this cat's wash takes: only those join the bar;
--                        SudsRules.NO_BOWS in it leaves the bows out (the opening's kitten, #285)
--   HUD.setTip(tip)      the tutorial's tip line in the step bar's place (HUD/TipLine, switch tutorialTip), or nil;
--                        HUD.tipShown() is it while it shows, HUD.onTipChanged(fn) when it shows, hides or resizes
--   HUD.setMeter(f, step) the bar that fills while the player works an area step (HUD/WashMeter; ScrubController's
--                        meter, switch washMeter): f from 0 to 1, nil hides it; it sits under the step line or tip pill
--   HUD.listShown()      true while the tick list of this cat's steps shows (HUD/StepList, switch washChecklist), in
--                        the pips' place; HUD.onListChanged(fn) when that flips (the button row steps aside for it)
--
-- The look follows the screens' README: numbers and status are white words with an ink outline and no box, Fredoka
-- One only, and every piece is laid out in design pixels on a 1280 x 720 canvas and scaled like Scale.luau:
-- clamp(min(w / 1280, h / 720), 0.75, 1.3). A screen shorter than 560 design pixels (a phone held sideways) gets the
-- compact sizes. The tray only shows the tool each step uses; it is not pressable yet. UI never fires remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FriendViewRules = require(Shared:WaitForChild("FriendViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))
local Wallet = require(Shared:WaitForChild("Wallet"))
local WashDraft = require(Shared:WaitForChild("WashDraft"))

local Comfort = require(script.Parent:WaitForChild("Comfort"))
local Icons = require(script:WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local StepList = require(script:WaitForChild("StepList"))
local TipLine = require(script:WaitForChild("TipLine"))
local WashMeter = require(script:WaitForChild("WashMeter"))

local HUD = {}

HUD.FLAG = "gameHud"
-- With this switch on the tool tray does not show: each step already takes its own tool, so a row of tools read as a
-- menu to pick from (Derek's dev test, 2026-11-24: "should be more like animal salon where it just auto changes to
-- proper tool no need for a selector menu"). The top line says the step and the tick list shows the rest; on a short
-- screen, with no tick list, the step pips come back to show the progress the tray's ticks showed.
HUD.AUTO_TOOL_FLAG = "autoTool"

local FONT = Kit.FONT
local WHITE = Kit.WHITE
local GOLD_TEXT = Kit.GOLD_TEXT
local EDGE = 22 -- design pixels from the root's edge (the screens' right margin)
local FRIEND_TEXT = 19 -- design px: the friend chip under the coins (issue 520)

-- One wash step per stage the player acts in, in order (ScrubController and SpaRules). A `later` step (#267) shows
-- only for a cat whose wash takes it (setPlan).
type Step = { stage: string, icon: string, say: string, later: boolean? }
HUD.STEPS = {
	{ stage = "dirty", icon = "Sponge", say = "Scrub the mud" },
	{ stage = "clean", icon = "Brush", say = "Brush the fur" },
	{ stage = "bath", icon = "Smell", say = WashDraft.SAY.bath, later = true },
	{ stage = "claws", icon = "Claws", say = WashDraft.SAY.claws, later = true },
	{ stage = "fluffed", icon = "Bow", say = "Pick a bow" },
	{ stage = "styled", icon = "Camera", say = "Take the photo" },
} :: { Step }

-- Sizes in design pixels: full, then compact for a short screen.
local SIZES = {
	full = {
		coinIcon = 48,
		coinText = 46,
		stepText = 30,
		pip = 30,
		slot = 76,
		slotIcon = 52,
		lift = 10,
	},
	short = {
		coinIcon = 48,
		coinText = 40,
		stepText = 26,
		pip = 26,
		slot = 68,
		slotIcon = 52,
		lift = 8,
	},
}
type Sizes = typeof(SIZES.full)

type Pieces = {
	coins: Frame,
	friends: Frame,
	friendText: TextLabel,
	coinIcon: Frame,
	coinText: TextLabel,
	steps: Frame,
	stepText: TextLabel,
	pipRow: Frame,
	pips: { Frame },
	ticks: { TextLabel },
	tray: Frame,
	slots: { Frame },
	slotTicks: { TextLabel },
	faces: { Frame },
	iconBoxes: { Frame },
	faded: { boolean },
	scales: { UIScale },
}

local pieces: Pieces? = nil
local coins = 0
local friendsHere: unknown = nil -- the Player attribute FriendsHere (switch friendBonus, issue 520)
local stage: string? = nil
local plan: { string } = {} -- the later steps this wash takes
local listWas = false
local meterFraction: number? = nil
local meterStep: string? = nil
local root: Frame? = nil
local listListeners: { () -> () } = {}
local washWas = false -- a wash under way when last drawn (the side buttons step aside for it, issue 625)
-- Between two steps the stage passes through a moment with no shown step. The wash's look holds through it for up
-- to GAP_HOLD seconds, so the side buttons never pop in over the step line and the meter never jumps (issue 698).
local GAP_HOLD = 1.2
local heldStep: number? = nil
local heldUntil = 0
local holdCheck = false

-- The steps this wash shows, as indexes into HUD.STEPS, in order.
local function shownSteps(): { number }
	local out: { number } = {}
	local noBows = table.find(plan, SudsRules.NO_BOWS) ~= nil
	for index, step in HUD.STEPS do
		if step.stage == "fluffed" and noBows then
			continue
		end
		if not step.later or table.find(plan, step.stage) ~= nil then
			table.insert(out, index)
		end
	end
	return out
end

-- Where `name` falls among the shown steps (1 = first shown), or nil.
local function stepIndex(name: string?, shown: { number }): number?
	for place, index in shown do
		if HUD.STEPS[index].stage == name then
			return place
		end
	end
	return nil
end

local corner = Kit.corner
local stroke = Kit.stroke
local outlined = Kit.outlined

local function holder(
	name: string,
	parent: Instance,
	anchor: Vector2,
	position: UDim2
): (Frame, UIScale)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	frame.Visible = false
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = frame
	frame.Parent = parent
	return frame, scale
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

local screenScale = Kit.screenScale

local function on(): boolean
	return LiveFlags.isOn(HUD.FLAG)
end

-- True while the game HUD is switched on; other starter pieces (the Menu) lay out around it.
HUD.active = on

-- Calls fn() when the HUD's switch flips.
function HUD.onActiveChanged(fn: () -> ())
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. HUD.FLAG):Connect(fn)
end

-- The wash meter starts under whichever line shows at the top centre: the tutorial's pill, else the step line.
local function placeMeter()
	local p, r = pieces, root
	if p == nil or r == nil then
		return
	end
	local above: GuiObject? = TipLine.shown()
	if above == nil and p.steps.Visible then
		above = p.steps
	end
	local top = if above
		then above.AbsolutePosition.Y + above.AbsoluteSize.Y - r.AbsolutePosition.Y
		else 6
	WashMeter.place(top)
end

-- Sizes, scale and what shows, from the current coins, stage and screen.
local function redraw()
	local p = pieces
	if p == nil then
		return
	end
	local scale, short = screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	for _, uiScale in p.scales do
		uiScale.Scale = scale
	end

	p.coins.Visible = on()
	p.coinIcon.Size = UDim2.fromOffset(s.coinIcon, s.coinIcon)
	p.coinText.TextSize = s.coinText
	p.coinText.Text = Wallet.format(coins)
	-- the friend chip under the coins: friends in the server and their bonus, nothing with none
	local friendText = FriendViewRules.chipText(friendsHere)
	p.friends.Visible = on() and friendText ~= nil
	p.friendText.Text = friendText or ""
	p.friendText.TextSize = FRIEND_TEXT
	p.friends.Position = UDim2.new(1, -EDGE, 0, 8 + (s.coinIcon + 8) * scale)

	local shown = shownSteps()
	local current = stepIndex(stage, shown)
	local held = heldStep
	if current ~= nil then
		heldStep, heldUntil = current, os.clock() + GAP_HOLD
	elseif held ~= nil and on() and os.clock() < heldUntil then
		current = held
		if not holdCheck then
			holdCheck = true
			task.delay(heldUntil - os.clock() + 0.05, function()
				holdCheck = false
				redraw()
			end)
		end
	else
		heldStep = nil
	end
	local washing = on() and current ~= nil
	p.steps.Visible = washing and not TipLine.isShown() -- one line at the top centre: a tutorial tip wins
	-- The tick list (switch washChecklist) shows this cat's steps at the left and takes the pips' place; the top line
	-- keeps its words. Parent, not Visible: a hidden child still counts in the list's gaps in some layouts.
	local listSteps: { StepList.Step } = {}
	if washing then
		for _, index in shown do
			table.insert(listSteps, { icon = HUD.STEPS[index].icon, say = HUD.STEPS[index].say })
		end
	end
	StepList.set(listSteps, current or 0)
	local listNow = StepList.isShown()
	-- with the switch on the pips go on every screen: a short one has no card, and the tray's ticks show the progress;
	-- with no tray (switch autoTool) the pips stay where there is no card
	local checklist = StepList.isOn()
	local noTray = LiveFlags.isOn(HUD.AUTO_TOOL_FLAG)
	p.pipRow.Parent = if checklist and not (noTray and not listNow) then nil else p.steps
	if listNow ~= listWas or washing ~= washWas then
		listWas, washWas = listNow, washing
		for _, fn in listListeners do
			task.spawn(fn)
		end
	end
	p.tray.Visible = washing and not noTray
	WashMeter.set(if on() then meterFraction else nil, meterStep)
	placeMeter()
	if current == nil then
		return
	end
	local step = HUD.STEPS[shown[current]]
	p.stepText.TextSize = s.stepText
	p.stepText.Text = `Step {current} of {#shown} · {step.say}`
	-- each step's place among the shown ones; a later step this wash skips is hidden
	local placeOf: { [number]: number } = {}
	for place, index in shown do
		placeOf[index] = place
	end
	for index, pip in p.pips do
		local place = placeOf[index]
		pip.Visible = place ~= nil
		p.slots[index].Visible = place ~= nil
		local at = place or 0
		local size = if at == current then s.pip + 8 else s.pip
		pip.Size = UDim2.fromOffset(size, size)
		pip.BackgroundColor3 = if at < current
			then Color3.fromHex("C9F5E5")
			elseif at == current then GOLD_TEXT
			else WHITE
		p.ticks[index].Visible = at < current
	end
	for index, slot in p.slots do
		local at = placeOf[index] or 0
		slot.Size = UDim2.fromOffset(s.slot, s.slot + s.lift)
		local face = p.faces[index]
		face.Size = UDim2.fromOffset(s.slot, s.slot)
		face.Position = UDim2.fromOffset(0, if at == current then 0 else s.lift)
		face.BackgroundColor3 = if at == current
			then Color3.fromHex("FFC94D")
			elseif at < current then Color3.fromHex("E7F6EF")
			else WHITE
		p.slotTicks[index].Visible = checklist and at > 0 and at < current
		local iconBox = p.iconBoxes[index]
		iconBox.Size = UDim2.fromOffset(s.slotIcon, s.slotIcon) -- model icons never under 48 (Design-Agent)
		local fade = at < current
		if p.faded[index] ~= fade then
			p.faded[index] = fade
			Icons.draw(HUD.STEPS[index].icon, iconBox, fade)
		end
	end
end

function HUD.build(rootFrame: Frame)
	root = rootFrame
	local scales: { UIScale } = {}

	-- Coin counter, top right: icon then number, no box.
	local coinsFrame, coinsScale =
		holder("Coins", rootFrame, Vector2.new(1, 0), UDim2.new(1, -EDGE, 0, 8))
	table.insert(scales, coinsScale)
	list(coinsFrame, true, 12)
	local coinIcon = Instance.new("Frame")
	coinIcon.Name = "CoinIcon"
	coinIcon.BackgroundTransparency = 1
	coinIcon.LayoutOrder = 1
	coinIcon.Parent = coinsFrame
	Icons.draw("Coins", coinIcon)
	local coinText = outlined("Amount", coinsFrame)
	coinText.LayoutOrder = 2

	-- Friend chip, under the coins (switch friendBonus): "2 friends · +20%".
	local friendsFrame, friendsScale =
		holder("Friends", rootFrame, Vector2.new(1, 0), UDim2.new(1, -EDGE, 0, 64))
	table.insert(scales, friendsScale)
	local friendChip = Instance.new("Frame")
	friendChip.Name = "Chip"
	friendChip.AutomaticSize = Enum.AutomaticSize.X
	friendChip.Size = UDim2.fromOffset(0, FRIEND_TEXT + 14)
	friendChip.BackgroundColor3 = Kit.WHITE
	Kit.corner(friendChip, UDim.new(0.5, 0))
	local friendEdge = Kit.stroke(friendChip, 3)
	friendEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local friendPad = Instance.new("UIPadding")
	friendPad.PaddingLeft, friendPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	friendPad.Parent = friendChip
	local friendText = Instance.new("TextLabel")
	friendText.Name = "Text"
	friendText.BackgroundTransparency = 1
	friendText.AutomaticSize = Enum.AutomaticSize.X
	friendText.Size = UDim2.fromScale(0, 1)
	friendText.Font = Kit.FONT
	friendText.TextColor3 = Kit.INK
	friendText.TextSize = FRIEND_TEXT
	Kit.minText(friendText)
	friendText.Parent = friendChip
	friendChip.Parent = friendsFrame

	-- Step bar, top centre: "Step 1 of 4 · Scrub the mud" over one pip per step.
	local steps, stepsScale =
		holder("WashSteps", rootFrame, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 6))
	table.insert(scales, stepsScale)
	list(steps, false, 6)
	local stepText = outlined("Step", steps)
	stepText.LayoutOrder = 1
	local pipRow = Instance.new("Frame")
	pipRow.Name = "Pips"
	pipRow.BackgroundTransparency = 1
	pipRow.AutomaticSize = Enum.AutomaticSize.XY
	pipRow.Size = UDim2.fromOffset(0, 0)
	pipRow.LayoutOrder = 2
	pipRow.Parent = steps
	list(pipRow, true, 10)
	local pips: { Frame } = {}
	local ticks: { TextLabel } = {}
	for index = 1, #HUD.STEPS do
		local pip = Instance.new("Frame")
		pip.Name = `Pip{index}`
		pip.LayoutOrder = index
		corner(pip, UDim.new(0.5, 0))
		stroke(pip, 3)
		local tick = Instance.new("TextLabel")
		tick.Name = "Tick"
		tick.BackgroundTransparency = 1
		tick.Size = UDim2.fromScale(1, 1)
		tick.Text = "✓"
		tick.TextScaled = true -- a mark, not words
		tick.TextColor3 = Color3.fromHex("3FA868")
		tick.Font = FONT
		tick.Parent = pip
		ticks[index] = tick
		pip.Parent = pipRow
		pips[index] = pip
	end

	-- Tool tray, bottom centre: one slot per step's tool, the current one raised. Not pressable yet.
	local tray, trayScale =
		holder("ToolTray", rootFrame, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -EDGE))
	table.insert(scales, trayScale)
	tray.BackgroundTransparency = 0
	tray.BackgroundColor3 = Color3.fromHex("FFF6EC")
	Comfort.backdrop(tray, 0.08) -- solid for players who ask for less see-through UI (switch comfortSettings)
	corner(tray, UDim.new(0, 24))
	stroke(tray, 4)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 10)
	pad.Parent = tray
	list(tray, true, 12)
	local slots: { Frame } = {}
	local slotTicks: { TextLabel } = {}
	local faces: { Frame } = {}
	local iconBoxes: { Frame } = {}
	local faded: { boolean } = {}
	for index, step in HUD.STEPS do
		local slot = Instance.new("Frame")
		slot.Name = `Slot{index}`
		slot.BackgroundTransparency = 1
		slot.LayoutOrder = index
		local face = Instance.new("Frame")
		face.Name = "Face"
		corner(face, UDim.new(0, 18))
		stroke(face, 4)
		face.Parent = slot
		local iconBox = Instance.new("Frame")
		iconBox.Name = "IconBox"
		iconBox.BackgroundTransparency = 1
		iconBox.AnchorPoint = Vector2.new(0.5, 0.5)
		iconBox.Position = UDim2.fromScale(0.5, 0.5)
		iconBox.Parent = face
		Icons.draw(step.icon, iconBox)
		faded[index] = false
		-- a green tick on a finished step's slot, with the tick list's switch on (washChecklist)
		local slotTick = Instance.new("TextLabel")
		slotTick.Name = "Tick"
		slotTick.BackgroundTransparency = 1
		slotTick.AnchorPoint = Vector2.new(1, 0)
		slotTick.Position = UDim2.new(1, 2, 0, -2)
		slotTick.Size = UDim2.fromOffset(30, 30)
		slotTick.Text = "✓"
		slotTick.TextScaled = true -- a mark, not words
		slotTick.TextColor3 = Color3.fromHex("3FA868")
		slotTick.TextStrokeColor3 = WHITE
		slotTick.TextStrokeTransparency = 0
		slotTick.Font = FONT
		slotTick.Visible = false
		slotTick.Parent = face
		slotTicks[index] = slotTick
		slot.Parent = tray
		slots[index] = slot
		faces[index] = face
		iconBoxes[index] = iconBox
	end

	TipLine.build(rootFrame)
	TipLine.onChanged(redraw)
	WashMeter.build(rootFrame)
	steps:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeMeter)
	steps:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeMeter)
	StepList.build(rootFrame)
	StepList.onFlagsChanged(redraw)

	pieces = {
		coins = coinsFrame,
		friends = friendsFrame,
		friendText = friendText,
		coinIcon = coinIcon,
		coinText = coinText,
		steps = steps,
		stepText = stepText,
		pipRow = pipRow,
		pips = pips,
		ticks = ticks,
		tray = tray,
		slots = slots,
		slotTicks = slotTicks,
		faces = faces,
		iconBoxes = iconBoxes,
		faded = faded,
		scales = scales,
	}

	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. HUD.FLAG)
		:Connect(redraw)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. HUD.AUTO_TOOL_FLAG)
		:Connect(redraw)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

-- Friends in the server (the Player attribute FriendsHere; nil while friendBonus is off).
function HUD.setFriends(value: unknown)
	friendsHere = value
	redraw()
end

function HUD.setCoins(value: unknown)
	coins = if type(value) == "number" then value else 0
	redraw()
end

function HUD.setTip(tip: TipLine.Tip?)
	TipLine.set(tip)
end

-- The tutorial's step pill while it shows, else nil; HUD.onTipChanged(fn) when it shows, hides or changes size.
function HUD.tipShown(): GuiObject?
	return TipLine.shown()
end

function HUD.onTipChanged(fn: () -> ())
	TipLine.onChanged(fn)
end

function HUD.setMeter(fraction: number?, step: string?)
	meterFraction, meterStep = fraction, step
	if on() then
		WashMeter.set(fraction, step)
		placeMeter()
	else
		WashMeter.set(nil, nil)
	end
end

function HUD.listShown(): boolean
	return StepList.isShown()
end

-- True while a wash is under way and the HUD is on: the step line has the top of the screen.
function HUD.washing(): boolean
	return washWas
end

-- fn() when the tick list shows or hides, or a wash starts or ends.
function HUD.onListChanged(fn: () -> ())
	table.insert(listListeners, fn)
end

function HUD.setPlan(later: { string })
	if table.concat(later, ",") == table.concat(plan, ",") then
		return
	end
	plan = table.clone(later)
	redraw()
end

-- Which step's tool goes under the finger now (UI/HUD/HeldTool): the icon name of a drag step (scrub, brush, the
-- Bubble Bath, the Pawdicure), or nil for a tap step (a bow, the photo) or no wash.
local DRAG_STAGES = { dirty = true, clean = true, bath = true, claws = true }
function HUD.toolIcon(): string?
	local now = stage
	if now == nil or not DRAG_STAGES[now] then
		return nil
	end
	for _, step in HUD.STEPS do
		if step.stage == now then
			return step.icon
		end
	end
	return nil
end

function HUD.setStage(value: string?)
	if value == stage then
		return
	end
	stage = value
	redraw()
end

return HUD
