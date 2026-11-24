--!strict
-- StepList: the tick list of this cat's wash steps (switch washChecklist, off by default), from the reference
-- screens' idea in our own look (Design-Agent, 2026-11-24). A cream card with the ink outline at the top left, under
-- Roblox's menu where the HUD's button row sits (that row and the starter Menu step aside during a wash), one row per
-- step this cat's wash takes: its tool icon and words, a green tick once done, the current row gold. It takes the
-- place of the step bar's pips; the top line keeps the words ("Step 1 of 4 · Scrub the mud"). On a short screen (a
-- phone held sideways) the card does not show: there the tool tray at the bottom is already the row of this cat's
-- icons, and with the switch on its finished slots wear the ticks (HUD), as a separate row of model icons at 48 px or
-- more would not fit beside the step line, nor a column above the thumbstick.
--
--   StepList.build(root)               makes it once
--   StepList.set(steps, current)       draws `steps` ({ icon, say }, in order) with step `current` (1-based) up now;
--                                      an empty list hides it
--   StepList.isShown()                 true while it shows (switches on, a wash under way, not a short screen)
--   StepList.isOn()                    true while its switch and the game HUD's are on
--
-- It only shows; it is not pressable.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("Icons"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local StepList = {}

StepList.FLAG = "washChecklist"
local HUD_FLAG = "gameHud"

export type Step = { icon: string, say: string }

local MAX_STEPS = 6 -- HUD.STEPS' length: one row each at most
local EDGE = Vector2.new(16, 14) -- real px from the root's top left, as the HUD's button row
local DONE_FILL = Color3.fromHex("E7F6EF")
local TICK_GREEN = Color3.fromHex("3FA868")
-- Design px. Model icons are never drawn under 48 (Design-Agent).
local ICON, ROW, WORDS, WIDTH, PAD, GAP, TICK = 48, 56, 22, 262, 10, 4, 24

type Row = {
	frame: Frame,
	iconBox: Frame,
	words: TextLabel,
	tick: TextLabel,
	icon: string?,
	faded: boolean?,
}
type Parts = { card: Frame, scale: UIScale, rows: { Row } }

local parts: Parts? = nil
local steps: { Step } = {}
local current = 0

function StepList.isOn(): boolean
	return LiveFlags.isOn(StepList.FLAG) and LiveFlags.isOn(HUD_FLAG)
end

function StepList.isShown(): boolean
	local _, short = Kit.screenScale()
	return #steps > 0 and not short and StepList.isOn()
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local shown = StepList.isShown()
	p.card.Visible = shown
	if not shown then
		return
	end
	local scale = Kit.screenScale()
	p.scale.Scale = scale
	for index, row in p.rows do
		local step = steps[index]
		-- a row past this cat's steps leaves the list (Parent, not Visible: a hidden row still counts in some
		-- layouts' gaps)
		row.frame.Parent = if step then p.card else nil
		if step == nil then
			continue
		end
		local done = index < current
		local now = index == current
		row.frame.BackgroundTransparency = if now or done then 0 else 1
		row.frame.BackgroundColor3 = if now then Kit.GOLD else DONE_FILL
		if row.icon ~= step.icon or row.faded ~= done then
			row.icon, row.faded = step.icon, done
			Icons.draw(step.icon, row.iconBox, done)
		end
		row.words.Text = step.say
		row.words.TextColor3 = if done then Kit.INK_SOFT else Kit.INK
		row.tick.Visible = done
	end
end

function StepList.set(newSteps: { Step }, newCurrent: number)
	steps = table.clone(newSteps)
	current = newCurrent
	redraw()
end

function StepList.onFlagsChanged(fn: () -> ())
	for _, name in { StepList.FLAG, HUD_FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name):Connect(fn)
	end
end

function StepList.build(root: Instance)
	local card = Instance.new("Frame")
	card.Name = "StepList"
	card.Position = UDim2.fromOffset(EDGE.X, EDGE.Y)
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.Size = UDim2.fromOffset(0, 0)
	card.BackgroundColor3 = Kit.CREAM
	card.BorderSizePixel = 0
	card.Visible = false
	Kit.corner(card, UDim.new(0, 18))
	Kit.stroke(card, 4)
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = card
	local padding = Instance.new("UIPadding")
	local pad = UDim.new(0, PAD)
	padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom =
		pad, pad, pad, pad
	padding.Parent = card

	local rows: { Row } = {}
	for index = 1, MAX_STEPS do
		local frame = Instance.new("Frame")
		frame.Name = `Step{index}`
		frame.LayoutOrder = index
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromOffset(WIDTH, ROW)
		Kit.corner(frame, UDim.new(0, 12))
		local iconBox = Instance.new("Frame")
		iconBox.Name = "IconBox"
		iconBox.BackgroundTransparency = 1
		iconBox.AnchorPoint = Vector2.new(0, 0.5)
		iconBox.Position = UDim2.new(0, 4, 0.5, 0)
		iconBox.Size = UDim2.fromOffset(ICON, ICON)
		iconBox.Parent = frame
		local words = Instance.new("TextLabel")
		words.Name = "Words"
		words.BackgroundTransparency = 1
		words.FontFace = Kit.BODY_FACE
		words.TextXAlignment = Enum.TextXAlignment.Left
		words.TextTruncate = Enum.TextTruncate.AtEnd
		words.TextSize = WORDS
		words.Position = UDim2.fromOffset(ICON + 14, 0)
		words.Size = UDim2.new(1, -(ICON + 18 + TICK), 1, 0)
		Kit.minText(words)
		words.Parent = frame
		local tick = Instance.new("TextLabel")
		tick.Name = "Tick"
		tick.BackgroundTransparency = 1
		tick.AnchorPoint = Vector2.new(1, 0.5)
		tick.Position = UDim2.new(1, -6, 0.5, 0)
		tick.Size = UDim2.fromOffset(TICK, TICK)
		tick.Text = "✓"
		tick.TextScaled = true -- a mark, not words
		tick.TextColor3 = TICK_GREEN
		tick.Font = Kit.FONT
		tick.Parent = frame
		table.insert(rows, { frame = frame, iconBox = iconBox, words = words, tick = tick })
	end
	card.Parent = root

	parts = { card = card, scale = scale, rows = rows }
	StepList.onFlagsChanged(redraw)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

return StepList
