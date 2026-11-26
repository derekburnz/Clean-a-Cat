--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local DirtRules = require(Shared:WaitForChild("DirtRules"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))
local SpecialRules = require(Shared:WaitForChild("SpecialRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local function always(value: number): () -> number
	return function()
		return value
	end
end

return function()
	describe("SpecialRules", function()
		it("brings the first visitor at 4:00 of play, never right at a join", function()
			expect(SpecialRules.dueAt(10, 0, false, always(0))).to.equal(240)
			expect(SpecialRules.dueAt(500, 480, false, always(0))).to.equal(510)
		end)

		it("brings later ones 8 to 15 minutes of play after the last", function()
			expect(SpecialRules.dueAt(1000, 0, true, always(0))).to.equal(1000 + 480)
			expect(SpecialRules.dueAt(1000, 0, true, always(0.999999)) < 1000 + 900 + 0.01).to.equal(
				true
			)
		end)

		it("always gives the first visitor's crate, then about one in twenty", function()
			expect(SpecialRules.dropsCrate(false, always(0.99))).to.equal(true)
			expect(SpecialRules.dropsCrate(true, always(0.04))).to.equal(true)
			expect(SpecialRules.dropsCrate(true, always(0.05))).to.equal(false)
		end)

		it("picks only special cats, each with the same visitor", function()
			for _, value in { 0, 0.3, 0.6, 0.9999 } do
				local cat = SpecialRules.pickCat(always(value))
				expect(CatRules.isSpecial(cat)).to.equal(true)
				expect(table.find(SpecialRules.LOOKS, SpecialRules.lookFor(cat)) ~= nil).to.equal(
					true
				)
			end
			expect(SpecialRules.lookFor("Bathtile")).to.equal(SpecialRules.lookFor("Bathtile"))
		end)
	end)

	describe("Special cats in the shared rules", function()
		it("are their own rarity, rarest, outside the rolls and the main index", function()
			local cat = CatRules.SPECIAL_CATS[1]
			expect(CatRules.rarityOf(cat)).to.equal(CatRules.SPECIAL)
			expect(table.find(CatRules.RARITIES, CatRules.SPECIAL)).to.equal(nil)
			expect(CatRules.rank(CatRules.SPECIAL)).to.equal(#CatRules.ALL_RARITIES)
			for _, rarity in CatRules.RARITIES do
				expect(table.find(CatRules.ROSTER[rarity], cat)).to.equal(nil)
			end
		end)

		it("pay the most, always at dirt level 4", function()
			local cat = CatRules.SPECIAL_CATS[1]
			expect(CatRules.pay(cat).coins).to.equal(120)
			expect(CatRules.pay(cat).tip).to.equal(20)
			expect(DirtRules.roll(cat, always(0))).to.equal(DirtRules.SPECIAL_LEVEL)
		end)

		it("get the full recap card, which survives the client's check", function()
			local cat = CatRules.SPECIAL_CATS[2]
			local recap = RecapRules.make(cat, CatRules.pay(cat), 0, 100, true)
			expect(recap.full).to.equal(true)
			expect(recap.rarity).to.equal(CatRules.SPECIAL)
			expect(RecapRules.clean(recap)).to.be.ok()
		end)

		it("are never taken by a worker in any mode", function()
			-- SpaService marks a visitor's place reserved in the line the workers see
			local line: { WorkerRules.Entry } = {
				{ kind = CatRules.SPECIAL_CATS[1], dirt = 4, left = 0.05, reserved = true },
			}
			for _, mode in WorkerRules.MODES do
				expect(WorkerRules.pick(mode, line)).to.equal(nil)
			end
		end)
	end)
end
