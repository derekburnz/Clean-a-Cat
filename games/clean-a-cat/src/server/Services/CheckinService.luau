--!strict
-- CheckinService: the seven day check in card (CheckinRules, issue 517). It keeps the Player attributes CheckinReady
-- (the card's day waiting, 1 to 7, or nil) and CheckinDays (days taken on this card) up to date, so Design's card
-- can show itself between washes; a tap on its button asks RequestCheckin, and the server gives that day's reward
-- once. A day is the player's own calendar day (SaveSchema.day) on the server's clock.
--
-- It also keeps the player's time zone, once (ReportTimeZone, whole hours from -12 to +14): the quest book (issue 516)
-- and this card count days from it, and it is never taken again, so changing a clock cannot bring a day early.
-- Behind the LiveFlags switch checkinCard.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BowRules = require(Shared:WaitForChild("BowRules"))
local CheckinRules = require(Shared:WaitForChild("CheckinRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local CHECK_SECONDS = 5 -- how often the waiting day is looked at again (the first card's 3:45, midnight)

local CheckinService = {}

local function show(player: Player)
	local save = DataService.get(player)
	if save == nil or not LiveFlags.isOn(CheckinRules.FLAG) then
		player:SetAttribute(CheckinRules.READY_ATTRIBUTE, nil)
		player:SetAttribute(CheckinRules.DAYS_ATTRIBUTE, nil)
		return
	end
	local ready = CheckinRules.ready(
		save.checkin,
		SaveSchema.day(save, os.time()),
		Telemetry.played(player) or save.playSeconds
	)
	if player:GetAttribute(CheckinRules.READY_ATTRIBUTE) ~= ready then
		player:SetAttribute(CheckinRules.READY_ATTRIBUTE, ready)
	end
	if player:GetAttribute(CheckinRules.DAYS_ATTRIBUTE) ~= save.checkin.days then
		player:SetAttribute(CheckinRules.DAYS_ATTRIBUTE, save.checkin.days)
	end
end

local function give(player: Player, save: SaveSchema.Save, reward: CheckinRules.Reward)
	local coins = reward.coins or 0
	local bow = reward.bow
	if bow and BowRules.TIER[bow] then
		if save.bows[bow] then
			coins += reward.worth or 0 -- already bought: what it is worth instead
		else
			save.bows[bow] = true
			save.bow = BowRules.best(save.bows) -- the tier in use is always the best one owned
			player:SetAttribute(BowRules.ATTRIBUTE, save.bow)
		end
	end
	local crate = reward.crate
	if crate and PetService.give(player, crate, 1) then
		Telemetry.event(player, "crate_earned", 1, { "checkin" })
	end
	if coins > 0 then
		save.coins += coins
		WalletService.show(player)
		Telemetry.economy(player, "coins", "source", coins, save.coins, "Gameplay", "checkin")
	end
end

local function onClaim(player: Player)
	if not LiveFlags.isOn(CheckinRules.FLAG) then
		return
	end
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local day, reward = CheckinRules.claim(
		save.checkin,
		SaveSchema.day(save, os.time()),
		Telemetry.played(player) or save.playSeconds
	)
	if day == nil or reward == nil then
		return
	end
	give(player, save, reward)
	show(player)
	NetService.notice(player, `Day {day}: {reward.text}!`)
	Telemetry.event(player, "checkin_claimed", day)
end

local function onTimeZone(player: Player, rawHours: unknown)
	if not LiveFlags.isOn(CheckinRules.FLAG) then
		return
	end
	local hours = Guard.int(rawHours, -12, 14)
	local save = DataService.get(player)
	if hours == nil or save == nil or save.quests.tz ~= nil then
		return -- saved once, never again
	end
	save.quests.tz = hours
	show(player)
end

function CheckinService.Init(_services: { [string]: any }) end

function CheckinService.Start()
	NetService.on("RequestCheckin", { perSecond = 1, burst = 2 }, onClaim)
	NetService.on("ReportTimeZone", { perSecond = 1, burst = 2 }, onTimeZone)
	DataService.onLoaded:Connect(function(player: Player)
		show(player)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheckinRules.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				show(player)
			end
		end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				show(player)
			end
		end
	end)
end

return CheckinService
