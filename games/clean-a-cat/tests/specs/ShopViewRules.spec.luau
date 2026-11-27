--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Passes = require(Shared:WaitForChild("Passes"))
local SaleRules = require(Shared:WaitForChild("SaleRules"))
local ShopViewRules = require(Shared:WaitForChild("ShopViewRules"))

return function()
	describe("ShopViewRules.cards", function()
		it("draws a card only for a pass with a real price, in shop order", function()
			local prices: { [string]: unknown } =
				{ DoubleCoins = 199, Lou = 249, GoldenSponge = 0, SecondBuilder = "299" }
			local cards = ShopViewRules.cards(function(key: string): unknown
				return prices[key]
			end, function(key: string): boolean
				return key == "Lou"
			end)
			expect(#cards).to.equal(2)
			expect(cards[1].key).to.equal("DoubleCoins")
			expect(cards[1].name).to.equal(Passes.INFO.DoubleCoins.name)
			expect(cards[1].badge).to.equal("x2")
			expect(cards[1].price).to.equal(199)
			expect(cards[1].owned).to.equal(false)
			expect(cards[2].key).to.equal("Lou")
			expect(cards[2].owned).to.equal(true)
		end)

		it("has a look for every pass", function()
			local cards = ShopViewRules.cards(function(): unknown
				return 99
			end, function(key: string): boolean
				return key == "DoubleCoins"
			end, function(): boolean
				return true
			end)
			expect(#cards).to.equal(#Passes.KEYS)
			for _, card in cards do
				expect(card.icon ~= "Star").to.equal(true)
			end
		end)

		it("shows 3x Coins only after 2x, and the struck regular price only on a real sale", function()
			local prices: { [string]: number } = { DoubleCoins = 25, TripleCoins = 50, Lou = 249 }
			local function price(key: string): unknown
				return prices[key]
			end
			local function none(_key: string): boolean
				return false
			end
			local function isOn(flag: string): boolean
				return flag == SaleRules.FLAG or flag == Passes.LADDER_FLAG
			end
			local cards = ShopViewRules.cards(price, none, isOn)
			expect(#cards).to.equal(2) -- 2x Coins and Lou; no 3x before 2x is owned
			expect(cards[1].was).to.equal(SaleRules.REGULAR_PASSES.DoubleCoins)
			expect(cards[2].was).to.equal(nil) -- Lou at his regular price: nothing struck
			local owner = ShopViewRules.cards(price, function(key: string): boolean
				return key == "DoubleCoins"
			end, isOn)
			expect(owner[2].key).to.equal("TripleCoins")
			expect(owner[2].badge).to.equal("x3")
			expect(owner[2].was).to.equal(SaleRules.REGULAR_PASSES.TripleCoins)
			local saleOff = ShopViewRules.cards(price, none, function(flag: string): boolean
				return flag == Passes.LADDER_FLAG
			end)
			expect(saleOff[1].was).to.equal(nil)
		end)

		it("writes the price in Robux, never a hurry", function()
			expect(ShopViewRules.priceText(199)).to.equal("199 Robux")
			local low = string.lower(ShopViewRules.EMPTY)
			expect(string.find(low, "hurry", 1, true)).to.equal(nil)
		end)
	end)
end
