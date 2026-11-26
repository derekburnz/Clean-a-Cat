--!strict
-- WashPops: little pop ups during the wash (issue 902; Derek's playtest, 2026-11-26: "little pop ups still needed for cleaning
-- minigames", with his My Pet Salon video as the feel to study; ideas only, our own words and look). Behind the switch
-- washPops, off by default. Controllers/WashPopsController feeds it from the wash's own signals.
--
--   cheer   a word pops over the cat as a step's progress passes a mark (MARKS: "Nice!" at a third, "Nearly there!"
--           at two thirds), with a soft chime
--   done    the step's own word when it ends (DONE_WORDS: "Squeaky clean!", "So fresh!", "Neat paws!", "So fluffy!",
--           "Too cute!"), a little bigger, over the cat
--   combo   quick hits on the cat (mud, foam, claws, brush strokes) less than CHAIN seconds apart count up; from the
--           second one a small "x N" pops where the latest hit landed, with a thin ring that spreads from it
--
-- Look: Fredoka One, white words with the HUD's plum outline and a gold fill for the done word; each word grows from
-- 0.6 past 1.12 to 1, tilts a few degrees, rises and fades over WORD_SECONDS. Words sit over the cat, kept inside
-- the middle of the screen and under the top TOP_CLEAR share where the step title lives. At most MAX_WORDS words at
-- once (an older one leaves early). Reduced Motion: words fade in and out in place, no grow, tilt or rise. Less
-- sparkle: no rings.
--
--   WashPops.word(t, seconds) -> (scale, rise, seen)   pure: a word's grow, rise share and how shown at t seconds
--   WashPops.marksPassed(before, after) -> { number }  pure: the MARKS indexes a progress move from before to after
--                                                      crossed (0 to 1 each)
--   WashPops.chain(state, now) -> number               pure: counts a hit; the combo count after it
--   WashPops.cheer(text, at, kind)                     shows a word over world point `at` ("cheer" or "done")
--   WashPops.combo(count, at)                          shows the combo count at world point `at`
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WashPops = {}

WashPops.MARKS = { 1 / 3, 2 / 3 } :: { number }
WashPops.MARK_WORDS = { "Nice!", "Nearly there!" } :: { string }
WashPops.DONE_WORDS = {
	scrub = "Squeaky clean!",
	rinse = "So fresh!",
	claws = "Neat paws!",
	brush = "So fluffy!",
	bow = "Too cute!",
} :: { [string]: string }
WashPops.CHAIN = 0.9 -- seconds between hits that still count as one combo
WashPops.WORD_SECONDS = 0.9
WashPops.COMBO_SECONDS = 0.5
WashPops.RING_SECONDS = 0.35
WashPops.MAX_WORDS = 2
WashPops.TOP_CLEAR = 0.2 -- of the screen's height: the step title's band
WashPops.WORD_SIZE = 34 -- design px (scaled like the HUD)
WashPops.DONE_SIZE = 42
WashPops.COMBO_SIZE = 24
WashPops.GOLD = Color3.fromHex("FFC94D")
WashPops.INK = Color3.fromHex("45226B")

function WashPops.word(t: number, seconds: number): (number, number, number)
	local u = math.clamp(t / seconds, 0, 1)
	local scale
	if u < 0.12 then
		local k = u / 0.12
		scale = 0.6 + (1.12 - 0.6) * (1 - (1 - k) * (1 - k))
	elseif u < 0.22 then
		scale = 1.12 - 0.12 * ((u - 0.12) / 0.1)
	else
		scale = 1
	end
	local rise = u
	local seen = if u < 0.08 then u / 0.08 elseif u > 0.7 then 1 - (u - 0.7) / 0.3 else 1
	return scale, rise, seen
end

function WashPops.marksPassed(before: number, after: number): { number }
	local out: { number } = {}
	for i, mark in WashPops.MARKS do
		if before < mark and after >= mark then
			table.insert(out, i)
		end
	end
	return out
end

export type Chain = { last: number, count: number }

function WashPops.newChain(): Chain
	return { last = -math.huge, count = 0 }
end

function WashPops.chain(state: Chain, now: number): number
	if now - state.last <= WashPops.CHAIN then
		state.count += 1
	else
		state.count = 1
	end
	state.last = now
	return state.count
end

type Pop = {
	label: TextLabel,
	ring: Frame?,
	born: number,
	seconds: number,
	at: Vector2,
	rise: number, -- px over the whole life
	still: boolean,
	tilt: number,
}

local gui: ScreenGui? = nil
local words: { Pop } = {}
local others: { Pop } = {}
local comboPop: Pop? = nil
local stepping: RBXScriptConnection? = nil

local function comfort(): (boolean, boolean)
	local ok, still, calm = pcall(function()
		local Comfort =
			require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort")) :: any
		return Comfort.reducedMotion(), Comfort.lessSparkle()
	end)
	if not ok then
		return false, false
	end
	return still == true, calm == true
end

local function scale(): number
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(size.X / 1280, size.Y / 720), 0.75, 1.3)
end

local function screen(): ScreenGui
	local g = gui
	if g and g.Parent then
		return g
	end
	local made = Instance.new("ScreenGui")
	made.Name = "CleanACat_Fx_WashPops"
	made.ResetOnSpawn = false
	made.IgnoreGuiInset = true
	made.DisplayOrder = 20
	made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = made
	return made
end

WashPops.HUD_NAMES = { "WashMeter", "StepList" } -- the wash HUD pieces a word must stay below
WashPops.HUD_GAP = 26 -- px under the lowest of them

