--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local Products = require(Shared:WaitForChild("Products"))
local SaleRules = require(Shared:WaitForChild("SaleRules"))

local function on(flag: string): boolean
	return flag == SaleRules.FLAG
end

local function off(_flag: string): boolean
	return false
end

return function()
	describe("SaleRules", function()
		it("is off by default and has a regular price for every pass and product", function()
			expect(LiveFlags.OFF_BY_DEFAULT[SaleRules.FLAG]).to.equal(true)
			for _, key in Passes.KEYS do
				expect(SaleRules.REGULAR_PASSES[key]).to.be.ok()
			end
			for key in Products.NONE do
				expect(SaleRules.REGULAR_PRODUCTS[key]).to.be.ok()
			end
		end)

		it("halves a price, at least 1 Robux, and the coin ladder lands on 25 and 50", function()
			expect(SaleRules.salePrice(SaleRules.REGULAR_PASSES.DoubleCoins)).to.equal(25)
			expect(SaleRules.salePrice(SaleRules.REGULAR_PASSES.TripleCoins)).to.equal(50)
			expect(SaleRules.salePrice(249)).to.equal(124)
			expect(SaleRules.salePrice(1)).to.equal(1)
		end)

		it("strikes the regular price only with the sale on and the live price really lower", function()
			local regular = SaleRules.REGULAR_PASSES
			expect(SaleRules.was(regular, "DoubleCoins", 25, on)).to.equal(50)
			expect(SaleRules.was(regular, "DoubleCoins", 25, off)).to.equal(nil)
			expect(SaleRules.was(regular, "DoubleCoins", 50, on)).to.equal(nil)
			expect(SaleRules.was(regular, "DoubleCoins", 60, on)).to.equal(nil)
			expect(SaleRules.was(regular, "DoubleCoins", nil, on)).to.equal(nil)
			expect(SaleRules.was(regular, "Nope", 1, on)).to.equal(nil)
			expect(string.find(string.lower(SaleRules.LABEL), "hurry", 1, true)).to.equal(nil)
		end)
	end)
end
