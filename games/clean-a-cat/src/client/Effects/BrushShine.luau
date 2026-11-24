--!strict
-- BrushShine: how the coat looks while it is brushed (Derek's dev test 2026-11-24: "no need for that [the fur puffs]
-- just have it shine top to bottom then sparkle when done and show a gradual color change when brushing").
--
-- The coat goes from the wet look (darkened by the cat's WetDarken) back to its dry colour a share at a time, one
-- share each brush stroke. Each stroke also sends a soft shine down the coat from the top of the cat to the bottom,
-- and the last stroke ends in a sparkle. This module is the only writer of the coat's colours once a cat is tracked,
-- so the wet look and the shine never fight over a part's Color.
--
-- Client only, like every Effect. The shine and the sparkle sit behind the `fluffEffects` switch (the caller checks);
-- the wet look itself is part of the wash and always runs.
--
-- API
--   BrushShine.track(cat, coat, wetDarken)  takes over the coat: `coat` maps each coat part to its dry colour
--   BrushShine.setWet(cat, amount)          0 dry to 1 fully wet (the scrub sets 1, each stroke lowers it)
--   BrushShine.sweep(cat)                   one shine from the top of the coat to the bottom
--   BrushShine.done(cat)                    the last sweep and a sparkle over the coat
--   BrushShine.untrack(cat)                 puts the dry colours back and lets go
--   BrushShine.band(height, along)          the shine's strength on a part `height` (0 bottom, 1 top) of the way up
--                                           the coat, `along` (0 to 1) the sweep; pure, for the specs
--   BrushShine.tint(dry, keep, shine)       a part's colour: its dry colour darkened to `keep`, lifted by `shine`
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local BrushShine = {}

BrushShine.SWEEP = table.freeze({
	seconds = 0.55, -- top to bottom
	band = 0.35, -- the shine's width, as a share of the coat's height
	lift = 0.45, -- how far toward the shine colour a part goes at the band's middle
	color = Color3.fromRGB(255, 252, 240), -- a warm white
})
BrushShine.SPARKLE = "revealSparkle"

type Entry = {
	coat: { [BasePart]: Color3 },
	darken: number,
	wet: number,
	sweeps: { number }, -- start times of the sweeps still running
	dirty: boolean, -- colours to write this frame
}

local entries: { [Model]: Entry } = {}
local connection: RBXScriptConnection? = nil

function BrushShine.band(height: number, along: number): number
	local band = BrushShine.SWEEP.band
	-- the band's middle starts just over the top and ends just under the bottom, so the whole coat is crossed
	local middle = 1 + band / 2 - math.clamp(along, 0, 1) * (1 + band)
	local k = 1 - math.abs(height - middle) / (band / 2)
	if k <= 0 then
		return 0
	end
	return k * k * (3 - 2 * k) -- soft edges
end

function BrushShine.tint(dry: Color3, keep: number, shine: number): Color3
	local base = Color3.new(dry.R * keep, dry.G * keep, dry.B * keep)
	if shine <= 0 then
		return base
	end
	return base:Lerp(BrushShine.SWEEP.color, math.clamp(shine, 0, 1) * BrushShine.SWEEP.lift)
end

local function write(cat: Model, entry: Entry, now: number)
	local keep = 1 - entry.darken * entry.wet
	local running: { number } = {}
	for _, started in entry.sweeps do
		if now - started < BrushShine.SWEEP.seconds then
			table.insert(running, started)
		end
	end
	entry.sweeps = running
	local bottom, height = 0, 1
	if #running > 0 then
		local box, size = cat:GetBoundingBox()
		bottom, height = box.Position.Y - size.Y / 2, math.max(size.Y, 0.01)
	end
	for part, dry in entry.coat do
		local shine = 0
		if #running > 0 then
			local h = (part.Position.Y - bottom) / height
			for _, started in running do
				shine =
					math.max(shine, BrushShine.band(h, (now - started) / BrushShine.SWEEP.seconds))
			end
		end
		part.Color = BrushShine.tint(dry, keep, shine)
	end
	entry.dirty = #running > 0 -- keep writing while a sweep runs, and once more after it ends
end

local function step()
	local now = os.clock()
	for cat, entry in entries do
		if not cat.Parent then
			entries[cat] = nil
		elseif entry.dirty then
			write(cat, entry, now)
		end
	end
	if next(entries) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function wake()
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
end

function BrushShine.track(cat: Model, coat: { [BasePart]: Color3 }, wetDarken: number)
	entries[cat] = {
		coat = coat,
		darken = math.clamp(wetDarken, 0, 1),
		wet = 0,
		sweeps = {},
		dirty = false,
	}
end

function BrushShine.setWet(cat: Model, amount: number)
	local entry = entries[cat]
	if entry == nil then
		return
	end
	entry.wet = math.clamp(amount, 0, 1)
	-- written now (not next frame), so a caller that reads a colour straight after sees the new look
	write(cat, entry, os.clock())
	if entry.dirty then
		wake()
	end
end

function BrushShine.sweep(cat: Model)
	local entry = entries[cat]
	if entry == nil or not cat:IsDescendantOf(Workspace) then
		return
	end
	table.insert(entry.sweeps, os.clock())
	entry.dirty = true
	wake()
end

function BrushShine.done(cat: Model)
	BrushShine.sweep(cat)
	if cat:IsDescendantOf(Workspace) then
		Effects.burst(BrushShine.SPARKLE, (cat:GetBoundingBox()).Position)
	end
end

function BrushShine.untrack(cat: Model)
	local entry = entries[cat]
	if entry == nil then
		return
	end
	entries[cat] = nil
	for part, dry in entry.coat do
		part.Color = dry
	end
end

return BrushShine
