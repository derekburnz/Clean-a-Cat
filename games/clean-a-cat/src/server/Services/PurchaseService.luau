--!strict
-- PurchaseService: the one owner of MarketplaceService.ProcessReceipt, Roblox's callback for developer products
-- (Robux buys a player can make again). Setting ProcessReceipt anywhere else would silently replace this one, so
-- every product goes through here. Products and their ids are in shared/Products.
--
--   PurchaseService.register(key, grant)   grant(player, save, receipt) changes the save and returns true once the
--                                          product is given; false (or an error) means "not yet", and Roblox asks
--                                          again later. It must check before it changes anything, and not yield
--   PurchaseService.prompt(player, key)    opens Roblox's purchase prompt; false when the product is not created or
--                                          its price is not known yet (the button should not have shown)
--   PurchaseService.priced(key)            true when the product is created and its price is known
--   PurchaseService.closed:Connect(fn)     fn(player, key, bought) when the player closes that prompt
--
-- A receipt is granted once: its PurchaseId goes into save.receipts with the grant, and Roblox hears PurchaseGranted
-- only after a write that holds it has landed (DataService.saveAndConfirm). When anything is unsure the answer is
-- NotProcessedYet: the purchase stays open and Roblox sends it again when the player next joins; it is never lost
-- that way. A repeat of a receipt already in the save is answered from the save without granting again.
--
-- Each product's price, set by the owner on Roblox, is read with GetProductInfo into the ReplicatedStorage attribute
-- Products.PRICE_PREFIX .. key, for the buttons. Not behind a switch itself: each product's own feature is, and a
-- product with id 0 (not created) can never be prompted.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Products"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local Signal = require(Shared:WaitForChild("Signal"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local LikeAskService = require(script.Parent:WaitForChild("LikeAskService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

export type Grant = (player: Player, save: SaveSchema.Save, receipt: { [string]: any }) -> boolean

local SAVE_WAIT = 15 -- seconds a receipt waits for the player's save to load
local CONFIRM_WAIT = 20 -- seconds it waits for the write that holds the grant
local PRICE_RETRY = 60 -- seconds between tries at reading a price Roblox did not give

local PurchaseService = {}

PurchaseService.closed = Signal.new() :: Signal.Signal<Player, string, boolean>

local grants: { [string]: Grant } = {}

function PurchaseService.register(key: string, grant: Grant)
	assert(Products.IDS[key] ~= nil, `PurchaseService: {key} is not in shared/Products`)
	assert(grants[key] == nil, `PurchaseService: {key} is registered twice`)
	grants[key] = grant
end

local function priceOf(key: string): number?
	local price = ReplicatedStorage:GetAttribute(Products.PRICE_PREFIX .. key)
	return if type(price) == "number" and price > 0 then price else nil
end

function PurchaseService.priced(key: string): boolean
	return Products.id(key) ~= nil and priceOf(key) ~= nil
end

function PurchaseService.prompt(player: Player, key: string): boolean
	local id = Products.id(key)
	if id == nil or priceOf(key) == nil or grants[key] == nil then
		return false
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, id)
	end)
	if not ok then
		warn(`PurchaseService: prompt for {key} failed: {err}`)
		return false
	end
	Telemetry.event(player, "purchase_step", 1, { key, "prompt" })
	return true
end

local function waitForSave(player: Player): SaveSchema.Save?
	local deadline = os.clock() + SAVE_WAIT
	local save = DataService.get(player)
	while save == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.5)
		save = DataService.get(player)
	end
	return save
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local productId = receipt.ProductId
	local key = if type(productId) == "number" then Products.keyOf(productId) else nil
	local grant = if key then grants[key] else nil
	if key == nil or grant == nil then
		warn(`PurchaseService: no grant for product {productId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- sent again when they next join
	end
	local save = waitForSave(player)
	if save == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(save.receipts, purchaseId) == nil then
		local ok, granted = pcall(grant, player, save, receipt)
		if not ok or granted ~= true then
			if not ok then
				warn(`PurchaseService: grant for {key} failed: {granted}`)
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(save.receipts, purchaseId)
		while #save.receipts > SaveSchema.RECEIPTS_KEPT do
			table.remove(save.receipts, 1)
		end
		Telemetry.event(player, "purchase_step", 1, { key, "granted" })
		LikeAskService.moment(player, "purchase") -- (likeAsk) two minutes later, off the purchase screen
	end
	local stored = DataService.saveAndConfirm(player, function(saved)
		local receipts = saved.receipts
		return type(receipts) == "table" and table.find(receipts, purchaseId) ~= nil
	end, CONFIRM_WAIT)
	return if stored
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Reads every created product's price into its attribute, trying again later for any Roblox did not give.
local function readPrices()
	while true do
		local missing = false
		for key in Products.IDS do
			local id = Products.id(key)
			if id == nil or priceOf(key) ~= nil then
				continue
			end
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
			end)
			local price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
			if type(price) == "number" and price > 0 then
				ReplicatedStorage:SetAttribute(Products.PRICE_PREFIX .. key, price)
			else
				missing = true
			end
		end
		if not missing then
			return
		end
		task.wait(PRICE_RETRY)
	end
end

function PurchaseService.Init(_services: { [string]: any }) end

function PurchaseService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, bought: boolean)
			local player = Players:GetPlayerByUserId(userId)
			local key = Products.keyOf(productId)
			if player == nil or key == nil then
				return
			end
			if not bought then
				Telemetry.event(player, "purchase_step", 1, { key, "cancelled" })
				LikeAskService.bad(player)
			end
			PurchaseService.closed:Fire(player, key, bought)
		end
	)
	task.spawn(readPrices)
end

return PurchaseService
