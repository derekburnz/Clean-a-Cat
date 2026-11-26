--!strict
-- Audio: every sound plays on the client, through cue ids from Cues.luau. Never on the server, never by asset id
-- elsewhere. A missing or failing sound stays silent and never breaks gameplay. See the audio-pipeline skill.
--
-- API
--   Audio.start()                         builds the SoundGroups and preloads the few `preload` cues
--   Audio.applySettings({ music, sound, musicLevel?, soundLevel? })
--                                         mutes groups and sets their levels (0..1, default 1, from the Settings card's
--                                         sliders); music starts only after the first call. Sounds play
--                                         before it at the default levels (on), so the opening's truck is
--                                         heard from the first frame; a saved "sound off" mutes the groups
--                                         the moment it is applied
--   Audio.play(cueId, options?)           one shot, 2D or at a BasePart / Attachment (options.at)
--   Audio.loop(cueId, at?)                a looping cue; returns a handle with stop() and setSpeed()
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CueRules = require(script:WaitForChild("CueRules"))
local Cues = require(script:WaitForChild("Cues"))

type Cue = CueRules.Cue

export type Settings = { music: boolean, sound: boolean, musicLevel: number?, soundLevel: number? }
export type PlayOptions = { at: Instance?, variant: number?, pitch: number? }
export type LoopHandle = { stop: () -> (), setSpeed: (speed: number) -> () }

local MUSIC_TRACKS = { "spaMusicA", "spaMusicB" }
local MUSIC_FADE = 2

local Audio = {}

local started = false
local groups: { [string]: SoundGroup } = {}
local pools: { [string]: { [number]: Sound? } } = {}
local nextSlot: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}
local warned: { [string]: boolean } = {}
local rng = Random.new()

