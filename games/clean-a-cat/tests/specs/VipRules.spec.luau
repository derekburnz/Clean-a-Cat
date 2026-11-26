--!strict
return function()
	local VipRules = require(game:GetService("ReplicatedStorage").Shared.VipRules)
	local CatRules = require(game:GetService("ReplicatedStorage").Shared.CatRules)

	describe("VipRules", function()
		it("seats only washed special cats, in roster order", function()
			local first = CatRules.SPECIAL_CATS[1]
			local third = CatRules.SPECIAL_CATS[3]
			local index: any = {
				[third] = { washed = true },
				[first] = { washed = true },
				[CatRules.SPECIAL_CATS[2]] = { washed = false },
				Smudge = { washed = true }, -- not a special cat
			}
			local seated = VipRules.residents(index, 8)
			expect(#seated).to.equal(2)
			expect(seated[1]).to.equal(first)
			expect(seated[2]).to.equal(third)
		end)

		it("never seats more cats than seats", function()
			local index: any = {}
			for _, kind in CatRules.SPECIAL_CATS do
				index[kind] = { washed = true }
			end
			expect(#VipRules.residents(index, 2)).to.equal(2)
			expect(#VipRules.residents(index, 0)).to.equal(0)
			expect(#VipRules.residents(index, 99)).to.equal(#CatRules.SPECIAL_CATS)
		end)

		it("reads the area's attributes safely", function()
			expect(VipRules.seatCount(8)).to.equal(8)
			expect(VipRules.seatCount(2.5)).to.equal(VipRules.DEFAULT_SEATS)
			expect(VipRules.seatCount(nil)).to.equal(VipRules.DEFAULT_SEATS)
			expect(VipRules.scale(1.2)).to.equal(1.2)
			expect(VipRules.scale(-1)).to.equal(VipRules.DEFAULT_SCALE)
			expect(VipRules.scale("big")).to.equal(VipRules.DEFAULT_SCALE)
		end)
	end)
end
