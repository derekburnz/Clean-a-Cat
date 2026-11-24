--!strict
-- SettingsController: applies the Settings card (UI/Settings, switch settingsCard, #230). The Music and Sounds sliders
-- set the SoundGroup levels through Audio; Less screen shake and Less sparkle go to UI/Comfort, so every screen and
-- effect that asks Comfort.reducedMotion() or Comfort.lessSparkle() calms down. Kept on this device for the session;
-- saving them is a later change. If the switch goes off, everything goes back to the defaults. No remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SettingsRules = require(Shared:WaitForChild("SettingsRules"))

local Client = script.Parent.Parent
local Audio = require(Client:WaitForChild("Audio"))
local Comfort = require(Client:WaitForChild("UI"):WaitForChild("Comfort"))
local UI = require(Client:WaitForChild("UI"))

local SettingsController = {}

local FLAG = "settingsCard"

local changedByPlayer = false

local function apply(settings: SettingsRules.Settings)
	Audio.applySettings({
		music = settings.music > 0,
		sound = settings.sounds > 0,
		musicLevel = settings.music,
		soundLevel = settings.sounds,
	})
	Comfort.setChoices(settings.lessShake, settings.lessSparkle)
end

function SettingsController.Init(_controllers: { [string]: any }) end

function SettingsController.Start()
	UI.onSettingsChanged(function(settings: SettingsRules.Settings)
		if not LiveFlags.isOn(FLAG) then
			return
		end
		changedByPlayer = true
		apply(settings)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(function()
			if not LiveFlags.isOn(FLAG) and changedByPlayer then
				changedByPlayer = false
				local defaults = SettingsRules.defaults()
				apply(defaults)
				UI.showSettings(defaults)
			end
		end)
end

return SettingsController
