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
local GiftRules = require(Shared:WaitForChild("GiftRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local CHECK_SECONDS = 5 -- how often the stands are looked at again (the 7:00 light, a plot changing hands)
local SAVE_WAIT = 10 -- seconds a claim waits for the save holding the pet to be written
local SEAT_PET = "GiftPet" -- Starcoat's copy on the stand's PetSeat

local GiftService = {}

local claiming: { [Player]: boolean } = {}

local function on(): boolean
	return LiveFlags.isOn(GiftRules.FLAG) and LiveFlags.isOn(CrateRules.FLAG)
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
	if base == nil or seat == nil or not seat:IsA("BasePart") then
		return
	end
	local pet = base:Clone()
	pet.Name = SEAT_PET
	for _, piece in pet:GetDescendants() do
		local level = piece:GetAttribute("StarLevel")
		if piece:IsA("Model") and type(level) == "number" and level > 1 then
			piece:Destroy()
		elseif piece:IsA("Script") or piece:IsA("LocalScript") then
			piece:Destroy()
		end
	end
	local scale = pet:GetAttribute("PetScale")
	pet:ScaleTo(if type(scale) == "number" and scale > 0 then scale else 0.7)
	local top = (seat :: BasePart).CFrame * CFrame.new(0, (seat :: BasePart).Size.Y / 2, 0)
	pet:PivotTo(top)
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
		light(stand :: Model, owner ~= nil and owner:GetAttribute(GiftRules.LIT_ATTRIBUTE) == true)
		seatPet(stand :: Model, save == nil or not save.giftClaimed)
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
	if not GiftRules.canClaim(state) then
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
	local pet = GiftRules.give(save :: any, CrateRules.PLAYER_SLOT)
	if pet == nil then
		claiming[player] = nil
		return
	end
	Telemetry.event(player, "gift_claimed", 1)
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
	NetService.notice(player, "Starcoat is yours! Thank you for joining us")
end

function GiftService.Init(_services: { [string]: any }) end

function GiftService.Start()
	NetService.on("RequestGiftFavourite", { perSecond = 1, burst = 2 }, onFavourite)
	NetService.on("RequestGiftCheck", { perSecond = 0.5, burst = 2 }, check)
	NetService.on("RequestGiftClaim", { perSecond = 0.5, burst = 2 }, onClaim)
	DataService.onLoaded:Connect(function(player: Player, _save: SaveSchema.Save)
		show(player)
		task.spawn(check, player)
		drawStands()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		claiming[player] = nil
		task.defer(drawStands)
	end)
	for _, flag in { GiftRules.FLAG, CrateRules.FLAG } do
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
