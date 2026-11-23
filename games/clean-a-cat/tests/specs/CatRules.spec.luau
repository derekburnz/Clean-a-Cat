--!strict
return function()
	local CatRules = require(game:GetService("ReplicatedStorage").Shared.CatRules)

	-- A fake random that returns the given values in order.
	local function sequence(values: { number }): () -> number
		local i = 0
		return function()
			i += 1
			return values[i] or 0
		end
	end

	describe("CatRules tables", function()
		it("has chances that sum to 100 and a cat and a pay for every rarity", function()
			local sum = 0
			for _, rarity in CatRules.RARITIES do
				sum += CatRules.CHANCES[rarity]
				expect(#CatRules.ROSTER[rarity] > 0).to.equal(true)
				expect(CatRules.PAY[rarity]).to.be.ok()
			end
			expect(sum).to.be.near(100, 1e-9)
		end)

		it("has ten different cats", function()
			local seen = {}
			local count = 0
			for _, rarity in CatRules.RARITIES do
				for _, name in CatRules.ROSTER[rarity] do
					expect(seen[name]).to.equal(nil)
					seen[name] = true
					count += 1
					expect(CatRules.rarityOf(name)).to.equal(rarity)
				end
			end
			expect(count).to.equal(10)
		end)
	end)

	describe("CatRules.roll", function()
		it("gives the first customer a common cat whatever the roll", function()
			for _, r in { 0, 0.5, 0.999 } do
				local name = CatRules.roll(sequence({ 0.999, r }), true)
				expect(CatRules.rarityOf(name)).to.equal("Common")
			end
		end)

		it("follows the chance table at its edges", function()
			expect(CatRules.rarityOf(CatRules.roll(sequence({ 0, 0 }), false))).to.equal("Common")
			expect(CatRules.rarityOf(CatRules.roll(sequence({ 0.599, 0 }), false))).to.equal(
				"Common"
			)
			expect(CatRules.rarityOf(CatRules.roll(sequence({ 0.6, 0 }), false))).to.equal(
				"Uncommon"
			)
			expect(CatRules.rarityOf(CatRules.roll(sequence({ 0.85, 0 }), false))).to.equal("Rare")
			expect(CatRules.rarityOf(CatRules.roll(sequence({ 0.96, 0 }), false))).to.equal("Epic")
			expect(CatRules.rarityOf(CatRules.roll(sequence({ 0.9951, 0.99 }), false))).to.equal(
				"Legendary"
			)
		end)

		it("matches the shown chances over many rolls", function()
			local rng = Random.new(7)
			local counts: { [string]: number } = {}
			local n = 20000
			for _ = 1, n do
				local rarity = CatRules.rarityOf(CatRules.roll(function()
					return rng:NextNumber()
				end, false)) :: string
				counts[rarity] = (counts[rarity] or 0) + 1
			end
			for _, rarity in CatRules.RARITIES do
				local share = 100 * (counts[rarity] or 0) / n
				expect(math.abs(share - CatRules.CHANCES[rarity]) < 1.5).to.equal(true)
			end
		end)
	end)

	describe("CatRules.boardLines", function()
		it("shows exactly the chances and cats the roll uses, summing to 100", function()
			local sum = 0
			local lines = CatRules.boardLines()
			expect(#lines).to.equal(#CatRules.RARITIES)
			for i, line in lines do
				expect(line.rarity).to.equal(CatRules.RARITIES[i])
				expect(line.percent).to.equal(CatRules.CHANCES[line.rarity])
				expect(#line.cats).to.equal(#CatRules.ROSTER[line.rarity])
				sum += line.percent
			end
			expect(sum).to.be.near(100, 1e-9)
			expect(CatRules.percentText(60)).to.equal("60%")
			expect(CatRules.percentText(3.5)).to.equal("3.5%")
			expect(CatRules.percentText(0.5)).to.equal("0.5%")
		end)
	end)

	describe("CatRules star tiers", function()
		it("starts each tier at its stars", function()
			expect(CatRules.tierFor(0)).to.equal(1)
			expect(CatRules.tierFor(CatRules.TIERS[2].stars - 1)).to.equal(1)
			expect(CatRules.tierFor(CatRules.TIERS[2].stars)).to.equal(2)
			expect(CatRules.tierFor(10 ^ 6)).to.equal(#CatRules.TIERS)
			expect(CatRules.tierFor(0 / 0)).to.equal(1)
			expect(CatRules.nextTierStars(1)).to.equal(CatRules.TIERS[2].stars)
			expect(CatRules.nextTierStars(#CatRules.TIERS)).to.equal(nil)
		end)

		it("sums to 100 at every tier and never lowers a rarer chance", function()
			for index, tier in CatRules.TIERS do
				local sum = 0
				for _, rarity in CatRules.RARITIES do
					sum += tier.chances[rarity]
				end
				expect(sum).to.be.near(100, 1e-9)
				local before = CatRules.TIERS[index - 1]
				if before then
					expect(tier.stars > before.stars).to.equal(true)
					for _, rarity in CatRules.RARITIES do
						if rarity ~= "Common" then
							expect(tier.chances[rarity] >= before.chances[rarity]).to.equal(true)
						end
					end
				end
			end
		end)

		it("shows on the board exactly the table the roll uses, at every tier", function()
			for tier in CatRules.TIERS do
				local lines = CatRules.boardLines(tier)
				local edge = 0
				for i, line in lines do
					expect(line.rarity).to.equal(CatRules.RARITIES[i])
					expect(line.percent).to.equal(CatRules.chancesAt(tier)[line.rarity])
					-- A roll just inside this line's share lands on this rarity.
					local pick = (edge + line.percent / 2) / 100
					local name = CatRules.roll(sequence({ pick, 0 }), false, tier)
					expect(CatRules.rarityOf(name)).to.equal(line.rarity)
					edge += line.percent
				end
			end
		end)

		it("reads a tier from an attribute safely", function()
			expect(CatRules.cleanTier(2)).to.equal(2)
			expect(CatRules.cleanTier(1.5)).to.equal(1)
			expect(CatRules.cleanTier(99)).to.equal(1)
			expect(CatRules.cleanTier("2")).to.equal(1)
			expect(CatRules.cleanTier(nil)).to.equal(1)
		end)
	end)

	describe("CatRules needs and pay", function()
		it("gives rarer cats more needs and locks the dryer until it is built", function()
			expect(#CatRules.needs("Smudge")).to.equal(2)
			local needs = CatRules.needs("Starcoat")
			expect(#needs).to.equal(3)
			local locked = CatRules.lockedNeeds(needs, {})
			expect(#locked).to.equal(1)
			expect(locked[1]).to.equal("wet")
			expect(#CatRules.lockedNeeds(needs, { Dryer = true })).to.equal(0)
		end)

		it("pays more for rarer cats and like a common for an unknown name", function()
			expect(CatRules.pay("Starcoat").coins > CatRules.pay("Smudge").coins).to.equal(true)
			expect(CatRules.pay("Nobody").coins).to.equal(CatRules.PAY.Common.coins)
		end)
	end)
end
