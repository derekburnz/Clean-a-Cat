--!strict
-- FreeRewardService: the server side of the Free Rewards rows on the gift card (FreeRewardRules, issue 730). The
-- client only asks; each reward is paid once per save, here:
--   RequestLikeAsk()          the player opened the like ask: likeAskedAt is stamped once (server os.time()), and
--                             FreeLikeReadyAt shows when its Claim unlocks (LIKE_WAIT later). The like itself is
--                             never read or needed: a game cannot see it, and the card says the gift comes either way.
--   RequestFreeReward(key)    "like": asked LIKE_WAIT or more seconds ago, 150 coins. "play": 30 minutes of play in
--                             total, one normal crate. FreePlayClaimed / FreeLikeClaimed once paid.
-- PlaySeconds on the player shows the save's play time for the play row (whole seconds, every CHECK_SECONDS).
-- The favourite plus group row (Starcoat) stays GiftService's. Behind the LiveFlags switch freeRewards, with
-- giftStand and pets on too; nothing costs Robux.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local FreeRewardRules = require(Shared:WaitForChild("FreeRewardRules"))
local GiftFlowRules = require(Shared:WaitForChild("GiftFlowRules"))
local GiftRules = require(Shared:WaitForChild("GiftRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local CHECK_SECONDS = 5 -- how often PlaySeconds is shown again

local FreeRewardService = {}

local function on(): boolean
	return LiveFlags.isOn(FreeRewardRules.FLAG)
		and LiveFlags.isOn(GiftRules.FLAG)
		and LiveFlags.isOn(CrateRules.FLAG)
end

local function setAttribute(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function played(player: Player, save: SaveSchema.Save): number
	return Telemetry.played(player) or save.playSeconds
end

-- The card's attributes, as the save has them now; all cleared while the switches are off.
local function show(player: Player)
	if player.Parent ~= Players then
		return
	end
	local save = DataService.get(player)
	if not on() or save == nil then
		setAttribute(player, FreeRewardRules.PLAY_CLAIMED_ATTRIBUTE, nil)
		setAttribute(player, FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE, nil)
		setAttribute(player, FreeRewardRules.LIKE_READY_ATTRIBUTE, nil)
		setAttribute(player, FreeRewardRules.PLAY_SECONDS_ATTRIBUTE, nil)
		return
	end
	setAttribute(
		player,
		FreeRewardRules.PLAY_CLAIMED_ATTRIBUTE,
		if save.freeRewards.play then true else nil
	)
	setAttribute(
		player,
		FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE,
		if save.freeRewards.like then true else nil
	)
	setAttribute(
		player,
		FreeRewardRules.LIKE_READY_ATTRIBUTE,
		FreeRewardRules.likeReadyAt(save.likeAskedAt)
	)
	setAttribute(player, FreeRewardRules.PLAY_SECONDS_ATTRIBUTE, math.floor(played(player, save)))
end

local function onLikeAsk(player: Player)
	if not on() then
		return
	end
	local save = DataService.get(player)
	if save == nil or save.likeAskedAt > 0 or save.freeRewards.like then
		return
	end
	save.likeAskedAt = os.time()
	Telemetry.event(player, "free_reward_step", 1, { "like_asked" })
	show(player)
end

local function onClaim(player: Player, rawKey: unknown)
	if not on() then
		return
	end
	local clean: FreeRewardRules.Key? = FreeRewardRules.cleanKey(rawKey)
	local save = DataService.get(player)
	if clean == nil or save == nil then
		return
	end
	local key: FreeRewardRules.Key = clean
	local refusal = FreeRewardRules.refusal({
		claimed = save.freeRewards,
		likeAskedAt = save.likeAskedAt,
		played = played(player, save),
		now = os.time(),
	}, key)
	-- (giftFlow, issue 919) the playtime gift opens only once the welcome gift is claimed
	local flow = LiveFlags.isOn(GiftFlowRules.FLAG)
	if
		refusal == nil
		and flow
		and key == "play"
		and not GiftFlowRules.playOpen(GiftFlowRules.stage(save.giftClaimed, save.freeRewards.play))
	then
		refusal = "notYet"
	end
	if refusal ~= nil then
		show(player) -- the card falls back to the server's view
		return
	end
	if key == "like" then
		save.freeRewards.like = true
		save.coins += FreeRewardRules.LIKE_COINS
		WalletService.show(player)
		Telemetry.economy(
			player,
			"coins",
			"source",
			FreeRewardRules.LIKE_COINS,
			save.coins,
			"Gameplay",
			"free_like"
		)
		NetService.notice(player, `+{FreeRewardRules.LIKE_COINS} coins. Thank you for playing!`)
	else
		save.freeRewards.play = true
		-- (giftFlow) a good crate, the second crate of the first session
		local kind = if flow then GiftFlowRules.PLAY_CRATE else FreeRewardRules.PLAY_CRATE
		PetService.give(player, kind, FreeRewardRules.PLAY_CRATES)
		Telemetry.event(player, "crate_earned", FreeRewardRules.PLAY_CRATES, { "free_play" })
		NetService.notice(
			player,
			"A free crate is by your tub. Thanks for spending time at the spa!"
		)
	end
	Telemetry.event(player, "free_reward_claimed", 1, { key :: string })
	show(player)
end

function FreeRewardService.Init(_services: { [string]: any }) end

function FreeRewardService.Start()
	NetService.on("RequestLikeAsk", { perSecond = 1, burst = 2 }, onLikeAsk)
	NetService.on("RequestFreeReward", { perSecond = 1, burst = 2 }, onClaim)
	DataService.onLoaded:Connect(function(player: Player, _save: SaveSchema.Save)
		show(player)
	end)
	for _, flag in { FreeRewardRules.FLAG, GiftRules.FLAG, CrateRules.FLAG, GiftFlowRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				for _, player in Players:GetPlayers() do
					show(player)
				end
			end)
	end
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				show(player)
			end
		end
	end)
end

return FreeRewardService
