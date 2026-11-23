--!strict
-- ScrubRules: the pure rules of scrubbing mud off a cat (patch layout, how much rubbing clears a patch, when the
-- rest pops off). No Roblox calls, so specs cover it; ScrubController does the world and input on top.
-- Numbers are draft tuning from the first session plan: first scrub about 8 seconds on a phone.

local ScrubRules = {}

-- Tuning (draft). Change here only; the specs read these too.
ScrubRules.PATCH_COUNT = 16 -- the design's range is 12 to 20; cheap phones cap at 20
ScrubRules.MAX_PATCHES = 20
ScrubRules.SPONGE_RADIUS = 0.9 -- studs around the touch point that the sponge reaches
ScrubRules.RUB_TO_CLEAR = 1.2 -- studs of sponge travel over a patch to clear it
ScrubRules.REVEAL_FRACTION = 0.8 -- at this share cleared, the rest pops off
ScrubRules.MAX_RUB_PER_STEP = 1.5 -- studs counted from one input step at most, so a teleporting pointer is not a free clear

export type State = {
	rub: { number },
	cleared: { boolean },
	clearedCount: number,
	total: number,
	revealed: boolean,
}

local function spiral(n: number): { Vector3 }
	local directions = {}
	local goldenAngle = math.pi * (3 - math.sqrt(5))
	-- y runs from near the top (0.95) down to a little below the middle (-0.35): the top and the sides, never
	-- the belly, which the player cannot see.
	local top, bottom = 0.95, -0.35
	for i = 0, n - 1 do
		local t = if n == 1 then 0 else i / (n - 1)
		local y = top + (bottom - top) * t
		local radius = math.sqrt(math.max(0, 1 - y * y))
		local angle = goldenAngle * i
		table.insert(directions, Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius))
	end
	return directions
end

-- Unit directions for `count` patches on a ball-shaped cat, spread evenly with a golden angle spiral. When
-- `avoid` is given (a unit direction, such as where the head sits), no patch lands within the cone whose
-- cosine is `avoidDot`, so no patch hides under the head. The same arguments give the same layout every time.
function ScrubRules.patchDirections(count: number, avoid: Vector3?, avoidDot: number?): { Vector3 }
	local n = math.clamp(math.floor(count), 1, ScrubRules.MAX_PATCHES)
	if avoid == nil then
		return spiral(n)
	end
	local limit = avoidDot or 0.8
	for m = n, n * 4 do
		local kept: { Vector3 } = {}
		for _, direction in spiral(m) do
			if direction:Dot(avoid) < limit then
				table.insert(kept, direction)
			end
		end
		if #kept >= n then
			local first: { Vector3 } = table.move(kept, 1, n, 1, {} :: { Vector3 })
			return first
		end
	end
	return spiral(n)
end

function ScrubRules.newState(total: number): State
	local n = math.clamp(math.floor(total), 1, ScrubRules.MAX_PATCHES)
	local rub = table.create(n, 0)
	local cleared = table.create(n, false)
	return { rub = rub, cleared = cleared, clearedCount = 0, total = n, revealed = false }
end

-- Rub patch `index` by `amount` studs of sponge travel. Returns true only on the step that clears it.
-- Ignores bad input (unknown index, NaN, negative) and does nothing once the cat is revealed.
function ScrubRules.rub(state: State, index: number, amount: number): boolean
	if state.revealed or state.cleared[index] == nil or state.cleared[index] then
		return false
	end
	if amount ~= amount or amount <= 0 then
		return false
	end
	local step = math.min(amount, ScrubRules.MAX_RUB_PER_STEP)
	state.rub[index] += step
	if state.rub[index] >= ScrubRules.RUB_TO_CLEAR then
		state.cleared[index] = true
		state.clearedCount += 1
		return true
	end
	return false
end

-- True once enough patches are cleared for the rest to pop off.
function ScrubRules.shouldReveal(state: State): boolean
	return not state.revealed
		and state.clearedCount >= math.ceil(state.total * ScrubRules.REVEAL_FRACTION)
end

-- Marks the cat revealed and returns the indexes of the patches still left, which pop off together.
function ScrubRules.reveal(state: State): { number }
	local rest = {}
	for index, done in state.cleared do
		if not done then
			table.insert(rest, index)
			state.cleared[index] = true
		end
	end
	state.clearedCount = state.total
	state.revealed = true
	return rest
end

function ScrubRules.patchesLeft(state: State): number
	return state.total - state.clearedCount
end

return table.freeze(ScrubRules)
