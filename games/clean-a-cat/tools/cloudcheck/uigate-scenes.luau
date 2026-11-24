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
end

return Scenes
