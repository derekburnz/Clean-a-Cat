--!strict
-- Cues: every sound in the game, by cue id. The only place asset ids live.
-- Rows mirror docs/audio/clean-a-cat/sound-list.md; licenses are in assets/clean-a-cat/audio/README.md.
-- An empty `ids` list plays nothing: ids are filled in after an upload under the game's owner or a Creator Store pick.
local CueRules = require(script.Parent:WaitForChild("CueRules"))

type Cue = CueRules.Cue

local Cues: { [string]: Cue } = {
	-- Creator Store pick pending (search in Studio)
	scrubLoop = { ids = {}, group = "Sfx", volume = 0.5, voices = 1, preload = true, looped = true },
	-- synth: CleanACat_Sfx_BubblePop_1..3
	bubblePop = {
		ids = {},
		group = "Sfx",
		volume = 0.35,
		pitch = { 0.92, 1.08 },
		minGap = 0.12,
		voices = 3,
		preload = true,
	},
	-- synth: CleanACat_Sfx_MudPlop (pitch set per play by CueRules.mudPlopPitch)
	mudPlop = { ids = {}, group = "Sfx", volume = 0.5, minGap = 0.05, voices = 3, preload = true },
	-- synth: CleanACat_Sfx_RevealChime
	revealChime = {
		ids = {},
		group = "Sfx",
		volume = 0.55,
		minGap = 0.5,
		voices = 1,
		preload = true,
	},
	-- Creator Store pick pending
	catShake = {
		ids = {},
		group = "Sfx",
		volume = 0.5,
		pitch = { 0.95, 1.05 },
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_BrushSwish_1..3, variant = stroke index
	brushSwish = {
		ids = {},
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.97, 1.03 },
		minGap = 0.1,
		voices = 2,
		preload = true,
	},
	-- Creator Store pick pending
	purr = { ids = {}, group = "Sfx", volume = 0.5, pitch = { 0.95, 1.05 }, minGap = 1, voices = 1 },
	-- synth: CleanACat_Sfx_BowPop
	bowPop = {
		ids = {},
		group = "Sfx",
		volume = 0.5,
		pitch = { 0.95, 1.05 },
		minGap = 0.15,
		voices = 1,
	},
	-- synth: CleanACat_Ui_Camera
	camera = { ids = {}, group = "Ui", volume = 0.5, minGap = 0.3, voices = 1 },
	-- synth: CleanACat_Ui_Click
	uiClick = {
		ids = {},
		group = "Ui",
		volume = 0.4,
		pitch = { 0.98, 1.02 },
		minGap = 0.05,
		voices = 2,
		preload = true,
	},
	-- Creator Store pick pending; played at the cat (3D)
	meow = { ids = {}, group = "Sfx", volume = 0.45, pitch = { 0.9, 1.15 }, minGap = 4, voices = 2 },
	-- Creator Store picks pending; two beds that alternate
	spaMusicA = { ids = {}, group = "Music", volume = 0.5, voices = 1 },
	spaMusicB = { ids = {}, group = "Music", volume = 0.5, voices = 1 },
}

return Cues
