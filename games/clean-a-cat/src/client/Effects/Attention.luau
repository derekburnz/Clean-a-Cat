--!strict
-- Attention: a HUD button that gently asks to be pressed (Derek, 2026-11-25: the starter pack's button should bob
-- bigger and smaller with shiny sparkles popping round it). Design-Agent's spec: the `hud` state of
-- assets/clean-a-cat/ui/screens/starterpack.html (PR 493).
--
--   bob       the button's UIScale goes 1.00 to 1.08 and back over BOB_SECONDS, sine in and out, `bobs` times,
--             then the button sits still (it never loops: Growth-Agent's ruling via Review-QA, 2026-11-25)
--   sparkles  three small stars at the top-left, right and bottom-left edges pop in turn, one every SPARKLE_GAP on a
--             SPARKLE_CYCLE: they grow from 0.3 to 1.1 with a 20 degree turn as they fade in, then shrink and fade
--             out by 45% of the cycle; only while the bobs play (a pop under way finishes)
--   settle    when the bobs end the button rests at its own scale with one still star, and the frame loop lets go
--   comfort   Reduced Motion or Less sparkle (UI/Comfort): nothing moves; it settles at once
--
-- THE CALLER OWNS THE LIMIT (our monetization policy: no endless nagging): 3 bobs on the button's first appearance,
-- 1 on each later visit, and no call at all once the player has opened the pack window or after three visits. That
-- per-player count lives with the caller (the save or the controller), not here.
--
-- Client only and cosmetic. It steps only while the button is visible inside an enabled ScreenGui, and lets go by
-- itself when the button is destroyed. Any HUD button can use it. The stars are the HUD's Sparkle icon
-- (UI/HUD/Icons), already uploaded to the group.
--
-- API
--   Attention.start(button, bobs?) -> Handle   plays `bobs` (default DEFAULT_BOBS) bobs with sparkles, then settles;
--                                           handle.stop() removes the stars and puts the button back as it was
--   Attention.length(bobs) -> number       pure: seconds until it is all over, the last sparkle's fade included
--   Attention.bob(t) -> number             pure: the scale at `t` seconds
--   Attention.sparkle(t, index) -> (scale, transparency, degrees)   pure: sparkle `index` (1 to 3) at `t` seconds
local RunService = game:GetService("RunService")

local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort"))
local Icons =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons"))

local Attention = {}

Attention.BOB_SECONDS = 1.6
Attention.DEFAULT_BOBS = 3
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

function Attention.bob(t: number): number
	return 1 + Attention.BOB_SIZE * 0.5 * (1 - math.cos(2 * math.pi * t / Attention.BOB_SECONDS))
end

-- Sparkle `index` at `t`; with `cutoff` set, a pop that would start at or after `cutoff` seconds is not shown.
function Attention.sparkle(t: number, index: number, cutoff: number?): (number, number, number)
	local cycle = Attention.SPARKLE_CYCLE
	local since = t - (index - 1) * Attention.SPARKLE_GAP
	if since < 0 then
		return 0, 1, 0
	end
	if
		cutoff
		and since - (since % cycle) + (index - 1) * Attention.SPARKLE_GAP >= cutoff - 1e-6
	then
		return 0, 1, 0
	end
	local u = (since % cycle) / cycle
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

function Attention.length(bobs: number): number
	return bobs * Attention.BOB_SECONDS + Attention.SPARKLE_OUT * Attention.SPARKLE_CYCLE
end

export type Handle = { stop: () -> () }

type Star = { holder: ImageLabel }

local function makeStar(button: GuiObject, i: number): Star
	local spot = Attention.SPOTS[i]
	-- the HUD's own Sparkle icon (Review-QA after #553: crossed bars beside a button read as a plus or a close mark)
	local holder = Instance.new("ImageLabel")
	holder.Name = "AttentionSparkle" .. i
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(spot.x, spot.y)
	holder.Size = UDim2.fromScale(spot.size, spot.size)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.ScaleType = Enum.ScaleType.Fit
	holder.Image = Icons.IMAGES.Sparkle
	holder.ImageTransparency = 1
	holder.ZIndex = button.ZIndex + 2
	holder.Parent = button
	return { holder = holder }
end

local function show(star: Star, i: number, scale: number, seen: number, degrees: number)
	local size = Attention.SPOTS[i].size * scale
	star.holder.Size = UDim2.fromScale(size, size)
	star.holder.Rotation = degrees
	star.holder.ImageTransparency = seen
end

function Attention.start(button: GuiObject, bobs: number?): Handle
	local count = math.max(0, math.floor(bobs or Attention.DEFAULT_BOBS))
	local playFor = count * Attention.BOB_SECONDS
	local endAt = Attention.length(count)
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

	local stars: { Star } = {}
	for i = 1, #Attention.SPOTS do
		table.insert(stars, makeStar(button, i))
	end

	local start = os.clock()
	local stepping: RBXScriptConnection? = nil
	local watchers: { RBXScriptConnection } = {}
	local settled = false
	local stopped = false

	-- the rest pose, written once: own scale, the first star still, the others hidden; the frame loop lets go
	local function settle()
		if settled then
			return
		end
		settled = true
		local c = stepping
		if c then
			c:Disconnect()
			stepping = nil
		end
		uiScale.Scale = base
		for i, star in stars do
			show(star, i, 1, if i == 1 then 0 else 1, 0)
		end
	end

	local function frame()
		local t = os.clock() - start
		if t >= endAt or Comfort.reducedMotion() or Comfort.lessSparkle() then
			settle()
			return
		end
		uiScale.Scale = if t < playFor then base * Attention.bob(t) else base
		for i, star in stars do
			local s, seen, degrees = Attention.sparkle(t, i, playFor)
			show(star, i, s, seen, degrees)
		end
	end

	local screen = button:FindFirstAncestorWhichIsA("ScreenGui")
	local function shown(): boolean
		local gui = button:FindFirstAncestorWhichIsA("ScreenGui")
		return button.Visible and button.Parent ~= nil and (gui == nil or gui.Enabled)
	end

	local function run()
		if settled or stopped then
			return
		end
		if shown() and stepping == nil then
			stepping = RunService.RenderStepped:Connect(frame)
			frame()
		elseif not shown() and stepping then
			local c = stepping :: RBXScriptConnection
			c:Disconnect()
			stepping = nil
		end
	end

	local function stop()
		if stopped then
			return
		end
		stopped = true
		local c = stepping
		if c then
			c:Disconnect()
			stepping = nil
		end
		for _, w in watchers do
			w:Disconnect()
		end
		for _, star in stars do
			star.holder:Destroy()
		end
		if made then
			uiScale:Destroy()
		elseif uiScale.Parent then
			uiScale.Scale = base
		end
	end

	table.insert(watchers, button:GetPropertyChangedSignal("Visible"):Connect(run))
	if screen then
		table.insert(watchers, screen:GetPropertyChangedSignal("Enabled"):Connect(run))
	end
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
	if count == 0 or Comfort.reducedMotion() or Comfort.lessSparkle() then
		settle()
	else
		run()
	end
	return { stop = stop }
end

return Attention
