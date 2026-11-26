--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Passes = require(Shared:WaitForChild("Passes"))
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
			end, function(): boolean
				return false
			end)
			expect(#cards).to.equal(#Passes.KEYS)
			for _, card in cards do
				expect(card.icon ~= "Star").to.equal(true)
			end
		end)

		it("writes the price in Robux, never a hurry", function()
			expect(ShopViewRules.priceText(199)).to.equal("199 Robux")
			local low = string.lower(ShopViewRules.EMPTY)
			expect(string.find(low, "hurry", 1, true)).to.equal(nil)
		end)
	end)
end
