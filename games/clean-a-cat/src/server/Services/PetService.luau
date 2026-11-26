--!strict
-- PetService: crates and pets on the server (CrateRules, issues 511 and 512). The player opens a crate they hold with
-- their own tap (RequestOpenCrate): the pet is rolled from the crate's shown chance list, saved, and sent back for the
-- reveal (CrateOpened). Pets go beside the player or a worker (RequestPlacePet) and three of the same fuse into a star
-- up (RequestFusePets); the server checks every pet in a request belongs to the player. Crates held show as the Player
-- attributes Crates_<kind>, the pet in each slot as Pet_<slot> = "<kind>:<star>" (every client draws them), and the
-- whole pen goes to the owner as Pets after every change.
-- Coins never buy a crate. The Robux crate is issue 514, behind PolicyService.
-- Behind the LiveFlags switch `pets`, off by default.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PassService = require(script.Parent:WaitForChild("PassService"))

local SECOND_PASS = "SecondPetSlot" -- Passes key: a second slot for the player and every worker (issue 518)

local PetService = {}

local random = Random.new()
local MAX_PET_ID = 1_000_000_000
local SLOT_PATTERN = "^%a+%d?$" -- "player" or a worker id plus its slot number

local function nextNumber(): number
	return random:NextNumber()
end

local function second(player: Player): boolean
	return PassService.owns(player, SECOND_PASS)
end

-- Every crate count, every slot's pet, and the pen for the owner.
function PetService.show(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	for _, kind in CrateRules.KINDS do
		player:SetAttribute(CrateRules.CRATE_ATTRIBUTE_PREFIX .. kind, save.crates[kind] or 0)
	end
	local inSlot: { [string]: string } = {}
	for _, pet in save.pets do
		if pet.slot then
			inSlot[pet.slot] = `{pet.kind}:{pet.star}`
		end
	end
	-- every slot the save could have, so a second slot's pet goes from view when the pass no longer counts
	local counts = CrateRules.slots(save, second(player))
	for _, slot in CrateRules.slots(save, true) do
		local value = if table.find(counts, slot) then inSlot[slot] else nil
		player:SetAttribute(CrateRules.PET_ATTRIBUTE_PREFIX .. slot, value)
	end
	if LiveFlags.isOn(CrateRules.FLAG) then
		NetService.fire(player, "Pets", save.pets)
	end
end

-- Adds `count` crates of `kind` to the player's save (quests, the check in card, a special visitor) and shows them.
function PetService.give(player: Player, kind: string, count: number): boolean
	local save = DataService.get(player)
	local clean = CrateRules.cleanKind(kind)
	if save == nil or clean == nil or count <= 0 then
		return false
	end
	save.crates[clean] = (save.crates[clean] or 0) + count
	PetService.show(player)
	return true
end

-- How much the player's own pets add to their tips (switch pets): 0.05 is +5%.
function PetService.playerBoost(player: Player): number
	local save = DataService.get(player)
	if save == nil or not LiveFlags.isOn(CrateRules.FLAG) then
		return 0
	end
	return CrateRules.boostOf(save.pets, CrateRules.playerSlots(second(player)))
end

-- How much worker `id`'s pets add to their pay (switch pets), capped at CrateRules.PET_CAP.
function PetService.workerBoost(player: Player, id: string): number
	local save = DataService.get(player)
	if save == nil or not LiveFlags.isOn(CrateRules.FLAG) then
		return 0
	end
	return CrateRules.boostOf(
		save.pets,
		CrateRules.workerSlots(id, second(player)),
		CrateRules.PET_CAP
	)
end

local function onOpen(player: Player, rawKind: unknown)
	local kind = CrateRules.cleanKind(rawKind)
	local save = DataService.get(player)
	if not LiveFlags.isOn(CrateRules.FLAG) or kind == nil or save == nil then
		return
	end
	local pet = CrateRules.open(save, kind, nextNumber)
	if pet == nil then
		NetService.notice(player, "No crate to open", "warning")
		return
	end
	NetService.fire(player, "CrateOpened", kind, { id = pet.id, kind = pet.kind, star = pet.star })
	local rarity = CrateRules.rarityOf(pet.kind) or "Common"
	local where = if pet.slot == CrateRules.PLAYER_SLOT
		then "on your tips"
		else "when it sits beside you or a helper"
	NetService.notice(
		player,
		`You got {pet.kind}! {rarity}, +{math.floor(
			CrateRules.boost(pet.kind, pet.star) * 100 + 0.5
		)}% {where}`
	)
	PetService.show(player)
end

local function onPlace(player: Player, rawId: unknown, rawSlot: unknown)
	local id = Guard.int(rawId, 1, MAX_PET_ID)
	local save = DataService.get(player)
	if not LiveFlags.isOn(CrateRules.FLAG) or id == nil or save == nil then
		return
	end
	local slot: string? = nil
	if rawSlot ~= nil then
		local text = Guard.text(rawSlot, 16)
		if text == nil or not string.match(text, SLOT_PATTERN) then
			return
		end
		slot = text
	end
	if CrateRules.place(save, id, slot, second(player)) then
		PetService.show(player)
	end
end

local function onFuse(player: Player, rawA: unknown, rawB: unknown, rawC: unknown)
	local save = DataService.get(player)
	local a, b, c =
		Guard.int(rawA, 1, MAX_PET_ID),
		Guard.int(rawB, 1, MAX_PET_ID),
		Guard.int(rawC, 1, MAX_PET_ID)
	if not LiveFlags.isOn(CrateRules.FLAG) or save == nil or a == nil or b == nil or c == nil then
		return
	end
	local fused = CrateRules.fuse(save, { a, b, c })
	if fused == nil then
		NetService.notice(player, "Fuse three of the same pet at the same star", "warning")
		return
	end
	NetService.fire(player, "PetFused", { id = fused.id, kind = fused.kind, star = fused.star })
	NetService.notice(player, `{fused.kind} is star {fused.star}`)
	PetService.show(player)
end

function PetService.Init(_services: { [string]: any }) end

function PetService.Start()
	NetService.on("RequestOpenCrate", { perSecond = 1, burst = 2 }, onOpen)
	NetService.on("RequestPlacePet", { perSecond = 2, burst = 4 }, onPlace)
	NetService.on("RequestFusePets", { perSecond = 1, burst = 2 }, onFuse)
	DataService.onLoaded:Connect(function(player: Player)
		PetService.show(player)
	end)
	-- the Second pet slot bought, found on join, or the passes switch turned either way: the slots follow
	PassService.changed:Connect(function(player: Player, key: string)
		if key == SECOND_PASS then
			PetService.show(player)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Passes.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				PetService.show(player)
			end
		end)
	for _, player in Players:GetPlayers() do
		PetService.show(player)
	end
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CrateRules.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				PetService.show(player)
			end
		end)
end

return PetService
