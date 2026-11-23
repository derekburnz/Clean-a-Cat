--!strict
-- Presets: every effect as data, per device tier. Tune in Studio in the dev place, then copy the numbers here.
-- Every field must exist in both tiers (the spec checks), or the missing tier errors only on that device.
-- Rows mirror docs/vfx/clean-a-cat/effects-list.md. Colours are placeholders until the style guide's palette lands.

export type Tier = "low" | "high"

export type Emitter = {
	texture: string, -- "" uses Roblox's default particle (a soft dot)
	color: { Color3 }, -- 1 or 2 stops, start to end
	size: { number }, -- { start, end } in studs
	transparency: { number }, -- { start, end }
	lifetime: { number }, -- { min, max } seconds
	speed: { number }, -- { min, max } studs per second
	spread: number, -- degrees
	acceleration: Vector3,
	drag: number,
	lightEmission: number,
	maxRate: number, -- steady stream at full speed (0 for burst-only presets)
	burst: number, -- particles per Emit (0 for stream-only presets)
}

local FOAM_WHITE = Color3.fromRGB(255, 255, 255)
local FOAM_BLUE = Color3.fromRGB(214, 236, 255)
local GOLD = Color3.fromRGB(255, 214, 120)
local GOLD_LIGHT = Color3.fromRGB(255, 240, 196)
local MUD = Color3.fromRGB(122, 88, 58)
local MUD_DARK = Color3.fromRGB(92, 64, 42)

local function foam(
	colorA: Color3,
	colorB: Color3,
	size: number,
	spread: number,
	rate: number
): Emitter
	return {
		texture = "",
		color = { colorA, colorB },
		size = { size, size * 1.3 },
		transparency = { 0.15, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 0.6, 1.4 },
		spread = spread,
		acceleration = Vector3.new(0, 1.5, 0),
		drag = 2,
		lightEmission = 0.1,
		maxRate = rate,
		burst = 0,
	}
end

local function mud(count: number): Emitter
	return {
		texture = "",
		color = { MUD, MUD_DARK },
		size = { 0.18, 0.08 },
		transparency = { 0, 1 },
		lifetime = { 0.4, 0.7 },
		speed = { 2, 4 },
		spread = 60,
		acceleration = Vector3.new(0, -18, 0),
		drag = 0.5,
		lightEmission = 0,
		maxRate = 0,
		burst = count,
	}
end

local Presets: { [Tier]: { [string]: Emitter } } = {
	low = {
		foamTrail = foam(FOAM_WHITE, FOAM_BLUE, 0.22, 25, 8),
		foamTrailWide = foam(FOAM_WHITE, FOAM_BLUE, 0.26, 55, 8),
		foamTrailGold = foam(GOLD_LIGHT, GOLD, 0.22, 25, 8),
		mudChunks = mud(4),
	},
	high = {
		foamTrail = foam(FOAM_WHITE, FOAM_BLUE, 0.22, 25, 16),
		foamTrailWide = foam(FOAM_WHITE, FOAM_BLUE, 0.26, 55, 16),
		foamTrailGold = foam(GOLD_LIGHT, GOLD, 0.22, 25, 16),
		mudChunks = mud(6),
	},
}

-- Budget caps from the animation-vfx skill, section 7. The spec holds every preset under them.
local Budgets: { [Tier]: { maxRate: number, maxBurst: number, maxLifetime: number } } = {
	low = { maxRate = 8, maxBurst = 12, maxLifetime = 1.5 },
	high = { maxRate = 16, maxBurst = 24, maxLifetime = 1.5 },
}

return {
	emitters = Presets,
	budgets = Budgets,
}
