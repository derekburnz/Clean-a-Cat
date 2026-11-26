--!strict
-- CrateWindowController: feeds the crate window (UI/CrateWindow, switch crateWindow, issue 526). A tap on the crate by
-- the tub (CrateController.lookInside) opens the window on that crate kind with its chance list (CrateViewRules.rows,
-- from CrateRules.odds), how many the player holds (the server's Crates_<kind> attributes) and which pets they have
-- already (the server's Pets list). Open crate sends RequestOpenCrate; the server rolls the pet and CrateController
-- plays the lid and the reveal. Behind crateWindow and the crates' own switch pets.
--
-- Bought crates (issue 514, switch crateShop): the Robux rows show on the normal crate only while the server sets the
-- Player attribute CrateShop (PolicyService allows paid random items) and the row's ProductPrice_ is known. A press
-- sends RequestBuyCrate(key); the server opens Roblox's purchase prompt, the player's real confirm.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Products = require(Shared:WaitForChild("Products"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local CrateWindowController = {}

local shownKind: string? = nil
local owned: { [string]: boolean } = {}

local function count(kind: string): number
	local raw = Players.LocalPlayer:GetAttribute(CrateRules.CRATE_ATTRIBUTE_PREFIX .. kind)
	return if type(raw) == "number" then math.max(0, math.floor(raw)) else 0
end

local function on(): boolean
	return LiveFlags.isOn(CrateViewRules.FLAG) and LiveFlags.isOn(CrateRules.FLAG)
end

local function canBuy(): boolean
	return on()
		and LiveFlags.isOn(CrateRules.SHOP_FLAG)
		and Players.LocalPlayer:GetAttribute(CrateRules.SHOP_ATTRIBUTE) == true
end

local function productPrice(key: string): unknown
	return ReplicatedStorage:GetAttribute(Products.PRICE_PREFIX .. key)
end

local function refreshShop()
	UI.setCrateShop(CrateViewRules.shopRows(shownKind or "", canBuy(), productPrice))
end

local function refresh()
	local kind = shownKind
	if kind then
		UI.setCrate(kind, count(kind), CrateViewRules.rows(kind, owned))
	end
	refreshShop()
end

local function cleanPets(raw: unknown): { CrateRules.Pet }
	local out: { CrateRules.Pet } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, entry in raw :: { any } do
		if
			type(entry) == "table"
			and type(entry.kind) == "string"
			and type(entry.id) == "number"
		then
			table.insert(out, {
				id = entry.id,
				kind = entry.kind,
				star = if type(entry.star) == "number" then entry.star else 1,
			})
		end
	end
	return out
end

-- Opens the window on crate `kind` (the check in card's chance button for the good crate). False with the switches off.
function CrateWindowController.show(raw: string): boolean
	local kind = CrateRules.cleanKind(raw)
	if kind == nil or not on() then
		return false
	end
	shownKind = kind
	refreshShop()
	UI.showCrate(kind, count(kind), CrateViewRules.rows(kind, owned))
	return true
end

function CrateWindowController.Init(controllers: { [string]: any })
	local crates = controllers.CrateController
	if crates and crates.lookInside then
		crates.lookInside:Connect(function(raw: string)
			CrateWindowController.show(raw)
		end)
	end
end

function CrateWindowController.Start()
	UI.onCrateOpen(function(kind: string)
		if on() and count(kind) > 0 then
			Remotes.event("RequestOpenCrate"):FireServer(kind)
		end
	end)
	UI.onCrateBuy(function(key: string)
		if canBuy() and shownKind == CrateRules.SHOP_KIND and CrateRules.SHOP[key] ~= nil then
			Remotes.event("RequestBuyCrate"):FireServer(key)
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal(CrateRules.SHOP_ATTRIBUTE):Connect(refreshShop)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CrateRules.SHOP_FLAG)
		:Connect(refreshShop)
	for _, key in CrateRules.SHOP_KEYS do
		ReplicatedStorage:GetAttributeChangedSignal(Products.PRICE_PREFIX .. key)
			:Connect(refreshShop)
	end
	for _, kind in CrateRules.KINDS do
		Players.LocalPlayer
			:GetAttributeChangedSignal(CrateRules.CRATE_ATTRIBUTE_PREFIX .. kind)
			:Connect(refresh)
	end
	-- the server sends the whole list once the save loads and again after each change (WorkerController reads it too)
	Remotes.event("Pets").OnClientEvent:Connect(function(raw: unknown)
		owned = CrateViewRules.ownedKinds(cleanPets(raw))
		refresh()
	end)
end

return CrateWindowController
