--!strict
-- TipLine: the tutorial's step pill at the top centre, from Design-Agent's draft (tutorial.html, state "tip", after the
-- owner's Pet Store Tycoon note of 2026-11-24: "the tutorial steps are very well done. feels easy to follow"). A cream
-- pill with an ink edge and lip holds a gold count chip ("1 / 3") and one short instruction in ink, such as "Wash him".
-- It takes the wash step bar's place while it shows, so there is still one thing at the top centre, and it sits over
-- the tutorial's dim (Spotlight), so the step still reads while the screen dims. Behind the live switch tutorialTip, off
-- by default (rule 16: every first-session change ships behind its own switch), and only with the game HUD (gameHud).
--
--   TipLine.build(root)    makes it once
--   TipLine.set(tip)       shows a tip ({ step, total, say }) or nil to take it away
--   TipLine.isShown()      true while a tip shows (the HUD hides its step bar then)
--   TipLine.onChanged(fn)  fn() when it shows, hides or changes size
--   TipLine.shown()        the pill while it shows, else nil (the tutorial's dim keeps its words clear of it)
--
-- It only shows words; which step comes when, and so the count, is the caller's (the opening's own step list).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local TipLine = {}

TipLine.FLAG = "tutorialTip"
local HUD_FLAG = "gameHud"

export type Tip = { step: number, total: number, say: string }

local CHIP_GOLD = Color3.fromHex("FFD84D") -- the draft's count chip, the same gold as the dim's lit ring
local STROKE = 4 -- design px: the pill's ink edge (the kit's --stroke)
local CHIP_STROKE = 3
local LIP = 4 -- design px: the ink lip under the pill (Design-Agent on #429: the 3 to 4 px it drew on a phone)
local Z = 9 -- over the tutorial's dim (8), under the windows and the recap (10)
-- the widest the pill draws, as a share of the screen's width: centred, it then stays clear of the coin counter at
-- the right and the button row at the left (Review-QA on #429: at 667 x 375 with Largest text it met the coins)
local MAX_SHARE = 0.6

-- Sizes in design pixels: full, then compact for a short screen.
local SIZES = {
	full = { count = 22, say = 30 },
	short = { count = 19, say = 26 },
}

type Parts = {
	holder: Frame,
	scale: UIScale,
	pill: Frame,
	lip: Frame,
	count: TextLabel,
	say: TextLabel,
}

local parts: Parts? = nil
local baseScale = 1 -- the pill's scale before any narrowing (redraw)
local tip: Tip? = nil
local listeners: { () -> () } = {}

function TipLine.isShown(): boolean
	return tip ~= nil and LiveFlags.isOn(TipLine.FLAG) and LiveFlags.isOn(HUD_FLAG)
end

-- The holder and the lip follow the pill's own size (it sizes to its words), in design pixels. A pill wider than
-- MAX_SHARE of the screen draws smaller, so its words stay whole. Its design size never depends on the scale, so
-- setting the scale here settles at once.
local function fit()
	local p = parts
	if p == nil then
		return
	end
	local scale = if p.scale.Scale > 0 then p.scale.Scale else 1
	local size = p.pill.AbsoluteSize / scale
	p.lip.Size = UDim2.fromOffset(size.X, size.Y)
	p.holder.Size = UDim2.fromOffset(size.X, size.Y + LIP)
	local camera = Workspace.CurrentCamera
	local limit = if camera then camera.ViewportSize.X * MAX_SHARE else math.huge
	local want = baseScale
	if size.X > 0 and size.X * want > limit then
		want = limit / size.X
	end
	if math.abs(p.scale.Scale - want) > 0.001 then
		p.scale.Scale = want
	end
end

function TipLine.shown(): GuiObject?
	local p = parts
	return if p and TipLine.isShown() then p.holder else nil
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local shown = TipLine.isShown()
	p.holder.Visible = shown
	local current = tip
	if not shown or current == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s = if short then SIZES.short else SIZES.full
	-- never drawn smaller than its design size: at the HUD's phone scale (0.75) the words were about 18 px, small
	-- for the one line that says what to do next (Design-Agent on #429: about 26 px on a phone, 30 on a desktop)
	baseScale = math.max(scale, 1)
	p.scale.Scale = baseScale
	p.count.TextSize = s.count
	p.count.Text = `{current.step} / {current.total}`
	p.say.TextSize = s.say
	p.say.Text = current.say
	fit()
end

local function changed()
	redraw()
	for _, listener in listeners do
		listener()
	end
end

function TipLine.set(newTip: Tip?)
	tip = newTip
	changed()
end

function TipLine.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

local function label(name: string, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = Kit.FONT
	text.TextColor3 = Kit.INK
	text.AutomaticSize = Enum.AutomaticSize.XY
	text.Size = UDim2.fromOffset(0, 0)
	text.ZIndex = Z
	Kit.minText(text)
	text.Parent = parent
	return text
end

local function padding(parent: Instance, top: number, right: number, bottom: number, left: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top)
	pad.PaddingRight = UDim.new(0, right)
	pad.PaddingBottom = UDim.new(0, bottom)
	pad.PaddingLeft = UDim.new(0, left)
	pad.Parent = parent
end

function TipLine.build(root: Instance)
	local holder = Instance.new("Frame")
	holder.Name = "TipLine"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 6)
	holder.Size = UDim2.fromOffset(0, 0)
	holder.ZIndex = Z
	holder.Visible = false
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = holder

	-- the lip: an ink copy of the pill's shape, LIP lower and behind it
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BackgroundColor3 = Kit.INK
	lip.BorderSizePixel = 0
	lip.Position = UDim2.fromOffset(0, LIP)
	lip.ZIndex = Z
	Kit.corner(lip, UDim.new(0, 22))
	Kit.stroke(lip, STROKE)
	lip.Parent = holder

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.BackgroundColor3 = Kit.CREAM
	pill.BorderSizePixel = 0
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.Size = UDim2.fromOffset(0, 0)
	pill.ZIndex = Z
	Kit.corner(pill, UDim.new(0, 22))
	Kit.stroke(pill, STROKE)
	padding(pill, 6, 20, 6, 8)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 12)
	list.Parent = pill
	pill.Parent = holder

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.BackgroundColor3 = CHIP_GOLD
	chip.BorderSizePixel = 0
	chip.AutomaticSize = Enum.AutomaticSize.XY
	chip.Size = UDim2.fromOffset(0, 0)
	chip.LayoutOrder = 1
	chip.ZIndex = Z
	Kit.corner(chip, UDim.new(0, 14))
	Kit.stroke(chip, CHIP_STROKE)
	padding(chip, 2, 12, 2, 12)
	chip.Parent = pill
	local count = label("Count", chip)

	local say = label("Say", pill)
	say.LayoutOrder = 2

	parts = { holder = holder, scale = scale, pill = pill, lip = lip, count = count, say = say }
	pill:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit()
		for _, listener in listeners do
			listener()
		end
	end)
	holder.Parent = root
	for _, name in { TipLine.FLAG, HUD_FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name)
			:Connect(changed)
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

return TipLine
