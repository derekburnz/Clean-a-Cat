--!strict
-- FavouriteAskService: when the one favourite reminder is due (FavouriteAskRules, issue 815, switch favouriteAsk). It
-- sets the Player attribute FavouriteAskDue on the second visit or after 10 hand washes in a visit, for a save the
-- stand has no favourite for and that never saw it; the client shows it when the ask queue gives it a turn and reports
-- RequestFavouriteAskSeen, which saves it as shown for good. Nothing here opens a prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AskRules = require(Shared:WaitForChild("AskRules"))
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local FavouriteAskRules = require(Shared:WaitForChild("FavouriteAskRules"))
local GiftRules = require(Shared:WaitForChild("GiftRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local SpaService = require(script.Parent:WaitForChild("SpaService"))

local CHECK_SECONDS = 1

local FavouriteAskService = {}

local washes: { [Player]: number } = {} -- hand washes this visit

local function on(): boolean
	-- the button opens the gift stand's own favourite prompt, which needs giftStand and pets
	return LiveFlags.isOn(FavouriteAskRules.FLAG)
		and LiveFlags.isOn(AskRules.FLAG)
		and LiveFlags.isOn(BubbleRules.FLAG)
		and LiveFlags.isOn(GiftRules.FLAG)
		and LiveFlags.isOn(CrateRules.FLAG)
end

local function check(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local due = on()
		and FavouriteAskRules.due({
			visit = save.visits,
			washes = washes[player] or 0,
			favourited = save.giftFavourite,
			asked = save.asks[FavouriteAskRules.SAVE_KEY] == true,
		})
	if player:GetAttribute(FavouriteAskRules.ATTRIBUTE) ~= (if due then true else nil) then
		player:SetAttribute(FavouriteAskRules.ATTRIBUTE, if due then true else nil)
	end
end

-- The bubble went up on the player's screen: never again for this save. Only while it is due.
local function onSeen(player: Player)
	local save = DataService.get(player)
	if save == nil or player:GetAttribute(FavouriteAskRules.ATTRIBUTE) ~= true then
		return
	end
	save.asks[FavouriteAskRules.SAVE_KEY] = true
	player:SetAttribute(FavouriteAskRules.ATTRIBUTE, nil)
end

function FavouriteAskService.Init(_services: { [string]: any }) end

function FavouriteAskService.Start()
	NetService.on("RequestFavouriteAskSeen", { perSecond = 1, burst = 2 }, onSeen)
	SpaService.washed:Connect(function(player: Player, _counts: any)
		washes[player] = (washes[player] or 0) + 1
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		washes[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return FavouriteAskService
