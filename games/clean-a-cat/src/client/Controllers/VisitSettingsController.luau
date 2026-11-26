--!strict
-- VisitSettingsController: the client side of visiting's own pieces of UI (issue 520). It shows the server's
-- VisitorsAllowed on the Settings card's "Visitors can come in" row (hidden while it is nil: switch visiting off) and
-- sends RequestVisiting(allowed) when the row is pressed; the row moves only when the server's answer comes back. It
-- also hands FriendsHere (friends in this server, nil while friendBonus is off) to the HUD's friend chip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local VisitRules = require(Shared:WaitForChild("VisitRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local VisitSettingsController = {}

local player = Players.LocalPlayer

local function allowed(): boolean?
	local raw = player:GetAttribute(VisitRules.ALLOWED_ATTRIBUTE)
	return if type(raw) == "boolean" then raw else nil
end

local function refresh()
	UI.setVisitors(allowed())
	UI.setFriends(player:GetAttribute(VisitRules.FRIENDS_ATTRIBUTE))
end

function VisitSettingsController.Init(_controllers: { [string]: any }) end

function VisitSettingsController.Start()
	UI.onVisitors(function(want: boolean)
		if allowed() ~= nil then
			Remotes.event("RequestVisiting"):FireServer(want)
		end
	end)
	player:GetAttributeChangedSignal(VisitRules.ALLOWED_ATTRIBUTE):Connect(refresh)
	player:GetAttributeChangedSignal(VisitRules.FRIENDS_ATTRIBUTE):Connect(refresh)
	refresh()
end

return VisitSettingsController
