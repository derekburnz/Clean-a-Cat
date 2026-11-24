--!strict
-- TipLine: the tutorial's tip line at the top centre, from Design-Agent's draft (tutorial.html, states "trail" and
-- "tip"): an icon, "Step 2 of 3:" in gold and a few words, such as "Scrub the mud". It takes the wash step bar's place
-- while it shows, so there is still one line at the top centre. Behind the live switch tutorialTip, off by default
-- (rule 16: every first-session change ships behind its own switch), and only with the game HUD (gameHud) on.
--
--   TipLine.build(root)    makes it once
--   TipLine.set(tip)       shows a tip ({ step, total, icon, say }) or nil to take it away
--   TipLine.isShown()      true while a tip shows (the HUD hides its step bar then)
--   TipLine.onChanged(fn)  fn() when it shows or hides
--
-- It only shows words; which step comes when is the first session's call (issue #5), so nothing here sets a tip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("Icons"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local TipLine = {}

TipLine.FLAG = "tutorialTip"
local HUD_FLAG = "gameHud"

export type Tip = { step: number, total: number, icon: string, say: string }

-- Sizes in design pixels: full, then compact for a short screen.
local SIZES = {
	full = { icon = 48, step = 22, say = 30 },
	short = { icon = 48, step = 20, say = 27 },
}

type Parts = { holder: Frame, scale: UIScale, iconBox: Frame, step: TextLabel, say: TextLabel }

local parts: Parts? = nil
local tip: Tip? = nil
local drawnIcon: string? = nil
local listeners: { () -> () } = {}

function TipLine.isShown(): boolean
	return tip ~= nil and LiveFlags.isOn(TipLine.FLAG) and LiveFlags.isOn(HUD_FLAG)
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
	p.scale.Scale = scale
	p.iconBox.Size = UDim2.fromOffset(s.icon, s.icon)
	if drawnIcon ~= current.icon then
		drawnIcon = current.icon
		Icons.draw(current.icon, p.iconBox)
	end
	p.step.TextSize = s.step
	p.step.Text = `Step {current.step} of {current.total}:`
	p.say.TextSize = s.say
	p.say.Text = current.say
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

function TipLine.build(root: Instance)
	local holder = Instance.new("Frame")
	holder.Name = "TipLine"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 6)
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Visible = false
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = holder
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 14) -- room after "Step 2 of 3:" past both outlines (Review-QA on #258)
	list.Parent = holder
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundTransparency = 1
	iconBox.LayoutOrder = 1
	iconBox.Parent = holder
	local step = Kit.outlined("Step", holder)
	step.LayoutOrder = 2
	step.TextColor3 = Kit.GOLD_TEXT
	local say = Kit.outlined("Say", holder)
	say.LayoutOrder = 3
	holder.Parent = root

	parts = { holder = holder, scale = scale, iconBox = iconBox, step = step, say = say }
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
