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

-- Every HUD button on, with hudTidy, coins, two friends, three in the line and the starter pack's prices.
local function allButtons(priced: boolean)
	hud(true)
	flag("hudTidy", true)
	UI.setCoins(999999)
	for _, name in
		{
			"catIndexWindow",
			"petsWindow",
			"helpersWindow",
			"workers",
			"checkinCard",
			"quests",
			"passes",
			"settingsCard",
			"starterPack",
			"queueWindow",
			"friendBonus",
			"buildWindow",
		}
	do
		flag(name, true)
	end
	UI.setFriends(2)
	local player = game:GetService("Players").LocalPlayer
	player:SetAttribute("WorkerLevel_Jo", 1)
	player:SetAttribute("QuestsOpen", true)
	player:SetAttribute("StarterEndsAt", 1)
	local StarterViewRules = UIShim.require("ReplicatedStorage.Shared.StarterViewRules")
	local prices: { [string]: number } = if priced
		then { GoldenSponge = 99, SecondPetSlot = 249, DoubleCoins = 199 }
		else { GoldenSponge = 99, DoubleCoins = 199 }
	UI.setStarter(
		StarterViewRules.items(function(key: string): unknown
			return prices[key]
		end),
		199,
		os.time() + 44 * 3600
	)
	UI.setSideNote("Starter", "1d 20h")
	local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
	local cards = QueueViewRules.cards({ "Muffin", "Cotton", "Patches" }, indexEntries(), {})
	UI.setQueue(cards, QueueViewRules.headline(cards, 1), {})
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
	-- The card at its tallest in play (issue 991, Sync on an iPhone 13): a quick, early, extra dirty wash with a bow, a
	-- tip, the stations bonus, friends and a pass, so eight coin rows.
	{
		"RecapRows",
		function()
			flag("recapCard", true)
			hud(true)
			UI.setCoins(999999)
			UI.showRecap({
				cat = "Marshmallow",
				rarity = "Legendary",
				coins = 80,
				grade = 3,
				speed = 12,
				early = 6,
				dirt = 20,
				bow = 8,
				bowTier = "Ribbon",
				tip = 15,
				bonus = 12,
				friends = 10,
				pass = 80,
				stars = 5,
				isNew = true,
				full = true,
			})
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
	-- Settings with visiting on (issue 520): the "Visitors can come in" row shows; then the HUD's friend chip.
	{
		"SettingsVisitors",
		function()
			flag("settingsCard", true)
			UI.setVisitors(true)
			UI.open("Settings")
		end,
	},
	-- Settings with "Reset my game" (issue 1037): shown only for the dev game, Studio or the group's owner.
	{
		"SettingsReset",
		function()
			flag("settingsCard", true)
			UI.setCanReset(true)
			UI.open("Settings")
		end,
	},
	-- Settings with "Send feedback" (issue 1081, switch feedback), alone and with Reset my game on a dev server; then
	-- after one send ("Sent, thank you! Send more"), the longest words it shows.
	{
		"SettingsFeedback",
		function()
			flag("settingsCard", true)
			flag("feedback", true)
			UI.setFeedback(true, 0, 3)
			UI.open("Settings")
		end,
	},
	{
		"SettingsFeedbackReset",
		function()
			flag("settingsCard", true)
			flag("feedback", true)
			UI.setFeedback(true, 1, 3)
			UI.setCanReset(true)
			UI.setVisitors(true) -- the tallest Settings: every optional row and both buttons
			UI.open("Settings")
		end,
	},
	-- The Feedback card (issue 1081): as it opens (Send grey), then with "Something is hard" picked and a long note.
	{
		"Feedback",
		function()
			flag("feedback", true)
			UI.open("Feedback")
		end,
	},
	{
		"FeedbackPicked",
		function()
			flag("feedback", true)
			UI.open("Feedback")
			local card = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.FeedbackCard")
			card.pick("hard")
		end,
	},
	-- The Helpers window with menuOnly (issue 1033): Jo and Sam not hired yet, each with a Hire button.
	{
		"HelpersHire",
		function()
			hud(true)
			UI.setCoins(1240)
			flag("helpersWindow", true)
			flag("workers", true)
			flag("menuOnly", true)
			local HelperViewRules = UIShim.require("ReplicatedStorage.Shared.HelperViewRules")
			UI.setHelpers(
				HelperViewRules.rows(function(_name)
					return nil
				end, {}, function(name: string): boolean
					return name == "menuOnly" or name == "workers" or name == "helpersWindow"
				end),
				true,
				true
			)
			UI.open("Helpers")
		end,
	},
	{
		"HudFriends",
		function()
			hud(true)
			UI.setCoins(1240)
			UI.setWashStage(nil)
			UI.setFriends(2)
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
			UI.showCrate(
				"normal",
				3,
				CrateViewRules.rows("normal", { Clover = true, Angler = true })
			)
		end,
	},
	-- Each pet says what it gives (issue 927, switch petLines): "+5% tips or pay" on its chance row.
	{
		"CrateLines",
		function()
			flag("crateWindow", true)
			flag("petLines", true)
			local CrateViewRules = UIShim.require("ReplicatedStorage.Shared.CrateViewRules")
			UI.showCrate(
				"normal",
				3,
				CrateViewRules.rows("normal", { Clover = true, Angler = true })
			)
		end,
	},
	-- The Robux crate rows (issue 514, switch crateShop): under Open crate, with the chance list beside them.
	{
		"CrateShop",
		function()
			flag("crateWindow", true)
			flag("crateShop", true)
			local CrateViewRules = UIShim.require("ReplicatedStorage.Shared.CrateViewRules")
			local prices: { [string]: number } = { CrateOne = 99, CrateFive = 399 } -- the widest prices (issue 650)
			UI.setCrateShop(CrateViewRules.shopRows("normal", true, function(key: string): unknown
				return prices[key]
			end))
			UI.showCrate("normal", 0, CrateViewRules.rows("normal", { Clover = true }))
		end,
	},
	-- With a crate held: Open crate and the Robux rows together, the tallest the window gets (bug hunt B8).
	{
		"CrateShopHeld",
		function()
			flag("crateWindow", true)
			flag("crateShop", true)
			local CrateViewRules = UIShim.require("ReplicatedStorage.Shared.CrateViewRules")
			local prices: { [string]: number } = { CrateOne = 99, CrateFive = 399 }
			UI.setCrateShop(CrateViewRules.shopRows("normal", true, function(key: string): unknown
				return prices[key]
			end))
			UI.showCrate("normal", 1, CrateViewRules.rows("normal", { Clover = true }))
		end,
	},
	{
		"CrateGood",
		function()
			flag("crateWindow", true)
			local CrateViewRules = UIShim.require("ReplicatedStorage.Shared.CrateViewRules")
			UI.setCrateShop({}) -- the Robux rows are on the normal crate only (CrateWindowController)
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
	-- The launch sale (issue 1032, switch launchSale): each card's regular price struck through before the sale price,
	-- and a red "50% off" tag on its picture.
	{
		"ShopSale",
		function()
			flag("passes", true)
			flag("launchSale", true)
			local ShopViewRules = UIShim.require("ReplicatedStorage.Shared.ShopViewRules")
			local prices: { [string]: number } = {
				DoubleCoins = 25,
				SecondBuilder = 149,
				GoldenSponge = 49,
				Lou = 124,
				SecondPetSlot = 124,
			}
			UI.setShop(ShopViewRules.cards(function(key: string): unknown
				return prices[key]
			end, function(key: string): boolean
				return key == "GoldenSponge"
			end, function(name: string): boolean
				return name == "launchSale" or name == "passes"
			end))
			UI.open("Shop")
		end,
	},
	-- The coin ladder (issue 1031, switch coinLadder) once 2x Coins is owned: 3x Coins takes 2x's card, so the shop
	-- still shows five cards (Passes.offered). Review-QA's check on the shop revamp (PR 1107).
	{
		"ShopLadder",
		function()
			flag("passes", true)
			flag("coinLadder", true)
			local ShopViewRules = UIShim.require("ReplicatedStorage.Shared.ShopViewRules")
			local prices: { [string]: number } = {
				DoubleCoins = 50,
				TripleCoins = 100,
				SecondBuilder = 299,
				GoldenSponge = 99,
				Lou = 249,
				SecondPetSlot = 249,
			}
			UI.setShop(ShopViewRules.cards(function(key: string): unknown
				return prices[key]
			end, function(key: string): boolean
				return key == "DoubleCoins"
			end, function(name: string): boolean
				return name == "coinLadder" or name == "passes"
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
				199,
				os.time() + 44 * 3600 + 14 * 60 + 36
			)
			UI.open("Starter")
		end,
	},
	-- starterPet (issue 1090): a fourth card for Midas, "Bonus" and no price, with the saving from the three passes.
	{
		"StarterPet",
		function()
			flag("passes", true)
			flag("starterPack", true)
			flag("starterPet", true)
			local StarterViewRules = UIShim.require("ReplicatedStorage.Shared.StarterViewRules")
			local prices: { [string]: number } =
				{ GoldenSponge = 99, SecondPetSlot = 249, DoubleCoins = 199 }
			UI.setStarter(
				StarterViewRules.items(function(key: string): unknown
					return prices[key]
				end),
				199,
				os.time() + 44 * 3600
			)
			UI.open("Starter")
		end,
	},
	-- starterBuilder (issue 1097): the Second Builder in place of the Golden Sponge, with Midas, at regular prices.
	{
		"StarterBuilder",
		function()
			flag("passes", true)
			flag("starterPack", true)
			flag("starterPet", true)
			flag("starterBuilder", true)
			local StarterViewRules = UIShim.require("ReplicatedStorage.Shared.StarterViewRules")
			local LiveFlags = UIShim.require("ReplicatedStorage.Shared.LiveFlags")
			local prices: { [string]: number } =
				{ SecondPetSlot = 249, DoubleCoins = 50, SecondBuilder = 299 }
			UI.setStarter(
				StarterViewRules.items(function(key: string): unknown
					return prices[key]
				end, LiveFlags.isOn),
				199,
				os.time() + 44 * 3600
			)
			UI.open("Starter")
		end,
	},
	{
		"HudStarterBuilder",
		function()
			allButtons(true)
			flag("starterCard", true)
			flag("starterBuilder", true)
		end,
	},
	-- The Cat Hotel's desk card (issue 1051, switch catHotel): a Lilac Cloud guest waits; room 1 is ready, room 2
	-- asleep, room 3 free, room 4 not built. Then every room full with no guest, two ready to collect.
	{
		"Hotel",
		function()
			flag("catHotel", true)
			local t = os.time()
			UI.setHotel({
				open = true,
				rooms = 3,
				stays = {
					["1"] = { kind = "Marble", rarity = "Rare", hours = 4, endsAt = t - 10 },
					["2"] = {
						kind = "Cotton",
						rarity = "Common",
						hours = 8,
						endsAt = t + 3 * 3600 + 12 * 60,
					},
				},
				guest = { kind = "LilacCloud", rarity = "Epic" },
				now = t,
			}, 0)
			UI.open("Hotel")
		end,
	},
	{
		"HotelFull",
		function()
			flag("catHotel", true)
			local t = os.time()
			UI.setHotel({
				open = true,
				rooms = 4,
				stays = {
					["1"] = { kind = "Marble", rarity = "Rare", hours = 4, endsAt = t - 10 },
					["2"] = { kind = "Starcoat", rarity = "Legendary", hours = 8, endsAt = t - 5 },
					["3"] = { kind = "Tux", rarity = "Uncommon", hours = 1, endsAt = t + 40 * 60 },
					["4"] = { kind = "Inky", rarity = "Common", hours = 8, endsAt = t + 7 * 3600 },
				},
				now = t,
			}, 0)
			UI.open("Hotel")
		end,
	},
	-- starterNoClock (issue 1069): the window's band line says "New player offer", no time left.
	{
		"StarterNoClock",
		function()
			flag("passes", true)
			flag("starterPack", true)
			flag("starterNoClock", true)
			local StarterViewRules = UIShim.require("ReplicatedStorage.Shared.StarterViewRules")
			local prices: { [string]: number } =
				{ GoldenSponge = 99, SecondPetSlot = 249, DoubleCoins = 199 }
			UI.setStarter(
				StarterViewRules.items(function(key: string): unknown
					return prices[key]
				end),
				199,
				os.time() + 44 * 3600
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
				199,
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
				{ id = 1, kind = "Clover", star = 1, slot = "player" },
				{ id = 2, kind = "Angler", star = 2, slot = "player2" },
				{ id = 3, kind = "Blaze", star = 1, slot = "Jo1" },
				{ id = 4, kind = "Ooze", star = 1 },
			}, { Jo = true, Sam = true }, true)
			UI.open("Pets")
		end,
	},
	-- Staff names (issue 487, switch staffRename): Jo renamed to the longest name, Sam with the default, both with
	-- Rename, Lou locked; then the Rename card for Jo.
	{
		"PetsNames",
		function()
			flag("petsWindow", true)
			flag("staffRename", true)
			UI.setStaffNames({ Jo = "Captain Bubbles" }, true)
			UI.setPets({
				{ id = 1, kind = "Clover", star = 1, slot = "player" },
				{ id = 4, kind = "Angler", star = 2, slot = "Jo1" },
			}, { Jo = true, Sam = true }, true)
			UI.open("Pets")
		end,
	},
	{
		"Rename",
		function()
			flag("staffRename", true)
			UI.showRename("Jo", "Captain Bubbles", "Jo")
		end,
	},
	{
		"RenameEmpty",
		function()
			flag("staffRename", true)
			UI.showRename("Sam", "Sam", "Sam")
			UI.setStaffNames({}, false)
		end,
	},
	-- The Helpers window (issue 526 item 3, switch helpersWindow): Jo renamed to the longest name at level 4 taking
	-- the longest mode, Sam not hired yet, Lou pointing to his pass; then all three hired, Lou at the top level.
	{
		"Helpers",
		function()
			flag("helpersWindow", true)
			flag("workers", true)
			local HelperViewRules = UIShim.require("ReplicatedStorage.Shared.HelperViewRules")
			local values = { WorkerLevel_Jo = 4, WorkerMode_Jo = "leaving" }
			UI.setHelpers(
				HelperViewRules.rows(function(name)
					return values[name]
				end, { Jo = "Captain Bubbles" }),
				true,
				true
			)
			UI.open("Helpers")
		end,
	},
	-- The Helpers window with the HUD behind it (issues 873 and 929, switch helperPets): a pet box starts each hired
	-- row (Jo's Angler, Sam's paw), the buttons stand 16 px apart, and the X clears the coin pill.
	{
		"HelpersPets",
		function()
			hud(true)
			UI.setCoins(1240)
			flag("helpersWindow", true)
			flag("workers", true)
			flag("pets", true)
			flag("helperPets", true)
			local HelperViewRules = UIShim.require("ReplicatedStorage.Shared.HelperViewRules")
			local values = { WorkerLevel_Jo = 4, WorkerMode_Jo = "leaving", WorkerLevel_Sam = 1 }
			UI.setPets({
				{ id = 1, kind = "Angler", star = 2, slot = "Jo1" },
				{ id = 2, kind = "Ooze", star = 1 },
			}, { Jo = true, Sam = true })
			UI.setHelpers(
				HelperViewRules.rows(function(name)
					return values[name]
				end, { Jo = "Captain Bubbles" }),
				true,
				true
			)
			UI.open("Helpers")
		end,
	},
	{
		"HelpersAll",
		function()
			flag("helpersWindow", true)
			flag("workers", true)
			local HelperViewRules = UIShim.require("ReplicatedStorage.Shared.HelperViewRules")
			local values = {
				WorkerLevel_Jo = 2,
				WorkerMode_Jo = "dirtiest",
				WorkerLevel_Sam = 1,
				WorkerLevel_Lou = 5,
				WorkerMode_Lou = "rarest",
			}
			UI.setHelpers(
				HelperViewRules.rows(function(name)
					return values[name]
				end, { Sam = "Mister Whiskers" }),
				false,
				false
			)
			UI.open("Helpers")
		end,
	},
	-- The free gifts card (issue 730, switch freeRewards): the like asked and counting down, favourite done, play
	-- time to go; then the like and play gifts ready to claim.
	{
		"FreeGifts",
		function()
			flag("giftStand", true)
			flag("pets", true)
			flag("freeRewards", true)
			UI.setGift({
				lit = true,
				favourite = true,
				group = false,
				claimed = false,
				free = {
					likeAsked = true,
					likeIn = 8,
					likeClaimed = false,
					played = 1260,
					playClaimed = false,
				},
			})
			UI.open("Gift")
		end,
	},
	{
		"FreeGiftsReady",
		function()
			flag("giftStand", true)
			flag("pets", true)
			flag("freeRewards", true)
			UI.setGift({
				lit = true,
				favourite = false,
				group = false,
				claimed = false,
				free = {
					likeAsked = true,
					likeIn = 0,
					likeClaimed = false,
					played = 4000,
					playClaimed = false,
				},
			})
			UI.open("Gift")
		end,
	},
	-- The gift stand's card giving the gift crate (switch giftCrate, issue 859), with the free rewards rows.
	{
		"GiftCrate",
		function()
			flag("giftStand", true)
			flag("pets", true)
			flag("freeRewards", true)
			flag("giftCrate", true)
			UI.setGift({
				lit = true,
				favourite = true,
				group = true,
				claimed = false,
				free = {
					likeAsked = true,
					likeIn = 0,
					likeClaimed = false,
					played = 4000,
					playClaimed = false,
				},
			})
			UI.open("Gift")
		end,
	},
	-- giftGroupOnly (issue 1068): the welcome gifts need the group join alone; the favourite row is a plain ask.
	{
		"GiftGroupOnly",
		function()
			flag("giftStand", true)
			flag("pets", true)
			flag("freeRewards", true)
			flag("giftCrate", true)
			flag("giftFlow", true)
			flag("giftGroupOnly", true)
			game:GetService("Players").LocalPlayer:SetAttribute("GiftStage", 1)
			UI.setGift({
				lit = true,
				favourite = false,
				group = false,
				claimed = false,
				groupOnly = true,
				free = {
					likeAsked = false,
					likeIn = 0,
					likeClaimed = false,
					played = 500,
					playClaimed = false,
				},
			})
			UI.open("Gift")
		end,
	},
	-- The gift stand in stages (switch giftFlow, issue 968): the welcome gifts with one Claim all, then the playtime gift.
	{
		"GiftWelcome",
		function()
			flag("giftStand", true)
			flag("pets", true)
			flag("freeRewards", true)
			flag("giftCrate", true)
			flag("giftFlow", true)
			game:GetService("Players").LocalPlayer:SetAttribute("GiftStage", 1)
			UI.setGift({
				lit = true,
				favourite = true,
				group = false,
				claimed = false,
				free = {
					likeAsked = false,
					likeIn = 0,
					likeClaimed = false,
					played = 500,
					playClaimed = false,
				},
			})
			UI.open("Gift")
		end,
	},
	{
		"GiftPlaytime",
		function()
			flag("giftStand", true)
			flag("pets", true)
			flag("freeRewards", true)
			flag("giftCrate", true)
			flag("giftFlow", true)
			game:GetService("Players").LocalPlayer:SetAttribute("GiftStage", 2)
			UI.setGift({
				lit = true,
				favourite = true,
				group = true,
				claimed = true,
				free = {
					likeAsked = false,
					likeIn = 0,
					likeClaimed = false,
					played = 1260,
					playClaimed = false,
				},
			})
			UI.open("Gift")
		end,
	},
	-- The like how-to (switch likeHowTo, issue 869): Like was just tapped on the open welcome gifts card.
	{
		"LikeHowTo",
		function()
			flag("giftStand", true)
			flag("pets", true)
			flag("freeRewards", true)
			flag("giftCrate", true)
			flag("giftFlow", true)
			flag("likeHowTo", true)
			game:GetService("Players").LocalPlayer:SetAttribute("GiftStage", 1)
			local function gift(asked: boolean)
				UI.setGift({
					lit = true,
					favourite = true,
					group = false,
					claimed = false,
					free = {
						likeAsked = asked,
						likeIn = 0,
						likeClaimed = false,
						played = 500,
						playClaimed = false,
					},
				})
			end
			gift(false)
			UI.open("Gift")
			gift(true)
		end,
	},
	-- The leave lines (issue 726, switch leaveLines) at their longest, as Roblox's menu opens over the HUD.
	{
		"LeaveLines",
		function()
			hud(true)
			UI.setCoins(1240)
			UI.setLeaveLines(
				"Your helpers fill the tip jar while you're away!",
				"Come back tomorrow for day 2: Good crate!"
			)
			UI.showLeaveLines(true)
		end,
	},
	-- Every HUD button at once, Helpers among them, at its widest: the row must stay on the screen.
	{
		"HudAllButtons",
		function()
			hud(true)
			UI.setCoins(999999)
			for _, name in
				{
					"catIndexWindow",
					"petsWindow",
					"helpersWindow",
					"workers",
					"checkinCard",
					"quests",
					"passes",
				}
			do
				flag(name, true)
			end
			flag("settingsCard", true)
			flag("starterPack", true)
			local player = game:GetService("Players").LocalPlayer
			player:SetAttribute("WorkerLevel_Jo", 1)
			player:SetAttribute("QuestsOpen", true)
			player:SetAttribute("StarterEndsAt", 1)
		end,
	},
	-- The tidy HUD (issues 738 and 739, switch hudTidy): Shop, Pets, Quests and More in a 2 by 2 grid, the coins on
	-- a pill with the friend tag, the waiting faces gone, and the starter pack's side ad with its struck total and
	-- saving. HudTidyMore: the More tray open. HudTidyNoPrice: a pass price missing, so no struck total or saving.
	{
		"HudTidy",
		function()
			allButtons(true)
		end,
	},
	{
		"HudTidyMore",
		function()
			allButtons(true)
			UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.HUD.SideButtons")
				.openTray()
		end,
	},
	{
		"HudTidyNoPrice",
		function()
			allButtons(false)
		end,
	},
	-- starterCard (issue 1080): the dark card with one big picture, the price and the round "i"; then with the pack's
	-- own price not known yet ("See the pack", no struck total).
	{
		"HudStarterCard",
		function()
			allButtons(true)
			flag("starterCard", true)
		end,
	},
	{
		"HudStarterCardNoPrice",
		function()
			allButtons(false)
			flag("starterCard", true)
			local StarterViewRules = UIShim.require("ReplicatedStorage.Shared.StarterViewRules")
			UI.setStarter(
				StarterViewRules.items(function(): unknown
					return nil
				end),
				nil,
				os.time() + 44 * 3600
			)
		end,
	},
	-- starterPet (issue 1090): Midas is the card's big picture, with gold rays behind him.
	{
		"HudStarterPet",
		function()
			allButtons(true)
			flag("starterCard", true)
			flag("starterPet", true)
		end,
	},
	-- starterNoClock (issue 1069): the starter ad's chip says "New player offer" instead of the time left.
	{
		"HudStarterNoClock",
		function()
			allButtons(true)
			flag("starterNoClock", true)
			UI.setSideNote("Starter", "New player offer")
		end,
	},
	-- Build and upgrades (issue 751, switch buildWindow): a tub built, one building, the rest waiting, then the
	-- tools and the next bow; on a phone the list scrolls.
	{
		"Build",
		function()
			for _, name in
				{ "buildWindow", "builds", "toolsBoard", "bowTiers", "tubBuilds", "dirtLevels" }
			do
				flag(name, true)
			end
			local BuildViewRules = UIShim.require("ReplicatedStorage.Shared.BuildViewRules")
			local function isOn(name: string): boolean
				return game:GetService("ReplicatedStorage"):GetAttribute("LiveFlag_" .. name)
					== true
			end
			UI.setBuild(
				BuildViewRules.builds(
					{ station = { item = "ThirdTub", endsAt = 1000 + 1500 } },
					{ SecondTub = true },
					1000,
					isOn
				),
				BuildViewRules.upgrades(isOn, function(id: string): boolean
					return id == "BubbleSoap"
				end, "Ribbon")
			)
			UI.open("Build")
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
	-- The pets window (issue 526, switch petsWindow): three Clover ready to fuse, a 2 star Angler with Jo, Sam not hired.
	{
		"Pets",
		function()
			flag("petsWindow", true)
			UI.setPets({
				{ id = 1, kind = "Clover", star = 1, slot = "player" },
				{ id = 2, kind = "Clover", star = 1 },
				{ id = 3, kind = "Clover", star = 1 },
				{ id = 4, kind = "Angler", star = 2, slot = "Jo1" },
				{ id = 5, kind = "Ooze", star = 1 },
				{ id = 6, kind = "Ooze", star = 1 },
				{ id = 7, kind = "Blaze", star = 3 },
				{ id = 8, kind = "Ghost", star = 1 },
			}, { Jo = true })
			UI.open("Pets")
		end,
	},
	-- The same pets, each tile with its line of what it gives at its stars (issue 927, switch petLines).
	{
		"PetsLines",
		function()
			flag("petsWindow", true)
			flag("petLines", true)
			UI.setPets({
				{ id = 1, kind = "Clover", star = 1, slot = "player" },
				{ id = 2, kind = "Clover", star = 1 },
				{ id = 3, kind = "Clover", star = 1 },
				{ id = 4, kind = "Angler", star = 2, slot = "Jo1" },
				{ id = 5, kind = "Ooze", star = 1 },
				{ id = 6, kind = "Ooze", star = 1 },
				{ id = 7, kind = "Blaze", star = 3 },
				{ id = 8, kind = "Ghost", star = 1 },
			}, { Jo = true })
			UI.open("Pets")
		end,
	},
	-- The same pets one per tile (issue 1035, switch petSingles): no "x3", no stars on one star pets, one Fuse on the
	-- first of the three Clover.
	{
		"PetsSingles",
		function()
			flag("petsWindow", true)
			flag("petLines", true)
			flag("petSingles", true)
			UI.setPets({
				{ id = 1, kind = "Clover", star = 1, slot = "player" },
				{ id = 2, kind = "Clover", star = 1 },
				{ id = 3, kind = "Clover", star = 1 },
				{ id = 4, kind = "Angler", star = 2, slot = "Jo1" },
				{ id = 5, kind = "Ooze", star = 1 },
				{ id = 6, kind = "Ooze", star = 1 },
				{ id = 7, kind = "Blaze", star = 3 },
				{ id = 8, kind = "Ghost", star = 1 },
			}, { Jo = true })
			UI.open("Pets")
		end,
	},
	-- The Helpers window with windowClear (issue 1038): the badge inside the title band, the HUD's buttons aside.
	{
		"HelpersClear",
		function()
			hud(true)
			flag("helpersWindow", true)
			flag("windowClear", true)
			UI.open("Helpers")
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
	-- A notice at its longest (UI.toast): the old dark bar, then (switch toastCards, issue 877) the small card with
	-- the visitor's portrait, at the top right clear of the wash's meter.
	{
		"Toast",
		function()
			hud(true)
			UI.setCoins(1240)
			UI.toast("859 more coins to hire Sam", "warning")
		end,
	},
	{
		"ToastCard",
		function()
			hud(true)
			flag("toastCards", true)
			UI.setCoins(1240)
			UI.toast("Marshmallow is here! Only you can wash their cat", "info", "Marshmallow")
		end,
	},
	-- (issue 1024) every notice with its picture: a crate's icon in the card's tab; then the big reward popup for a
	-- crate pet (its portrait on the sunburst, rarity colour) and for a crate bought (the crate icon).
	{
		"ToastCardIcon",
		function()
			hud(true)
			flag("toastCards", true)
			UI.setCoins(1240)
			UI.toast("Ginger left you a crate!", "info")
		end,
	},
	{
		"RewardPopPet",
		function()
			hud(true)
			flag("toastCards", true)
			flag("rewardPop", true)
			UI.setCoins(1240)
			UI.toast("You got Dragon! Epic, +12% when it sits beside you or a helper", "info")
		end,
	},
	{
		"RewardPopCrate",
		function()
			hud(true)
			flag("toastCards", true)
			flag("rewardPop", true)
			UI.setCoins(1240)
			UI.toast("A crate is yours! Tap it to open", "info")
		end,
	},
	-- The card beside the starter pack ad (issue 925): with the tidy HUD the ad sits at the top right, so the card
	-- moves left of it and never covers its ribbon.
	{
		"ToastCardAd",
		function()
			allButtons(true)
			flag("toastCards", true)
			UI.setCoins(1240)
			UI.toast("New in the Cat Index: Marshmallow", "info")
		end,
	},
	-- Suds's like ask after a special visitor (switch likeAsk, q2-likeask): his own "Sure!" button, no reward named.
	{
		"LikeAsk",
		function()
			hud(true)
			flag("sudsBubble", true)
			UI.setCoins(1240)
			UI.setWashStage(nil)
			UI.showLikeAsk("special", function() end)
		end,
	},
	-- The gift stand's card (issue 521, switch giftStand): nothing done yet, then the favourite done, then both.
	{
		"Gift",
		function()
			flag("pets", true)
			flag("giftStand", true)
			UI.setGift({ lit = true, favourite = false, group = false, claimed = false })
			UI.open("Gift")
		end,
	},
	{
		"GiftReady",
		function()
			flag("pets", true)
			flag("giftStand", true)
			UI.setGift({ lit = true, favourite = true, group = true, claimed = false })
			UI.open("Gift")
		end,
	},
	-- Suds's tip above the compact recap strip (issue 626): the two never overlap.
	{
		"SudsBubbleStrip",
		function()
			hud(true)
			flag("sudsBubble", true)
			flag("recapCard", true)
			UI.setCoins(1240)
			UI.setWashStage(nil)
			UI.showRecap({
				cat = "Muffin",
				rarity = "Common",
				coins = 12,
				tip = 2,
				bonus = 0,
				stars = 3,
				isNew = false,
				full = false,
			})
			local BubbleRules = UIShim.require("ReplicatedStorage.Shared.BubbleRules")
			UI.showBubble(BubbleRules.get("quests"))
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

-- The menus with their stronger card edges (issue 928, switch menuContrast): the same scenes, the switch on.
for _, name in { "Shop", "Build", "Quests", "Helpers", "Pets", "Crate" } do
	for _, scene in table.clone(SCENES) do
		if scene[1] == name then
			local open = scene[2]
			table.insert(SCENES, {
				name .. "Contrast",
				function()
					flag("menuContrast", true)
					open()
				end,
			})
		end
	end
end

-- Light on light no more (issue 1029, switch menuContrast2): every main window with the deeper panel, white cards, ink
-- edges and ink body text.
for _, name in
	{
		"Shop",
		"Build",
		"Quests",
		"Helpers",
		"Pets",
		"Crate",
		"Settings",
		"CatIndex",
		"Checkin",
		"Starter",
	}
do
	for _, scene in table.clone(SCENES) do
		if scene[1] == name then
			local open = scene[2]
			table.insert(SCENES, {
				name .. "Contrast2",
				function()
					flag("menuContrast2", true)
					open()
				end,
			})
		end
	end
end

-- Readable button words (issue 1096, switch menuContrast3, with menuContrast2 as on dev): the windows with the most
-- buttons, their white words drawn again with an ink outline, and the deeper tick green and gold.
for _, name in
	{
		"Shop",
		"Build",
		"Helpers",
		"SettingsFeedbackReset",
		"CatIndex",
		"Checkin",
		"FreeGifts",
		"FreeGiftsReady",
	}
do
	for _, scene in table.clone(SCENES) do
		if scene[1] == name then
			local open = scene[2]
			table.insert(SCENES, {
				name .. "Contrast3",
				function()
					flag("menuContrast2", true)
					flag("menuContrast3", true)
					open()
				end,
			})
		end
	end
end

-- Fewer words (issue 1027, switch shortText): the windows with the most text, with their long lines cut or hidden.
for _, name in
	{
		"Shop",
		"Helpers",
		"Pets",
		"Crate",
		"Settings",
		"Checkin",
		"Gift",
		"Starter",
	}
do
	for _, scene in table.clone(SCENES) do
		if scene[1] == name then
			local open = scene[2]
			table.insert(SCENES, {
				name .. "Short",
				function()
					flag("shortText", true)
					open()
				end,
			})
		end
	end
end

-- The shop revamp (issue 1030, switch shopRevamp): the featured card and the two by two grid, at full price with one
-- pass owned, in the launch sale, and with 2x Coins owned and the coin ladder on, each also with shortText on.
for _, name in { "Shop", "ShopSale", "ShopLadder" } do
	for _, scene in table.clone(SCENES) do
		if scene[1] == name then
			local open = scene[2]
			table.insert(SCENES, {
				name .. "Revamp",
				function()
					flag("shopRevamp", true)
					open()
				end,
			})
			table.insert(SCENES, {
				name .. "RevampShort",
				function()
					flag("shopRevamp", true)
					flag("shortText", true)
					open()
				end,
			})
		end
	end
end

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
	flag("helpersWindow", false)
	flag("helperPets", false)
	flag("petLines", false)
	flag("petSingles", false)
	flag("launchSale", false)
	flag("menuOnly", false)
	UI.setCanReset(false)
	UI.setFeedback(false, 0, 3)
	flag("feedback", false)
	flag("windowClear", false)
	flag("starterCard", false)
	flag("starterPet", false)
	flag("starterBuilder", false)
	flag("catHotel", false)
	flag("menuContrast2", false)
	flag("menuContrast3", false)
	flag("shortText", false)
	flag("shopRevamp", false)
	flag("coinLadder", false)
	flag("giftCrate", false)
	flag("giftFlow", false)
	flag("likeHowTo", false)
	game:GetService("Players").LocalPlayer:SetAttribute("GiftStage", nil)
	flag("giftGroupOnly", false)
	flag("menuContrast", false)
	UI.showLeaveLines(false)
	flag("freeRewards", false)
	flag("workers", false)
	flag("checkinCard", false)
	flag("quests", false)
	flag("passes", false)
	flag("starterPack", false)
	flag("hudTidy", false)
	for _, name in { "buildWindow", "builds", "toolsBoard", "bowTiers", "tubBuilds", "dirtLevels" } do
		flag(name, false)
	end
	flag("friendBonus", false)
	UI.setFriends(nil)
	UI.setSideNote("Starter", nil)
	local tester = game:GetService("Players").LocalPlayer
	for _, name in { "WorkerLevel_Jo", "QuestsOpen", "StarterEndsAt" } do
		tester:SetAttribute(name, nil)
	end
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
