--!strict
-- ScrubRules: the pure rules of scrubbing mud off a cat (which pieces are mud, how much rubbing clears one, when
-- the rest pops off). No Roblox calls, so specs cover it; ScrubController does the world and input on top.
-- Numbers are draft tuning from the first session plan: first scrub about 8 seconds on a phone.

local ScrubRules = {}

-- Tuning (draft). Change here only; the specs read these too.
ScrubRules.MAX_PATCHES = 20 -- the design's range is 12 to 20; cheap phones cap at 20 (blobs past it are removed)
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

-- The number at the end of a dirt piece's name: `pieceNumber("CleanACat_Cat_Smudge_Dirty_Mud07", "Mud")` is 7. Nil for
-- any other name, so a part that only contains the word (such as "MuddyPaw") is never taken for a piece.
function ScrubRules.pieceNumber(name: string, kind: string): number?
	local digits = string.match(name, "_" .. kind .. "(%d+)$")
	return if digits then tonumber(digits) else nil
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
