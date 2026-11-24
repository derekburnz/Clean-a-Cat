--!strict
-- ScrubRules: the pure rules of scrubbing mud off a cat (which pieces are mud, how much rubbing clears one, when
-- the rest pops off). No Roblox calls, so specs cover it; ScrubController does the world and input on top.
-- Numbers are draft tuning from the first session plan: first scrub about 8 seconds on a phone.

local ScrubRules = {}

-- Tuning (draft). Change here only; the specs read these too.
ScrubRules.MAX_PATCHES = 20 -- the design's range is 12 to 20; cheap phones cap at 20 (blobs past it are removed)
ScrubRules.SPONGE_RADIUS = 0.9 -- studs around the touch point that the sponge reaches
ScrubRules.RUB_TO_CLEAR = 1.2 -- studs of sponge travel over a patch to clear it
-- With the scrubFeel switch on: a patch takes about two passes of the sponge, so a first scrub is a few strokes
-- back and forth rather than one swipe (one short drag cleared 14 of 20 patches at RUB_TO_CLEAR, issue #149).
ScrubRules.RUB_TO_CLEAR_PACED = 3.6
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
-- `toClear` is the travel a patch needs (RUB_TO_CLEAR when nil). Ignores bad input (unknown index, NaN,
-- negative) and does nothing once the cat is revealed.
function ScrubRules.rub(state: State, index: number, amount: number, toClear: number?): boolean
	if state.revealed or state.cleared[index] == nil or state.cleared[index] then
		return false
	end
	if amount ~= amount or amount <= 0 then
		return false
	end
	local step = math.min(amount, ScrubRules.MAX_RUB_PER_STEP)
	state.rub[index] += step
	if state.rub[index] >= (toClear or ScrubRules.RUB_TO_CLEAR) then
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

-- Patches still to clear before the rest pops off.
function ScrubRules.patchesNeeded(state: State): number
	if state.revealed then
		return 0
	end
	return math.max(0, math.ceil(state.total * ScrubRules.REVEAL_FRACTION) - state.clearedCount)
end

-- How far to turn the cat (radians about the up axis, as CFrame.Angles(0, yaw, 0) turns) so the middle of the mud
-- still on it faces the camera, or nil when enough of it faces the camera already. `offsets` are the remaining
-- patches' positions minus the cat's centre; `toCamera` points from the cat's centre to the camera. Heights are
-- ignored. A patch faces the camera when it sits within FACING_ANGLE of the camera's side, or on top of the cat
-- (within ON_TOP of its middle, seen from the camera above). The turn brings round the middle of the patches that do
-- not face it, so each turn shows mud that was hidden; a cat whose mud sits on both flanks turns to one, then the
-- other. Sync-Agent's run on 4ae0e33: with "the camera's half" as facing, Suds's flank patches counted as facing, so
-- he never turned, yet the close-up's fixed camera could only reach them through his head and body.
ScrubRules.FACING_ANGLE = math.rad(55)
ScrubRules.ON_TOP = 0.2 -- studs from the middle, seen from above

function ScrubRules.turnToShow(offsets: { Vector3 }, toCamera: Vector3, needed: number): number?
	local camera = Vector3.new(toCamera.X, 0, toCamera.Z)
	if needed <= 0 or #offsets == 0 or camera.Magnitude < 1e-6 then
		return nil
	end
	local look = camera.Unit
	local cone = math.cos(ScrubRules.FACING_ANGLE)
	local facing = 0
	local sum = Vector3.zero
	for _, offset in offsets do
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local size = flat.Magnitude
		if size <= ScrubRules.ON_TOP or flat:Dot(look) >= cone * size then
			facing += 1
		else
			sum += flat
		end
	end
	if facing >= math.min(needed, #offsets) or sum.Magnitude < 1e-6 then
		return nil
	end
	-- CFrame.Angles(0, yaw, 0) moves a direction at angle atan2(z, x) to that angle minus yaw.
	local yaw = math.atan2(sum.Z, sum.X) - math.atan2(camera.Z, camera.X)
	return (yaw + math.pi) % (2 * math.pi) - math.pi
end

return table.freeze(ScrubRules)
