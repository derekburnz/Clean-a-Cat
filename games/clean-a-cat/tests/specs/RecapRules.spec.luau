--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))

return function()
	describe("RecapRules.isFull", function()
		it("shows the full card while the spa has fewer than FULL_BELOW_STARS stars", function()
			for stars = 0, RecapRules.FULL_BELOW_STARS - 1 do
				expect(RecapRules.isFull(stars, "Common")).to.equal(true)
			end
			expect(RecapRules.isFull(RecapRules.FULL_BELOW_STARS, "Common")).to.equal(false)
			expect(RecapRules.isFull(500, "Uncommon")).to.equal(false)
		end)

		it("always shows the full card from FULL_FROM_RARITY up", function()
			local from = table.find(CatRules.RARITIES, RecapRules.FULL_FROM_RARITY) :: number
			for index, rarity in CatRules.RARITIES do
				expect(RecapRules.isFull(500, rarity)).to.equal(index >= from)
			end
		end)
	end)

	describe("RecapRules.make", function()
		it("copies what the customer paid and works out the rarity and card size", function()
			local cat = CatRules.ROSTER.Rare[1]
			local pay = CatRules.pay(cat)
			local recap = RecapRules.make(cat, pay, 4, 100, true)
			expect(recap.cat).to.equal(cat)
			expect(recap.rarity).to.equal("Rare")
			expect(recap.coins).to.equal(pay.coins)
			expect(recap.tip).to.equal(pay.tip)
			expect(recap.bonus).to.equal(4)
			expect(recap.stars).to.equal(pay.stars)
			expect(recap.isNew).to.equal(true)
			expect(recap.full).to.equal(true)
			expect(RecapRules.total(recap)).to.equal(pay.coins + pay.tip + 4)
		end)
	end)

	describe("RecapRules.rows", function()
		it("lists wash, tip and bonus in order and leaves out a row worth 0", function()
			local cat = CatRules.ROSTER.Common[1]
			local recap = RecapRules.make(cat, CatRules.pay(cat), 0, 10, false)
			local rows = RecapRules.rows(recap)
			expect(#rows).to.equal(2)
			expect(rows[1].key).to.equal("wash")
			expect(rows[2].key).to.equal("tip")
			recap.bonus = 3
			rows = RecapRules.rows(recap)
			expect(#rows).to.equal(3)
			expect(rows[3].key).to.equal("bonus")
			expect(rows[3].value).to.equal(3)
		end)
	end)

	describe("RecapRules.clean", function()
		it("keeps a recap the server made", function()
			local cat = CatRules.ROSTER.Common[1]
			local recap = RecapRules.make(cat, CatRules.pay(cat), 2, 0, true)
			local cleaned = RecapRules.clean(recap)
			expect(cleaned).to.be.ok()
			local c = cleaned :: RecapRules.Recap
			expect(c.cat).to.equal(cat)
			expect(c.bonus).to.equal(2)
			expect(c.full).to.equal(true)
			expect(c.isNew).to.equal(true)
		end)

		it("refuses anything malformed", function()
			local good =
				{ cat = "Muffin", rarity = "Common", coins = 10, tip = 2, bonus = 0, stars = 1 }
			expect(RecapRules.clean(nil)).to.equal(nil)
			expect(RecapRules.clean("Muffin")).to.equal(nil)
			local function with(key: string, value: any): any
				local copy = table.clone(good) :: { [string]: any }
				copy[key] = value
				return copy
			end
			expect(RecapRules.clean(with("cat", ""))).to.equal(nil)
			expect(RecapRules.clean(with("cat", string.rep("a", 40)))).to.equal(nil)
			expect(RecapRules.clean(with("rarity", "Mythic"))).to.equal(nil)
			expect(RecapRules.clean(with("coins", -1))).to.equal(nil)
			expect(RecapRules.clean(with("coins", 0 / 0))).to.equal(nil)
			expect(RecapRules.clean(with("tip", "2"))).to.equal(nil)
			expect(RecapRules.clean(with("stars", 1000))).to.equal(nil)
			expect(RecapRules.clean(with("bonus", nil))).to.equal(nil)
			expect(RecapRules.clean(good)).to.be.ok()
		end)
	end)
end
