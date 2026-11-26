--!strict
-- NotifyAskService: when Suds's one notification ask is due (NotifyAskRules, issue 814, switch notifyAsk). It sets the
-- Player attribute NotifyAskDue from 1:45 of play for a save that never saw it; the client shows it when the ask queue
-- gives it a turn and Roblox would prompt, then reports RequestNotifyAskSeen, which saves it as shown for good.
-- Nothing here opens a prompt: only the player's tap on the bubble does, on their device.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AskRules = require(Shared:WaitForChild("AskRules"))
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local NotifyAskRules = require(Shared:WaitForChild("NotifyAskRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local CHECK_SECONDS = 1
local BELL_FLAG = "longBuildOffer" -- NotifyService: the notification is only sent while it is on

local NotifyAskService = {}

local function on(): boolean
	return LiveFlags.isOn(NotifyAskRules.FLAG)
		and LiveFlags.isOn(AskRules.FLAG)
		and LiveFlags.isOn(BubbleRules.FLAG)
		and LiveFlags.isOn(BELL_FLAG)
end

local function check(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local due = on()
		and NotifyAskRules.due(
			Telemetry.played(player) or save.playSeconds,
			save.asks[NotifyAskRules.SAVE_KEY] == true
		)
	if player:GetAttribute(NotifyAskRules.ATTRIBUTE) ~= (if due then true else nil) then
		player:SetAttribute(NotifyAskRules.ATTRIBUTE, if due then true else nil)
	end
end

-- The bubble went up on the player's screen: never again for this save. Only while it is due.
local function onSeen(player: Player)
	local save = DataService.get(player)
	if save == nil or player:GetAttribute(NotifyAskRules.ATTRIBUTE) ~= true then
		return
	end
	save.asks[NotifyAskRules.SAVE_KEY] = true
	player:SetAttribute(NotifyAskRules.ATTRIBUTE, nil)
end

function NotifyAskService.Init(_services: { [string]: any }) end

function NotifyAskService.Start()
	NetService.on("RequestNotifyAskSeen", { perSecond = 1, burst = 2 }, onSeen)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return NotifyAskService
