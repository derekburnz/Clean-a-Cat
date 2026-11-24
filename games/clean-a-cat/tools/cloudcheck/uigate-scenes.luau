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
local plainTrial -- the StyleTrial card built the plain way (#186); the styled way needs StyleSheet, which the shim lacks

function Scenes.setup()
	UI = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI")
	UI.init()
	local StyleTrial = UIShim.require("StarterPlayer.StarterPlayerScripts.Client.UI.StyleTrial")
	local gui = Instance.new("ScreenGui")
	gui.Name = "StyleTrialPlain"
	gui.Parent = UIShim.playerGui
	plainTrial = StyleTrial.build(gui, false)
end

local SCENES = {
	{ "Example", function()
		UI.open("Example")
	end },
	{ "StyleTrialPlain", function()
		-- alone on screen: the starter HUD's placeholder font would count as a third font next to the card's two
		UIShim.playerGui.HUD.Enabled = false
		plainTrial.Visible = true
	end },
	{ "Toast", function()
		UI.toast("This server updates in 10 minutes. Your progress is saved.", "info")
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
	plainTrial.Visible = false
	UIShim.playerGui.HUD.Enabled = true
end

return Scenes
