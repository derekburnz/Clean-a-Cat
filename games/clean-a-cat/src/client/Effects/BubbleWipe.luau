--!strict
-- BubbleWipe: a quick bubbly wipe across the screen for the wash screen (issue 856, Derek: "a quick bubbly across
-- screen animation when transitioning to it"). Gameplay's WashScreenController calls it on the way in and on the way
-- out, behind its switch washScreen; this module has no switch of its own.
--
-- Pastel bubbles sweep in from the left and grow until they overlap, a solid fill closes any gap, onCovered runs
-- once while the screen is fully covered, then the bubbles shrink away in the same direction. COVER seconds in,
-- UNCOVER seconds out. One soft bubblePop on the way in. About 30 plain round Frames, no images, no particles, so
-- the iPhone 12 keeps its frame rate.
--
-- Reduced Motion (UI/Comfort): a plain fade of the same fill, FADE seconds each way, no sweep.
--
--   BubbleWipe.grow(t, column) -> number    pure: bubble size (0 to about 1.1) in `column` at t seconds into the cover
--   BubbleWipe.shrink(t, column) -> number  pure: the same while uncovering (1 to 0)
--   BubbleWipe.covered(t) -> boolean        pure: every bubble is full at t seconds into the cover
--   BubbleWipe.play(onCovered)              covers, calls onCovered once (errors are caught and logged), uncovers
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BubbleWipe = {}

BubbleWipe.COVER = 0.3
BubbleWipe.UNCOVER = 0.3
BubbleWipe.FADE = 0.15 -- Reduced Motion, each way
BubbleWipe.COLUMNS = 6
BubbleWipe.ROWS = 4
BubbleWipe.GROW = 0.16 -- seconds one bubble takes to grow; the sweep spreads the starts over the rest
BubbleWipe.OVER = 1.1 -- a small bubbly overshoot at the top of the grow
BubbleWipe.COLOURS = {
	Color3.fromHex("BFEFFF"), -- soap blue
	Color3.fromHex("FFD6EA"), -- pink
	Color3.fromHex("FFF6EC"), -- cream (Kit.CREAM)
} :: { Color3 }
BubbleWipe.FILL = Color3.fromHex("DDF5FF")

local function spread(total: number): number
	return total - BubbleWipe.GROW
end

-- 0 to 1 over GROW, rising past 1 to OVER and settling back to 1 (an ease-out with a small overshoot)
local function swell(k: number): number
	if k <= 0 then
		return 0
	end
	if k >= 1 then
		return 1
	end
	if k < 0.7 then
		local u = k / 0.7
		return BubbleWipe.OVER * (1 - (1 - u) * (1 - u))
	end
	local u = (k - 0.7) / 0.3
	return BubbleWipe.OVER + (1 - BubbleWipe.OVER) * u
end

local function startOf(column: number, total: number): number
	return (column - 1) / math.max(BubbleWipe.COLUMNS - 1, 1) * spread(total)
end

function BubbleWipe.grow(t: number, column: number): number
	return swell((t - startOf(column, BubbleWipe.COVER)) / BubbleWipe.GROW)
end

function BubbleWipe.shrink(t: number, column: number): number
	local k = math.clamp((t - startOf(column, BubbleWipe.UNCOVER)) / BubbleWipe.GROW, 0, 1)
	return 1 - k * k
end

function BubbleWipe.covered(t: number): boolean
	return t >= BubbleWipe.COVER
end

local function call(onCovered: () -> ())
	local ok, problem = pcall(function()
		onCovered()
	end)
	if not ok then
		warn("[BubbleWipe] onCovered failed: " .. tostring(problem))
	end
end

-- Runs `each(t)` every frame for `seconds`, then once more at the end; yields until done.
local function run(seconds: number, each: (number) -> ())
	local began = os.clock()
	while true do
		local t = os.clock() - began
		if t >= seconds then
			each(seconds)
			return
		end
		each(t)
		RunService.RenderStepped:Wait()
	end
end

local function reducedMotion(): boolean
	local ok, on = pcall(function()
		local Comfort =
			require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort")) :: any
		return Comfort.reducedMotion()
	end)
	return ok and on == true
end

local function sound()
	pcall(function()
		local Audio = require(script.Parent.Parent:WaitForChild("Audio")) :: any
		Audio.play("bubblePop")
	end)
end

local function makeGui(): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CleanACat_Fx_BubbleWipe"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100 -- over every window and the wash interface
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = BubbleWipe.FILL
	fill.BackgroundTransparency = 1
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = 1
	fill.Active = true -- swallows taps while it shows
	fill.Parent = gui
	return gui, fill
end

local function fadeWipe(gui: ScreenGui, fill: Frame, onCovered: () -> ())
	run(BubbleWipe.FADE, function(t)
		fill.BackgroundTransparency = 1 - t / BubbleWipe.FADE
	end)
	call(onCovered)
	RunService.RenderStepped:Wait()
	run(BubbleWipe.FADE, function(t)
		fill.BackgroundTransparency = t / BubbleWipe.FADE
	end)
	gui:Destroy()
end

local function bubbleWipe(gui: ScreenGui, fill: Frame, onCovered: () -> ())
	-- one bubble per cell, each big enough that its circle covers its cell's corners (diameter 1.5 x the cell's
	-- longer side), so neighbours overlap; rows are staggered by half a cell for a bubbly edge
	local bubbles: { { frame: Frame, column: number } } = {}
	local cols, rows = BubbleWipe.COLUMNS, BubbleWipe.ROWS
	for row = 1, rows do
		for column = 1, cols do
			local bubble = Instance.new("Frame")
			bubble.Name = "Bubble"
			bubble.BorderSizePixel = 0
			bubble.AnchorPoint = Vector2.new(0.5, 0.5)
			bubble.Position =
				UDim2.fromScale((column - 0.5) / cols, (row - 0.5 + (column % 2) * 0.25) / rows)
			bubble.Size = UDim2.fromScale(0, 0)
			bubble.BackgroundColor3 = BubbleWipe.COLOURS[(row + column) % #BubbleWipe.COLOURS + 1]
			bubble.ZIndex = 2
			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.DominantAxis = Enum.DominantAxis.Width
			ratio.Parent = bubble
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = bubble
			bubble.Parent = gui
			table.insert(bubbles, { frame = bubble, column = column })
		end
	end
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local cell = math.max(view.X / cols, view.Y / rows)
	local full = 1.5 * cell / math.max(view.X, 1) -- the diameter as a share of the screen's width

	local function size(k: number)
		return UDim2.fromScale(full * k, full * k)
	end

	sound()
	run(BubbleWipe.COVER, function(t)
		for _, b in bubbles do
			b.frame.Size = size(BubbleWipe.grow(t, b.column))
		end
	end)
	fill.BackgroundTransparency = 0
	call(onCovered)
	RunService.RenderStepped:Wait() -- one covered frame, so whatever onCovered built is drawn before the reveal
	fill.BackgroundTransparency = 1
	run(BubbleWipe.UNCOVER, function(t)
		for _, b in bubbles do
			b.frame.Size = size(BubbleWipe.shrink(t, b.column))
		end
	end)
	gui:Destroy()
end

function BubbleWipe.play(onCovered: () -> ())
	local player = Players.LocalPlayer
	local gui, fill = makeGui()
	gui.Parent = player:WaitForChild("PlayerGui")
	local called = false
	local function once()
		if not called then
			called = true
			call(onCovered)
		end
	end
	task.spawn(function()
		local ok, problem = pcall(function()
			if reducedMotion() then
				fadeWipe(gui, fill, once)
			else
				bubbleWipe(gui, fill, once)
			end
		end)
		if not ok then
			warn("[BubbleWipe] " .. tostring(problem))
			gui:Destroy()
			once() -- the screen still changes, even if the wipe broke before covering (Review-QA, PR 860)
		end
	end)
end

return BubbleWipe
