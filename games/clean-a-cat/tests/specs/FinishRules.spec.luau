--!strict
return function()
	local FinishRules = require(game:GetService("ReplicatedStorage").Shared.FinishRules)
	local Products = require(game:GetService("ReplicatedStorage").Shared.Products)

	local function state(): FinishRules.State
		return { stations = {}, builds = {} }
	end

	describe("FinishRules.tier", function()
		it("prices by the time left and shows nothing under 15 seconds", function()
			expect(FinishRules.tier(14)).to.equal(nil)
			expect(FinishRules.tier(0 / 0)).to.equal(nil)
			expect(FinishRules.tier(15)).to.equal(1)
			expect(FinishRules.tier(120)).to.equal(1)
			expect(FinishRules.tier(121)).to.equal(2)
			expect(FinishRules.tier(3600)).to.equal(2)
			expect(FinishRules.tier(3601)).to.equal(3)
			expect(FinishRules.tier(4 * 3600)).to.equal(3)
			expect(FinishRules.tier(12 * 3600)).to.equal(4)
			expect(FinishRules.tier(12 * 3600 + 1)).to.equal(5)
			expect(FinishRules.tier(24 * 3600)).to.equal(5)
		end)

		it("has the design's prices and a product key for each tier", function()
			local prices = {}
			for index, tier in FinishRules.TIERS do
				table.insert(prices, tier.robux)
				expect(FinishRules.tierOfKey(tier.key)).to.equal(index)
				expect(Products.IDS[tier.key]).to.be.ok()
			end
			expect(table.concat(prices, ",")).to.equal("5,15,35,75,99")
		end)
	end)

	describe("FinishRules credits", function()
		it("drops damaged entries and spends the cheapest credit that covers", function()
			local credits =
				FinishRules.cleanCredits({ ["2"] = 1, ["4"] = 2.7, ["5"] = 0 / 0, x = 3 })
			expect(credits["2"]).to.equal(1)
			expect(credits["4"]).to.equal(2)
			expect(credits["5"]).to.equal(nil)
			expect(credits.x).to.equal(nil)
			expect(FinishRules.creditFor(credits, 1)).to.equal(2)
			expect(FinishRules.creditFor(credits, 2)).to.equal(2)
			expect(FinishRules.creditFor(credits, 3)).to.equal(4)
			expect(FinishRules.creditFor(credits, 5)).to.equal(nil)
			-- a dear credit never goes on a cheap finish: tier 4 covers tiers 3 and 4 only
			expect(FinishRules.creditFor({ ["4"] = 1 }, 2)).to.equal(nil)
			expect(FinishRules.creditFor({ ["5"] = 1 }, 1)).to.equal(nil)
			expect(FinishRules.spendCredit(credits, 2)).to.equal(true)
			expect(credits["2"]).to.equal(nil)
			expect(FinishRules.spendCredit(credits, 2)).to.equal(false)
			FinishRules.addCredit(credits, 5)
			expect(FinishRules.creditFor(credits, 5)).to.equal(5)
		end)
	end)

	describe("FinishRules.target and finish", function()
		it("finishes the asked build, or any build the tier covers", function()
			local s = state()
			s.builds.station = { item = "ThirdTub", endsAt = 1000 + 600 } -- 10 min left: tier 2
			expect(FinishRules.target(s, 1000, 2, "station")).to.equal("station")
			expect(FinishRules.target(s, 1000, 1, "station")).to.equal(nil) -- paid too little
			expect(FinishRules.target(s, 1000, 2, "room")).to.equal("station") -- asked slot is empty
			expect(FinishRules.target(s, 1590, 2, nil)).to.equal("station") -- under 15 s left now: still finished
			expect(FinishRules.target(s, 1600, 2, nil)).to.equal(nil) -- ended on its own: a credit
			expect(FinishRules.finish(s, "station")).to.equal("ThirdTub")
			expect(s.stations.ThirdTub).to.equal(true)
			expect(s.builds.station).to.equal(nil)
			expect(FinishRules.finish(s, "station")).to.equal(nil)
		end)
	end)

	describe("Products", function()
		it("hides a product that is not created", function()
			expect(Products.id("FinishTier1")).to.equal(
				if Products.IDS.FinishTier1 > 0 then Products.IDS.FinishTier1 else nil
			)
			expect(Products.id("Nope")).to.equal(nil)
			expect(Products.keyOf(0)).to.equal(nil)
		end)
	end)
end
