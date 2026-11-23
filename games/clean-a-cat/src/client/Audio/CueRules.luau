--!strict
-- CueRules: the pure parts of audio playback (no Roblox services), so they have specs.
-- Audio/init.luau uses these; Cues.luau holds the data they check.

local CueRules = {}

export type Group = "Music" | "Ambience" | "Sfx" | "Ui"

export type Cue = {
	ids: { string }, -- "rbxassetid://..." strings; empty means silent, never an error
	group: Group,
	volume: number,
	pitch: { number }?, -- { min, max } random PlaybackSpeed per play
	minGap: number?, -- seconds between plays; drops spam
	voices: number?, -- pooled Sounds for this cue
	preload: boolean?,
	looped: boolean?,
}

CueRules.GROUPS = { "Music", "Ambience", "Sfx", "Ui" } :: { Group }

CueRules.GROUP_VOLUME = {
	Music = 0.5,
	Ambience = 0.6,
	Sfx = 0.8,
	Ui = 0.7,
} :: { [string]: number }

CueRules.MAX_PRELOAD = 10

local ID_PATTERN = "^rbxassetid://%d+$"

-- Returns a list of problems in a cue table; empty when it is clean.
function CueRules.validate(cues: { [string]: Cue }): { string }
	local problems = {}
	local preloads = 0
	for id, cue in cues do
		if CueRules.GROUP_VOLUME[cue.group] == nil then
			table.insert(problems, `{id}: unknown group {tostring(cue.group)}`)
		end
		if type(cue.volume) ~= "number" or cue.volume < 0 or cue.volume > 1 then
			table.insert(problems, `{id}: volume must be 0 to 1`)
		end
		for _, assetId in cue.ids do
			if string.match(assetId, ID_PATTERN) == nil then
				table.insert(problems, `{id}: bad asset id {assetId}`)
			end
		end
		local pitch = cue.pitch
		if pitch ~= nil and (#pitch ~= 2 or pitch[1] <= 0 or pitch[1] > pitch[2]) then
			table.insert(problems, `{id}: pitch must be {"{"} min, max {"}"} with 0 < min <= max`)
		end
		if cue.voices ~= nil and (cue.voices < 1 or cue.voices > 4 or cue.voices % 1 ~= 0) then
			table.insert(problems, `{id}: voices must be a whole number from 1 to 4`)
		end
		if cue.minGap ~= nil and cue.minGap < 0 then
			table.insert(problems, `{id}: minGap must not be negative`)
		end
		if cue.preload then
			preloads += 1
		end
	end
	if preloads > CueRules.MAX_PRELOAD then
		table.insert(
			problems,
			`{preloads} cues preload; keep it to {CueRules.MAX_PRELOAD} or fewer`
		)
	end
	return problems
end

-- True when enough time has passed since the cue last played.
function CueRules.canPlay(lastPlayed: number?, now: number, minGap: number?): boolean
	if lastPlayed == nil or minGap == nil then
		return true
	end
	return now - lastPlayed >= minGap
end

-- A PlaybackSpeed inside the cue's range; `roll` is a number from 0 to 1.
function CueRules.pitchFor(cue: Cue, roll: number): number
	local pitch = cue.pitch
	if pitch == nil then
		return 1
	end
	return pitch[1] + (pitch[2] - pitch[1]) * math.clamp(roll, 0, 1)
end

-- Which file of the cue to play: the given variant (1-based) when it exists, else one picked by `roll`.
function CueRules.pickId(cue: Cue, roll: number, variant: number?): string?
	local count = #cue.ids
	if count == 0 then
		return nil
	end
	if variant ~= nil and cue.ids[variant] ~= nil then
		return cue.ids[variant]
	end
	return cue.ids[math.clamp(math.floor(roll * count) + 1, 1, count)]
end

-- The pool slot to use next: round robin, so the oldest Sound restarts when all are busy.
function CueRules.nextVoice(current: number, voices: number): number
	return current % math.max(voices, 1) + 1
end

-- Mud plop pitch: starts low and rises as more patches are cleared, capped.
function CueRules.mudPlopPitch(cleared: number): number
	return math.min(0.9 + 0.02 * math.max(cleared, 0), 1.3)
end

-- Sponge loop speed from drag speed in pixels a second: 0.9 still, 1.15 at a fast drag.
function CueRules.scrubLoopSpeed(dragSpeed: number): number
	return 0.9 + 0.25 * math.clamp(dragSpeed / 1200, 0, 1)
end

-- The next music track: alternates between the tracks that have ids, starting at the first.
function CueRules.nextTrack(
	tracks: { string },
	current: string?,
	hasIds: (string) -> boolean
): string?
	local playable: { string } = {}
	for _, track in tracks do
		if hasIds(track) then
			table.insert(playable, track)
		end
	end
	if #playable == 0 then
		return nil
	end
	local index = if current then table.find(playable, current) else nil
	if index == nil then
		return playable[1]
	end
	return playable[index % #playable + 1]
end

return CueRules
