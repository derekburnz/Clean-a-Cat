--!strict
-- GiftService: the gift stand and its free pet (GiftRules, issue 521). With the switch on, every plot holds Model-Agent's
-- stand (CleanACat_Prop_GiftStand) at its GiftStand spot, with Starcoat sitting on its PetSeat until the plot's owner
-- has the pet. The stand stays unlit until GiftRules.LIGHT_AT of the owner's play (7:00), then its Glow and Lamp turn on
-- (the stand's attribute Lit, for the effects) and the Player attribute GiftLit lets the card open from it.
--
-- The card's three steps (Design's card; GiftController sends these):
--   RequestGiftFavourite(true)   the player's own favourite prompt said yes: saved (save.giftFavourite), GiftFavourite
--                                on the player. The device tells it; the server trusts that for one free pet.
--   RequestGiftCheck()           the server asks Roblox whether the player is in the group: GiftGroup on the player.
--   RequestGiftClaim()           both checked (the group asked again here): Starcoat goes into the save once
--                                (save.giftClaimed), the save is written, then GiftClaimed and the notice.
-- The like is asked on the card and never checked or needed: a game cannot read it.
-- Behind the LiveFlags switch giftStand, with pets on too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local FreeRewardRules = require(Shared:WaitForChild("FreeRewardRules"))
local GiftFlowRules = require(Shared:WaitForChild("GiftFlowRules"))
local GiftRules = require(Shared:WaitForChild("GiftRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local CHECK_SECONDS = 5 -- how often the stands are looked at again (the 7:00 light, a plot changing hands)
local SAVE_WAIT = 10 -- seconds a claim waits for the save holding the pet to be written
local SEAT_PET = "GiftPet" -- Starcoat's copy on the stand's PetSeat

local GiftService = {}

local claiming: { [Player]: boolean } = {}
local verifiedAt: { [Player]: number } = {} -- (groupVerify) os.clock() of the last answered Verify tap

local function on(): boolean
	return LiveFlags.isOn(GiftRules.FLAG) and LiveFlags.isOn(CrateRules.FLAG)
end

-- (switch giftFlow, issue 919) The save's gift stage, or nil with the switch off.
local function stageOf(save: any): number?
	if save == nil or not LiveFlags.isOn(GiftFlowRules.FLAG) then
		return nil
	end
	return GiftFlowRules.stage(save.giftClaimed == true, save.freeRewards.play == true)
end

local function setAttribute(player: Player, name: string, value: boolean)
	local shown = if value then true else nil
	if player:GetAttribute(name) ~= shown then
		player:SetAttribute(name, shown)
	end
end

local function asset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = if assets then assets:FindFirstChild(name) else nil
	return if found and found:IsA("Model") then found :: Model else nil
end

local function anchor(model: Instance)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			(part :: BasePart).Anchored = true
		end
	end
end

local function propsOf(slot: number): Instance?
	local plot = SpaLayout.plotModel(slot)
	return if plot then plot:FindFirstChild(SpaLayout.PROPS_FOLDER) else nil
end

local function ownerOf(slot: number): Player?
	for _, player in Players:GetPlayers() do
		if SpaLayout.slotOf(player) == slot then
			return player
		end
	end
	return nil
end

-- Lights or darkens the stand's Glow and Lamp (every light, particle and beam under them).
local function light(stand: Model, lit: boolean)
	if stand:GetAttribute("Lit") == lit then
		return
	end
	stand:SetAttribute("Lit", lit)
	for _, name in { "Glow", "Lamp" } do
		local piece = stand:FindFirstChild(name, true)
		if piece == nil then
			continue
		end
		for _, child in piece:GetDescendants() do
			if child:IsA("Light") or child:IsA("ParticleEmitter") or child:IsA("Beam") then
				(child :: any).Enabled = lit
			end
		end
	end
end

-- Starcoat on the PetSeat while `show`.
local function seatPet(stand: Model, show: boolean)
	local current = stand:FindFirstChild(SEAT_PET)
	if not show then
		if current then
			current:Destroy()
		end
		return
	end
	if current then
		return
	end
	local seat = stand:FindFirstChild("PetSeat", true)
	local base = asset(`CleanACat_Pet_{GiftRules.PET}`)
	-- PetSeat is an Attachment on Model-Agent's stand (a part's top also works)
	local top: CFrame? = if seat and seat:IsA("Attachment")
		then (seat :: Attachment).WorldCFrame
		elseif seat and seat:IsA("BasePart") then (seat :: BasePart).CFrame * CFrame.new(
			0,
			(seat :: BasePart).Size.Y / 2,
			0
		)
		else nil
	if base == nil or top == nil then
		return
	end
	local pet = base:Clone()
	pet.Name = SEAT_PET
	for _, piece in pet:GetDescendants() do
		local level = piece:GetAttribute("StarLevel")
		local aboveStar = piece:IsA("Model") and type(level) == "number" and level > 1
		if aboveStar or piece:IsA("Script") or piece:IsA("LocalScript") then
			piece:Destroy()
		end
	end
	-- on the stand the pet takes the stand's CatScale (Model-Agent: PetScale is for the one that follows the player)
	local standScale = stand:GetAttribute("CatScale")
	local petScale = pet:GetAttribute("PetScale")
	local scale = if type(standScale) == "number" and standScale > 0
		then standScale
		elseif type(petScale) == "number" and petScale > 0 then petScale
		else 0.7
	pet:ScaleTo(scale)
	pet:PivotTo(top :: CFrame)
	anchor(pet)
	pet.Parent = stand
end

-- Every plot's stand, as it should be now: there with the switch on, lit for an owner past 7:00, the pet on it until
-- the owner has it.
local function drawStands()
	local placed = ReplicatedStorage:GetAttribute(SpaLayout.PLACED_ATTRIBUTE) == true
	local folder = game:GetService("Workspace"):FindFirstChild(SpaLayout.PLOTS_FOLDER)
	if folder == nil then
		return
	end
	for _, plot in folder:GetChildren() do
		local slot = plot:GetAttribute("Slot")
		if type(slot) ~= "number" then
			continue
		end
		local props = propsOf(slot)
		if props == nil then
			continue
		end
		local found = props:FindFirstChild(GiftRules.STAND_NAME)
		if not (on() and placed) then
			if found then
				found:Destroy()
			end
			continue
		end
		local stand: Model? = if found and found:IsA("Model") then found :: Model else nil
		local holder = ownerOf(slot)
		local finished = if holder then stageOf(DataService.get(holder)) else nil
		if stand == nil and finished and not GiftFlowRules.standStays(finished) then
			continue
		end
		if stand == nil then
			local base = asset(GiftRules.STAND_ASSET)
			if base == nil then
				continue
			end
			local made = base:Clone() :: Model
			made.Name = GiftRules.STAND_NAME
			made:PivotTo(SpaLayout.slotSpot(GiftRules.STAND_SPOT, slot))
			anchor(made)
			made:SetAttribute("Lit", true)
			light(made, false) -- every light under Glow and Lamp off until the owner's 7:00
			made.Parent = props
			stand = made
		end
		local owner = ownerOf(slot)
		local save = if owner then DataService.get(owner) else nil
		-- (giftFlow) both gifts claimed: the stand leaves this spa for good, after a moment for the puff
		local stage = stageOf(save)
		if stage and not GiftFlowRules.standStays(stage) then
			local leaving = stand :: Model
			if leaving:GetAttribute(GiftFlowRules.LEAVING_ATTRIBUTE) ~= true then
				leaving:SetAttribute(GiftFlowRules.LEAVING_ATTRIBUTE, true)
				task.delay(GiftFlowRules.LEAVE_SECONDS, function()
					if leaving.Parent then
						leaving:Destroy()
					end
				end)
			end
			continue
		end
		light(stand :: Model, owner ~= nil and owner:GetAttribute(GiftRules.LIT_ATTRIBUTE) == true)
		-- (giftCrate) Starcoat is no longer the gift, only a chance in the crate: he leaves the stand
		seatPet(
			stand :: Model,
			(save == nil or not save.giftClaimed) and not LiveFlags.isOn(CrateRules.GIFT_FLAG)
		)
	end
end

local function show(player: Player)
	local save = DataService.get(player)
	local active = on() and save ~= nil
	local played = Telemetry.played(player) or (if save then save.playSeconds else 0)
	setAttribute(player, GiftRules.LIT_ATTRIBUTE, active and GiftRules.lit(played))
	setAttribute(
		player,
		GiftRules.FAVOURITE_ATTRIBUTE,
		active and save ~= nil and save.giftFavourite
	)
	setAttribute(player, GiftRules.CLAIMED_ATTRIBUTE, active and save ~= nil and save.giftClaimed)
	local stage = if active then stageOf(save) else nil
	if player:GetAttribute(GiftFlowRules.STAGE_ATTRIBUTE) ~= stage then
		player:SetAttribute(GiftFlowRules.STAGE_ATTRIBUTE, stage)
	end
	if not active then
		setAttribute(player, GiftRules.GROUP_ATTRIBUTE, false)
	end
end

-- Asks Roblox whether `player` is in the game's group; false when the check fails. Yields.
local function inGroup(player: Player): boolean
	local ok, result = pcall(function()
		return player:IsInGroupAsync(GiftRules.GROUP_ID)
	end)
	return ok and result == true
end

local function check(player: Player)
	if not on() then
		return
	end
	local member = inGroup(player)
	if player.Parent == Players then
		setAttribute(player, GiftRules.GROUP_ATTRIBUTE, member)
	end
end

local function onFavourite(player: Player, raw: unknown)
	if not on() or raw ~= true then
		return
	end
	local save = DataService.get(player)
	if save == nil or save.giftFavourite then
		return
	end
	save.giftFavourite = true
	Telemetry.event(player, "gift_step", 1, { "favourite" })
	show(player)
end

local function onClaim(player: Player)
	if not on() or claiming[player] then
		return
	end
	local save = DataService.get(player)
	if save == nil or player:GetAttribute(GiftRules.LIT_ATTRIBUTE) ~= true then
		return
	end
	claiming[player] = true
	local member = inGroup(player) -- asked again: the card's tick may be old
	if player.Parent ~= Players then
		claiming[player] = nil
		return
	end
	setAttribute(player, GiftRules.GROUP_ATTRIBUTE, member)
	local state: GiftRules.State =
		{ favourite = save.giftFavourite, group = member, claimed = save.giftClaimed }
	if not GiftRules.canClaim(state, LiveFlags.isOn) then
		claiming[player] = nil
		if not save.giftClaimed then
			NetService.notice(
				player,
				if not member
					then "Join the group to get Starcoat"
					else "Favourite the game to get Starcoat",
				"warning"
			)
		end
		return
	end
	-- (switch giftCrate, issue 859) a gift crate to open, with its chances shown, instead of Starcoat straight away
	local crate = LiveFlags.isOn(CrateRules.GIFT_FLAG)
	local given = if crate
		then GiftRules.giveCrate(save :: any, CrateRules.GIFT_KIND)
		else GiftRules.give(save :: any, CrateRules.PLAYER_SLOT) ~= nil
	if not given then
		claiming[player] = nil
		return
	end
	Telemetry.event(player, "gift_claimed", 1, { if crate then "crate" else "pet" })
	-- (giftFlow) Claim all: the like row's coins come in the same tap, once, if they were not taken before
	local flow = LiveFlags.isOn(GiftFlowRules.FLAG)
	local likeCoins = flow and not save.freeRewards.like
	if likeCoins then
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
		player:SetAttribute(FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE, true)
	end
	PetService.show(player)
	-- the pet is the player's from now on; the card hears it once the save holding it is written (or after SAVE_WAIT,
	-- when the next save carries it)
	DataService.saveAndConfirm(player, function(saved: { [string]: any }): boolean
		return saved.giftClaimed == true
	end, SAVE_WAIT)
	claiming[player] = nil
	if player.Parent ~= Players then
		return
	end
	show(player)
	drawStands()
	local gift = if crate then "a gift crate" else "Starcoat"
	NetService.notice(
		player,
		if likeCoins
			then `+{FreeRewardRules.LIKE_COINS} coins and {gift}! Thank you for joining us`
			elseif crate then "Your gift crate is here! Thank you for joining us"
			else "Starcoat is yours! Thank you for joining us"
	)
