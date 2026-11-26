--!strict
-- FavouriteAskController: the one favourite reminder (FavouriteAskRules, issue 815, switch favouriteAsk). When the
-- server says it is due (FavouriteAskDue) it waits its turn in the ask queue (id "favourite": never in a wash or a
-- recap, a minute from any other ask) and shows Design's bubble. Only a tap on Favourite opens Roblox's favourite
-- prompt, through the gift stand's own GiftController.favourite, so a yes there ticks the stand's favourite too. The X
-- just closes. Either way the server saves it as shown, so it never comes back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AskRules = require(Shared:WaitForChild("AskRules"))
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local FavouriteAskRules = require(Shared:WaitForChild("FavouriteAskRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Client = script.Parent.Parent
local UI = require(Client:WaitForChild("UI"))

local ID = FavouriteAskRules.ASK_ID

local FavouriteAskController = {}

local player = Players.LocalPlayer
local ask: any = nil -- AskController
local gift: any = nil -- GiftController
local wanted = false
local shown = false -- this session: the bubble went up

local function on(): boolean
	return LiveFlags.isOn(FavouriteAskRules.FLAG) and LiveFlags.isOn(BubbleRules.FLAG) and ask.on()
end

local function show()
	if shown or player:GetAttribute(FavouriteAskRules.ATTRIBUTE) ~= true or not on() then
		ask.skip(ID)
		wanted = false
		return
	end
	shown = true
	Remotes.event("RequestFavouriteAskSeen"):FireServer()
	local pressed = false
	UI.showBubble(FavouriteAskRules.BUBBLE, function()
		pressed = true
		gift.favourite() -- only this tap opens Roblox's prompt
	end, function(closed: boolean)
		wanted = false
		local answer: AskRules.Answer = if pressed then "yes" elseif closed then "no" else "closed"
		ask.done(ID, answer)
	end)
end

local function sync()
	local due = player:GetAttribute(FavouriteAskRules.ATTRIBUTE) == true and on() and not shown
	if not due then
		if wanted then
			wanted = false
			ask.drop(ID)
		end
		return
	end
	if not wanted then
		wanted = ask.want(ID, show, UI.hideBubble)
	end
end

function FavouriteAskController.Init(controllers: { [string]: any })
	ask = controllers.AskController
	gift = controllers.GiftController
end

function FavouriteAskController.Start()
	player:GetAttributeChangedSignal(FavouriteAskRules.ATTRIBUTE):Connect(sync)
	for _, flag in { FavouriteAskRules.FLAG, BubbleRules.FLAG, AskRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(sync)
	end
	sync()
end

return FavouriteAskController
