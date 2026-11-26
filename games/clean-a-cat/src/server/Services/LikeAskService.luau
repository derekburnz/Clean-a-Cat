--!strict
-- LikeAskService: decides when a player is asked to like the game (LikeAskRules, Derek's q2-likeask rule), behind the
-- LiveFlags switch likeAsk with askQueue. Other services report moments:
--   LikeAskService.moment(player, kind)   a good moment ("special", "crate", "stars", "helper", "purchase")
--   LikeAskService.bad(player)            a lost cat or a cancelled purchase: no ask for two minutes
-- When the ask is due the Player attribute LikeAskDue holds the moment's name; the client's ask queue shows Design's
-- card when the screen is free and answers with RequestLikeAnswer. A "no" is saved (likeNoVisit, likeNos), so the
-- ask waits three visits and stops after two; a "yes" is saved (likeYes) and it never comes again; "closed" is no
-- answer. None while the first session's tutorial runs. Nothing here pays anything: the like row's coins stay FreeRewardService's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AskRules = require(Shared:WaitForChild("AskRules"))
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local LikeAskRules = require(Shared:WaitForChild("LikeAskRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local CHECK_SECONDS = 1

local LikeAskService = {}

type Visit = {
	asked: boolean, -- the ask came due this visit
	lastBadAt: number,
	pending: { moment: LikeAskRules.Moment, at: number }?, -- a purchase's ask, waiting PURCHASE_DELAY
}

local visits: { [Player]: Visit } = {}

local function on(): boolean
	-- the card is Suds's bubble, so with sudsBubble off it cannot show and no visit's ask is spent on it
	return LiveFlags.isOn(LikeAskRules.FLAG)
		and LiveFlags.isOn(AskRules.FLAG)
		and LiveFlags.isOn(BubbleRules.FLAG)
end

local function visitOf(player: Player): Visit
	local found = visits[player]
	if found then
		return found
	end
	local visit: Visit = { asked = false, lastBadAt = -math.huge, pending = nil :: any }
	visits[player] = visit
	return visit
end

local function blocked(player: Player, visit: Visit): boolean
	local save = DataService.get(player)
	if save == nil then
		return true
	end
	return LikeAskRules.blocked({
		visit = save.visits,
		noVisit = save.likeNoVisit,
		nos = save.likeNos,
		saidYes = save.likeYes,
		inTutorial = (Telemetry.played(player) or save.playSeconds) < SpaRules.TUTORIAL_ENDS_AT,
		likePaid = save.freeRewards.like,
		askedThisVisit = visit.asked,
		lastBadAt = visit.lastBadAt,
		now = os.clock(),
	})
end

local function makeDue(player: Player, moment: LikeAskRules.Moment)
	local visit = visitOf(player)
	visit.asked = true
	visit.pending = nil
	player:SetAttribute(LikeAskRules.ATTRIBUTE, moment)
	Telemetry.event(player, "like_ask_due", 1, { moment :: string })
end

function LikeAskService.moment(player: Player, kind: LikeAskRules.Moment)
	if not on() or player.Parent ~= Players then
		return
	end
	local visit = visitOf(player)
	if blocked(player, visit) or player:GetAttribute(LikeAskRules.ATTRIBUTE) ~= nil then
		return
	end
	local now = os.clock()
	local at = LikeAskRules.dueAt(kind, now, LiveFlags.isOn(LikeAskRules.PURCHASE_FLAG))
	if at == nil then
		return
	elseif at <= now then
		makeDue(player, kind)
	elseif visit.pending == nil then
		visit.pending = { moment = kind, at = at }
	end
end

function LikeAskService.bad(player: Player)
	local visit = visitOf(player)
	visit.lastBadAt = os.clock()
	visit.pending = nil -- a purchase's ask is dropped, not put off
	-- an ask due but not answered yet goes away too; a later good moment may still bring it this visit
	if player:GetAttribute(LikeAskRules.ATTRIBUTE) ~= nil then
		player:SetAttribute(LikeAskRules.ATTRIBUTE, nil)
		visit.asked = false
	end
end

local function onAnswer(player: Player, raw: unknown)
	local answer = LikeAskRules.cleanAnswer(raw)
	local due = player:GetAttribute(LikeAskRules.ATTRIBUTE)
	if answer == nil or due == nil then
		return
	end
	player:SetAttribute(LikeAskRules.ATTRIBUTE, nil)
	local save = DataService.get(player)
	if answer == "no" and save then
		save.likeNoVisit = save.visits
		save.likeNos += 1
	elseif answer == "yes" and save then
		save.likeYes = true
	end
	Telemetry.event(player, "like_ask_answered", 1, { answer :: string, tostring(due) })
end

function LikeAskService.Init(_services: { [string]: any }) end

function LikeAskService.Start()
	NetService.on("RequestLikeAnswer", { perSecond = 1, burst = 2 }, onAnswer)
	Players.PlayerRemoving:Connect(function(player: Player)
		visits[player] = nil
	end)
	for _, flag in { LikeAskRules.FLAG, AskRules.FLAG, BubbleRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				if on() then
					return
				end
				for _, player in Players:GetPlayers() do
					player:SetAttribute(LikeAskRules.ATTRIBUTE, nil)
					local visit = visits[player]
					if visit then
						visit.pending = nil
					end
				end
			end)
	end
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local now = os.clock()
			for player, visit in visits do
				local pending = visit.pending
				if pending and now >= pending.at then
					visit.pending = nil
					-- a purchase's ask waiting while likeAskPurchase went off is dropped (Review-QA on 818)
					if
						on()
						and (pending.moment ~= "purchase" or LiveFlags.isOn(
							LikeAskRules.PURCHASE_FLAG
						))
						and not blocked(player, visit)
						and player:GetAttribute(LikeAskRules.ATTRIBUTE) == nil
					then
						makeDue(player, pending.moment)
					end
				end
			end
		end
	end)
end

return LikeAskService
