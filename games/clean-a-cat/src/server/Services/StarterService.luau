--!strict
-- StarterService: the starter pack (StarterRules, issue 519). On each join it counts the visit (save.visits) and, with
-- the switch on, stamps the pack's end once (SaveSchema.stampStarter: 72 hours from first join, or from this join for
-- a save from before the pack). While the pack is offered, the Player attribute StarterEndsAt holds its end on the
-- server's clock for Design's button and window; it goes away at zero, once the player owns any of the three passes,
-- or once it is bought. The button's tap asks RequestStarter and Roblox's purchase prompt opens; nothing opens by
-- itself. PurchaseService grants the product: the three passes go into the save (save.passes) before Roblox hears it
-- went through, and a purchase confirmed just before zero is still honoured after it.
-- Behind the LiveFlags switch starterPack, with passes on too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local StarterRules = require(Shared:WaitForChild("StarterRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PassService = require(script.Parent:WaitForChild("PassService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local PurchaseService = require(script.Parent:WaitForChild("PurchaseService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local CHECK_SECONDS = 15 -- how often the offer is looked at again (the tutorial's end, the clock's zero)
local EXPIRED_ASK = "starterExpired" -- save.asks key: pack_expired was logged
local SHOWN_ASK = "starterShown" -- save.asks key: pack_offer_shown was logged (the button's first show)

local StarterService = {}

local function on(): boolean
	return LiveFlags.isOn(StarterRules.FLAG) and LiveFlags.isOn(Passes.FLAG)
end

local function offered(player: Player, save: SaveSchema.Save): boolean
	return StarterRules.offered(
		save.starterEndsAt,
		os.time(),
		Telemetry.played(player) or save.playSeconds,
		function(key: string): boolean
			return PassService.owns(player, key) or save.passes[key] == true
		end
	)
end

local function show(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local open = on() and offered(player, save)
	local ends = if open then save.starterEndsAt else nil
	if open and save.asks[SHOWN_ASK] ~= true then
		save.asks[SHOWN_ASK] = true
		Telemetry.event(player, "pack_offer_shown", 1) -- the button's first show, once per save (Review-QA on #615)
	end
	if player:GetAttribute(StarterRules.ENDS_ATTRIBUTE) ~= ends then
		player:SetAttribute(StarterRules.ENDS_ATTRIBUTE, ends)
	end
	local opened = if on() and save.starterOpened then true else nil
	if player:GetAttribute(StarterRules.OPENED_ATTRIBUTE) ~= opened then
		player:SetAttribute(StarterRules.OPENED_ATTRIBUTE, opened)
	end
	if player:GetAttribute(StarterRules.VISITS_ATTRIBUTE) ~= save.visits then
		player:SetAttribute(StarterRules.VISITS_ATTRIBUTE, save.visits)
	end
	-- the clock reached zero with the pack never bought: logged once for the save
	if
		on()
		and save.starterEndsAt > 0
		and os.time() >= save.starterEndsAt
		and save.asks[EXPIRED_ASK] ~= true
	then
		save.asks[EXPIRED_ASK] = true
		local bought = true
		for _, key in StarterRules.CONTENTS do
			bought = bought and save.passes[key] == true
		end
		if not bought then
			Telemetry.event(player, "pack_expired", 1)
		end
	end
end

-- Starts the 72 hours once, the first join with the switch on.
local function stamp(_player: Player, save: SaveSchema.Save)
	if not on() or save.starterEndsAt ~= 0 then
		return
	end
	SaveSchema.stampStarter(save, os.time())
end

local function onRequest(player: Player)
	if not on() then
		return
	end
	local save = DataService.get(player)
	if save == nil or not offered(player, save) then
		return
	end
	PurchaseService.prompt(player, StarterRules.PRODUCT)
end

local function onOpened(player: Player)
	if not on() then
		return
	end
	local save = DataService.get(player)
	if save == nil or save.starterOpened then
		return
	end
	save.starterOpened = true
	Telemetry.event(player, "shop_opened", 1, { "pack_button" })
	show(player)
end

-- (starterPet) The pack's golden pet into the save, once; true when it was given now. No yield.
local function givePet(save: SaveSchema.Save): boolean
	if not LiveFlags.isOn(StarterRules.PET_FLAG) then
		return false
	end
	return StarterRules.givePet(save :: any, CrateRules.PLAYER_SLOT) ~= nil
end

-- (starterPet) A save that bought the pack before the switch: its pet, once, with a thank you.
local function catchUp(player: Player, save: SaveSchema.Save)
	if save.starterPet or not StarterRules.boughtBefore(save.passes) then
		return
	end
	if givePet(save) then
		PetService.show(player)
		NetService.notice(
			player,
			`Thanks for getting the starter pack: {StarterRules.PET} is yours too!`
		)
	end
end

-- The pack's grant: all three passes into the save (no yield, nothing to check first: a repeat receipt never gets
-- here). The passes count from the next frame, once PassService hears of them.
local function grant(player: Player, save: SaveSchema.Save, _receipt: { [string]: any }): boolean
	for _, key in StarterRules.CONTENTS do
		save.passes[key] = true
	end
	local pet = givePet(save)
	Telemetry.event(
		player,
		"pack_bought",
		StarterRules.hoursIn(save.starterEndsAt, os.time(), SaveSchema.STARTER_SECONDS)
	)
	task.defer(function()
		for _, key in StarterRules.CONTENTS do
			PassService.grant(player, key)
		end
		show(player)
		if pet then
			PetService.show(player)
		end
		NetService.notice(
			player,
			if pet
				then `Starter pack: {StarterRules.PET}, the Golden Sponge, a second pet slot and 2x Coins are yours!`
				else "Starter pack: the Golden Sponge, a second pet slot and 2x Coins are yours!"
		)
	end)
	return true
end

function StarterService.Init(_services: { [string]: any })
	PurchaseService.register(StarterRules.PRODUCT, grant)
end

function StarterService.Start()
	NetService.on("RequestStarter", { perSecond = 1, burst = 2 }, onRequest)
	NetService.on("RequestStarterOpened", { perSecond = 1, burst = 2 }, onOpened)
	DataService.onLoaded:Connect(function(player: Player, save)
		save.visits += 1
		stamp(player, save)
		show(player)
		catchUp(player, save)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. StarterRules.PET_FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				local save = DataService.get(player)
				if save then
					catchUp(player, save)
				end
			end
		end)
	-- a pass bought on its own takes the pack away at once
	PassService.changed:Connect(function(player: Player)
		show(player)
	end)
	for _, flag in { StarterRules.FLAG, Passes.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				for _, player in Players:GetPlayers() do
					local save = DataService.get(player)
					if save then
						stamp(player, save)
						show(player)
					end
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

return StarterService
