--!strict
-- TrailLine: the tutorial's guide line on the floor (Derek, 2026-11-25: "green or yellow transparent arrow lines
-- starting from character to destination ... with an arrow at the end pointing at it"). Design-Agent's spec is
-- issue #451, the mock is assets/clean-a-cat/ui/screens/tutorial.html state `line`.
--
-- One continuous see-through green band from the player's feet along the path, with a dark edge and a soft light
-- glow, ending in one arrowhead whose tip sits on the spot. A lighter dash runs along it toward the spot about once a
-- second and holds still with reduced motion. Phone budget: flat anchored parts (a few per path leg), no particles,
-- no textures. Client only and cosmetic: nothing collides, catches a ray or touches.
--
-- This module only draws. Spa/FloorTrail decides when (switch trailLine) and hands it the path every frame.
--
-- API
--   TrailLine.show(from, to) -> Handle      Gameplay's entry (FloorTrail): both points on the floor, `from` the feet,
--                                           `to` the spot (the arrow's tip touches it); handle.update(from, to) every
--                                           frame, handle.destroy() when done. A straight path.
--   TrailLine.new(parent?) -> Line          parent defaults to Workspace
--   line.draw(points, dt)                   points: the path on the floor, feet first, the spot last (floor height
--                                           per point); dt moves the running dash
--   line.hide()                             hides every part (keeps them for the next draw)
--   line.destroy()
--   TrailLine.layout(points) -> Layout      pure: the band's legs, cut short where the arrowhead starts, and the
--                                           arrowhead's base and tip (for the specs)
--   TrailLine.dashes(length, offset) -> { number }   pure: where the dashes sit, in studs from the feet
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local TrailLine = {}

TrailLine.LOOK = table.freeze({
	width = 1.6, -- the band, studs
	fill = Color3.fromHex("63E87F"),
	fillSeen = 0.6, -- transparency: the floor shows through (Design-Agent, PR 452)
	edge = Color3.fromHex("1c8a3f"),
	edgeWidth = 0.14,
	edgeSeen = 0.4,
	glow = Color3.fromHex("d6ffd9"),
	glowWidth = 0.35, -- each side, past the edge
	glowSeen = 0.8,
	arrowWidth = 3.8,
	arrowLength = 5,
	dash = Color3.fromHex("d6ffd9"),
	dashLength = 0.9,
	dashSeen = 0.25,
	dashGap = 7, -- studs between dashes; at `dashSpeed` a dash passes any point about once a second
	dashSpeed = 7, -- studs a second, toward the spot
	thick = 0.04, -- every part is this thin
	lift = 0.03, -- the glow's height over the floor; the fill, edges and dash stack above it
	layer = 0.02, -- between stacked see-through tops, so they never shimmer on a phone (Review-QA's rule)
})

-- Derek's playtest, 2026-11-26: "the green and white lines flowing kinda blend in with the models of the map/spa". With
-- the switch trailBold (off by default) a new line takes this look instead: a warm gold band (no floor or wall in the
-- spa or the town uses it) with the HUD's dark plum outline, a white glow, less see-through, a wider arrowhead and a
-- brighter dash. Only colours, widths and transparency change: the arrow's length and the dash spacing stay LOOK's,
-- so TrailLine.layout and TrailLine.dashes hold for both looks.
TrailLine.BOLD_FLAG = "trailBold"
TrailLine.LOOK_BOLD = table.freeze({
	width = 1.8,
	fill = Color3.fromHex("FFC94D"), -- Kit.GOLD
	fillSeen = 0.25,
	edge = Color3.fromHex("45226B"), -- Kit.INK, the outline every HUD word wears
	edgeWidth = 0.22,
	edgeSeen = 0.1,
	glow = Color3.fromHex("FFFFFF"),
	glowWidth = 0.4,
	glowSeen = 0.55,
	arrowWidth = 4.6,
	arrowLength = TrailLine.LOOK.arrowLength,
	dash = Color3.fromHex("FFFFFF"),
	dashLength = TrailLine.LOOK.dashLength,
	dashSeen = 0.05,
	dashGap = TrailLine.LOOK.dashGap,
	dashSpeed = TrailLine.LOOK.dashSpeed,
	thick = TrailLine.LOOK.thick,
	lift = TrailLine.LOOK.lift,
	layer = TrailLine.LOOK.layer,
})

-- The look a new line takes: LOOK_BOLD while trailBold is on. Read once per line, so a switch flip shows on the
-- next line drawn (the next step's trail, or the next time the player walks away).
function TrailLine.look(): typeof(TrailLine.LOOK)
	local ok, bold = pcall(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local LiveFlags =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any
		return LiveFlags.isOn(TrailLine.BOLD_FLAG)
	end)
	return if ok and bold == true then TrailLine.LOOK_BOLD else TrailLine.LOOK
end

export type Leg = { from: Vector3, to: Vector3, length: number }
export type Layout = { legs: { Leg }, length: number, base: Vector3?, tip: Vector3? }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The path's legs (zero-length ones dropped), cut where the arrowhead's base sits, `arrowLength` short of the spot
-- along the path. A path shorter than the arrowhead is all arrowhead: no legs, the base at the feet.
function TrailLine.layout(points: { Vector3 }): Layout
	local look = TrailLine.LOOK
	local n = #points
	if n < 2 then
		return { legs = {}, length = 0, base = nil, tip = nil }
	end
	local tip = points[n]
	-- walk back from the spot to find where the arrowhead's base falls
	local need = look.arrowLength
	local cut = 1 -- legs 1..cut-1 are whole; leg cut ends at `base`
	local base = points[1]
	for i = n, 2, -1 do
		local a, b = points[i - 1], points[i]
		local length = flat(b - a).Magnitude
		if length >= need then
			base = b + (a - b) * (need / length)
			cut = i - 1
			need = 0
			break
		end
		need -= length
	end
	if need > 0 then
		-- the whole path is shorter than the arrowhead: draw only the arrowhead, pointing from the feet
		return { legs = {}, length = 0, base = points[1], tip = tip }
	end
	local legs: { Leg } = {}
	local total = 0
	for i = 1, cut do
		local a = points[i]
		local b = if i == cut then base else points[i + 1]
		local length = flat(b - a).Magnitude
		if length > 1e-3 then
			table.insert(legs, { from = a, to = b, length = length })
			total += length
		end
	end
	return { legs = legs, length = total, base = base, tip = tip }
end

-- Where the dashes are, in studs from the feet: every `dashGap`, shifted by `offset` (which grows with time, so they
-- run toward the spot), only those whose whole dash fits on the band.
function TrailLine.dashes(length: number, offset: number): { number }
	local look = TrailLine.LOOK
	local out: { number } = {}
	local first = offset % look.dashGap
	local at = first
	while at + look.dashLength <= length do
		table.insert(out, at)
		at += look.dashGap
	end
	return out
end

-- The point `distance` studs along the legs, and that leg's direction.
local function along(legs: { Leg }, distance: number): (Vector3, Vector3)
	local left = distance
	for _, leg in legs do
		if left <= leg.length then
			return leg.from + (leg.to - leg.from) * (left / leg.length),
				flat(leg.to - leg.from).Unit
		end
		left -= leg.length
	end
	local last = legs[#legs]
	return last.to, flat(last.to - last.from).Unit
end

type Line = {
	draw: (points: { Vector3 }, dt: number) -> (),
	hide: () -> (),
	destroy: () -> (),
}
export type LineHandle = Line

local UP = Vector3.yAxis

-- A flat strip lying on the floor from `a` to `b` (floor heights), `width` across, `up` over the floor.
local function strip(p: BasePart, a: Vector3, b: Vector3, width: number, up: number, side: number?)
	local d = flat(b - a)
	local length = d.Magnitude
	local dir = d.Unit
	local s = dir:Cross(UP) -- to the right of the way
	local middle = (a + b) / 2 + UP * up + s * (side or 0)
	p.Size = Vector3.new(width, TrailLine.LOOK.thick, length)
	p.CFrame = CFrame.lookAt(middle, middle + dir)
end

-- Half the arrowhead as a WedgePart lying flat: the right angle at the base's middle, one leg along the way to the
-- tip, the other out to the base's corner on side `sign` (1 right, -1 left). `grow` widens it for the glow.
local function halfArrow(
	p: BasePart,
	base: Vector3,
	dir: Vector3,
	sign: number,
	up: number,
	grow: number,
	shape: typeof(TrailLine.LOOK)
)
	local look = shape
	local half = look.arrowWidth / 2 + grow
	local length = look.arrowLength + grow * 2
	local start = base - dir * grow
	local s = dir:Cross(UP) * sign
	-- WedgePart: the right angle is at local (-Y/2, +Z/2); +Y runs to the base corner, -Z to the tip
	local yAxis = s
	local zAxis = -dir
	local xAxis = yAxis:Cross(zAxis)
	local centre = start + s * (half / 2) + dir * (length / 2) + UP * up
	p.Size = Vector3.new(look.thick, half, length)
	p.CFrame = CFrame.fromMatrix(centre, xAxis, yAxis, zAxis)
end

function TrailLine.new(parent: Instance?): LineHandle
	local look = TrailLine.look()
	local folder = Instance.new("Folder")
	folder.Name = "CleanACat_TrailLine"
	folder.Parent = parent or Workspace

	local pools: { [string]: { BasePart } } = {}
	local used: { [string]: number } = {}

	local function take(
		kind: string,
		wedge: boolean,
		color: Color3,
		seen: number,
		neon: boolean
	): BasePart
		local pool = pools[kind]
		if pool == nil then
			pool = {}
			pools[kind] = pool
		end
		local index = (used[kind] or 0) + 1
		used[kind] = index
		local p: BasePart? = pool[index]
		if p == nil then
			local made: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
			made.Name = kind
			made.Anchored = true
			made.CanCollide = false
			made.CanQuery = false
			made.CanTouch = false
			made.CastShadow = false
			made.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
			made.Color = color
			made.Parent = folder
			pool[index] = made
			made.Transparency = seen
			return made
		end
		local part = p :: BasePart
		part.Transparency = seen
		return part
	end

	local function finish()
		for kind, pool in pools do
			for i = (used[kind] or 0) + 1, #pool do
				pool[i].Transparency = 1
			end
		end
		table.clear(used)
	end

	local offset = 0
	local line = {} :: Line

	function line.draw(points: { Vector3 }, dt: number)
		if folder.Parent == nil then
			return
		end
		if not Effects.reducedMotion() then
			offset += dt * look.dashSpeed
		end
		local layout = TrailLine.layout(points)
		local w = look.width
		for _, leg in layout.legs do
			strip(
				take("Glow", false, look.glow, look.glowSeen, true),
				leg.from,
				leg.to,
				w + look.glowWidth * 2,
				look.lift
			)
			strip(
				take("Fill", false, look.fill, look.fillSeen, false),
				leg.from,
				leg.to,
				w,
				look.lift + look.layer
			)
			for _, sign in { -1, 1 } do
				strip(
					take("Edge", false, look.edge, look.edgeSeen, false),
					leg.from,
					leg.to,
					look.edgeWidth,
					look.lift + look.layer * 2,
					sign * (w - look.edgeWidth) / 2
				)
			end
		end
		local base, tip = layout.base, layout.tip
		if base and tip and flat(tip - base).Magnitude > 1e-3 then
			local dir = flat(tip - base).Unit
			for _, sign in { -1, 1 } do
				halfArrow(
					take("ArrowGlow", true, look.glow, look.glowSeen, true),
					base,
					dir,
					sign,
					look.lift,
					look.glowWidth,
					look
				)
				halfArrow(
					take("Arrow", true, look.fill, look.fillSeen, false),
					base,
					dir,
					sign,
					look.lift + look.layer,
					0,
					look
				)
				-- the dark edge along each slanted side, from the base's corner to the tip
				local corner = base + dir:Cross(UP) * sign * (look.arrowWidth / 2)
				local inward = (flat(tip - corner).Unit):Cross(UP) * -sign * (look.edgeWidth / 2) -- toward the middle
				strip(
					take("Edge", false, look.edge, look.edgeSeen, false),
					corner + inward,
					tip + inward,
					look.edgeWidth,
					look.lift + look.layer * 2
				)
			end
		end
		if #layout.legs > 0 then
			for _, at in TrailLine.dashes(layout.length, offset) do
				local a = along(layout.legs, at)
				local b = along(layout.legs, at + look.dashLength)
				if flat(b - a).Magnitude > 1e-3 then
					strip(
						take("Dash", false, look.dash, look.dashSeen, true),
						a,
						b,
						w * 0.6,
						look.lift + look.layer * 3
					)
				end
			end
		end
		finish()
	end

	function line.hide()
		table.clear(used)
		finish()
	end

	function line.destroy()
		folder:Destroy()
		table.clear(pools)
	end

	return line
end

export type Handle = { update: (from: Vector3, to: Vector3) -> (), destroy: () -> () }

function TrailLine.show(from: Vector3, to: Vector3): Handle
	local line = TrailLine.new()
	local last = os.clock()
	local function update(a: Vector3, b: Vector3)
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		line.draw({ a, b }, dt)
	end
	update(from, to)
	return { update = update, destroy = line.destroy }
end

return TrailLine
