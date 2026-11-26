--!strict
-- LiveFlags: live on/off switches, so a feature can be turned on or off in every running server within about
-- a minute, with no publish and no restart. Every switch is a boolean in one entry, ALL_ENTRY, of the DataStore
-- named STORE (a table keyed by switch name), so one read a minute covers them all (#325). The flags workflow
-- (tools/opencloud/flags.sh) writes it; LiveFlagService reads it every CHECK_SECONDS and copies each switch to a
-- ReplicatedStorage attribute (ATTRIBUTE_PREFIX .. key) so client code can read it too. Until flags.sh first writes
-- ALL_ENTRY, servers read the older layout instead: one boolean entry per switch, named after the switch.
--
-- Two kinds of switch:
-- - A plain key in KEYS is ON unless the store says an explicit false. A missing entry, a wrong type or a
--   failed read leaves it on, so a broken store can never switch the game off. Use it as a kill switch.
-- - A key also listed in OFF_BY_DEFAULT is OFF unless the store says an explicit true, so a missing entry or
--   a broken store never switches it on. New features ship this way: merged and published while off, then
--   turned on with the flags workflow, with the off switch kept for instant rollback.
--
-- Keep one key per line in the shape below: flags.sh reads the names straight from this file.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = {}

LiveFlags.STORE = "CleanACat_Flags"
-- The entry that holds every switch. A switch name never has an underscore, so it can never be a switch's own entry.
LiveFlags.ALL_ENTRY = "_switches"
LiveFlags.ATTRIBUTE_PREFIX = "LiveFlag_"
LiveFlags.CHECK_SECONDS = 60
-- Set true on ReplicatedStorage once a server has read every switch for the first time (or gave up after
-- READ_WAIT_SECONDS). Until then every switch reads as its default, so code that decides something once per join,
-- like whether the opening plays, waits for it with LiveFlags.waitForRead (the first player in a new server joins
-- before the store has answered).
LiveFlags.READ_ATTRIBUTE = "LiveFlagsRead"
LiveFlags.READ_WAIT_SECONDS = 8

LiveFlags.KEYS = {
	"exampleFeature", -- an example to copy: say what the switch does and which module reads it; off by default
	"scrubPrototype", -- the scrub and reveal prototype (Controllers/ScrubController); off by default
	"scrubEffects", -- foam and mud particles while scrubbing (Controllers/EffectsController); off by default
	"revealEffects", -- sparkles and water droplets when a cat comes clean (Controllers/EffectsController); off by default
	"fluffEffects", -- fur puffs, the fluffed glow and bow hearts (Controllers/EffectsController); off by default
	"catMotion", -- cat idle, blink, ear twitch, shake-off and happy wiggle (Effects/CatMotion); off by default
	"dryEffects", -- warm air wisps from the dryer nozzle (Controllers/EffectsController); off by default
	"toolsBoard", -- the Tools board and Bubble Soap (ToolService, Controllers/ToolsBoardController); off by default
	"customers", -- customers at the door bring rolled cats and pay on return (SpaService, Controllers/DoorController); off by default
	"strays", -- strays, the display window and its tips (SpaService, WindowService, Controllers/WindowController); off by default
	"catIndex", -- Cat Index stamps and the full set bonus (IndexService, Controllers/IndexController); off by default
	"builds", -- station and room builds with timers that run while away (BuildService, Controllers/BuildBoardController); off by default
	"spaPlot", -- the spa plot in Workspace and every spot on it (PlotService, Shared/SpaLayout); off by default
	"onboardingFunnel", -- the onboarding_v1 funnel and its side events (Telemetry, FunnelService); off by default
	"scrubTurn", -- the cat turns in the tub to show its muddy side (Controllers/ScrubController); off by default
	"longBuildOffer", -- the bell on long builds and the build finished notification (NotifyService, BuildBoardController); off by default
	"spaVisitors", -- players may walk into other players' spas; off means look only (Controllers/PlotController); off by default
	"stations", -- built stations and build pads in the player's plot, and the dry step (StationService, ScrubController); off by default
	"customerFigures", -- real customers holding carriers at the door, drawn by the server (FigureService, DoorController); off by default
	"scrubFeel", -- a mud patch takes a few strokes and a scrubbing finger never walks the player (Controllers/ScrubController); off by default
	"spawnView", -- the player spawns behind their tub facing the street, so the first frame is not a wall (PlotService); off by default
	"comfortSettings", -- see-through panels honour the player's solid-background choice and the toast grows with larger text (UI/Comfort); off by default
	"springUi", -- trial (#183): windows pop in and buttons squash with spr springs (UI/Motion); off by default
	"queuePick", -- the player picks which waiting customer is washed next (SpaService, QueuePickController); off by default
	"gameHud", -- the game HUD: coin counter, wash step bar and tool tray (UI/HUD, HudController); off by default
	"recapCard", -- the recap card after each customer's cat, and the next cat waits for Next cat (UI/Recap, RecapController); off by default
	"catIndexWindow", -- the Cat Index window and its HUD button (UI/CatIndex, IndexWindowController); off by default
	"queueWindow", -- the "Who's next?" window and the HUD's waiting faces (UI/QueueWindow, QueueWindowController); off by default
	"tutorialTrail", -- the tutorial's floor trail: green arrows on the floor to a spot, a ring and a gold arrow over it (Spa/FloorTrail); off by default
	"tutorialTip", -- the tutorial's step pill ("2 / 3" and "Wash him") in the step bar's place, over the dim (UI/HUD/TipLine); off by default
	"tutorialDim", -- the tutorial's dim step: the screen dims round one HUD button and an arrow says tap it (UI/Spotlight); off by default
	"windowsHideControls", -- the phone's thumbstick and jump button hide while a window is open (UI/init); off by default
	"sudsMascot", -- Suds curls up on his bed by the door once named, and purrs and hops when tapped (MascotService, #285); off by default
	"sudsWash", -- a brand new save's first cat is the muddy kitten who becomes Suds, washed for a 3 star score (Shared/SudsRules, #285); off by default
	"bubbleBath", -- the Bubble Bath station and the smell need it washes (WashDraft, #267); off by default
	"pawdicure", -- the Pawdicure station and the long claws need it trims (WashDraft, #267); off by default
	"proBrush", -- the Pro Brush on the Tools board: the tangles brush out in fewer strokes (WashDraft, #267); off by default
	"settingsCard", -- the Settings card: sound sliders, less shake and less sparkle; the Menu opens it (UI/Settings, SettingsController); off by default
	"sudsBubble", -- Suds's help bubble at the bottom of the screen: his face, why, one button that points the way, once each per save (UI/SudsBubble, BubbleController); off by default
	"recapSide", -- the full recap card as a narrow column at the left with no dim, so the clean cat stays in view; the touch controls hide while it shows (UI/Recap); off by default
	"washChecklist", -- a tick list of this cat's wash steps at the left in the step pips' place; the HUD button row steps aside during the wash (UI/HUD/StepList); off by default
	"spaSign", -- each spa's name on the face of its window sign, "<display name>'s Spa" (Controllers/SpaSignController, #379); off by default
	"openingReplay", -- testing only: the game's owner gets the opening again on every join, nobody else (SpaService); off by default
	"carryHold", -- Derek's carry hold from his clip (forearms out at belly height, Effects/Carry) instead of the crossed arms; on in dev, Studio playtests always use it; off by default
	"openingBox", -- the opening scene: the truck, the bump and the box landing in front of the player (Effects/OpeningScene); off by default
	"photoCamera", -- Model-Agent's photo camera on a stand (CleanACat_Prop_PhotoCamera) for the photo tap in the tub, instead of the pink block (Controllers/ScrubController); off by default
	"washView", -- every cat in the tub is washed in the close-up wash view with the avatar hidden, not only Suds in the opening (Spa/WashView, Controllers/ScrubController); off by default
	"autoTool", -- the wash picks each step's tool by itself with no tool tray at the bottom; the top line and the tick list say what to do (UI/HUD); off by default
	"toolCursor", -- the wash step's tool (sponge, brush, ...) drawn under the finger while it works on the cat, kept off the cat's face (UI/HUD/HeldTool); off by default
	"toolOnCat", -- the wash step's real 3D tool (sponge, brush, clipper) on the cat's fur where the player rubs, following the finger (Spa/ToolOnCat); off by default
	"customerCarry", -- the player takes a customer's cat from them at the door and carries it to the tub; the wash starts once it is in (SpaService, CarryController, CarryRules); off by default
	"carryShared", -- a cat in someone's arms shows for every other player too, arms and all (Effects, Motion-FX; the server marks the character, CarryRules); off by default
	"washScene", -- the wash's close-up as its own scene: a tighter shot, a narrower view and the room softly blurred (Effects/WashCamera, Motion-FX #407); off by default
	"smallPrompts", -- every tap prompt (pick him up, open the box, the boards) drawn as a small pill beside its thing instead of Roblox's big black button (Controllers/PromptController); off by default
	"worldBackdrop", -- the draft world behind the street: hills, houses and trees the road runs into (Model-Agent's CleanACat_Area_Backdrop, BackdropController), this player's own copy; off by default
	"skyDraft", -- the draft sky and light: pastel haze, soft clouds, warm tint and gentle bloom (Effects/Sky), this player's own; off by default
	"streetLoadTest", -- dev place only: fills every empty plot with a full plot for the phone frame check (StreetLoadService); off by default
	"latherFoam", -- the Bubble Bath lathers foam onto the fur where the player rubs, then it rinses off by itself once he is covered (the owner's 2026-11-25 note, ScrubController); off by default
	"trailLine", -- the tutorial's guide: one see-through green line from the player's feet to the spot with an arrowhead, instead of the floor chevrons (Spa/FloorTrail, Effects/TrailLine, #451); off by default
	"placeAfterHop", -- the opening asks the server to take Suds only once his hop into the tub lands, so the tub's kitten never shows mid-hop (the owner's dev note of 2026-11-25, OpeningController); off by default
	"townsfolk", -- the customers at the door are Model-Agent's eight townsfolk with the carrier in their hand, walking in from the pavement and up the line (FigureService, CustomerWalkController, #446); off by default
	"customerWalk", -- the townsfolk's legs and arms swing as they walk and they look round while they wait (Effects/CustomerMotion, Motion-FX #462); off by default
	"washMeter", -- a fill bar at the top over the wash's area steps (scrub, brush, lather, a new spray-off rinse, claws); at about 90 percent the cat shakes off the rest and the next step starts (the owner's 2026-11-25 salon video note, ScrubController, WashMeter); off by default
	"dirtLevels", -- each customer's cat comes at a dirt level 1 to 4, rarer cats dirtier: more mud and tangles, more steps (the bath from level 2, the claws from 3, no station needed) and more pay (the owner's 2026-11-25 pick, DirtRules); off by default
	"heartBar", -- each waiting customer's cat has a heart bar that drains; picked early it pays a bonus, at empty the customer leaves (never before 10 minutes of play, never before the first serve), and the pay is base x wash stars x early x dirt with a recap line each (the owner's 2026-11-25 picks, HeartRules, issue 507); off by default
	"promptFocus", -- while the player holds a cat or Suds, the tub's "Put in tub" or "Wash him" is the only prompt on their device, so a board's prompt nearby never takes the pill (Spa/PromptFocus, Review-QA's pass A, #540); off by default
	"bowTiers", -- bow tiers bought with coins at the Tools board (Silk, Satin, Golden after the free Ribbon), each paying more on every hand washed customer's cat (BowRules, issue 508); off by default
	"workers", -- Jo and Sam are hired with coins, each with a station on the back wall; a worker takes a waiting cat by the mode the player sets, washes it with a progress bar over it, and pays a small share (WorkerRules, WorkerService, issue 509); off by default
	"specialVisitors", -- now and then a special visitor joins the line with one of the six special cats (always dirt level 4, pays the most, workers never take it); the first of a save comes at about 4:00 and its wash always leaves a crate, later ones rarely (SpecialRules, issue 510); off by default
	"pets", -- crates the player holds stand by their tub with their chance list over them; a tap opens one, the pet walks beside the player (boosting tips) or sits by a worker (boosting their pay, capped), and three of the same fuse into a star up (CrateRules, PetService, issues 511 and 512); off by default
}

LiveFlags.OFF_BY_DEFAULT = {
	exampleFeature = true,
	scrubPrototype = true,
	scrubEffects = true,
	revealEffects = true,
	fluffEffects = true,
	catMotion = true,
	dryEffects = true,
	toolsBoard = true,
	customers = true,
	strays = true,
	catIndex = true,
	builds = true,
	spaPlot = true,
	onboardingFunnel = true,
	scrubTurn = true,
	longBuildOffer = true,
	spaVisitors = true,
	stations = true,
	customerFigures = true,
	scrubFeel = true,
	streetLoadTest = true,
	comfortSettings = true,
	springUi = true,
	spawnView = true,
	queuePick = true,
	gameHud = true,
	recapCard = true,
	settingsCard = true,
	catIndexWindow = true,
	queueWindow = true,
	tutorialDim = true,
	tutorialTip = true,
	tutorialTrail = true,
	windowsHideControls = true,
	sudsWash = true,
	sudsMascot = true,
	bubbleBath = true,
	pawdicure = true,
	proBrush = true,
	openingBox = true,
	carryHold = true,
	skyDraft = true,
	worldBackdrop = true,
	photoCamera = true,
	washView = true,
	smallPrompts = true,
	autoTool = true,
	toolCursor = true,
	toolOnCat = true,
	customerCarry = true,
	washScene = true,
	carryShared = true,
	openingReplay = true,
	sudsBubble = true,
	recapSide = true,
	washChecklist = true,
	spaSign = true,
	placeAfterHop = true,
	latherFoam = true,
	trailLine = true,
	townsfolk = true,
	customerWalk = true,
	washMeter = true,
	dirtLevels = true,
	heartBar = true,
	promptFocus = true,
	bowTiers = true,
	workers = true,
	specialVisitors = true,
	pets = true,
} :: { [string]: boolean }

-- What a stored value means for a key. `stored` is whatever the DataStore returned (nil when missing).
function LiveFlags.resolve(key: string, stored: unknown): boolean
	if LiveFlags.OFF_BY_DEFAULT[key] then
		return stored == true
	end
	return stored ~= false
end

-- What the ALL_ENTRY entry `all` stores for `key`: nil when `all` is not a table or has no such key, which then
-- means the same as a missing entry did in the one-entry-per-switch layout.
function LiveFlags.storedIn(all: unknown, key: string): unknown
	if type(all) ~= "table" then
		return nil
	end
	return (all :: { [any]: unknown })[key]
end

-- Is the switch on right now? Works on the server and the client. Before LiveFlagService's first read the
-- attribute is missing, which gives each switch its default.
function LiveFlags.isOn(key: string): boolean
	return LiveFlags.resolve(key, ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key))
end

-- Has this server read the switches yet (READ_ATTRIBUTE)?
function LiveFlags.read(): boolean
	return ReplicatedStorage:GetAttribute(LiveFlags.READ_ATTRIBUTE) == true
end

-- Yields until the first read is done, at most `seconds` (default READ_WAIT_SECONDS). True when it was read.
function LiveFlags.waitForRead(seconds: number?): boolean
	local deadline = os.clock() + (seconds or LiveFlags.READ_WAIT_SECONDS)
	while not LiveFlags.read() and os.clock() < deadline do
		task.wait(0.1)
	end
	return LiveFlags.read()
end

return LiveFlags