local current: Settings = { music = true, sound = true }
local musicSound: Sound? = nil
local musicAllowed = false -- the spaMusic switch (AudioController); the player's own music setting comes on top
local musicTrack: string? = nil
local musicEnded: RBXScriptConnection? = nil

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[Audio] {message}`)
	end
end

local function hasIds(cueId: string): boolean
	local cue = Cues[cueId]
	return cue ~= nil and #cue.ids > 0
end

local function newSound(cueId: string, cue: Cue, slot: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = `{cueId}_{slot}`
	sound.SoundGroup = groups[cue.group]
	sound.Volume = cue.volume
	sound.Looped = cue.looped == true
	sound.Parent = SoundService
	return sound
end

-- The next pooled Sound for a cue, replacing one whose 3D parent was destroyed.
local function takeVoice(cueId: string, cue: Cue): Sound
	local pool = pools[cueId]
	if pool == nil then
		pool = {}
		pools[cueId] = pool
	end
	local slot = CueRules.nextVoice(nextSlot[cueId] or 0, cue.voices or 1)
	nextSlot[cueId] = slot
	local existing = pool[slot]
	if existing and existing.Parent then
		return existing
	end
	local sound = newSound(cueId, cue, slot)
	pool[slot] = sound
	return sound
end

local function place(sound: Sound, at: Instance?)
	local target: Instance = SoundService
	if
		at ~= nil
		and (at:IsA("BasePart") or at:IsA("Attachment"))
		and at:IsDescendantOf(workspace)
	then
		target = at
	end
	if sound.Parent ~= target then
		sound.Parent = target
	end
end

function Audio.start()
	if started then
		return
	end
	started = true
	for _, name in CueRules.GROUPS do
		local group = SoundService:FindFirstChild(name)
		if group == nil or not group:IsA("SoundGroup") then
			local made = Instance.new("SoundGroup")
			made.Name = name
			made.Parent = SoundService
			group = made
		end
		local soundGroup = group :: SoundGroup
		soundGroup.Volume = CueRules.GROUP_VOLUME[name] or 0.5
		groups[name] = soundGroup
	end

	local problems = CueRules.validate(Cues)
	for _, problem in problems do
		warnOnce(problem, `cue table: {problem}`)
	end

	local preload: { Instance } = {}
	for cueId, cue in Cues do
		if cue.preload and #cue.ids > 0 then
			local sound = takeVoice(cueId, cue)
			sound.SoundId = cue.ids[1]
			table.insert(preload, sound)
		end
	end
	if #preload > 0 then
		task.spawn(function()
			local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, preload)
			if not ok then
				warnOnce("preload", `preload failed: {err}`)
			end
		end)
	end
end

local function stopMusic()
	if musicEnded then
		musicEnded:Disconnect()
		musicEnded = nil
	end
	local old = musicSound
	musicSound = nil
	musicTrack = nil
	if old then
		local fade = TweenService:Create(old, TweenInfo.new(MUSIC_FADE), { Volume = 0 })
		fade.Completed:Once(function()
			old:Destroy()
		end)
		fade:Play()
	end
end

local function playNextTrack()
	local track = CueRules.nextTrack(MUSIC_TRACKS, musicTrack, hasIds)
	if track == nil then
		return
	end
	local cue = Cues[track]
	local old = musicSound
	if musicEnded then
		musicEnded:Disconnect()
	end
	if old then
		TweenService:Create(old, TweenInfo.new(MUSIC_FADE), { Volume = 0 }):Play()
		task.delay(MUSIC_FADE, function()
			old:Destroy()
		end)
	end

	local sound = Instance.new("Sound")
	sound.Name = track
	sound.SoundId = cue.ids[1]
	sound.SoundGroup = groups.Music
	sound.Volume = 0
	sound.Looped = false
	sound.Parent = SoundService
	musicSound = sound
	musicTrack = track
	musicEnded = sound.Ended:Connect(playNextTrack)
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(MUSIC_FADE), { Volume = cue.volume }):Play()
end

-- A slider level kept inside 0..1; a missing or broken one is full volume.
local function level(raw: number?): number
	if raw == nil or raw ~= raw then
		return 1
	end
	return math.clamp(raw, 0, 1)
end

function Audio.applySettings(settings: Settings)
	if not started then
		Audio.start()
	end
	current = {
		music = settings.music,
		sound = settings.sound,
		musicLevel = settings.musicLevel,
		soundLevel = settings.soundLevel,
	}
	local soundOn = if settings.sound then level(settings.soundLevel) else 0
	local musicOn = if settings.music then level(settings.musicLevel) else 0
	groups.Sfx.Volume = (CueRules.GROUP_VOLUME["Sfx"] or 0) * soundOn
	groups.Ui.Volume = (CueRules.GROUP_VOLUME["Ui"] or 0) * soundOn
	groups.Ambience.Volume = (CueRules.GROUP_VOLUME["Ambience"] or 0) * soundOn
	groups.Music.Volume = (CueRules.GROUP_VOLUME["Music"] or 0) * musicOn

	local playing = musicSound
	local wanted = settings.music and musicAllowed
	if wanted and not playing then
		playNextTrack()
	elseif playing and not wanted then
		stopMusic()
	end
end

-- Lets the spa songs play or stops them, keeping the player's own settings (the spaMusic switch, issue 529).
function Audio.allowMusic(allowed: boolean)
	if musicAllowed == allowed then
		return
	end
	musicAllowed = allowed
	Audio.applySettings(current)
end

function Audio.play(cueId: string, options: PlayOptions?)
	if not started or not current.sound then
		return
	end
	local cue = Cues[cueId]
	if cue == nil then
		warnOnce(`missing {cueId}`, `no cue named {cueId}`)
		return
	end
	local now = os.clock()
	if not CueRules.canPlay(lastPlayed[cueId], now, cue.minGap) then
		return
	end
	local assetId = CueRules.pickId(cue, rng:NextNumber(), options and options.variant)
	if assetId == nil then
		return -- no file yet: silent on purpose
	end
	lastPlayed[cueId] = now

	local ok, err = pcall(function()
		local sound = takeVoice(cueId, cue)
		place(sound, options and options.at)
		sound.SoundId = assetId
		sound.PlaybackSpeed = (options and options.pitch)
			or CueRules.pitchFor(cue, rng:NextNumber())
		sound.TimePosition = 0
		sound:Play()
	end)
	if not ok then
		warnOnce(`play {cueId}`, `could not play {cueId}: {err}`)
	end
end

local NO_LOOP: LoopHandle = {
	stop = function() end,
	setSpeed = function(_speed: number) end,
}

function Audio.loop(cueId: string, at: Instance?): LoopHandle
	if not started or not current.sound then
		return NO_LOOP
	end
	local cue = Cues[cueId]
	if cue == nil then
		warnOnce(`missing {cueId}`, `no cue named {cueId}`)
		return NO_LOOP
	end
	local assetId = CueRules.pickId(cue, rng:NextNumber(), nil)
	if assetId == nil then
		return NO_LOOP
	end
	local sound = takeVoice(cueId, cue)
	place(sound, at)
	sound.SoundId = assetId
	sound.Looped = true
	sound.PlaybackSpeed = CueRules.pitchFor(cue, 0.5)
	sound:Play()
	return {
		stop = function()
			sound:Stop()
		end,
		setSpeed = function(speed: number)
			sound.PlaybackSpeed = speed
		end,
	}
end

return Audio
