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
	"spaMusic", -- the two spa songs on the spa floor (Audio, AudioController, issue 529); off by default
	"uiSounds", -- soft open and close sounds for windows and the More tray (Audio/UiSounds, issue 800); off by default
	"helperPopFx", -- the helper pay popup pops in with one soft coin sound (UI/HelperPopup, issue 801); off by default
	"counterCardFx", -- the counter cards grow and fade in, fade out and ease their heart bar (UI/CounterCard, issue 803); off by default
	"counterSlim", -- the counter card is only a small heart bar sized in studs, all in one row, so neighbours never collide (UI/CounterCard, Derek 2026-11-27); off by default
	"joPrice", -- Jo costs 300 coins, not 150, so the first helper still comes near cat 15 (WorkerRules.JO_PRICE, issue 841); off by default
	"washPace", -- each wash step takes about 4 to 5 seconds: more brush strokes, more lather, a narrower rinse, a longer claw hold (WashPace, issue 865); off by default
	"gradeStars", -- a wash earns its grade in spa stars (1 to 3, plus a rarer cat's extra) and the star tiers start 3 times higher (CatRules.gradeStars, issue 868); off by default
	"toastCards", -- the short notices are small cards at the top right, coloured by kind with a portrait for a cat, not a dark bar across the screen (UI/ToastCard, ToastRules, issue 877); off by default
	"rewardPop", -- a pet, crate, gift, check-in day or purchase shows as a big popup in the middle with its picture on a sunburst (UI/RewardPop, ToastRules, issue 1024); off by default
	"contextAsks", -- pop ups only when they guide a next action: announcement cards cut, guide cards name the action and start the floor trail, the notification ask waits for a first build, the special visitor and first crate get guide cards (BubbleRules, issue 877); off by default
	"openingBonus", -- a brand new spa's first customer tops the player up to Jo's price with a one-time Grand opening gift line (WorkerRules.openingGift, issue 913); off by default
	"sudsVoice", -- one soft meow when Suds's speech bubble appears (Audio/SudsVoice, issue 827); off by default
	"trailBold", -- the guide line in gold with a dark outline so it reads on the spa floor (Effects/TrailLine, Derek 2026-11-26); off by default
	"zoomCap", -- the camera zooms out at most CameraZoomController.MAX_ZOOM studs so the map ends stay hidden (issue 895); off by default
	"photoFx", -- the photo camera's LED blinks faster, the flash fires and a printed card slides out the back (Effects/PhotoFx, issue 862); off by default
	"carryBlink", -- a cat scaled after its rig was built (carried Suds) blinks with eyes at its own size (Effects/CatMotion, issue 903); off by default
	"washPops", -- little words and a combo count pop over the cat during the wash, with soft chimes (Effects/WashPops, issue 902); off by default
	"joArrive", -- Jo walks in to his hire pad with a short camera shot when the first helper card starts its trail (Effects/JoArrive, issue 913); off by default
	"tubLife", -- the tub's foam settles and breathes, bubbles rise and pop, the tap runs with a ripple (Effects/TubLife, issue 879); off by default
	"catWalkStand", -- a washed cat walks out on its standing model with a leg trot, not sitting (Effects/CatWalkOut); off by default
	"pillPointer", -- a gold hand bobs over the prompt pill at the end of a guided walk (Controllers/PillPointerController); off by default
	"boxGuide", -- the guide line back to the closed box when the player walks away before opening it (Controllers/BoxGuideController); off by default
	"coinBump", -- the HUD coin pill bumps, counts up and gives one coinPop on a gain (Effects/CoinBump, issue 826); off by default
	"counterSounds", -- a soft thud as a crate is set down and a meow as the cat steps out, own plot (Effects/CounterCrate, issue 828); off by default
	"claimFx", -- a claim sound and three sparkles when a Free Reward or the gift pet is claimed (Effects/ClaimFx, issue 802); off by default
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
	"washScreen", -- the wash minigame on its own screen: a clean room around the shot, no Walk button, prompt pills, player list or regular HUD, a bubbly wipe in and out (WashScreenController, issue 856); off by default
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
	"crateWindow", -- a tap on the crate by the tub opens the crate window: every pet with its chance and boost, how many crates the player holds and Open crate, in place of the list over the crate (UI/CrateWindow, CrateWindowController, issue 526); off by default
	"barSpacing", -- each waiting customer's heart bar ends at least heart.releaseStagger after the one ahead, so customers who joined together never leave together (HeartRules.spacedSince, SpaService, issue 573); off by default
	"boardKeys", -- each row of the Tools and Build boards has its own key and gamepad button, and on a touch screen every row's pill shows, so every row can be bought from where the player stands (BoardProp.rowKeys, issue 574); off by default
	"lineSwap", -- the door line is redrawn new first and old after, and a leaving customer's figure goes as their walk off starts, so the line never blinks empty or shows the leaver twice (FigureService, issue 571); off by default
	"benchGrow", -- once the spa has served its first customer the bench holds 3 plus one per built tub, at most 6 (places 4 to 6 on SpotBench4 to 6), and a short line takes its next customer every 6 s less one per tub (BuildRules.benchSize and refillSeconds, SpaService, issue 515); off by default
	"tutorialBench", -- until the tutorial ends at 2:45 of play the line holds 1 customer, then 2 from 2:00 (bench.tutorialSize, SpaRules.tutorialBench, SpaService); off by default
	"petsWindow", -- the HUD's Pets button and window: the player's pets with their stars and counts, Fuse on three of the same, and who has a pet (you and each hired helper), tap a slot then a pet (UI/PetsWindow, PetsWindowController, issue 526); off by default
	"finishNow", -- a running build's board prompt offers Finish now for Robux by the time left (5 min, 30 min, 2 h, 8 h, more; never under 15 s left), once the owner has created that tier's developer product; a saved credit covers it free (FinishRules, PurchaseService, BuildService, issue 515); off by default
	"tipJar", -- the tip jar fills from the hired workers while the player is away (30 coins an hour each, up to 8 hours; 12 hours and 1.25 times as fast with the Garden) and a tap on the jar collects it (JarRules, JarService, JarController, issue 517); off by default
	"lineReuse", -- with townsfolk on, the door line is redrawn in place: each waiting customer keeps their figure and steps up 1.2 s after a leaver goes, a new one walks in and a leaver is taken away, so nothing blinks or doubles (FigureService, CustomerWalkController, issues 571 and 570); off by default
	"checkinCard", -- the seven day check in card: one reward for each day played (not days in a row), the first at 3:45 of the first session; the server keeps CheckinReady and CheckinDays on the player for Design's card, and saves the player's time zone once (CheckinRules, CheckinService, issue 517); off by default
	"passes", -- the five game passes (2x Coins, Second Builder, Golden Sponge, Extra Worker, Second pet slot): each can be bought once the owner has created it, and works the moment it is bought and on every join (Passes, PassService, issue 518); off by default
	"landscapeLock", -- phones and tablets play in landscape only: the screen turns between the two landscape sides and never to portrait (OrientationController, issue 522); off by default
	"askQueue", -- the first session's ask queue: the check in card and later every ask outside the wash (notification, gift stand, favourite, each new HUD button, the starter button's bob) wait their turn, one at a time and a minute apart, never during a wash, a recap, a window or the opening, and a no is final for the visit (AskRules, AskController, issue 522); off by default
	"giftStand", -- the gift stand in every spa with its free pet Starcoat: lit from 7:00 of play, its card asks to like, favourite and join the group; the favourite and the group are checked and the pet is given once (the like is asked only) (GiftRules, GiftService, GiftController, issue 521); needs pets on too; off by default
	"visiting", -- the owner's setting for letting other players into their spa (on for every save; Settings card): while it is off, a visitor inside is moved out to the pavement in front (VisitRules, VisitService, issue 520); off by default
	"friendBonus", -- each of the player's Roblox friends in the server adds 10% to every cat they wash by hand, at most 30%, as its own recap line and on the HUD (tuning pay.friend; VisitRules, VisitService, SpaService, issue 520); off by default
	"staffRename", -- players rename their hired staff (up to 16 letters, numbers and spaces; empty is the default): every name goes through Roblox's text filter before anyone sees it, and again on each join; a hidden or failed name shows the default (StaffNameRules, StaffNameService, issue 487); off by default
	"benchSave", -- the waiting line is kept in the save each time it is sent, and a spa that has served before gets the same customers back on its next join, with full heart bars (never a special visitor or the tutorial line) (BenchSave, SpaService, issue 523); off by default
	"crateShop", -- normal crates for Robux (one for 49, five for 199), the same crate and chances as an earned one, shown only to players whose PolicyService info allows paid random items, with the chances shown before any buy (CrateRules.SHOP, CrateShopService, issue 514); needs pets on too; off by default
	"starterPack", -- the starter pack: one Robux product giving the Golden Sponge, the Second pet slot and 2x Coins, offered for 72 hours from first join (from the first join after this ships for older saves) to players who own none of the three, from the end of the tutorial; never restarts (StarterRules, StarterService, issue 519); needs passes on too; off by default
	"quests", -- the quest book: two daily quests from the pool each day of the player's own calendar and three weekly ones from Monday 00:00 UTC, counted from each customer's cat washed by hand and paid at once, with a normal crate for all three weekly ones (QuestRules, QuestService, issue 516); off by default
	"tubBuilds", -- the Build board sells the Second, Third and Fourth Tub, the VIP Room at its new price and the Garden; one builder; a built tub pays +2 on every hand wash and the VIP Room brings special visitors more often; with dirtLevels on, the old stations leave (BuildRules, issue 515); off by default
	"pets", -- crates the player holds stand by their tub with their chance list over them; a tap opens one, the pet walks beside the player (boosting tips) or sits by a worker (boosting their pay, capped), and three of the same fuse into a star up (CrateRules, PetService, issues 511 and 512); off by default
	"helpersWindow", -- a Helpers button on the HUD, shown once a helper is hired, opens one row per helper: their name, level with Level up and its price, the line they wash first (tap to change) and Rename; a helper not hired yet shows their price at their pad, and Lou his pass in the Shop (UI/HelpersWindow, HelperViewRules, issue 526 item 3); off by default
	"helperPets", -- each hired helper's row in the Helpers window has a pet box: their pet, or a paw when empty; a tap opens Pets with that helper's slot picked (owner 2026-11-26, issue 929). The world "Give a pet" prompt going away is petMenuOnly's job; off by default
	"recapEvery", -- the full recap card after every customer, not only the first ones and rarer cats (RecapRules.EVERY_FLAG; owner's plan page answer of 2026-11-25, issue 890); off by default
	"petLines", -- each pet says what it gives: "+5% tips or pay" on its tile in Pets and on its row in the crate's chance list, true numbers from CrateRules (CrateViewRules.effectText; owner 2026-11-26, issue 927); off by default
	"menuContrast", -- the cards and rows inside every window get a lilac edge that stands 3 to 1 against the window, not the pale line that melted into it (Kit.line; owner 2026-11-26, issue 928); off by default
	"buttonArrive", -- a HUD button that unlocks while the player is in the game arrives with Motion-FX's small pop, tilt and twinkle, once (Effects/Arrive from UI/HUD/SideButtons, issue 528); buttons already there on join simply show; off by default
	"fewerPills", -- with smallPrompts: at most two prompt pills show at once, the nearest within 10 studs (a winning one such as the door's Take cat at any distance); every key still works (Spa/PillLayout, issue 745); off by default
	"buildWindow", -- with hudTidy: a Build button in the HUD grid opens "Build and upgrades", every build with its price and time (or its countdown, what it waits for, or Built) and every tool and the next bow with Buy; the server skips only the distance to the board for RequestBuild, RequestBuyTool and RequestBuyBow, while Finish now still needs the board (BuildService, ToolService, BuildViewRules, UI/BuildWindow, BuildWindowController, issue 751); off by default
	"hudTidy", -- the phone-friendly HUD: the side buttons become a 2 by 2 grid (Shop, Build, Helpers once one is hired, More) with the rest in a More tray, the coins sit on a solid pill, the waiting faces leave the HUD, the starter pack becomes a side ad with its struck shop total and saving, and the helper stand's Level up prompt leaves the world since the Helpers window has it (HUD/SideButtons, HUD/StarterAd, WorkerController, issues 738 and 739); off by default
	"leaveLines", -- while Roblox's menu is open, two big friendly lines above and below its leave screen, each true for this player now (the tip jar with a helper hired, tomorrow's check in gift) or left out; no guilt or hurry (UI/LeaveLines, LeaveLineRules, issue 726); off by default
	"spawnSide", -- with spawnView on, the player spawns on the same spot turned a quarter to face the door line's side of the room, so the camera behind them starts in open room and not on the back wall's art (SpaLayout.spawnSpot, PlotService, issue 670); off by default
	"freeRewards", -- the gift card's Free Rewards rows: like the game (asked, never checked: Claim 10 s after the ask, 150 coins either way) and 30 minutes of play (one normal crate), each paid once per save by the server, beside the favourite plus group row for Starcoat; needs giftStand and pets on too (FreeRewardRules, FreeRewardService, UI/GiftCard, issue 730); off by default
	"likeAsk", -- with askQueue: after a good moment (a special visitor's cat finished, a crate opened, a three star card, a helper hired, or two minutes after a completed purchase) the server sets LikeAskDue and Design's small card asks for a like, once a visit, none for three visits after a no, never within two minutes of a lost cat or a cancelled purchase, never once the like row is paid (LikeAskRules, LikeAskService, LikeAskController); off by default
	"likeAskPurchase", -- with likeAsk: the like ask may also come two minutes after a completed purchase, never on the buy screen (Derek, 2026-11-26, q2-purchaseask; LikeAskRules.PURCHASE_FLAG, issue 813); off by default
	"notifyAsk", -- with askQueue, sudsBubble and longBuildOffer: from 1:45 of play Suds asks once a save, in his bubble, whether to be told when a build is done; only a tap on Sure! opens Roblox's opt-in prompt, and players Roblox would not prompt (under 13, already opted in) never see it (NotifyAskRules, NotifyAskService, NotifyAskController, issue 814); off by default
	"favouriteAsk", -- with askQueue, sudsBubble, giftStand and pets: a player whose favourite the gift stand does not have gets one reminder in Suds's bubble on the second visit or after 10 hand washes in a visit; only a tap on Favourite opens Roblox's favourite prompt, no reward named, once a save (FavouriteAskRules, FavouriteAskService, FavouriteAskController, issue 815); off by default
	"helperPopups", -- a helper finishing a cat sends HelperPaid to the owner (a popup over their stand, Design's) instead of the "+N coins: NAME washed CAT" toast, and the per cat toasts that repeat the screen ("+N coins", "+N coins, +S stars", "CAT went home") are left out; one-off toasts stay (WorkerService, SpaService, issue 743); off by default
	"counterLine", -- waiting customers stand at an open counter window by the desk with their cat on the counter in front of them (their carrier empty), and the player takes any cat from its counter place, no walk to the back of the line; another place than the front works as a pick, the front customer's cat going back on the counter; a leaving customer packs their cat back up (CounterRules, SpaService, FigureService, CarryController, issue 746); needs customers and customerCarry; off by default
	"counterCards", -- with counterLine and heartBar: a small card over each cat on the counter, a round chip in its owner's shirt colour and its heart bar, and that cat's mat washed in the same colour, so it is plain whose cat it is; client only, the Take prompt stays the tap (CounterCardRules, UI/CounterCard, CounterCardController, issue 745); off by default
	"bigSpa", -- Model-Agent's bigger spa: a roomier building (stations, helpers and doors moved back and out, the residents' seat left of the entrance) with the open counter window by the desk, on a wider street (56 studs a plot) with its own backdrop; read when the street is placed, so it takes effect on the next server start (SpaLayout.BIG_SPOTS, PlotService, BackdropController, issue 746); a missing big asset keeps the small spa; off by default
	"counterCrate", -- with counterLine: a new customer walks up with their cat in its crate and sets it on the counter; the server times it (CounterSetAt when they arrive, CounterReadyAt 2.4 s later) and the cat can be taken only once it sits, while Motion-FX's Effects walk it out of the crate and fade the crate (CounterRules, FigureService, SpaService, CarryController); off by default
	"respawnCamera", -- for 2 s after a respawn, while the player stands still and has not moved the camera, a camera looking more than 30 degrees from the new character's facing is made Scriptable for one frame behind the character, then Custom again, so Roblox's camera module drops its stale last transform and carries on from there (on a respawn the module's own turn is lost and the camera keeps its old yaw) (RespawnCameraController, issue 670); off by default
	"catWalkOut", -- a customer's washed cat hops out of the tub and trots out, fading (Effects/CatWalkOut, CatReturned); off by default
	"foamStep", -- the Bubble Bath step is "Foam up the cat": a soap bar (Model-Agent's CleanACat_Tool_SoapBar, the bubble sponge until it exists) rubbed on, foam building where it passes (WashDraft.SAY_FOAM, ToolOnCat, issue 888); off by default
	"bowDrag", -- the bow step is a drag: the three bows show in the player's best tier and one goes on when dropped on the cat; a gamepad keeps the tap (Spa/BowDrag, ScrubController, issue 889); off by default
	"helperFetch", -- a helper walks to the counter for the cat they take, carries it to their stand and back out when washed, instead of the cat appearing in the stand (HelperFetchRules, WorkerService, FigureService.handOver, HelperFetchController, issue 884); off by default
	"humanBuilder", -- the human builder in overalls (Model-Agent's CleanACat_NPC_Builder) stands by the builder board instead of the hard hat kitten, with the same hammer and toolbox; the kitten while the model is missing (StationService, issue 891); off by default
	"feedback", -- Settings' "Send feedback": a tap choice and an optional short note, filtered, counted in analytics and kept by day in the DataStore Feedback_v1 with no name or user id (FeedbackRules, FeedbackService, issue 1081; the window is Design-Agent's); off by default
	"giftGroupOnly", -- the gift stand's gift needs the group join only: the favourite stays asked on the card with no reward tied to it (GiftRules.canClaim, GiftService, issue 1068; the card's words are Design-Agent's); off by default
	"giftCrate", -- the gift stand's favourite and group gift is a gift crate to open (CrateRules kind gift, its own chance per pet shown before it opens: no Commons, Starcoat only from it) instead of Starcoat straight away (GiftRules.giveCrate, GiftService, CrateController, issue 859); off by default
	"giftFlow", -- the gift stand in three stages: one Claim all pays the like row's 150 coins and the welcome gift together, then a good crate at 30 minutes of play once that is claimed, then the stand leaves the spa (GiftFlowRules, GiftService, FreeRewardService, issue 919); off by default
	"likeHowTo", -- after Like is tapped on the gift card, its picture side shows once a visit how to like the game: a grey heart a tap dot fills pink, "Tap Like on the game's page", the gift either way, Got it; never says the like is checked (LikeHowToRules, UI/GiftCard, issue 869); off by default
	"wideStreet", -- with the big spa, the six plots stand 84 studs apart instead of 56 on Model-Agent's longer street (CleanACat_Area_StreetWide, with scenery between them), read at the street's placement like bigSpa; the big street while the asset is missing (SpaLayout, PlotService, BackdropController, issue 887); off by default
	"petMenuOnly", -- a hired helper's stand drops its "Give a pet" prompt while the Pets menu (petsWindow) is on: pets are given to the player and each helper there (WorkerRules.givePrompt, WorkerController, issue 930); off by default
	"washSides", -- half way through the scrub, the lather and the rinse the cat turns once so the player works on another side, then turns back to the front as he shakes (WashSidesRules, ScrubController, issue 899); off by default
	"showerAim", -- the rinse's shower head is held off the fur, above and in front of the touch, its nozzle aimed at it (ToolOnCat.nozzle for the spray, issue 899); off by default
	"outdoorWalk", -- once the first session's tutorial has ended (2:45 of play), the player walks at 24 studs a second outside every spa building, the default 16 inside one and all through the tutorial (OutdoorWalkRules, OutdoorWalkService, OutdoorWalkController, issue 886); off by default
	"tipTake", -- with counterLine: while the next cat waits on Suds's tip after a recap card, the cats on the counter keep their Take cat prompt, and a tap asks for the next cat at once and takes that cat (BubbleController.hurry, CarryController, issue 1017); off by default
	"noVisitBoard", -- the "Who might visit" chance board by the door is not drawn (Derek: it adds clutter); the same chances stay in the cat index and the queue window (ChanceBoardController, issue 1021); off by default
	"petSingles", -- the Pets window draws every pet as its own tile (no "x3" stacks) and a one star pet with no stars; stars show from two up (CrateViewRules.tiles, PetsWindow, issue 1035); off by default
	"coinLadder", -- the shop's 3x Coins pass shows only once 2x Coins is owned, and the server prompts it only then; 3x pays in place of 2x, never both, and works once owned with this off too (Passes.offered, ShopViewRules, PassService, issue 1031); off by default
	"launchSale", -- a pass or product whose Roblox price is below its regular price (SaleRules.REGULAR_*) shows that regular price struck through and "Launch sale: 50% off"; the prices themselves are set on Roblox by store-setup sale-prices (SaleRules, ShopViewRules, issue 1032); off by default
	"windowClear", -- a window's round badge sits inside its title band (no overhang over the first row or the HUD), and the HUD's buttons step aside while a window is open (UI/Window, UI init, issue 1038); off by default
	"menuOnly", -- a choice with a menu is made only there: no helper hire pads or Hire and Takes prompts at the stands (Helpers window), no Buy and Build prompts on the boards (Build window), no Wash next prompts (Who's next?), each only while its window is on; guide cards open the window (MenuRules, issues 1028 and 1033); off by default
	"noVipRoom", -- the VIP Room leaves the game: not on the board or in the Build window, no special visitor boost, and Model-Agent's wall piece fills its door so the back wall has one door; a save that built it keeps it for when the switch goes off (BuildRules.shown, StationService, issue 1063); off by default
	"catHotel", -- the Cat Hotel behind the back door (needs expansionDoor and builds): the door opens through a 20 minute build (1,500 coins), rooms 1 and 2 open, rooms 3 and 4 are builds; a guest waits at the desk while a room is free and sleeps 1, 4 or 8 hours of server time, then pays its coins and a gift; the Garden moves to the side yard (HotelRules, HotelService, StationService, issue 1049; the stay card is Design-Agent's, issue 1051); off by default
	"expansionDoor", -- the back door is a building site (caution tape, planks, paint pots) with one prompt, "Unlock · 1500 coins" (50 on dev); the server saves the unlock and the door stands open; the Garden shows there only behind the open door once built (ExpansionRules, ExpansionService, ExpansionController, issue 1041); off by default
	"resetSave", -- Settings' "Reset my game" for the dev game, Studio or the group's owner only: the save goes back to a new one (receipts and passes kept) and the player rejoins at the opening (ResetRules, ResetService, issue 1037); off by default
	"starterCard", -- the starter pack's HUD card is dark with one big picture, the true price and a round "i" for the breakdown; a tap on the card asks for the purchase prompt; no bob, no sparkles and no time chip (HUD/StarterAd, issue 1080); off by default
	"menuContrast2", -- every window's cream card turns a deeper lilac, the cards in it white, their edges and the soft body text ink (UI/Contrast, issue 1029); off by default
	"starterNoClock", -- the starter pack keeps its 72 hours, but its HUD chip and window read "New player offer" instead of the time left (StarterViewRules.hudNote, issue 1069, Derek's plan answer of 2026-11-27); off by default
}

LiveFlags.OFF_BY_DEFAULT = {
	exampleFeature = true,
	scrubPrototype = true,
	scrubEffects = true,
	revealEffects = true,
	fluffEffects = true,
	spaMusic = true,
	uiSounds = true,
	claimFx = true,
	counterSounds = true,
	coinBump = true,
	trailBold = true,
	boxGuide = true,
	pillPointer = true,
	catWalkStand = true,
	tubLife = true,
	joArrive = true,
	washPops = true,
	carryBlink = true,
	photoFx = true,
	zoomCap = true,
	sudsVoice = true,
	joPrice = true,
	washPace = true,
	gradeStars = true,
	toastCards = true,
	rewardPop = true,
	contextAsks = true,
	openingBonus = true,
	counterCardFx = true,
	counterSlim = true,
	helperPopFx = true,
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
	washScreen = true,
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
	barSpacing = true,
	boardKeys = true,
	lineSwap = true,
	pets = true,
	tubBuilds = true,
	benchGrow = true,
	tutorialBench = true,
	crateWindow = true,
	petsWindow = true,
	finishNow = true,
	tipJar = true,
	lineReuse = true,
	checkinCard = true,
	quests = true,
	passes = true,
	starterPack = true,
	crateShop = true,
	benchSave = true,
	landscapeLock = true,
	askQueue = true,
	giftStand = true,
	visiting = true,
	friendBonus = true,
	staffRename = true,
	helpersWindow = true,
	helperPets = true,
	recapEvery = true,
	petLines = true,
	menuContrast = true,
	buttonArrive = true,
	leaveLines = true,
	hudTidy = true,
	buildWindow = true,
	fewerPills = true,
	freeRewards = true,
	likeAsk = true,
	likeAskPurchase = true,
	notifyAsk = true,
	favouriteAsk = true,
	spawnSide = true,
	respawnCamera = true,
	helperPopups = true,
	counterLine = true,
	counterCards = true,
	bigSpa = true,
	counterCrate = true,
	catWalkOut = true,
	foamStep = true,
	bowDrag = true,
	helperFetch = true,
	humanBuilder = true,
	giftCrate = true,
	giftFlow = true,
	likeHowTo = true,
	wideStreet = true,
	petMenuOnly = true,
	washSides = true,
	showerAim = true,
	outdoorWalk = true,
	tipTake = true,
	noVisitBoard = true,
	coinLadder = true,
	launchSale = true,
	menuOnly = true,
	resetSave = true,
	petSingles = true,
	expansionDoor = true,
	starterCard = true,
	menuContrast2 = true,
	noVipRoom = true,
	windowClear = true,
	giftGroupOnly = true,
	starterNoClock = true,
	feedback = true,
	catHotel = true,
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
