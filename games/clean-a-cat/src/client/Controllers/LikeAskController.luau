--!strict
-- LikeAskController: the like ask on the client (LikeAskRules, switch likeAsk with askQueue). The server decides when
-- it is due (the Player attribute LikeAskDue, the moment's name); this puts "like" in the ask queue, so it shows only
-- when the screen is free, and sends the answer back. Design's card plugs in:
--
--   LikeAskController.onShow(show, hide?)   show(moment) puts the card up when its turn comes; hide() takes it down
--   LikeAskController.answer(kind)          "yes" (Like the game: the card then opens the gift card's like row),
--                                           "no" (Not now: not asked again for three visits) or "closed" (X or back)
--
-- Until a card is plugged in nothing is queued, so the switch shows nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LikeAskRules = require(Shared:WaitForChild("LikeAskRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ID = "like"

local LikeAskController = {}

local player = Players.LocalPlayer
local ask: any = nil -- AskController
local showCard: ((moment: string) -> ())? = nil
local hideCard: (() -> ())? = nil
local up = false

local function due(): string?
	local moment = player:GetAttribute(LikeAskRules.ATTRIBUTE)
	return if type(moment) == "string" then moment else nil
end

local function sync()
	local moment = due()
	if
		moment == nil
		or not LiveFlags.isOn(LikeAskRules.FLAG)
		or showCard == nil
		or not ask.on()
	then
		ask.drop(ID)
		if up then
			up = false
			if hideCard then
				hideCard()
			end
			ask.done(ID, "closed")
		end
		return
	end
	if up then
		return
	end
	ask.want(ID, function()
		local now = due()
		local show = showCard
		if now == nil or show == nil then
			ask.skip(ID) -- it went away while it waited
			return
		end
		up = true
		show(now)
	end, function()
		up = false
		if hideCard then
			hideCard()
		end
	end)
end

function LikeAskController.onShow(show: (moment: string) -> (), hide: (() -> ())?)
	showCard = show
	hideCard = hide
	sync()
end

function LikeAskController.answer(kind: string)
	local answer = LikeAskRules.cleanAnswer(kind)
	if answer == nil or due() == nil then
		return
	end
	Remotes.event("RequestLikeAnswer"):FireServer(answer)
	up = false
	ask.done(ID, answer)
end

function LikeAskController.Init(controllers: { [string]: any })
	ask = controllers.AskController
end

function LikeAskController.Start()
	player:GetAttributeChangedSignal(LikeAskRules.ATTRIBUTE):Connect(sync)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. LikeAskRules.FLAG)
		:Connect(sync)
	sync()
end

return LikeAskController
