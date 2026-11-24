--!strict
-- Cues: every sound in the game, by cue id. The only place asset ids live.
-- Rows mirror docs/audio/clean-a-cat/sound-list.md; licenses are in assets/clean-a-cat/audio/README.md.
-- An empty `ids` list plays nothing: ids are filled in after an upload under the game's owner or a Creator Store pick.
local CueRules = require(script.Parent:WaitForChild("CueRules"))

type Cue = CueRules.Cue

local Cues: { [string]: Cue } = {
	-- synth: CleanACat_Sfx_SpongeLoop (seamless 2 s loop)
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
	-- synth: CleanACat_Sfx_FurShake
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
	-- synth: CleanACat_Sfx_Purr_1..2
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
	-- synth: CleanACat_Sfx_DryerHum (seamless 2 s loop); played at the dryer (3D) while a cat dries
	dryerHum = { ids = {}, group = "Sfx", volume = 0.35, voices = 1, looped = true },
	-- synth: CleanACat_Sfx_Meow_1..3; played at the cat (3D)
	meow = { ids = {}, group = "Sfx", volume = 0.45, pitch = { 0.9, 1.15 }, minGap = 4, voices = 2 },
	-- Opening scene (#281, Effects/OpeningScene), all 3D at the truck or the box.
	-- synth: CleanACat_Sfx_TruckRumble (seamless 2 s loop); follows the truck
	truckRumble = {
		ids = { "rbxassetid://128974104818127" },
		group = "Sfx",
		volume = 0.4,
		voices = 1,
		looped = true,
	},
	-- synth: CleanACat_Sfx_TruckHonk; one soft two-note toot
	truckHonk = {
		ids = { "rbxassetid://76728960044070" },
		group = "Sfx",
		volume = 0.4,
		minGap = 2,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_TruckBump_1..2; variant 1 front wheels, 2 back wheels with a cargo rattle
	truckBump = {
		ids = { "rbxassetid://83549622802247", "rbxassetid://131991798209030" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.1,
		voices = 2,
	},
	-- synth: CleanACat_Sfx_TruckDoor; the rear door clacks open
	truckDoor = {
		ids = { "rbxassetid://106598333989684" },
		group = "Sfx",
		volume = 0.4,
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_BoxThud; cardboard on pavement (pitched up for the small bounce)
	boxThud = {
		ids = { "rbxassetid://113317721257314" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.1,
		voices = 2,
	},
	-- synth: CleanACat_Sfx_BoxRustle; the box wiggles with something inside
	boxRustle = {
		ids = { "rbxassetid://112949884290830" },
		group = "Sfx",
		volume = 0.4,
		pitch = { 0.95, 1.05 },
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_CollarJingle; Suds is named and his collar with its gold bell pops on (SudsNamed)
	collarJingle = {
		ids = { "rbxassetid://132945251317866" },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
		voices = 1,
	},
	-- synth: CleanACat_Music_SpaA and CleanACat_Music_SpaB; two beds that alternate
	spaMusicA = { ids = {}, group = "Music", volume = 0.5, voices = 1 },
	spaMusicB = { ids = {}, group = "Music", volume = 0.5, voices = 1 },
}

return Cues
