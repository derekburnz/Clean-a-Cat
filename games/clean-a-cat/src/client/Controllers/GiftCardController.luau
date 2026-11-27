--!strict
-- GiftCardController: the gift stand's card (UI/GiftCard, issue 521), behind the switch giftStand with pets. It joins
-- Gameplay-Engineer's GiftController (the stand's prompt, the state and the asks to Roblox and the server) to the card:
--
--   * a tap on the player's own lit stand opens the card and asks the server to check the group again;
--   * Favourite and Join open Roblox's own prompts (GiftController.favourite and join); the ticks come from the
--     server's Player attributes, never from the card;
--   * Get Starcoat asks for the pet (GiftController.claim); the server answers with a notice, and once the pet is
--     saved the card shows "Starcoat is yours!" and closes a moment later;
--   * once the stand lights (GiftLit) and the pet is not claimed, Suds's "A gift for you!" waits its turn in the ask
--     line (AskController's "gift", switch askQueue); "Show me" opens the card. A "no" there is final for the visit;
--   * with the switch freeRewards (issue 730) the card also has the free rewards rows (GiftViewRules, FreeRewardRules):
--     Like asks the server to stamp the ask (RequestLikeAsk) and counts down to its Claim; Claim on the like or the
--     play row sends RequestFreeReward(key). The rows read the server's Player attributes only, and the gift never
--     depends on a like, which no game can read.
--   * with the switch giftCrate (issue 859) the gift is a crate: once the claim lands while the card shows, the card
--     shows "Your gift crate is here!" for a moment, then closes and opens the Crate window on the gift crate, so the
--     player lands on its chances and its Open button (CrateWindowController.show; the card's button says "Open your
--     gift crate", Design-Agent).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local FreeRewardRules = require(Shared:WaitForChild("FreeRewardRules"))
local GiftViewRules = require(Shared:WaitForChild("GiftViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local GiftCardController = {}

local ASK_ID = "gift"
local CLOSE_AFTER = 2.5 -- seconds "Starcoat is yours!" stays before the card closes
local CRATE_AFTER = 1.2 -- seconds "Your gift crate is here!" stays before the gift crate's window opens (giftCrate)
local ASK_UP_SECONDS = 20 -- Suds's tip goes by itself after this, as BubbleController's do (#649); not a "no"

local gift: any = nil -- GiftController
local asks: any = nil -- AskController
local crates: any = nil -- CrateWindowController
local asked = false -- the ask was put in the line this visit
local wasClaimed = false

local player = Players.LocalPlayer
local ticking = false -- the like's countdown redraws the card each second while it shows

local function number(raw: unknown): number
	return if type(raw) == "number" and raw == raw then raw else 0
end

local function freeOn(): boolean
	return LiveFlags.isOn(FreeRewardRules.FLAG)
		and LiveFlags.isOn(GiftViewRules.FLAG)
		and LiveFlags.isOn("pets")
end

local function free(): GiftViewRules.Free?
	if not freeOn() then
		return nil
	end
	local readyAt = number(player:GetAttribute(FreeRewardRules.LIKE_READY_ATTRIBUTE))
	local now = workspace:GetServerTimeNow()
	return {
		likeAsked = readyAt > 0,
		likeIn = if readyAt > 0 then math.max(0, math.ceil(readyAt - now)) else 0,
		likeClaimed = player:GetAttribute(FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE) == true,
		played = number(player:GetAttribute(FreeRewardRules.PLAY_SECONDS_ATTRIBUTE)),
		playClaimed = player:GetAttribute(FreeRewardRules.PLAY_CLAIMED_ATTRIBUTE) == true,
	}
end

local function state(): GiftViewRules.State
	local now: GiftViewRules.State = if gift == nil
		then { lit = false, favourite = false, group = false, claimed = false }
		else gift.state()
	return {
		lit = now.lit,
		favourite = now.favourite,
		group = now.group,
		claimed = now.claimed,
		free = free(),
	}
end

-- While the like counts down and the card shows, redraw it each second.
local function tick()
	if ticking then
		return
	end
	ticking = true
	task.spawn(function()
		while true do
			local f = free()
			if
				f == nil
				or not f.likeAsked
				or f.likeIn <= 0
				or not UI.isOpen(GiftViewRules.WINDOW)
			then
				break
			end
			UI.setGift(state())
			task.wait(1)
		end
		ticking = false
		UI.setGift(state())
	end)
end

local function open()
	UI.setGift(state())
	UI.open(GiftViewRules.WINDOW)
	if gift then
		gift.check()
	end
end

local function askOnce()
	local now = state()
	if asked or asks == nil or not now.lit or now.claimed then
		return
	end
	local bubble = BubbleRules.get(ASK_ID)
	if bubble == nil then
		return
	end
	asked = asks.want(ASK_ID, function()
		local answered = false
		UI.showBubble(bubble, function()
			answered = true
			asks.done(ASK_ID, "yes")
			open()
		end, function(closed: boolean)
			if not answered then
				asks.done(ASK_ID, if closed then "no" else "closed")
			end
		end)
		task.delay(ASK_UP_SECONDS, function()
			if not answered and UI.shownBubble() == bubble then
				UI.hideBubble()
			end
		end)
	end)
end

local function changed()
	local now = state()
	UI.setGift(now)
	if now.claimed and not wasClaimed and UI.isOpen(GiftViewRules.WINDOW) then
		if LiveFlags.isOn(CrateRules.GIFT_FLAG) and crates then
			-- the gift crate (issue 859): straight on to its window, on the Open button the card promised
			task.delay(CRATE_AFTER, function()
				if UI.isOpen(GiftViewRules.WINDOW) then
					UI.close(GiftViewRules.WINDOW)
					crates.show(CrateRules.GIFT_KIND)
				end
			end)
		else
			task.delay(CLOSE_AFTER, function()
				UI.close(GiftViewRules.WINDOW)
			end)
		end
	end
	wasClaimed = now.claimed
	if now.claimed and asks then
		asks.drop(ASK_ID)
	end
	askOnce()
end

function GiftCardController.Init(controllers: { [string]: any })
	gift = controllers.GiftController
	asks = controllers.AskController
	crates = controllers.CrateWindowController
end

function GiftCardController.Start()
	if gift == nil then
		return
	end
	wasClaimed = state().claimed
	gift.onOpen(open)
	gift.onChanged(changed)
	-- (likeHowTo, issue 869) the like how-to's ask_shown and ask_answered events
	UI.onLikeHowTo(function(answer: string?)
		Remotes.event("ReportAsk"):FireServer("likeHowTo", answer)
	end)
	UI.onGiftStep(function(key: string)
		if key == "favourite" then
			gift.favourite()
		elseif key == "group" then
			gift.join()
		elseif freeOn() then
			local f = free()
			if key == "like" and f and not f.likeAsked then
				Remotes.event("RequestLikeAsk"):FireServer()
			elseif key == "likeClaim" and f and not f.likeClaimed then
				Remotes.event("RequestFreeReward"):FireServer("like")
			elseif key == "playClaim" and f and not f.playClaimed then
				Remotes.event("RequestFreeReward"):FireServer("play")
			end
		end
	end)
	for _, name in
		{
			FreeRewardRules.LIKE_READY_ATTRIBUTE,
			FreeRewardRules.PLAY_SECONDS_ATTRIBUTE,
			FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE,
			FreeRewardRules.PLAY_CLAIMED_ATTRIBUTE,
		}
	do
		player:GetAttributeChangedSignal(name):Connect(function()
			UI.setGift(state())
			tick()
		end)
	end
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FreeRewardRules.FLAG)
		:Connect(function()
			UI.setGift(state())
		end)
	UI.onOpened(function(name: string)
		if name == GiftViewRules.WINDOW then
			tick()
		end
	end)
	UI.onGiftClaim(function()
		if GiftViewRules.ready(state()) then
			gift.claim()
		end
	end)
	changed()
end

return GiftCardController
