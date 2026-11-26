--!strict
-- LikeAskController: the like ask on the client (LikeAskRules, switch likeAsk with askQueue and sudsBubble). The
-- server decides when it is due (the Player attribute LikeAskDue, the moment's name); this puts it in the ask queue,
-- so it shows only when the screen is free, as Design's card UI.showLikeAsk (Suds's bubble, PR 774), and sends the
-- answer back with RequestLikeAnswer: "yes" (Sure!, which opens the gift card), "no" (the player's X) or "closed"
-- (the bubble went by itself).
-- The queue id is likeAskPurchase for the ask after a purchase and likeAsk for every other moment, so the
-- ask_shown and ask_answered events split the two (Growth's events spec, 2026-11-26 update).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AskRules = require(Shared:WaitForChild("AskRules"))
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local LikeAskRules = require(Shared:WaitForChild("LikeAskRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Client = script.Parent.Parent
local UI = require(Client:WaitForChild("UI"))

local LikeAskController = {}

local player = Players.LocalPlayer
local ask: any = nil -- AskController
local wanted: string? = nil -- the queue id waiting or up now
local up = false

local function due(): string?
	local moment = player:GetAttribute(LikeAskRules.ATTRIBUTE)
	return if type(moment) == "string" then moment else nil
end

local function idFor(moment: string): string
	return if moment == "purchase" then "likeAskPurchase" else "likeAsk"
end

local function on(): boolean
	return LiveFlags.isOn(LikeAskRules.FLAG) and LiveFlags.isOn(BubbleRules.FLAG) and ask.on()
end

local function answer(id: string, kind: AskRules.Answer)
	if not up or wanted ~= id then
		return -- this card already went (the queue or a switch took it down)
	end
	up = false
	wanted = nil
	if due() ~= nil then
		Remotes.event("RequestLikeAnswer"):FireServer(kind)
	end
	ask.done(id, kind)
end

local function sync()
	local moment = due()
	if moment == nil or not on() then
		local id = wanted
		if id == nil then
			return
		end
		wanted = nil
		ask.drop(id)
		if up then
			up = false
			UI.hideBubble()
			ask.done(id, "closed")
		end
		return
	end
	local id = idFor(moment)
	if wanted == id then
		return
	end
	if wanted ~= nil then
		ask.drop(wanted)
	end
	wanted = id
	ask.want(id, function()
		local now = due()
		if now == nil or wanted ~= id then
			ask.skip(id) -- it went away while it waited
			return
		end
		up = true
		UI.showLikeAsk(now, function(kind)
			answer(id, kind)
		end)
	end, function()
		-- the queue took it down (MAX_SHOWN or a clear): the bubble's gone callback answers "closed"
		UI.hideBubble()
	end)
end

function LikeAskController.Init(controllers: { [string]: any })
	ask = controllers.AskController
end

function LikeAskController.Start()
	player:GetAttributeChangedSignal(LikeAskRules.ATTRIBUTE):Connect(sync)
	for _, flag in { LikeAskRules.FLAG, BubbleRules.FLAG, AskRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(sync)
	end
	sync()
end

return LikeAskController
