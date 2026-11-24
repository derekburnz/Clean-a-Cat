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
	{ "Example", function()
		UI.open("Example")
	end },
	{ "Toast", function()
		UI.toast("This server updates in 10 minutes. Your progress is saved.", "info")
	end },
	-- The game HUD (#210, switch gameHud), at its widest: the longest coin count before it goes short (999,999)
	-- and the longest step line, then a short count on the first step.
	{ "HudWash", function()
		hud(true)
		UI.setCoins(999999)
		UI.setWashStage("styled")
	end },
	{ "HudScrub", function()
		hud(true)
		UI.setCoins(12345678)
		UI.setWashStage("dirty")
	end },
	{ "RecapFull", function()
		recap(true)
	end },
	{ "RecapStrip", function()
		recap(false)
	end },
	-- The Settings card (#230, switch settingsCard): as it opens, then with a slider low and a switch on.
	{ "Settings", function()
		flag("settingsCard", true)
		UI.open("Settings")
	end },
	{ "SettingsChanged", function()
		flag("settingsCard", true)
		UI.showSettings({ music = 0.2, sounds = 0.85, lessShake = true, lessSparkle = false })
		UI.open("Settings")
	end },
	-- The HUD's button row (#232) with the Settings button, in place of the starter Menu.
	{ "HudButtons", function()
		hud(true)
		flag("settingsCard", true)
		UI.setCoins(999999)
		UI.setWashStage("dirty")
	end },
	-- The Cat Index window (#238, switch catIndexWindow): a half-stamped grid, then one cat's detail.
	{ "CatIndex", function()
		flag("catIndexWindow", true)
		UI.setIndex(indexEntries(), { Muffin = true, LilacCloud = true }, 2)
		UI.open("CatIndex")
	end },
	-- The same with the switch windowsHideControls on: the phone's thumbstick and jump button hide while it is open.
	{ "CatIndexNoControls", function()
		flag("catIndexWindow", true)
		flag("windowsHideControls", true)
		UI.setIndex(indexEntries(), { Muffin = true, LilacCloud = true }, 2)
		UI.open("CatIndex")
	end },
	{ "CatIndexDetail", function()
		flag("catIndexWindow", true)
		UI.setIndex(indexEntries(), { LilacCloud = true }, 2)
		UI.open("CatIndex")
		UI.showIndexDetail("LilacCloud")
	end },
	-- "Who's next?" (#246, switch queueWindow): three everyday customers with picks open, then a line with a new Rare
	-- VIP and an Epic one, a Dryer not built yet (locked needs) and picks not open yet. HudWaiting: the HUD's
	-- waiting faces.
	{ "Queue", function()
		flag("queueWindow", true)
		local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
		local cards = QueueViewRules.cards({ "Muffin", "Cotton", "Patches" }, indexEntries(), { Dryer = true })
		UI.setQueue(cards, QueueViewRules.headline(cards, 1), { [2] = true, [3] = true })
		UI.open("Queue")
	end },
	{ "QueueVip", function()
		flag("queueWindow", true)
		local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
		local cards = QueueViewRules.cards({ "Smudge", "Toffee", "LilacCloud" }, indexEntries(), {})
		UI.setQueue(cards, QueueViewRules.headline(cards, 2), {})
		UI.open("Queue")
	end },
	-- A line where cats bring the later needs (#267, switches bubbleBath and pawdicure): five needs on the Legendary
	-- one, so the needs stack over the pay even on a short card and shrink to share the card's width.
	{ "QueueLater", function()
		flag("queueWindow", true)
		local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
		local rolled = {
			[1] = { "mud", "tangles", "wet", "smell" },
			[2] = { "mud", "tangles" },
			[3] = { "mud", "tangles", "wet", "smell", "claws" },
		}
		local cards = QueueViewRules.cards({ "Toffee", "Muffin", "Starcoat" }, indexEntries(), { Dryer = true }, rolled)
		UI.setQueue(cards, QueueViewRules.headline(cards, 2), { [2] = true, [3] = true })
		UI.open("Queue")
	end },
	{ "HudWaiting", function()
		hud(true)
		flag("queueWindow", true)
		flag("settingsCard", true)
		flag("catIndexWindow", true)
		UI.setCoins(999999)
		UI.setWashStage("dirty")
		local QueueViewRules = UIShim.require("ReplicatedStorage.Shared.QueueViewRules")
		UI.setQueue(QueueViewRules.cards({ "Muffin", "Toffee", "LilacCloud" }, {}, {}), "", {})
	end },
	-- The tutorial's dim step (switch tutorialDim): the screen dims round the Index button and the arrow says tap it.
	{ "TutorialDim", function()
		hud(true)
		flag("catIndexWindow", true)
		flag("tutorialDim", true)
		UI.setCoins(58)
		UI.setWashStage(nil)
		UI.pointAt("CatIndex", "Tap Index")
	end },
	-- The tutorial's tip line (switch tutorialTip) in the step bar's place, while the first cat is washed.
	{ "TutorialTip", function()
		hud(true)
		flag("tutorialTip", true)
		UI.setCoins(0)
		UI.setWashStage("dirty")
		UI.setTip({ step = 2, total = 3, icon = "Sponge", say = "Scrub the mud" })
	end },
	{ "HudWalking", function()
		hud(true)
		UI.setCoins(1240)
		UI.setWashStage(nil)
	end },
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
	hud(false)
	flag("recapCard", false)
	flag("settingsCard", false)
	flag("catIndexWindow", false)
	flag("queueWindow", false)
	flag("tutorialDim", false)
	flag("tutorialTip", false)
	flag("windowsHideControls", false)
	UI.setTip(nil)
	UI.clearPointer()
	UI.setQueue({}, "", {})
	UI.showIndexDetail(nil)
	UI.showSettings({ music = 1, sounds = 1, lessShake = false, lessSparkle = false })
end

return Scenes
