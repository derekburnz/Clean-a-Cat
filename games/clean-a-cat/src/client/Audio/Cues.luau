--!strict
-- Cues: every sound in the game, by cue id. The only place asset ids live.
-- Rows mirror docs/audio/clean-a-cat/sound-list.md; licenses are in assets/clean-a-cat/audio/README.md.
-- An empty `ids` list plays nothing: ids are filled in after an upload under the game's owner or a Creator Store pick.
local CueRules = require(script.Parent:WaitForChild("CueRules"))

type Cue = CueRules.Cue

local Cues: { [string]: Cue } = {
	-- synth: CleanACat_Sfx_SpongeLoop (seamless 2 s loop)
	scrubLoop = {
		ids = { "rbxassetid://125803317425310" },
		group = "Sfx",
		volume = 0.5,
		voices = 1,
		preload = true,
		looped = true,
	},
	-- synth: CleanACat_Sfx_BubblePop_1..3
	bubblePop = {
		ids = {
			"rbxassetid://130114968601790",
			"rbxassetid://110755365796073",
			"rbxassetid://116414110656793",
		},
		group = "Sfx",
		volume = 0.35,
		pitch = { 0.92, 1.08 },
		minGap = 0.12,
		voices = 3,
		preload = true,
	},
	-- synth: CleanACat_Sfx_MudPlop (pitch set per play by CueRules.mudPlopPitch)
	mudPlop = {
		ids = { "rbxassetid://107329071536560" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.05,
		voices = 3,
		preload = true,
	},
	-- synth: CleanACat_Sfx_RevealChime
	revealChime = {
		ids = { "rbxassetid://84312583849520" },
		group = "Sfx",
		volume = 0.55,
		minGap = 0.5,
		voices = 1,
		preload = true,
	},
	-- synth: CleanACat_Sfx_FurShake
	catShake = {
		ids = { "rbxassetid://128546270034088" },
		group = "Sfx",
		volume = 0.5,
		pitch = { 0.95, 1.05 },
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_BrushSwish_1..3, variant = stroke index
	brushSwish = {
		ids = {
			"rbxassetid://134072180392503",
			"rbxassetid://121263183608677",
			"rbxassetid://99870851025492",
		},
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.97, 1.03 },
		minGap = 0.1,
		voices = 2,
		preload = true,
	},
	-- synth: CleanACat_Sfx_Purr_1..2
	-- Two variants, picked at random. A variant's first play can be silent for a moment while Roblox streams it in
	-- (only ids[1] of a preload cue is preloaded), and minGap 1 with one voice drops a tap within a second of the last.
	purr = {
		ids = { "rbxassetid://112652819529138", "rbxassetid://93890384660354" },
		group = "Sfx",
		volume = 0.5,
		pitch = { 0.95, 1.05 },
		minGap = 1,
		voices = 1,
	},
	-- Derek's Roblox-Asset-Library: CatCafe_Sfx_CarryPurr, kept as CleanACat_Sfx_CarryPurr; a contented purr in the
	-- player's arms, looped while they carry a cat (Effects/Carry)
	carryPurr = {
		ids = { "rbxassetid://88268026074287" },
		group = "Sfx",
		volume = 0.45,
		voices = 1,
		looped = true,
	},
	-- synth: CleanACat_Sfx_BowPop
	bowPop = {
		ids = { "rbxassetid://136883364011549" },
		group = "Sfx",
		volume = 0.5,
		pitch = { 0.95, 1.05 },
		minGap = 0.15,
		voices = 1,
	},
	-- synth: CleanACat_Ui_Camera
	camera = {
		ids = { "rbxassetid://138137408834946" },
		group = "Ui",
		volume = 0.5,
		minGap = 0.3,
		voices = 1,
	},
	-- synth: CleanACat_Ui_Click
	uiClick = {
		ids = { "rbxassetid://133323658066149" },
		group = "Ui",
		volume = 0.4,
		pitch = { 0.98, 1.02 },
		minGap = 0.05,
		voices = 2,
	},
	-- the meow files again, quieter, for Suds's speech bubble (Audio/SudsVoice, switch sudsVoice, #827)
	sudsMeow = {
		ids = {
			"rbxassetid://100957394631396",
			"rbxassetid://89957276276636",
			"rbxassetid://70877155078126",
		},
		group = "Sfx",
		volume = 0.28,
		pitch = { 1.0, 1.15 },
		minGap = 60, -- Design-Agent: never twice in a minute
		voices = 1,
	},
	-- owner's Cat Cafe CatCafe_Ui_Open as CleanACat_Ui_Open: a window or the More tray opens (Audio/UiSounds, #800)
	uiOpen = {
		ids = { "rbxassetid://120566856629637" },
		group = "Ui",
		volume = 0.3,
		pitch = { 0.98, 1.02 },
		minGap = 0.08,
		voices = 1,
		preload = true,
	},
	-- owner's Cat Cafe CatCafe_Ui_Close as CleanACat_Ui_Close: the last window or the More tray closes (#800)
	uiClose = {
		ids = { "rbxassetid://113214587461466" },
		group = "Ui",
		volume = 0.25,
		pitch = { 0.98, 1.02 },
		minGap = 0.08,
		voices = 1,
		preload = true,
	},
	-- owner's Cat Cafe CatCafe_Sfx_CoinPop as CleanACat_Sfx_CoinPop: the helper pay popup over a stand (switch
	-- helperPopFx, #801); 2D, only the owner hears it, and it stands in for workerDone on their own plot
	coinPop = {
		ids = { "rbxassetid://78798450390778" },
		group = "Sfx",
		volume = 0.3,
		pitch = { 0.97, 1.05 },
		minGap = 0.25,
		voices = 1,
	},
	-- owner's Cat Cafe CatCafe_Sfx_GiftClaim as CleanACat_Sfx_GiftClaim: a Free Reward or the gift pet is claimed
	-- (Effects/ClaimFx, #802); a step under the other rewards, the level Derek liked in Cat Cafe
	giftClaim = {
		ids = { "rbxassetid://101429049924535" },
		group = "Ui",
		volume = 0.45,
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_DryerHum (seamless 2 s loop); played at the dryer (3D) while a cat dries
	dryerHum = {
		ids = { "rbxassetid://105566818572862" },
		group = "Sfx",
		volume = 0.35,
		voices = 1,
		looped = true,
	},
	-- synth: CleanACat_Sfx_Meow_1..3; played at the cat (3D)
	meow = {
		ids = {
			"rbxassetid://100957394631396",
			"rbxassetid://89957276276636",
			"rbxassetid://70877155078126",
		},
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.9, 1.15 },
		minGap = 4,
		voices = 2,
	},
	-- Opening scene (#281, Effects/OpeningScene), all 3D at the truck or the box.
	-- synth: CleanACat_Sfx_TruckRumble (seamless 2 s loop); follows the truck
	truckRumble = {
		ids = { "rbxassetid://128974104818127" },
		group = "Sfx",
		volume = 0.4,
		voices = 1,
		looped = true,
		preload = true,
	},
	-- synth: CleanACat_Sfx_TruckHonk; one soft two-note toot
	truckHonk = {
		ids = { "rbxassetid://76728960044070" },
		group = "Sfx",
		volume = 0.4,
		minGap = 2,
		voices = 1,
		preload = true,
	},
	-- synth: CleanACat_Sfx_TruckBump_1..2; variant 1 front wheels, 2 back wheels with a cargo rattle
	truckBump = {
		ids = { "rbxassetid://83549622802247", "rbxassetid://131991798209030" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.1,
		voices = 2,
		preload = true,
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
	-- The batch after the game was picked (2026-11-25): soft and cosy, Derek's feel pick.
	-- synth: CleanACat_Sfx_FoamSwell; BathFoamy ("so foamy")
	foamSwell = {
		ids = { "rbxassetid://86501880035340" },
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.97, 1.03 },
		minGap = 1.0,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_RinseLoop (seamless 2 s loop); at the cat while the shower sprays (RinseSpray)
	rinseLoop = {
		ids = { "rbxassetid://127073369403196" },
		group = "Sfx",
		volume = 0.3,
		voices = 1,
		looped = true,
	},
	-- synth: CleanACat_Sfx_FoamDrop; the rinse's end (ShakeOff "rinse"), the last foam lands round the feet
	foamDrop = {
		ids = { "rbxassetid://137954820723713" },
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.97, 1.03 },
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_StepChime; a wash bar fills (ShakeOff), smaller than the reveal chime
	stepChime = {
		ids = { "rbxassetid://92248002357092" },
		group = "Sfx",
		volume = 0.4,
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_ClawSnip; each claw (ClawSnipped)
	clawSnip = {
		ids = { "rbxassetid://108380936951876" },
		group = "Sfx",
		volume = 0.4,
		pitch = { 0.95, 1.08 },
		minGap = 0.05,
		voices = 2,
	},
	-- synth: CleanACat_Sfx_VisitorChime; a special customer arrives (VisitorArrived)
	visitorChime = {
		ids = { "rbxassetid://129234437034334" },
		group = "Sfx",
		volume = 0.45,
		minGap = 3.0,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_CrateDrop; a gift crate lands (CrateDropped), at the crate
	crateDrop = {
		ids = { "rbxassetid://80481093417771" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_BowTie; the bow is tied, the easy last step (BowTied)
	bowTie = {
		ids = { "rbxassetid://85030390046657" },
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.97, 1.03 },
		minGap = 0.3,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_HeartLow; a waiting cat's heart bar gets low (HeartLow)
	heartLow = {
		ids = { "rbxassetid://131163326823954" },
		group = "Sfx",
		volume = 0.35,
		minGap = 4,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_CatLeave; a cat gives up and leaves (CatLeft)
	catLeave = {
		ids = { "rbxassetid://76629422520057" },
		group = "Sfx",
		volume = 0.4,
		minGap = 1.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_CrateOpen; a crate is tapped open, the same for every pet (CrateOpened)
	crateOpen = {
		ids = { "rbxassetid://79226161962410" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.5,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_PetReveal; the pet is shown, one sound for every rarity (PetRevealed)
	petReveal = {
		ids = { "rbxassetid://127482831304110" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.8,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_StarUp; three pets fuse into a star up (PetStarUp)
	starUp = {
		ids = { "rbxassetid://101245579559480" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.8,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_WorkerDone; a worker finishes a cat, quieter since it comes often (WorkerFinished)
	workerDone = {
		ids = { "rbxassetid://80163733789302" },
		group = "Sfx",
		volume = 0.3,
		pitch = { 0.97, 1.03 },
		minGap = 0.6,
		voices = 1,
	},
	-- synth: CleanACat_Sfx_BuildDone; a build is finished (BuildFinished)
	buildDone = {
		ids = { "rbxassetid://132182941650686" },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
		voices = 1,
	},
	-- synth: CleanACat_Ui_QuestDone; a quest is ticked off (QuestDone)
	questDone = {
		ids = { "rbxassetid://86675527942579" },
		group = "Ui",
		volume = 0.45,
		minGap = 0.4,
		voices = 1,
	},
	-- synth: CleanACat_Ui_CheckIn; the check in card's reward is taken (CheckInClaimed)
	checkIn = {
		ids = { "rbxassetid://105013415580311" },
		group = "Ui",
		volume = 0.45,
		minGap = 0.5,
		voices = 1,
	},
	spaMusicA = {
		ids = { "rbxassetid://107621531888888" },
		group = "Music",
		volume = 0.5,
		voices = 1,
	},
	spaMusicB = {
		ids = { "rbxassetid://89957079712346" },
		group = "Music",
		volume = 0.5,
		voices = 1,
	},
}

return Cues
