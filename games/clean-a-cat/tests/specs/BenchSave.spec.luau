--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BenchSave = require(Shared:WaitForChild("BenchSave"))
local CatRules = require(Shared:WaitForChild("CatRules"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))

return function()
	describe("BenchSave", function()
		local common = CatRules.ROSTER.Common[1]
		local rare = CatRules.ROSTER.Rare[1]

		it("keeps who waits, front first, and never a special visitor", function()
			local kinds = { common, CatRules.SPECIAL_CATS[1], rare }
			local orders: { BenchSave.Waiting } = {
				{ dirt = 1, needs = { "mud" } },
				{ dirt = 4, needs = { "mud", "tangles" }, special = true },
				{ dirt = 3, needs = { "mud", "wet" } },
			}
			local saved = BenchSave.snapshot(kinds, orders)
			expect(#saved).to.equal(2)
			expect(saved[1].kind).to.equal(common)
			expect(saved[2].kind).to.equal(rare)
			expect(saved[2].dirt).to.equal(3)
			orders[3].needs[1] = "claws" -- the save holds its own copy
			expect(saved[2].needs[1]).to.equal("mud")
		end)

		it("reads a saved line back, dropping anything malformed", function()
			local back = BenchSave.restore({
				{ kind = common, dirt = 2, needs = { "mud", "mud", "nope" } },
				{ kind = "Nobody", dirt = 1, needs = { "mud" } },
				{ kind = CatRules.SPECIAL_CATS[1], dirt = 4, needs = { "mud" } },
				{ kind = rare, dirt = 9, needs = { "mud" } },
				{ kind = rare, dirt = 1, needs = {} },
				"junk",
				{ kind = rare, dirt = 1, needs = { "tangles" } },
			})
			expect(#back).to.equal(2)
			expect(#back[1].needs).to.equal(1) -- the double and the unknown need are gone
			expect(back[2].kind).to.equal(rare)
			expect(#BenchSave.restore(nil)).to.equal(0)
			expect(#BenchSave.restore("x")).to.equal(0)
		end)

		it("never gives back more than the biggest bench", function()
			local many = {}
			for _ = 1, SpaRules.MAX_QUEUE + 3 do
				table.insert(many, { kind = common, dirt = 1, needs = { "mud" } })
			end
			expect(#BenchSave.restore(many)).to.equal(SpaRules.MAX_QUEUE)
		end)
	end)
end
