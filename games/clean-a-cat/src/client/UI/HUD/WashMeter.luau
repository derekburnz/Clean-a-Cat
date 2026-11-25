--!strict
-- WashMeter: the bar at the top centre that fills while the player works an area step of the wash (Derek's salon
-- video of 2026-11-25: a bar that fills as you scrub, full at about 90 percent done, then the cat shakes off the rest
-- and the next step starts). The behaviour is ScrubController's, behind the switch washMeter: it sends a fraction
-- from 0 to 1 and the step, or nil to hide the bar. This file is only the look (Design-Agent), shown with the game
-- HUD (gameHud).
--
--   WashMeter.build(root)              makes it once, hidden
--   WashMeter.set(fraction, step)      fills the bar; nil hides it. step is "scrub", "brush", "lather", "rinse" or
--                                      "claws" and picks the bar's colour, its icon and the last cheer
--   WashMeter.place(top)               the real px from the root's top where the bar starts (under the step line or
--                                      the tutorial's pill, HUD.redraw)
--
-- The look: a cream track with the kit's ink edge, filled in the step's colour with a soft shine, the percent in
-- outlined white at its right end, and the step's need icon (mud, tangles...) in a round white badge over its left
-- end. A short cheer pops under it as it fills: "Keep going!" at half, "Almost!" at 80 percent and the step's own
-- word when full ("Squeaky clean!"), each once per step. Reduced Motion (Comfort) shows the cheer without the pop.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("Comfort"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local WashMeter = {}

-- One look per step: the fill colour, the need icon on the badge and the cheer when full.
type Look = { fill: Color3, icon: string, done: string }
WashMeter.LOOKS = {
	scrub = { fill = Color3.fromHex("7EE0B5"), icon = "Mud", done = "Squeaky clean!" },
	brush = { fill = Color3.fromHex("FFB3D9"), icon = "Tangles", done = "So fluffy!" },
	lather = { fill = Color3.fromHex("C9B6FF"), icon = "Smell", done = "So foamy!" },
	rinse = { fill = Color3.fromHex("63C7FF"), icon = "Wet", done = "All rinsed!" },
	claws = { fill = Color3.fromHex("FFC94D"), icon = "Claws", done = "Nice paws!" },
} :: { [string]: Look }
local FALLBACK = WashMeter.LOOKS.scrub

-- The cheers on the way, as { at, words }; the last one (full) is the step's own.
WashMeter.CHEERS = {
	{ at = 0.5, say = "Keep going!" },
	{ at = 0.8, say = "Almost!" },
}
local FULL = 0.999 -- the controller sends 1 when the bar is full

-- Sizes in design pixels (a 1280 x 720 canvas, scaled by Kit.screenScale like the rest of the HUD).
local WIDTH = 380 -- the whole piece: badge plus track
local BADGE = 60 -- the round icon badge; the icon inside is 48, the house floor for model icons
local ICON = 48
local TRACK_HEIGHT = 30
local TRACK_LEFT = 30 -- the track starts under the badge's middle, so the badge sits on its left end
local STROKE = 4 -- the kit's ink edge
local INSET = 4 -- the fill sits this far inside the track's edge
local FILL_LEFT = BADGE / 2 - 6 -- in the track: the fill starts just under the badge's right edge, so a started bar shows
local PERCENT_TEXT = 24
local CHEER_TEXT = 30
local CHEER_GAP = 2 -- under the badge
local GAP = 8 -- between the step line (or tip pill) and the bar
local CHEER_SECONDS = 1.3
local FILL_SECONDS = 0.15 -- the fill eases to each new value, so a drag reads smooth

type Parts = {
	holder: Frame,
	scale: UIScale,
	fill: Frame,
	percent: TextLabel,
	badge: Frame,
	iconBox: Frame,
	cheer: TextLabel,
	cheerScale: UIScale,
}

local parts: Parts? = nil
local fraction: number? = nil
local step: string? = nil
local drawnIcon: string? = nil
local cheered: { [number]: boolean } = {} -- which cheers this step has shown (index into CHEERS, or 0 for full)
local cheerToken = 0

local function look(): Look
	local found: Look? = if step then WashMeter.LOOKS[step] else nil
	return found or FALLBACK
end

local function fillWidth(value: number): UDim2
	-- a sliver would draw as a dot with square ends, so a started bar is never thinner than it is tall
	local inner = WIDTH - TRACK_LEFT - FILL_LEFT - INSET
	local height = TRACK_HEIGHT - INSET * 2
	local width = if value > 0 then math.max(height, inner * value) else 0
	return UDim2.fromOffset(width, height)
end

local function popCheer(say: string)
	local p = parts
	if p == nil then
		return
	end
	cheerToken += 1
	local token = cheerToken
	p.cheer.Text = say
	p.cheer.TextTransparency = 0
	p.cheer.Visible = true
	if Comfort.reducedMotion() then
		p.cheerScale.Scale = 1
	else
		p.cheerScale.Scale = 0.6
		TweenService:Create(
			p.cheerScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end
	task.delay(CHEER_SECONDS, function()
		if token ~= cheerToken or parts == nil then
			return
		end
		if Comfort.reducedMotion() then
			p.cheer.Visible = false
			return
		end
		local fade = TweenService:Create(p.cheer, TweenInfo.new(0.3), { TextTransparency = 1 })
		fade.Completed:Connect(function()
			if token == cheerToken then
				p.cheer.Visible = false
			end
		end)
		fade:Play()
	end)
end

local function cheerFor(value: number)
	if value >= FULL then
		if not cheered[0] then
			cheered[0] = true
			popCheer(look().done)
		end
		return
	end
	-- only the highest cheer passed shows, so a jump from 40 to 85 percent says "Almost!" once
	local best: number? = nil
	for index, cheer in WashMeter.CHEERS do
		if value >= cheer.at and not cheered[index] then
			cheered[index] = true
			best = index
		end
	end
	if best then
		popCheer(WashMeter.CHEERS[best].say)
	end
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local value = fraction
	p.holder.Visible = value ~= nil
	if value == nil then
		p.cheer.Visible = false
		cheerToken += 1
		return
	end
	p.scale.Scale = Kit.screenScale()
	local l = look()
	p.fill.BackgroundColor3 = l.fill
	if drawnIcon ~= l.icon then
		drawnIcon = l.icon
		Icons.draw(l.icon, p.iconBox)
	end
	p.percent.Text = `{math.floor(value * 100 + 0.5)}%`
	local target = fillWidth(value)
	if Comfort.reducedMotion() then
		p.fill.Size = target
	else
		TweenService
			:Create(p.fill, TweenInfo.new(FILL_SECONDS, Enum.EasingStyle.Quad), { Size = target })
			:Play()
	end
	cheerFor(value)
end

function WashMeter.set(value: number?, newStep: string?)
	if newStep ~= step or value == nil then
		cheered = {} -- a new step (or a hidden bar) cheers again from the start
	end
	if value ~= nil and newStep == step and fraction ~= nil and value < fraction - 0.25 then
		cheered = {} -- the same step started over (the next cat)
	end
	step = newStep
	fraction = if value ~= nil then math.clamp(value, 0, 1) else nil
	redraw()
end

function WashMeter.place(top: number)
	local p = parts
	if p == nil then
		return
	end
	local scale = p.scale.Scale
	p.holder.Position = UDim2.new(0.5, 0, 0, top + GAP * (if scale > 0 then scale else 1))
end

function WashMeter.build(root: Instance)
	local holder = Instance.new("Frame")
	holder.Name = "WashMeter"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 60)
	holder.Size = UDim2.fromOffset(WIDTH, BADGE)
	holder.Visible = false
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = holder

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Kit.CREAM
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, TRACK_LEFT, 0.5, 0)
	track.Size = UDim2.fromOffset(WIDTH - TRACK_LEFT, TRACK_HEIGHT)
	Comfort.backdrop(track, 0)
	Kit.corner(track, UDim.new(1, 0))
	Kit.stroke(track, STROKE)
	track.Parent = holder

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.new(0, FILL_LEFT, 0.5, 0)
	fill.Size = fillWidth(0)
	Kit.corner(fill, UDim.new(1, 0))
	fill.Parent = track
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Kit.WHITE
	shine.BackgroundTransparency = 0.55
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 6, 0.18, 0)
	shine.Size = UDim2.new(1, -12, 0.24, 0)
	Kit.corner(shine, UDim.new(1, 0))
	shine.Parent = fill

	local percent = Kit.outlined("Percent", track)
	percent.AutomaticSize = Enum.AutomaticSize.None
	percent.AnchorPoint = Vector2.new(1, 0.5)
	percent.Position = UDim2.new(1, -12, 0.5, 0)
	percent.Size = UDim2.fromOffset(70, TRACK_HEIGHT)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.TextSize = PERCENT_TEXT
	percent.ZIndex = 2

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BackgroundColor3 = Kit.WHITE
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(0, TRACK_LEFT, 0.5, 0)
	badge.Size = UDim2.fromOffset(BADGE, BADGE)
	badge.ZIndex = 3
	Kit.corner(badge, UDim.new(1, 0))
	Kit.stroke(badge, STROKE)
	badge.Parent = holder
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundTransparency = 1
	iconBox.AnchorPoint = Vector2.new(0.5, 0.5)
	iconBox.Position = UDim2.fromScale(0.5, 0.5)
	iconBox.Size = UDim2.fromOffset(ICON, ICON)
	iconBox.ZIndex = 4
	iconBox.Parent = badge

	local cheer = Kit.outlined("Cheer", holder)
	cheer.AnchorPoint = Vector2.new(0.5, 0)
	cheer.Position = UDim2.new(0.5, TRACK_LEFT / 2, 1, CHEER_GAP)
	cheer.TextColor3 = Kit.GOLD_TEXT
	cheer.TextSize = CHEER_TEXT
	cheer.Visible = false
	local cheerScale = Instance.new("UIScale")
	cheerScale.Parent = cheer

	holder.Parent = root
	parts = {
		holder = holder,
		scale = scale,
		fill = fill,
		percent = percent,
		badge = badge,
		iconBox = iconBox,
		cheer = cheer,
		cheerScale = cheerScale,
	}
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
end

return WashMeter
