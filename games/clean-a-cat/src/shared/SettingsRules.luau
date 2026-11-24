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

-- One press of a slider with a gamepad moves it this far, and wraps from full back to 0.
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

-- The next level for a gamepad press: up one step, back to 0 after full.
function SettingsRules.step(level: number): number
	if level >= 1 - 1e-6 then
		return 0
	end
	local next = math.floor(level / SettingsRules.GAMEPAD_STEP + 1e-6) * SettingsRules.GAMEPAD_STEP
		+ SettingsRules.GAMEPAD_STEP
	return math.clamp(next, 0, 1)
end

return SettingsRules
