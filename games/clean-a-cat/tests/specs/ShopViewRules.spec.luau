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
			expect(cards[1].icon).to.equal("ShopCoins2x") -- the x2 is in the picture
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
			expect(#cards).to.equal(Passes.SHOP_CARDS)
			for _, card in cards do
				expect(card.icon ~= "Star").to.equal(true)
			end
		end)

		it(
			"shows 3x Coins only after 2x, and the struck regular price only on a real sale",
			function()
				local prices: { [string]: number } =
					{ DoubleCoins = 25, TripleCoins = 50, Lou = 249 }
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
				expect(#owner).to.equal(2) -- 3x in 2x's place, and Lou
				expect(owner[1].key).to.equal("TripleCoins")
				expect(owner[1].icon).to.equal("ShopCoins3x")
				expect(owner[1].was).to.equal(SaleRules.REGULAR_PASSES.TripleCoins)
				local saleOff = ShopViewRules.cards(price, none, function(flag: string): boolean
					return flag == Passes.LADDER_FLAG
				end)
				expect(saleOff[1].was).to.equal(nil)
			end
		)

		it(
			"features the best pass not owned, then the rest with the owned ones last (shopRevamp, issue 1030)",
			function()
				local function card(key: string, owned: boolean): ShopViewRules.Card
					return {
						key = key,
						name = key,
						text = "",
						icon = "Star",
						price = 1,
						owned = owned,
					}
				end
				local featured, rest = ShopViewRules.arrange({
					card("DoubleCoins", true),
					card("SecondBuilder", false),
					card("GoldenSponge", false),
					card("Lou", true),
					card("SecondPetSlot", false),
				})
				expect(featured and featured.key).to.equal("SecondBuilder")
				expect(#rest).to.equal(4)
				expect(rest[1].key).to.equal("GoldenSponge")
				expect(rest[3].key).to.equal("DoubleCoins")
				expect(rest[4].key).to.equal("Lou")
				local none, all = ShopViewRules.arrange({ card("Lou", true) })
				expect(none).to.equal(nil)
				expect(#all).to.equal(1)
				for _, line in ShopViewRules.LINE do
					expect(#line <= 16).to.equal(true) -- one short line on the smallest phone card
				end
			end
		)

		it("writes the price in Robux, never a hurry", function()
			expect(ShopViewRules.priceText(199)).to.equal("199 Robux")
			local low = string.lower(ShopViewRules.EMPTY)
			expect(string.find(low, "hurry", 1, true)).to.equal(nil)
		end)
	end)
end
