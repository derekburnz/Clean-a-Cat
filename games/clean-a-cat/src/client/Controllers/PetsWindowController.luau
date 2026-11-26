--!strict
-- PetsWindowController: feeds the pets window (UI/PetsWindow, switch petsWindow, issue 526) from the server's Pets
-- list and the hired helpers (the WorkerLevel_<id> Player attributes), and sends what the player picks there:
-- RequestPlacePet(id, slot or nil) and RequestFusePets(a, b, c). The server checks every id and slot (PetService).
-- Behind petsWindow and the pets' own switch pets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local PetsWindowController = {}

local pets: { CrateRules.Pet } = {}

local function on(): boolean
	return LiveFlags.isOn(CrateViewRules.PETS_FLAG) and LiveFlags.isOn(CrateRules.FLAG)
end

local function hired(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, id in CrateViewRules.HELPERS do
		if Players.LocalPlayer:GetAttribute(`WorkerLevel_{id}`) ~= nil then
			out[id] = true
		end
	end
	return out
end

local SECOND_SLOT = Passes.ATTRIBUTE_PREFIX .. "SecondPetSlot"

-- The Second pet slot pass counts only with the passes switch on (PassService's own check).
local function second(): boolean
	return LiveFlags.isOn(Passes.FLAG) and Players.LocalPlayer:GetAttribute(SECOND_SLOT) == true
end

local function show()
	UI.setPets(pets, hired(), second())
end

local function cleanPets(raw: unknown): { CrateRules.Pet }
	local out: { CrateRules.Pet } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, entry in raw :: { any } do
		if
			type(entry) == "table"
			and type(entry.id) == "number"
			and type(entry.kind) == "string"
			and type(entry.star) == "number"
		then
			table.insert(out, {
				id = entry.id,
				kind = entry.kind,
				star = entry.star,
				slot = if type(entry.slot) == "string" then entry.slot else nil,
			})
		end
	end
	return out
end

function PetsWindowController.Init(_controllers: { [string]: any }) end

function PetsWindowController.Start()
	UI.onPetPlace(function(id: number, slot: string?)
		if on() then
			Remotes.event("RequestPlacePet"):FireServer(id, slot)
		end
	end)
	UI.onPetFuse(function(ids: { number })
		if on() and #ids == CrateRules.FUSE_COUNT then
			Remotes.event("RequestFusePets"):FireServer(ids[1], ids[2], ids[3])
		end
	end)
	for _, id in CrateViewRules.HELPERS do
		Players.LocalPlayer:GetAttributeChangedSignal(`WorkerLevel_{id}`):Connect(show)
	end
	Players.LocalPlayer:GetAttributeChangedSignal(SECOND_SLOT):Connect(show)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Passes.FLAG)
		:Connect(show)
	-- the server sends the whole list once the save loads and again after each change
	Remotes.event("Pets").OnClientEvent:Connect(function(raw: unknown)
		pets = cleanPets(raw)
		show()
	end)
	show()
end

return PetsWindowController
