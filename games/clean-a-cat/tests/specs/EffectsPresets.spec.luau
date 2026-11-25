--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local PresetData = require(Effects:WaitForChild("Presets")) :: any
	local Tier = require(Effects:WaitForChild("Tier")) :: any

	local FIELDS = {
		"texture",
		"color",
		"size",
		"transparency",
		"lifetime",
		"speed",
		"spread",
		"acceleration",
		"drag",
		"lightEmission",
		"maxRate",
		"burst",
	}

	describe("Presets", function()
		it("has the same presets in both tiers", function()
			for name in PresetData.emitters.low do
				expect(PresetData.emitters.high[name] ~= nil).to.equal(true)
			end
			for name in PresetData.emitters.high do
				expect(PresetData.emitters.low[name] ~= nil).to.equal(true)
			end
		end)

		it("has every field in every preset of every tier", function()
			for _, presets in PresetData.emitters do
				for _, preset in presets do
					for _, field in FIELDS do
						expect(preset[field] ~= nil).to.equal(true)
					end
				end
			end
		end)

		it("caps Highlights per tier", function()
			expect(PresetData.budgets.low.maxHighlights).to.equal(2)
			expect(PresetData.budgets.high.maxHighlights <= 4).to.equal(true)
		end)

		it("keeps every preset inside its tier's budget", function()
			for tierName, presets in PresetData.emitters do
				local budget = PresetData.budgets[tierName]
				for _, preset in presets do
					expect(preset.maxRate <= budget.maxRate).to.equal(true)
					expect(preset.burst <= budget.maxBurst).to.equal(true)
					expect(preset.lifetime[2] <= budget.maxLifetime).to.equal(true)
					expect(preset.lifetime[1] <= preset.lifetime[2]).to.equal(true)
				end
			end
		end)
	end)

	describe("Tier", function()
		it("picks low on touch-only devices and low graphics", function()
			expect(Tier.pick(true, false, 0)).to.equal("low")
			expect(Tier.pick(false, true, 2)).to.equal("low")
			expect(Tier.pick(false, true, 0)).to.equal("high")
			expect(Tier.pick(true, true, 8)).to.equal("high")
		end)

		it("scales the foam rate with drag speed and halves it for Reduce Motion", function()
			expect(Tier.foamRate(8, 0, 30, false)).to.equal(0)
			expect(Tier.foamRate(8, 15, 30, false)).to.equal(4)
			expect(Tier.foamRate(8, 300, 30, false)).to.equal(8)
			expect(Tier.foamRate(8, 300, 30, true)).to.equal(4)
		end)

		it("halves bursts for Reduce Motion but never to zero", function()
			expect(Tier.burst(6, false)).to.equal(6)
			expect(Tier.burst(6, true)).to.equal(3)
			expect(Tier.burst(1, true)).to.equal(1)
		end)
	end)
end
