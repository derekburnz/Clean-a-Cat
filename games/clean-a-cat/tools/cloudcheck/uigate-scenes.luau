--!nocheck
--[[
	uigate-scenes: what the UI gate (uigate.mjs) opens on each screen size. Called with (UIShim) from ui-shim.luau.

	setup() starts the real UI the way Controllers/UIController does. Give it a player chosen to stress the
	layout once the game has state (the longest numbers and names, full lists). Each scene then opens one window
	through the same call the game uses. A new window goes in SCENES; the gate builds it at every screen size.
	close() puts everything back between scenes.
]]

local UIShim = ...

local Scenes = {}

local UI

-- A switch, as the flags workflow would set it.
local function flag(name, on)
	game:GetService("ReplicatedStorage"):SetAttribute("LiveFlag_" .. name, on)
end
local function hud(on)
	flag("gameHud", on)
end

-- A Cat Index halfway through: some cats washed, some residents, the rest unseen.
local function indexEntries()
	return {
		Muffin = { washed = true, resident = false },
		Cotton = { washed = true, resident = true },
		Inky = { washed = true, resident = false },
		Tux = { washed = true, resident = true },
		Marble = { washed = false, resident = true },
		LilacCloud = { washed = true, resident = false },
	}
end

-- The recap card (#224, switch recapCard) at its widest: the longest name, every row, five stars and New!.
local function recap(full)
	flag("recapCard", true)
	hud(true)
	UI.setCoins(999999)
	UI.showRecap({
		cat = "Marshmallow",
		rarity = if full then "Legendary" else "Uncommon",
		coins = 80,
		tip = 15,
		bonus = 12,
		stars = if full then 5 else 1,
		isNew = true,
		full = full,
	})
end

function Scenes.setup()
	UI = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI")
	UI.init()
end

local SCENES = {
	{
		"Example",
		function()
			UI.open("Example")
		end,
	},
	{
		"Toast",
		function()
			UI.toast("This server updates in 10 minutes. Your progress is saved.", "info")
		end,
	},
	-- The game HUD (#210, switch gameHud), at its widest: the longest coin count before it goes short (999,999)
	-- and the longest step line, then a short count on the first step.
	{
		"HudWash",
		function()
			hud(true)
			UI.setCoins(999999)
			UI.setWashStage("styled")
		end,
	},
	{
		"HudScrub",
		function()
			hud(true)
			UI.setCoins(12345678)
			UI.setWashStage("dirty")
		end,
	},
	{
		"RecapFull",
		function()
			recap(true)
		end,
	},
	{
		"RecapStrip",
		function()
			recap(false)
		end,
	},
	-- The same card at the side with no dim (switch recapSide), so the clean cat stays in view; the touch controls hide.
	{
		"RecapSide",
		function()
			flag("recapSide", true)
			UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Recap").sideOnPhones = true
			recap(true)
		end,
	},
	-- The naming card at the side (switches recapSide and sudsWash).
	{
		"RecapSideSuds",
		function()
			flag("recapSide", true)
			UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Recap").sideOnPhones = true
			flag("recapCard", true)
			hud(true)
			UI.setCoins(0)
			UI.showRecap({
				cat = "Suds",
				rarity = "Common",
				coins = 0,
				tip = 0,
				bonus = 0,
				stars = 3,
				isNew = false,
				full = true,
				mascot = true,
			})
		end,
	},
	-- The opening's kitten's card at his naming (#285, switch sudsWash): his name and three stars, nothing paid.
	{
		"RecapSuds",
		function()
			flag("recapCard", true)
			hud(true)
			UI.setCoins(0)
			UI.showRecap({
				cat = "Suds",
				rarity = "Common",
				coins = 0,
				tip = 0,
				bonus = 0,
				stars = 3,
				isNew = false,
				full = true,
				mascot = true,
			})
		end,
	},
	-- The Settings card (#230, switch settingsCard): as it opens, then with a slider low and a switch on.
	{
		"Settings",
		function()
			flag("settingsCard", true)
			UI.open("Settings")
		end,
	},
	{
		"SettingsChanged",
		function()
			flag("settingsCard", true)
			UI.showSettings({ music = 0.2, sounds = 0.85, lessShake = true, lessSparkle = false })
			UI.open("Settings")
		end,
	},
	-- The HUD's button row (#232) with the Settings button, in place of the starter Menu.
	{
		"HudButtons",
		function()
			hud(true)
			flag("settingsCard", true)
			UI.setCoins(999999)
			UI.setWashStage("dirty")
		end,
	},
	-- The Cat Index window (#238, switch catIndexWindow): a half-stamped grid, then one cat's detail.
	{
		"CatIndex",
		function()
			flag("catIndexWindow", true)
			UI.setIndex(indexEntries(), { Muffin = true, LilacCloud = true }, 2)
			UI.open("CatIndex")
		end,
	},
	-- The same with the switch windowsHideControls on: the phone's thumbstick and jump button hide while it is open.
	{
		"CatIndexNoControls",
		function()
			flag("catIndexWindow", true)
			flag("windowsHideControls", true)
			UI.setIndex(indexEntries(), { Muffin = true, LilacCloud = true }, 2)
			UI.open("CatIndex")
		end,
	},
	{
		"CatIndexDetail",
		function()
			flag("catIndexWindow", true)
			UI.setIndex(indexEntries(), { LilacCloud = true }, 2)
			UI.open("CatIndex")
			UI.showIndexDetail("LilacCloud")
		end,
	},
	-- "Who's next?" (#246, switch queueWindow): three everyday customers with picks open, then a line with a new Rare
	-- VIP and an Epic one, a Dryer not built yet (locked needs) and picks not open yet. HudWaiting: the HUD's
	-- waiting faces.
	{
		"Queue",
		function()
			flag("queueWindow", true)
			local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
			local cards = QueueViewRules.cards(
				{ "Muffin", "Cotton", "Patches" },
				indexEntries(),
				{ Dryer = true }
			)
			UI.setQueue(cards, QueueViewRules.headline(cards, 1), { [2] = true, [3] = true })
			UI.open("Queue")
		end,
	},
	-- A line of six (benchGrow with tubs built): one row on a wide screen, scrolling sideways on a phone.
	{
		"QueueSix",
		function()
			flag("queueWindow", true)
			local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
			local cards = QueueViewRules.cards(
				{ "Muffin", "Cotton", "Patches", "Inky", "Marble", "Toffee" },
				indexEntries(),
				{}
			)
			UI.setQueue(
				cards,
				QueueViewRules.headline(cards, 1),
				{ [2] = true, [3] = true, [4] = true }
			)
			UI.open("Queue")
		end,
	},
	-- The bench cards with dirt levels and heart bars (dirtLevels, heartBar): a fresh cat in its quick bonus, one half
	-- way, a grumpy one, and a level 4 special visitor's cat.
	{
		"QueueHearts",
		function()
			flag("queueWindow", true)
			local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
			local now = game:GetService("Workspace"):GetServerTimeNow()
			local function heart(left: number)
				return { since = now - 240 * (1 - left), lasts = 240, stops = false, paused = false }
			end
			local DirtRules = UIShim.require("ReplicatedStorage.Shared.DirtRules")
			local cats = { "Muffin", "Patches", "Toffee", "Bathtile" }
			local rolled = {}
			for place, cat in cats do
				rolled[place] = DirtRules.needs(cat, place)
			end
			local cards = QueueViewRules.cards(
				cats,
				indexEntries(),
				{},
				rolled,
				{ [1] = 1, [2] = 2, [3] = 3, [4] = 4 },
				{ [1] = heart(0.97), [2] = heart(0.6), [3] = heart(0.2), [4] = heart(0.8) }
			)
			UI.setQueue(
				cards,
				QueueViewRules.headline(cards, 1),
				{ [2] = true, [3] = true, [4] = true }
			)
			UI.open("Queue")
		end,
	},
	{
		"QueueVip",
		function()
			flag("queueWindow", true)
			local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
			local cards = QueueViewRules.cards(
				{ "Smudge", "Toffee", "LilacCloud" },
				indexEntries(),
				{}
			)
			UI.setQueue(cards, QueueViewRules.headline(cards, 2), {})
			UI.open("Queue")
		end,
	},
	-- The crate window (issue 526, switch crateWindow): the normal crate with three held and two pets owned, then
	-- the day 2 good crate.
	{
		"Crate",
		function()
			flag("crateWindow", true)
			local CrateViewRules = UIShim.require("ReplicatedStorage.Shared.CrateViewRules")
			UI.showCrate("normal", 3, CrateViewRules.rows("normal", { Cozy = true, Koi = true }))
		end,
	},
	-- The Robux crate rows (issue 514, switch crateShop): under Open crate, with the chance list beside them.
	{
		"CrateShop",
		function()
			flag("crateWindow", true)
			flag("crateShop", true)
			local CrateViewRules = UIShim.require("ReplicatedStorage.Shared.CrateViewRules")
			local prices: { [string]: number } = { CrateOne = 49, CrateFive = 199 }
			UI.setCrateShop(CrateViewRules.shopRows("normal", true, function(key: string): unknown
				return prices[key]
			end))
			UI.showCrate("normal", 0, CrateViewRules.rows("normal", { Cozy = true }))
		end,
	},
	{
		"CrateGood",
		function()
			flag("crateWindow", true)
			local CrateViewRules = UIShim.require("ReplicatedStorage.Shared.CrateViewRules")
			UI.showCrate("good", 1, CrateViewRules.rows("good", {}))
		end,
	},
	-- The shop's passes (issues 518 and 526, switch passes): four priced, Lou owned; then a phone-wide second pet
	-- slot in the pets window.
	{
		"Shop",
		function()
			flag("passes", true)
			local ShopViewRules = UIShim.require("ReplicatedStorage.Shared.ShopViewRules")
			local prices: { [string]: number } = {
				DoubleCoins = 199,
				SecondBuilder = 299,
				GoldenSponge = 99,
				Lou = 249,
				SecondPetSlot = 249,
			}
			UI.setShop(ShopViewRules.cards(function(key: string): unknown
				return prices[key]
			end, function(key: string): boolean
				return key == "Lou"
			end))
			UI.open("Shop")
		end,
	},
	{
		"ShopEmpty",
		function()
			flag("passes", true)
			UI.setShop({})
			UI.open("Shop")
		end,
	},
	-- The starter pack (issue 519, switch starterPack with passes): every price known with the saving, then the pack's
	-- own price known but one pass price missing, so the struck total and the saving stay out.
	{
		"Starter",
		function()
			flag("passes", true)
			flag("starterPack", true)
			local StarterViewRules = UIShim.require("ReplicatedStorage.Shared.StarterViewRules")
			local prices: { [string]: number } =
				{ GoldenSponge = 99, SecondPetSlot = 249, DoubleCoins = 199 }
			UI.setStarter(
				StarterViewRules.items(function(key: string): unknown
					return prices[key]
				end),
				299,
				os.time() + 44 * 3600 + 14 * 60 + 36
			)
			UI.open("Starter")
		end,
	},
	{
		"StarterNoPrice",
		function()
			flag("passes", true)
			flag("starterPack", true)
			local StarterViewRules = UIShim.require("ReplicatedStorage.Shared.StarterViewRules")
			local prices: { [string]: number } = { GoldenSponge = 99, DoubleCoins = 199 }
			UI.setStarter(
				StarterViewRules.items(function(key: string): unknown
					return prices[key]
				end),
				299,
				os.time() + 3 * 3600 + 5
			)
			UI.open("Starter")
		end,
	},
	{
		"PetsSecond",
		function()
			flag("petsWindow", true)
			UI.setPets({
				{ id = 1, kind = "Cozy", star = 1, slot = "player" },
				{ id = 2, kind = "Koi", star = 2, slot = "player2" },
				{ id = 3, kind = "Nimbus", star = 1, slot = "Jo1" },
				{ id = 4, kind = "Pebble", star = 1 },
			}, { Jo = true, Sam = true }, true)
			UI.open("Pets")
		end,
	},
	-- The quest book (issue 516, switch quests): one daily done, the weekly crate one of three, then a short week.
	{
		"Quests",
		function()
			flag("quests", true)
			flag("crateWindow", true)
			local QuestViewRules = UIShim.require("ReplicatedStorage.Shared.QuestViewRules")
			UI.setQuests(
				QuestViewRules.clean({
					{
						id = "wash5",
						text = "Wash 5 customer cats",
						goal = 5,
						progress = 5,
						coins = 50,
						done = true,
					},
					{
						id = "dirty2",
						text = "Wash 2 cats at dirt level 3 or 4",
						goal = 2,
						progress = 1,
						coins = 60,
					},
					{
						id = "wStars20",
						text = "Get 3 stars on 20 cats",
						goal = 20,
						progress = 20,
						coins = 300,
						weekly = true,
						done = true,
					},
					{
						id = "wSpecial2",
						text = "Wash 2 special visitors' cats",
						goal = 2,
						progress = 1,
						coins = 300,
						weekly = true,
					},
					{
						id = "wDirt4x10",
						text = "Wash 10 cats at dirt level 4",
						goal = 10,
						progress = 4,
						coins = 300,
						weekly = true,
					},
				}),
				false,
				true
			)
			UI.open("Quests")
		end,
	},
	{
		"QuestsTaken",
		function()
			flag("quests", true)
			local QuestViewRules = UIShim.require("ReplicatedStorage.Shared.QuestViewRules")
			UI.setQuests(
				QuestViewRules.clean({
					{
						id = "bow3",
						text = "Put a bow on 3 cats",
						goal = 3,
						progress = 0,
						coins = 40,
					},
					{
						id = "early2",
						text = "Take 2 cats early",
						goal = 2,
						progress = 2,
						coins = 40,
						done = true,
					},
					{
						id = "wSpecial2",
						text = "Wash 2 special visitors' cats",
						goal = 2,
						progress = 2,
						coins = 300,
						weekly = true,
						done = true,
					},
				}),
				true,
				false
			)
			UI.open("Quests")
		end,
	},
	-- The check in card (issue 517, switch checkinCard): the first day ready, then day 2's good crate with day 1
	-- ticked, then nothing waiting after day 3.
	{
		"Checkin",
		function()
			flag("checkinCard", true)
			UI.setCheckin(1, 0, true)
			UI.open("Checkin")
		end,
	},
	{
		"CheckinDay2",
		function()
			flag("checkinCard", true)
			UI.setCheckin(2, 1, true)
			UI.open("Checkin")
		end,
	},
	{
		"CheckinWait",
		function()
			flag("checkinCard", true)
			UI.setCheckin(nil, 3, true)
			UI.open("Checkin")
		end,
	},
	-- The pets window (issue 526, switch petsWindow): three Cozy ready to fuse, a 2 star Koi with Jo, Sam not hired.
	{
		"Pets",
		function()
			flag("petsWindow", true)
			UI.setPets({
				{ id = 1, kind = "Cozy", star = 1, slot = "player" },
				{ id = 2, kind = "Cozy", star = 1 },
				{ id = 3, kind = "Cozy", star = 1 },
				{ id = 4, kind = "Koi", star = 2, slot = "Jo1" },
				{ id = 5, kind = "Pebble", star = 1 },
				{ id = 6, kind = "Pebble", star = 1 },
				{ id = 7, kind = "Nimbus", star = 3 },
				{ id = 8, kind = "Scrubby", star = 1 },
			}, { Jo = true })
			UI.open("Pets")
		end,
	},
	{
		"PetsEmpty",
		function()
			flag("petsWindow", true)
			UI.setPets({}, {})
			UI.open("Pets")
		end,
	},
	-- A line where cats bring the later needs (#267, switches bubbleBath and pawdicure): five needs on the Legendary
	-- one, so the needs stack over the pay even on a short card and shrink to share the card's width.
	{
		"QueueLater",
		function()
			flag("queueWindow", true)
			local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
			local rolled = {
				[1] = { "mud", "tangles", "wet", "smell" },
				[2] = { "mud", "tangles" },
				[3] = { "mud", "tangles", "wet", "smell", "claws" },
			}
			local cards = QueueViewRules.cards(
				{ "Toffee", "Muffin", "Starcoat" },
				indexEntries(),
				{ Dryer = true },
				rolled
			)
			UI.setQueue(cards, QueueViewRules.headline(cards, 2), { [2] = true, [3] = true })
			UI.open("Queue")
		end,
	},
	{
		"HudWaiting",
		function()
			hud(true)
			flag("queueWindow", true)
			flag("settingsCard", true)
			flag("catIndexWindow", true)
			UI.setCoins(999999)
			UI.setWashStage("dirty")
			local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
			UI.setQueue(QueueViewRules.cards({ "Muffin", "Toffee", "LilacCloud" }, {}, {}), "", {})
		end,
	},
	-- The tutorial's dim step (switch tutorialDim): the screen dims round the Index button and the arrow says tap it.
	{
		"TutorialDim",
		function()
			hud(true)
			flag("catIndexWindow", true)
			flag("tutorialDim", true)
			UI.setCoins(58)
			UI.setWashStage(nil)
			-- the step pill sits over the dim (#425), and the dim's words keep clear of it (#429)
			flag("tutorialTip", true)
			UI.setTip({ step = 3, total = 3, say = "Open your Index" })
			UI.pointAt("CatIndex", "Tap Index")
		end,
	},
	-- The tutorial's tip line (switch tutorialTip) in the step bar's place, while the first cat is washed.
	{
		"TutorialTip",
		function()
			hud(true)
			flag("tutorialTip", true)
			UI.setCoins(0)
			UI.setWashStage("dirty")
			UI.setTip({ step = 2, total = 3, say = "Wash him" })
		end,
	},
	-- The step bar with both later steps (#267): six steps, on the bath.
	{
		"HudLater",
		function()
			hud(true)
			UI.setCoins(999999)
			UI.setWashPlan({ "bath", "claws" })
			UI.setWashStage("bath")
		end,
	},
	-- The kitten's wash (#285): no bows, so three steps, on the brush.
	{
		"HudSuds",
		function()
			hud(true)
			UI.setCoins(0)
			UI.setWashPlan({ "noBows" })
			UI.setWashStage("clean")
		end,
	},
	-- Suds's help bubble (switch sudsBubble) at the bottom, with its longest words, while the player walks.
	{
		"SudsBubble",
		function()
			hud(true)
			flag("sudsBubble", true)
			UI.setCoins(1240)
			UI.setWashStage(nil)
			local BubbleRules = UIShim.require("ReplicatedStorage.Shared.BubbleRules")
			UI.showBubble(BubbleRules.get("longBuild"))
		end,
	},
	-- After Suds's naming card, the tub still empty: customers wait at the door (the HUD's waiting faces).
	{
		"SudsBubbleQueue",
		function()
			hud(true)
			flag("sudsBubble", true)
			flag("queueWindow", true)
			UI.setCoins(0)
			UI.setWashStage(nil)
			local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
			UI.setQueue(QueueViewRules.cards({ "Muffin", "Toffee", "LilacCloud" }, {}, {}), "", {})
			local BubbleRules = UIShim.require("ReplicatedStorage.Shared.BubbleRules")
			UI.showBubble(BubbleRules.get("firstCustomer"))
		end,
	},
	-- The tick list of this cat's steps (switch washChecklist) with both later steps, on the bath: two ticked, the
	-- bath gold, the button row stepped aside. Icons only on a short screen.
	{
		"HudChecklist",
		function()
			hud(true)
			flag("washChecklist", true)
			flag("catIndexWindow", true)
			flag("settingsCard", true)
			UI.setCoins(1240)
			UI.setWashPlan({ "bath", "claws" })
			UI.setWashStage("bath")
		end,
	},
	-- The wash meter (switch washMeter) under the step line, part filled, with the tick list on; and under the
	-- tutorial's pill on the first cat.
	{
		"HudMeter",
		function()
			hud(true)
			flag("washChecklist", true)
			UI.setCoins(999999)
			UI.setWashPlan({ "bath", "claws" })
			UI.setWashStage("dirty")
			UI.setWashMeter(0.62, "scrub")
		end,
	},
	{
		"HudMeterTip",
		function()
			hud(true)
			flag("tutorialTip", true)
			UI.setCoins(0)
			UI.setWashStage("dirty")
			UI.setTip({ step = 2, total = 3, say = "Wash him" })
			UI.setWashMeter(1, "scrub")
		end,
	},
	{
		"HudWalking",
		function()
			hud(true)
			UI.setCoins(1240)
			UI.setWashStage(nil)
		end,
	},
}

Scenes.names = {}
for _, scene in SCENES do
	table.insert(Scenes.names, scene[1])
end

function Scenes.open(name)
	for _, scene in SCENES do
		if scene[1] == name then
			scene[2]()
			return
		end
	end
	error("uigate: no scene " .. tostring(name))
end

function Scenes.close()
	UI.closeAll()
	UI.setWashStage(nil)
	UI.setWashMeter(nil, nil)
	UI.setWashPlan({})
	hud(false)
	flag("recapCard", false)
	flag("settingsCard", false)
	flag("catIndexWindow", false)
	flag("queueWindow", false)
	flag("crateWindow", false)
	flag("petsWindow", false)
	flag("tutorialDim", false)
	UI.hideBubble()
	flag("sudsBubble", false)
	flag("washChecklist", false)
	flag("recapSide", false)
	UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.Recap").sideOnPhones = false
	flag("tutorialTip", false)
	flag("windowsHideControls", false)
	UI.setTip(nil)
	UI.clearPointer()
	UI.setQueue({}, "", {})
	UI.showIndexDetail(nil)
	UI.showSettings({ music = 1, sounds = 1, lessShake = false, lessSparkle = false })
end

return Scenes
