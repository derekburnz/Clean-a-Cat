--!strict
-- SettingsRules: the player's own settings on the Settings card (#230, switch settingsCard) and how a slider turns
-- a pointer into a level. Pure, so tests/specs/SettingsRules.spec.luau covers it. Settings live on the player's
-- device for the session for now; saving them is a later change under a claim issue (it touches SaveSchema).
local SettingsRules = {}

export type Settings = {
	music: number, -- 0..1, the Music slider
	sounds: number, -- 0..1, the Sounds slider
	lessShake: boolean, -- calmer cat motion and bursts (with Roblox's Reduced Motion, through UI/Comfort)
	lessSparkle: boolean, -- fewer flashes and particles (through UI/Comfort)
}

SettingsRules.DEFAULTS = table.freeze({
	music = 1,
	sounds = 1,
	lessShake = false,
	lessSparkle = false,
}) :: Settings

-- One press of a slider with a gamepad moves it this far. It goes down from full to 0 and then back up a step at a
-- time, so a controller player never drops from full to silence in one press (Review-QA on #231).
SettingsRules.GAMEPAD_STEP = 0.25

function SettingsRules.defaults(): Settings
	return table.clone(SettingsRules.DEFAULTS) :: Settings
end

-- A slider level kept inside 0..1; a missing or broken value is the default.
function SettingsRules.level(raw: unknown, default: number): number
	if type(raw) ~= "number" or raw ~= raw then
		return default
	end
	return math.clamp(raw, 0, 1)
end

-- The level for a pointer at screen x on a slider whose track starts at `left` and is `width` wide, with a thumb
-- `thumb` wide that stays inside the track (the level is where the thumb's middle is).
function SettingsRules.fromPointer(x: number, left: number, width: number, thumb: number): number
	local travel = width - thumb
	if travel <= 0 then
		return 0
	end
	return math.clamp((x - left - thumb / 2) / travel, 0, 1)
end

-- Where the thumb's middle sits, from the track's left edge, for `level`.
function SettingsRules.thumbCentre(level: number, width: number, thumb: number): number
	return thumb / 2 + math.max(width - thumb, 0) * math.clamp(level, 0, 1)
end

-- The next level and direction for a gamepad press: one step in `direction` (1 up, -1 down), turning round at
-- either end, so the level walks 1, 0.75, 0.5, 0.25, 0, 0.25 and so on.
function SettingsRules.step(level: number, direction: number): (number, number)
	local stepSize = SettingsRules.GAMEPAD_STEP
	local dir = if direction < 0 then -1 else 1
	if dir > 0 and level >= 1 - 1e-6 then
		dir = -1
	elseif dir < 0 and level <= 1e-6 then
		dir = 1
	end
	local steps = level / stepSize
	local next = if dir > 0
		then (math.floor(steps + 1e-6) + 1) * stepSize
		else (math.ceil(steps - 1e-6) - 1) * stepSize
	return math.clamp(next, 0, 1), dir
end

return SettingsRules
