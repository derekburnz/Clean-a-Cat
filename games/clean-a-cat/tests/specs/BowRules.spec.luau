--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BowRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BowRules"))

type Save = { coins: number, bows: { [string]: boolean }, bow: string }

local function newSave(coins: number): Save
	return { coins = coins, bows = {}, bow = "Ribbon" }
end

return function()
	describe("BowRules", function()
		it("has tuning section 5's prices and bonuses", function()
			expect(BowRules.TIER.Ribbon.price).to.equal(0)
			expect(BowRules.TIER.Ribbon.bonus).to.equal(2)
			expect(BowRules.TIER.Silk.price).to.equal(150)
			expect(BowRules.TIER.Silk.bonus).to.equal(4)
			expect(BowRules.TIER.Satin.price).to.equal(600)
			expect(BowRules.TIER.Satin.bonus).to.equal(7)
			expect(BowRules.TIER.Golden.price).to.equal(2000)
			expect(BowRules.TIER.Golden.bonus).to.equal(12)
		end)

		it("gives everyone the Ribbon and sells the rest in order", function()
			local save = newSave(10_000)
			expect(BowRules.owns(save.bows, "Ribbon")).to.equal(true)
			expect(BowRules.nextTier(save.bows)).to.equal("Silk")
			expect((BowRules.canBuy(save, "Satin"))).to.equal(false)
			expect((BowRules.canBuy(save, "Ribbon"))).to.equal(false)
			expect(BowRules.buy(save, "Silk")).to.equal(150)
			expect(save.coins).to.equal(10_000 - 150)
			expect(save.bow).to.equal("Silk")
			expect(BowRules.buy(save, "Silk")).to.equal(0) -- never sold twice
			expect(BowRules.buy(save, "Satin")).to.equal(600)
			expect(BowRules.buy(save, "Golden")).to.equal(2000)
			expect(BowRules.nextTier(save.bows)).to.equal(nil)
			expect(save.bow).to.equal("Golden")
		end)

		it("refuses a tier the coins do not cover and takes nothing", function()
			local save = newSave(149)
			local ok, reason = BowRules.canBuy(save, "Silk")
			expect(ok).to.equal(false)
			expect(reason).to.equal("1 more coins for the Silk bow")
			expect(BowRules.buy(save, "Silk")).to.equal(0)
			expect(save.coins).to.equal(149)
			expect(save.bows.Silk).to.equal(nil)
		end)

		it("refuses a made up tier", function()
			expect(BowRules.clean("Diamond")).to.equal(nil)
			expect(BowRules.clean(3)).to.equal(nil)
			expect((BowRules.canBuy(newSave(99_999), "Diamond"))).to.equal(false)
		end)

		it("pays the Ribbon's bonus for an unknown tier", function()
			expect(BowRules.bonus(nil)).to.equal(2)
			expect(BowRules.bonus("nope")).to.equal(2)
			expect(BowRules.bonus("Satin")).to.equal(7)
		end)

		it("names the worn bow's look from the colour and the tier", function()
			expect(BowRules.lookId("BowPink", "Ribbon")).to.equal("BowPink")
			expect(BowRules.lookId("BowMint", "Silk")).to.equal("BowMintDouble")
			expect(BowRules.lookId("BowSky", "Satin")).to.equal("BowSkyRoyal")
			expect(BowRules.lookId("BowSky", nil)).to.equal("BowSky")
		end)
	end)
end
