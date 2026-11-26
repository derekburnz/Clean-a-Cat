--!strict
-- UiSounds: a soft sound when a window or the More tray opens, and another when it closes (issue 800, switch
-- uiSounds, off by default). Only listens: UI.onOpened and UI.onWindowsChanged for windows, the HUD's MoreTray frame's
-- Visible for the tray. No UI file changes.
--
-- Opening a window also closes the tray in the same frame, so requests are gathered for GATHER seconds and only the
-- strongest plays (open beats close). One sound per tap, never two. Button taps get no sound of their own: every HUD
-- tap already opens something, so a click on top would be noise.
--
--   UiSounds.pick(a, b) -> kind   pure: which of two requests wins
--   UiSounds.start(UI, isOn)      binds once; isOn() is read at play time, so the off switch is instant
local Players = game:GetService("Players")

local Audio = require(script.Parent)

local UiSounds = {}

export type Kind = "open" | "close"

UiSounds.GATHER = 0.03
UiSounds.CUES = { open = "uiOpen", close = "uiClose" } :: { [string]: string }
UiSounds.TRAY = "MoreTray"

local RANK = { open = 2, close = 1 } :: { [string]: number }

function UiSounds.pick(a: Kind?, b: Kind): Kind
	if a == nil then
		return b
	end
	if (RANK[b] or 0) > (RANK[a] or 0) then
		return b
	end
	return a
end

local started = false

function UiSounds.start(ui: any, isOn: () -> boolean)
	if started then
		return
	end
	started = true
	local pending: Kind? = nil
	local function request(kind: Kind)
		if not isOn() then
			return
		end
		local first = pending == nil
		pending = UiSounds.pick(pending, kind)
		if first then
			task.delay(UiSounds.GATHER, function()
				local chosen = pending
				pending = nil
				if chosen then
					Audio.play(UiSounds.CUES[chosen])
				end
			end)
		end
	end

	ui.onOpened(function()
		request("open")
	end)
	ui.onWindowsChanged(function(open: boolean)
		if not open then
			request("close")
		end
	end)

	local function watchTray(frame: Instance)
		if frame.Name ~= UiSounds.TRAY or not frame:IsA("GuiObject") then
			return
		end
		local tray = frame :: GuiObject
		tray:GetPropertyChangedSignal("Visible"):Connect(function()
			request(if tray.Visible then "open" else "close")
		end)
	end
	local player = Players.LocalPlayer
	local gui = player:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(watchTray)
	for _, d in gui:GetDescendants() do
		watchTray(d)
	end
end

return UiSounds