end

-- (groupVerify, issue 1111) The board's Verify: the server asks Roblox about the group on each answered tap and, on a
-- join, gives what is left of the stand's gift and the 150 coins, each once per save. Nothing else is asked for.
local function onVerify(player: Player)
	if not (on() and LiveFlags.isOn(GiftRules.VERIFY_FLAG)) or claiming[player] then
		return
	end
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local now = os.clock()
	if not GiftRules.verifyReady(verifiedAt[player], now) then
		player:SetAttribute(GiftRules.VERIFY_ATTRIBUTE, "wait")
		return
	end
	verifiedAt[player] = now
	claiming[player] = true
	local member = inGroup(player)
	if player.Parent ~= Players then
		claiming[player] = nil
		return
	end
	setAttribute(player, GiftRules.GROUP_ATTRIBUTE, member)
	player:SetAttribute(GiftRules.VERIFY_ATTRIBUTE, if member then "joined" else "notYet")
	Telemetry.event(
		player,
		"gift_step",
		1,
		{ if member then "verify_joined" else "verify_not_yet" }
	)
	if not member then
		claiming[player] = nil
		NetService.notice(player, GiftRules.NOT_YET_TEXT, "warning")
		return
	end
	local grant = GiftRules.verifyGrant(member, save.giftClaimed, save.freeRewards.like)
	local crate = LiveFlags.isOn(CrateRules.GIFT_FLAG)
	local given = false
	if grant.pet then
		given = if crate
			then GiftRules.giveCrate(save :: any, CrateRules.GIFT_KIND)
			else GiftRules.give(save :: any, CrateRules.PLAYER_SLOT) ~= nil
		if given then
			Telemetry.event(player, "gift_claimed", 1, { if crate then "crate" else "pet" })
		end
	end
	if grant.coins then
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
			"group_verify"
		)
		player:SetAttribute(FreeRewardRules.LIKE_CLAIMED_ATTRIBUTE, true)
	end
	if given then
		PetService.show(player)
		DataService.saveAndConfirm(player, function(saved: { [string]: any }): boolean
			return saved.giftClaimed == true
		end, SAVE_WAIT)
	end
	claiming[player] = nil
	if player.Parent ~= Players then
		return
	end
	show(player)
	if given then
		drawStands()
	end
	local gift = if crate then "a gift crate" else GiftRules.PET
	NetService.notice(
		player,
		if given and grant.coins
			then `+{FreeRewardRules.LIKE_COINS} coins and {gift}! Thank you for joining us`
			elseif given then `{gift} is yours! Thank you for joining us`
			elseif grant.coins then `+{FreeRewardRules.LIKE_COINS} coins! Thank you for joining us`
			else "You're in the group. Thank you for joining us!"
	)
end

function GiftService.Init(_services: { [string]: any }) end

function GiftService.Start()
	NetService.on("RequestGiftFavourite", { perSecond = 1, burst = 2 }, onFavourite)
	NetService.on("RequestGiftCheck", { perSecond = 0.5, burst = 2 }, check)
	NetService.on("RequestGiftClaim", { perSecond = 0.5, burst = 2 }, onClaim)
	NetService.on(GiftRules.VERIFY_REMOTE, { perSecond = 0.5, burst = 2 }, onVerify)
	DataService.onLoaded:Connect(function(player: Player, _save: SaveSchema.Save)
		show(player)
		task.spawn(check, player)
		drawStands()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		claiming[player] = nil
		verifiedAt[player] = nil
		task.defer(drawStands)
	end)
	for _, flag in { GiftRules.FLAG, CrateRules.FLAG, CrateRules.GIFT_FLAG, GiftFlowRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				for _, player in Players:GetPlayers() do
					show(player)
					task.spawn(check, player)
				end
				drawStands()
			end)
	end
	SpaLayout.changed(drawStands)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				show(player)
			end
			drawStands()
		end
	end)
end

return GiftService
