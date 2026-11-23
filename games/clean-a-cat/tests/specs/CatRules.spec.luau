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
