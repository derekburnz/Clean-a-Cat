--!strict
-- GiftController: the client side of the gift stand (GiftRules, issue 521), behind the switch giftStand (with pets).
-- It puts a prompt on the player's own stand (only theirs, made on this device) while the stand is lit and a gift is
-- left there: the pet not theirs yet, or with freeRewards on a Free Rewards row not paid (FreeRewardRules.giftLeft,
-- issue 730). It gives Design's card what it needs:
--
--   GiftController.onOpen(fn)     fn() when the player taps their stand's prompt: open the card
--   GiftController.onChanged(fn)  fn() when any of the card's ticks or the light changes
--   GiftController.state()        { lit, favourite, group, claimed } from the server's Player attributes
--   GiftController.favourite()    opens Roblox's own favourite prompt for the game; a yes is told to the server
--   GiftController.join()         opens Roblox's own join prompt for the game's group, then asks the server to check
--   GiftController.check()        asks the server to check the group again (the card's refresh)
--   GiftController.claim()        asks for the pet; the server checks both again and gives it once
--
-- The like has no prompt and no check on Roblox: the card asks for it in words and never ticks it.
local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local FreeRewardRules = require(Shared:WaitForChild("FreeRewardRules"))
local GiftRules = require(Shared:WaitForChild("GiftRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local CHECK_SECONDS = 1
local PROMPT_NAME = "GiftPrompt"

local GiftController = {}

export type State = { lit: boolean, favourite: boolean, group: boolean, claimed: boolean }

local player = Players.LocalPlayer
local opened = Signal.new() :: Signal.Signal<>
local changed = Signal.new() :: Signal.Signal<>
local prompt: ProximityPrompt? = nil
local favouriting = false

local function on(): boolean
	return LiveFlags.isOn(GiftRules.FLAG) and LiveFlags.isOn(CrateRules.FLAG)
end

function GiftController.state(): State
	return {
		lit = player:GetAttribute(GiftRules.LIT_ATTRIBUTE) == true,
		favourite = player:GetAttribute(GiftRules.FAVOURITE_ATTRIBUTE) == true,
		group = player:GetAttribute(GiftRules.GROUP_ATTRIBUTE) == true,
		claimed = player:GetAttribute(GiftRules.CLAIMED_ATTRIBUTE) == true,
	}
end

function GiftController.onOpen(fn: () -> ())
	opened:Connect(fn)
end

function GiftController.onChanged(fn: () -> ())
	changed:Connect(fn)
end

function GiftController.favourite()
	if not on() or favouriting then
		return
	end
	favouriting = true
	local ok, err = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	if not ok then
		favouriting = false
		warn(`GiftController: favourite prompt failed: {err}`)
	end
end

function GiftController.join()
	if not on() then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			return GroupService:PromptJoinAsync(GiftRules.GROUP_ID)
		end)
		if not ok then
			warn(`GiftController: group prompt failed: {err}`)
		end
		Remotes.event("RequestGiftCheck"):FireServer()
	end)
end

function GiftController.check()
	if on() then
		Remotes.event("RequestGiftCheck"):FireServer()
	end
end

function GiftController.claim()
	if on() then
		Remotes.event("RequestGiftClaim"):FireServer()
	end
end

-- Whether the stand still holds a gift for this player (Starcoat, or a Free Rewards row with freeRewards on).
local function giftLeft(state: State): boolean
	return FreeRewardRules.giftLeft(
		state.claimed,
		LiveFlags.isOn(FreeRewardRules.FLAG),
		player:GetAttribute(FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE) == true,
		player:GetAttribute(FreeRewardRules.PLAY_CLAIMED_ATTRIBUTE) == true
	)
end

-- The prompt on the player's own stand: there while the stand is lit and a gift is left on it.
local function refresh()
	local state = GiftController.state()
	local stand = if on() then SpaLayout.prop(GiftRules.STAND_NAME) else nil
	local want = stand ~= nil and state.lit and giftLeft(state)
	if not want then
		if prompt then
			prompt:Destroy()
			prompt = nil
		end
		return
	end
	local action = if state.claimed then "Free gifts" else "Free pet"
	if prompt and prompt.Parent and prompt:IsDescendantOf(stand :: Model) then
		prompt.ActionText = action
		return
	end
	if prompt then
		prompt:Destroy()
	end
	-- the stand's Prompt Attachment (Model-Agent), else its PetSeat, else its main part
	local holder = (stand :: Model):FindFirstChild("Prompt", true)
		or (stand :: Model):FindFirstChild("PetSeat", true)
		or (stand :: Model).PrimaryPart
	if holder == nil or not (holder:IsA("Attachment") or holder:IsA("BasePart")) then
		return
	end
	local made = Instance.new("ProximityPrompt")
	made.Name = PROMPT_NAME
	made.ActionText = action
	made.ObjectText = "Gift stand"
	made.HoldDuration = 0
	made.MaxActivationDistance = 10
	made.RequiresLineOfSight = false
	made.Triggered:Connect(function()
		if on() then
			GiftController.check()
			opened:Fire()
		end
	end)
	made.Parent = holder
	prompt = made
end

function GiftController.Init(_controllers: { [string]: any }) end

function GiftController.Start()
	AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result: Enum.AvatarPromptResult)
		favouriting = false
		if on() and result == Enum.AvatarPromptResult.Success then
			Remotes.event("RequestGiftFavourite"):FireServer(true)
		end
	end)
	for _, name in
		{
			GiftRules.LIT_ATTRIBUTE,
			GiftRules.FAVOURITE_ATTRIBUTE,
			GiftRules.GROUP_ATTRIBUTE,
			GiftRules.CLAIMED_ATTRIBUTE,
			FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE,
			FreeRewardRules.PLAY_CLAIMED_ATTRIBUTE,
		}
	do
		player:GetAttributeChangedSignal(name):Connect(function()
			refresh()
			changed:Fire()
		end)
	end
	for _, flag in { GiftRules.FLAG, CrateRules.FLAG, FreeRewardRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(refresh)
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(CHECK_SECONDS)
		end
	end)
end

return GiftController
