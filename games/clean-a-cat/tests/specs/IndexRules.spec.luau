--!strict
return function()
	local IndexRules = require(game:GetService("ReplicatedStorage").Shared.IndexRules)

	local CATS = { "Smudge", "Tux" }
	local function isCat(name: string): boolean
		return table.find(CATS, name) ~= nil
	end

	describe("IndexRules.stamp", function()
		it("stamps each cat once per kind of stamp", function()
			local index = {}
			expect(IndexRules.stamp(index, "Smudge", "washed")).to.equal(true)
			expect(IndexRules.stamp(index, "Smudge", "washed")).to.equal(false)
			expect(IndexRules.stamp(index, "Smudge", "resident")).to.equal(true)
			expect(index.Smudge.washed).to.equal(true)
			expect(index.Smudge.resident).to.equal(true)
		end)

		it("is complete only once every cat is washed", function()
			local index = {}
			IndexRules.stamp(index, "Smudge", "washed")
			IndexRules.stamp(index, "Tux", "resident")
			expect(IndexRules.washedCount(index, CATS)).to.equal(1)
			expect(IndexRules.complete(index, CATS)).to.equal(false)
			IndexRules.stamp(index, "Tux", "washed")
			expect(IndexRules.complete(index, CATS)).to.equal(true)
		end)
	end)

	describe("IndexRules.clean", function()
		it("keeps real cats with true stamps and drops the rest", function()
			local index = IndexRules.clean({
				Smudge = { washed = true, resident = "yes" },
				Nobody = { washed = true },
				Tux = 5,
				[3] = { washed = true },
			}, isCat)
			expect(index.Smudge.washed).to.equal(true)
			expect(index.Smudge.resident).to.equal(false)
			expect(index.Nobody).to.equal(nil)
			expect(index.Tux).to.equal(nil)
			expect(next(IndexRules.clean("junk", isCat))).to.equal(nil)
		end)
	end)
end
