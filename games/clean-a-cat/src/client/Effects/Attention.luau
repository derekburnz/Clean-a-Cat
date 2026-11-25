--!strict
-- Attention: a HUD button that gently asks to be pressed (Derek, 2026-11-25: the starter pack's button should bob
-- bigger and smaller with shiny sparkles popping round it). Design-Agent's spec: the `hud` state of
-- assets/clean-a-cat/ui/screens/starterpack.html (PR 493).
--
--   bob       the button's UIScale goes 1.00 to 1.08 and back over BOB_SECONDS, sine in and out, looping
--   sparkles  three small stars at the top-left, right and bottom-left edges pop in turn, one every SPARKLE_GAP on a
--             SPARKLE_CYCLE: they grow from 0.3 to 1.1 with a 20 degree turn as they fade in, then shrink and fade
--             out by 45% of the cycle
--   comfort   Reduced Motion or Less sparkle (UI/Comfort): no bob and one sparkle shown still
--
-- Client only and cosmetic. It works only while the button is visible, and lets go by itself when the button is
-- destroyed. Any HUD button can use it; the caller decides when (the starter pack's switch, for one).
--
-- API
--   Attention.start(button) -> Handle      handle.stop() puts the button back as it was
--   Attention.bob(t) -> number             pure: the scale at `t` seconds
--   Attention.sparkle(t, index) -> (scale, transparency, degrees)   pure: sparkle `index` (1 to 3) at `t` seconds
local RunService = game:GetService("RunService")

local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort"))

local Attention = {}

Attention.BOB_SECONDS = 1.6
Attention.BOB_SIZE = 0.08
Attention.SPARKLE_CYCLE = 2.4
Attention.SPARKLE_GAP = 0.8
Attention.SPARKLE_IN = 0.15 -- share of the cycle spent popping in
Attention.SPARKLE_OUT = 0.45 -- share of the cycle by which it is gone
Attention.SPARKLE_TURN = 20 -- degrees while popping in
-- where each star sits on the button (its middle, as a share of the button), and how big (share of its height)
Attention.SPOTS = table.freeze({
	{ x = 0.06, y = 0.08, size = 0.34 },
	{ x = 1.0, y = 0.42, size = 0.28 },
	{ x = 0.1, y = 0.94, size = 0.24 },
})
local GOLD = Color3.fromRGB(255, 226, 120)
local WHITE = Color3.fromRGB(255, 255, 255)

function Attention.bob(t: number): number
	return 1 + Attention.BOB_SIZE * 0.5 * (1 - math.cos(2 * math.pi * t / Attention.BOB_SECONDS))
end

function Attention.sparkle(t: number, index: number): (number, number, number)
	local cycle = Attention.SPARKLE_CYCLE
	local u = ((t - (index - 1) * Attention.SPARKLE_GAP) % cycle) / cycle
	local inEnd, outEnd = Attention.SPARKLE_IN, Attention.SPARKLE_OUT
	if u < inEnd then
		local k = u / inEnd
		local e = 1 - (1 - k) * (1 - k) -- eased out: a quick pop
		return 0.3 + 0.8 * e, 1 - e, Attention.SPARKLE_TURN * e
	elseif u < outEnd then
		local k = (u - inEnd) / (outEnd - inEnd)
		local e = k * k -- eased in: lingers, then goes
		return 1.1 * (1 - e), e, Attention.SPARKLE_TURN + 10 * k
	end
	return 0, 1, 0
end

export type Handle = { stop: () -> () }

function Attention.start(button: GuiObject): Handle
	local made = false
	local scale = button:FindFirstChildOfClass("UIScale")
	if scale == nil then
		local s = Instance.new("UIScale")
		s.Name = "AttentionScale"
		s.Parent = button
		scale = s
		made = true
	end
	local uiScale = scale :: UIScale
	local base = uiScale.Scale

	local stars: { TextLabel } = {}
	for i, spot in Attention.SPOTS do
		local star = Instance.new("TextLabel")
		star.Name = "AttentionSparkle" .. i
		star.BackgroundTransparency = 1
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(spot.x, spot.y)
		star.Size = UDim2.fromScale(spot.size, spot.size)
		star.SizeConstraint = Enum.SizeConstraint.RelativeYY
		star.Text = "✦"
		star.TextScaled = true
		star.TextColor3 = if i == 2 then WHITE else GOLD
		star.TextTransparency = 1
		star.ZIndex = button.ZIndex + 2
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 180, 60)
		stroke.Thickness = 1
		stroke.Transparency = 0.4
		stroke.Parent = star
		star.Parent = button
		table.insert(stars, star)
	end

	local start = os.clock()
	local stepping: RBXScriptConnection? = nil
	local watchers: { RBXScriptConnection } = {}
	local stopped = false

	local function frame()
		local t = os.clock() - start
		if Comfort.reducedMotion() or Comfort.lessSparkle() then
			uiScale.Scale = base
			for i, star in stars do
				star.TextTransparency = if i == 1 then 0 else 1
				star.Rotation = 0
				star.Size = UDim2.fromScale(Attention.SPOTS[i].size, Attention.SPOTS[i].size)
			end
			return
		end
		uiScale.Scale = base * Attention.bob(t)
		for i, star in stars do
			local s, seen, degrees = Attention.sparkle(t, i)
			local size = Attention.SPOTS[i].size * s
			star.Size = UDim2.fromScale(size, size)
			star.TextTransparency = seen
			star.Rotation = degrees
		end
	end

	local function run()
		local shown = button.Visible and button.Parent ~= nil
		if shown and stepping == nil then
			stepping = RunService.RenderStepped:Connect(frame)
			frame()
		elseif not shown and stepping then
			stepping:Disconnect()
			stepping = nil
		end
	end

	local function stop()
		if stopped then
			return
		end
		stopped = true
		if stepping then
			stepping:Disconnect()
			stepping = nil
		end
		for _, c in watchers do
			c:Disconnect()
		end
		for _, star in stars do
			star:Destroy()
		end
		if made then
			uiScale:Destroy()
		elseif uiScale.Parent then
			uiScale.Scale = base
		end
	end

	table.insert(watchers, button:GetPropertyChangedSignal("Visible"):Connect(run))
	table.insert(
		watchers,
		button.AncestryChanged:Connect(function()
			if button.Parent == nil then
				stop()
			else
				run()
			end
		end)
	)
	run()
	return { stop = stop }
end

return Attention
