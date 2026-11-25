--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local IndexViewRules = require(Shared:WaitForChild("IndexViewRules"))

return function()
	describe("IndexViewRules.cards", function()
		it("lists every cat, Common first, and hides an unwashed cat's stamps", function()
			local first = CatRules.ROSTER.Common[1]
			local cards =
				IndexViewRules.cards({ [first] = { washed = true, resident = true } }, "All", nil)
			expect(#cards).to.equal(#IndexViewRules.allCats())
			expect(cards[1].cat).to.equal(first)
			expect(cards[1].seen).to.equal(true)
			expect(cards[1].resident).to.equal(true)
			expect(cards[2].seen).to.equal(false)
			expect(cards[#cards].rarity).to.equal("Legendary")
		end)

		it("filters by rarity and marks New! only on washed cats", function()
			local rare = CatRules.ROSTER.Rare
			local cards = IndexViewRules.cards(
				{ [rare[1]] = { washed = true, resident = false } },
				"Rare",
				{ [rare[1]] = true, [rare[2]] = true }
			)
			expect(#cards).to.equal(#rare)
			expect(cards[1].isNew).to.equal(true)
			expect(cards[2].isNew).to.equal(false)
		end)
	end)

	describe("IndexViewRules.progress", function()
		it("counts washed cats out of the roster", function()
			local washed, total = IndexViewRules.progress({
				[CatRules.ROSTER.Common[1]] = { washed = true, resident = false },
				[CatRules.ROSTER.Common[2]] = { washed = false, resident = true },
			})
			expect(washed).to.equal(1)
			expect(total).to.equal(#IndexViewRules.allCats())
		end)
	end)

	describe("IndexViewRules.chanceLine", function()
		it("prints the chance board's number for that rarity and tier", function()
			local chance = CatRules.chancesAt(1).Rare
			expect(IndexViewRules.chanceLine("Rare", 1)).to.equal(
				`Rare cats: {CatRules.percentText(chance)} of customers`
			)
		end)
	end)

	describe("IndexViewRules.newlyWashed", function()
		it("finds cats washed since the last look", function()
			local fresh = IndexViewRules.newlyWashed({
				Muffin = { washed = true, resident = false },
				Tux = { washed = false, resident = true },
			}, {
				Muffin = { washed = true, resident = false },
				Tux = { washed = true, resident = true },
				Inky = { washed = true, resident = false },
			})
			expect(table.concat(fresh, ",")).to.equal("Inky,Tux")
		end)
	end)
end
