--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))

return function()
	describe("CrateViewRules.rows", function()
		it("lists every pet in the crate with the chance the roll uses", function()
			for _, kind in CrateRules.KINDS do
				local rows = CrateViewRules.rows(kind, {})
				local odds = CrateRules.odds(kind)
				expect(#rows).to.equal(#odds)
				for index, row in rows do
					expect(row.pet).to.equal(odds[index].pet)
					expect(row.chance).to.equal(CrateViewRules.percentText(odds[index].percent))
				end
				expect(math.abs(CrateViewRules.total(kind) - 100) < 0.001).to.equal(true)
			end
		end)

		it("writes the normal crate's numbers as tuning.md has them", function()
			local rows = CrateViewRules.rows("normal", { Cozy = true })
			expect(rows[1].pet).to.equal("Cozy")
			expect(rows[1].chance).to.equal("25%")
			expect(rows[1].boost).to.equal("+5%")
			expect(rows[1].owned).to.equal(true)
			expect(rows[2].owned).to.equal(false)
			expect(rows[#rows].rarity).to.equal("Legendary")
			expect(rows[#rows].chance).to.equal("2%")
			expect(rows[#rows].boost).to.equal("+20%")
		end)
	end)

	describe("CrateViewRules text", function()
		it("writes whole percents plain and others to one place", function()
			expect(CrateViewRules.percentText(25)).to.equal("25%")
			expect(CrateViewRules.percentText(12.5)).to.equal("12.5%")
			expect(CrateViewRules.percentText(6.666)).to.equal("6.7%")
		end)

		it("names the crate and counts what the player holds", function()
			expect(CrateViewRules.title("good")).to.equal("Good crate")
			expect(CrateViewRules.title("normal")).to.equal("Crate")
			expect(CrateViewRules.haveLine("normal", 1)).to.equal("You have 1 crate")
			expect(CrateViewRules.haveLine("normal", 3)).to.equal("You have 3 crates")
			expect(CrateViewRules.haveLine("good", 1)).to.equal("Your day 2 gift")
			expect(CrateViewRules.haveLine("normal", 0)).to.equal("No crates yet")
		end)

		it("collects the kinds the player owns", function()
			local owned = CrateViewRules.ownedKinds({
				{ id = 1, kind = "Koi", star = 1 },
				{ id = 2, kind = "Koi", star = 2, slot = "player" },
			})
			expect(owned.Koi).to.equal(true)
			expect(owned.Cozy).to.equal(nil)
		end)
	end)
end
