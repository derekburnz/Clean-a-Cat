--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarterRules = require(Shared:WaitForChild("StarterRules"))
local StarterViewRules = require(Shared:WaitForChild("StarterViewRules"))

return function()
	local prices: { [string]: number } =
		{ GoldenSponge = 99, SecondPetSlot = 249, DoubleCoins = 199 }
	local function price(key: string): unknown
		return prices[key]
	end

	describe("StarterViewRules items and saving", function()
		it("draws the three passes with their own prices", function()
			local items = StarterViewRules.items(price)
			expect(#items).to.equal(#StarterRules.CONTENTS)
			expect(items[1].key).to.equal(StarterRules.CONTENTS[1])
			expect(items[1].price).to.equal(prices[StarterRules.CONTENTS[1]])
		end)

		it("works the saving out from the live prices", function()
			local total, percent = StarterViewRules.saving(StarterViewRules.items(price), 299)
			expect(total).to.equal(547)
			expect(percent).to.equal(45)
			expect(StarterViewRules.saveText(45)).to.equal("Bundle · save 45%")
			expect(StarterViewRules.buyText(299)).to.equal("299 Robux · Get pack")
		end)

		it("hides the saving when a price is missing or nothing is saved", function()
			local some = StarterViewRules.items(function(key: string): unknown
				return if key == "DoubleCoins" then nil else 100
			end)
			expect(StarterViewRules.saving(some, 50)).to.equal(nil)
			expect(StarterViewRules.saving(StarterViewRules.items(price), nil)).to.equal(nil)
			expect(StarterViewRules.saving(StarterViewRules.items(price), 900)).to.equal(nil)
		end)
	end)

	describe("StarterViewRules clock", function()
		it("keeps the HUD calm: no seconds", function()
			expect(StarterViewRules.hudText(86400 + 20 * 3600 + 14 * 60 + 36)).to.equal("1d 20h")
			expect(StarterViewRules.hudText(5 * 3600 + 12 * 60 + 9)).to.equal("5h 12m")
			expect(StarterViewRules.hudText(12 * 60 + 59)).to.equal("12m")
			expect(StarterViewRules.hudText(20)).to.equal("1m")
		end)

		it("says when the offer ends in the window, never in seconds", function()
			expect(StarterViewRules.windowText(86400 + 20 * 3600 + 14 * 60 + 36)).to.equal(
				"Ends in 1d 20h"
			)
			expect(StarterViewRules.windowText(5 * 3600 + 12 * 60 + 9)).to.equal("Ends in 5h 12m")
			expect(StarterViewRules.windowText(3 * 3600 + 5)).to.equal("Ends in 3h 0m")
			expect(StarterViewRules.left(100, 40)).to.equal(60)
			expect(StarterViewRules.left(100, 400)).to.equal(0)
			expect(StarterViewRules.left(nil, 1)).to.equal(0)
		end)

		it("bobs 3 times on the first visit, once on the next two, then never", function()
			expect(StarterViewRules.bobs(1, false)).to.equal(3)
			expect(StarterViewRules.bobs(2, false)).to.equal(1)
			expect(StarterViewRules.bobs(3, false)).to.equal(1)
			expect(StarterViewRules.bobs(4, false)).to.equal(0)
			expect(StarterViewRules.bobs(1, true)).to.equal(0)
		end)

		it("never hurries", function()
			for _, line in
				{ StarterViewRules.TITLE, StarterViewRules.FINE, StarterViewRules.buyText(1) }
			do
				local low = string.lower(line)
				for _, word in { "hurry", "limited", "72", "now!", "last chance" } do
					expect(string.find(low, word, 1, true)).to.equal(nil)
				end
			end
		end)
	end)
end
