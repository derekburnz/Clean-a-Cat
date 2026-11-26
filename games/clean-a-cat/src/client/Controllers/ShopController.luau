--!strict
-- ShopController: the shop (UI/ShopWindow, issues 518 and 526), behind the switch passes. It draws the pass cards from
-- the price attributes PassService keeps on ReplicatedStorage (Passes.PRICE_PREFIX .. key, the real Robux price) and
-- the player's own pass attributes (Passes.ATTRIBUTE_PREFIX .. key), and sends RequestPass(key) when a price button
-- is pressed. The server checks the pass and opens Roblox's purchase prompt, which is the player's real confirm;
-- nothing here opens a prompt by itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopViewRules = require(Shared:WaitForChild("ShopViewRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local ShopController = {}

local player = Players.LocalPlayer

local function price(key: string): unknown
	return ReplicatedStorage:GetAttribute(Passes.PRICE_PREFIX .. key)
end

local function owns(key: string): boolean
	return player:GetAttribute(Passes.ATTRIBUTE_PREFIX .. key) == true
end

local function refresh()
	UI.setShop(ShopViewRules.cards(price, owns))
end

function ShopController.Init(_controllers: { [string]: any }) end

function ShopController.Start()
	UI.onShopBuy(function(key: string)
		if LiveFlags.isOn(Passes.FLAG) and Passes.INFO[key] ~= nil and not owns(key) then
			Remotes.event("RequestPass"):FireServer(key)
		end
	end)
	for _, key in Passes.KEYS do
		ReplicatedStorage:GetAttributeChangedSignal(Passes.PRICE_PREFIX .. key):Connect(refresh)
		player:GetAttributeChangedSignal(Passes.ATTRIBUTE_PREFIX .. key):Connect(refresh)
	end
	refresh()
end

return ShopController
