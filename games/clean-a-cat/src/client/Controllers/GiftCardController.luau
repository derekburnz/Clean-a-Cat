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
--     line (AskController's "gift", switch askQueue); "Show me" opens the card. A "no" there is final for the visit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local GiftViewRules = require(Shared:WaitForChild("GiftViewRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local GiftCardController = {}

local ASK_ID = "gift"
local CLOSE_AFTER = 2.5 -- seconds "Starcoat is yours!" stays before the card closes
local ASK_UP_SECONDS = 20 -- Suds's tip goes by itself after this, as BubbleController's do (#649); not a "no"

local gift: any = nil -- GiftController
local asks: any = nil -- AskController
local asked = false -- the ask was put in the line this visit
local wasClaimed = false

local function state(): GiftViewRules.State
	if gift == nil then
		return { lit = false, favourite = false, group = false, claimed = false }
	end
	return gift.state()
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
		task.delay(CLOSE_AFTER, function()
			UI.close(GiftViewRules.WINDOW)
		end)
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
end

function GiftCardController.Start()
	if gift == nil then
		return
	end
	wasClaimed = state().claimed
	gift.onOpen(open)
	gift.onChanged(changed)
	UI.onGiftStep(function(key: string)
		if key == "favourite" then
			gift.favourite()
		elseif key == "group" then
			gift.join()
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