-- The screen y just under the lowest wash HUD piece that is showing (the step title, dots and bar), or 0. Sync's
-- capture of the first build showed the done word over the next step's title and "Nice!" over the step dots.
local function hudFloor(): number
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return 0
	end
	local floor = 0
	for _, name in WashPops.HUD_NAMES do
		local piece = playerGui:FindFirstChild(name, true)
		if piece and piece:IsA("GuiObject") then
			local g = piece :: GuiObject
			local layer = g:FindFirstAncestorOfClass("ScreenGui")
			if g.Visible and (layer == nil or layer.Enabled) and g.AbsoluteSize.Y > 0 then
				floor = math.max(floor, g.AbsolutePosition.Y + g.AbsoluteSize.Y + WashPops.HUD_GAP)
			end
		end
	end
	return floor
end

-- Where world point `at` falls on screen, kept inside the middle and under the title band and the wash HUD; nil
-- behind the camera.
local function onScreen(at: Vector3, lift: number): Vector2?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local point, visible = camera:WorldToViewportPoint(at)
	if not visible or point.Z <= 0 then
		return nil
	end
	local size = camera.ViewportSize
	local x = math.clamp(point.X, size.X * 0.15, size.X * 0.85)
	local top = math.max(size.Y * WashPops.TOP_CLEAR + 30, hudFloor())
	local y = math.clamp(point.Y - lift, math.min(top, size.Y * 0.85), size.Y * 0.85)
	return Vector2.new(x, y)
end

local function label(text: string, px: number, gold: boolean, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = "Pop"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextSize = px
	l.TextColor3 = if gold then WashPops.GOLD else Color3.new(1, 1, 1)
	l.TextTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = WashPops.INK
	s.Thickness = math.max(2, math.floor(px / 11))
	s.Transparency = 1
	s.Parent = l
	l.Parent = parent
	return l
end

local function drop(p: Pop)
	p.label:Destroy()
	if p.ring then
		p.ring:Destroy()
	end
end

local function step()
	local now = os.clock()
	local function run(p: Pop): boolean
		local t = now - p.born
		if t >= p.seconds then
			drop(p)
			return false
		end
		local grow, rise, seen = WashPops.word(t, p.seconds)
		if p.still then
			grow, rise = 1, 0
		end
		local stroke = p.label:FindFirstChildOfClass("UIStroke") :: UIStroke?
		p.label.Position = UDim2.fromOffset(p.at.X, p.at.Y - p.rise * rise)
		p.label.TextTransparency = 1 - seen
		if stroke then
			stroke.Transparency = 1 - seen
		end
		local ui = p.label:FindFirstChildOfClass("UIScale") :: UIScale?
		if ui then
			ui.Scale = grow
		end
		p.label.Rotation = if p.still then 0 else p.tilt * (1 - math.min(t / (p.seconds * 0.3), 1))
		local ring = p.ring
		if ring then
			local r = math.clamp(t / WashPops.RING_SECONDS, 0, 1)
			local d = math.floor(14 + 46 * r)
			ring.Size = UDim2.fromOffset(d, d)
			local edge = ring:FindFirstChildOfClass("UIStroke") :: UIStroke?
			if edge then
				edge.Transparency = 0.2 + 0.8 * r
			end
		end
		return true
	end
	for i = #words, 1, -1 do
		if not run(words[i]) then
			table.remove(words, i)
		end
	end
	for i = #others, 1, -1 do
		if not run(others[i]) then
			if comboPop == others[i] then
				comboPop = nil
			end
			table.remove(others, i)
		end
	end
	if #words == 0 and #others == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function track(p: Pop, list: { Pop })
	local ui = Instance.new("UIScale")
	ui.Parent = p.label
	table.insert(list, p)
	if stepping == nil then
		stepping = RunService.RenderStepped:Connect(step)
	end
	step()
end

function WashPops.cheer(text: string, at: Vector3, kind: "cheer" | "done")
	local spot = onScreen(at, 40)
	if spot == nil then
		return
	end
	while #words >= WashPops.MAX_WORDS do
		drop(table.remove(words, 1) :: Pop)
	end
	local still = comfort()
	local done = kind == "done"
	local px = math.floor((if done then WashPops.DONE_SIZE else WashPops.WORD_SIZE) * scale())
	track({
		label = label(text, px, done, screen()),
		ring = nil,
		born = os.clock(),
		seconds = WashPops.WORD_SECONDS * (if done then 1.2 else 1),
		at = spot,
		rise = 36,
		still = still,
		tilt = if done then -6 else 5,
	}, words)
end

function WashPops.combo(count: number, at: Vector3)
	local spot = onScreen(at, 10)
	if spot == nil then
		return
	end
	local still, calm = comfort()
	local old = comboPop
	if old then
		-- one counter at a time: the old one goes as the new count pops
		old.born = -math.huge
	end
	local parent = screen()
	local ring: Frame? = nil
	if not calm and not still then
		local r = Instance.new("Frame")
		r.Name = "Ring"
		r.BackgroundTransparency = 1
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromOffset(spot.X, spot.Y)
		r.Size = UDim2.fromOffset(14, 14)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = r
		local edge = Instance.new("UIStroke")
		edge.Color = WashPops.GOLD
		edge.Thickness = 3
		edge.Parent = r
		r.Parent = parent
		ring = r
	end
	local px = math.floor(WashPops.COMBO_SIZE * scale())
	local p: Pop = {
		label = label("x" .. count, px, true, parent),
		ring = ring,
		born = os.clock(),
		seconds = WashPops.COMBO_SECONDS,
		at = spot + Vector2.new(26, -18),
		rise = 16,
		still = still,
		tilt = 8,
	}
	comboPop = p
	track(p, others)
end

return WashPops
