--!strict
return function()
	local JarRules = require(game:GetService("ReplicatedStorage").Shared.JarRules)

	describe("JarRules.fill", function()
		it("fills 30 coins an hour per worker while away, up to 8 hours", function()
			expect(JarRules.fill(0, 1000, 1000 + 3600, 1, 8, 1)).to.equal(30)
			expect(JarRules.fill(0, 1000, 1000 + 3600, 2, 8, 1)).to.equal(60)
			expect(JarRules.fill(0, 1000, 1000 + 24 * 3600, 1, 8, 1)).to.equal(240) -- capped at 8 h
			expect(JarRules.fill(200, 1000, 1000 + 3 * 3600, 1, 8, 1)).to.equal(240) -- tops up to the cap
		end)

		it("holds 12 hours and fills faster with the Garden", function()
			expect(JarRules.fill(0, 1000, 1000 + 3600, 1, 12, 1.25)).to.equal(37)
			expect(JarRules.fill(0, 1000, 1000 + 48 * 3600, 1, 12, 1.25)).to.equal(450)
		end)

		it("adds nothing with no workers, no stamp or a clock that went back", function()
			expect(JarRules.fill(0, 1000, 99999, 0, 8, 1)).to.equal(0)
			expect(JarRules.fill(0, 0, 99999, 2, 8, 1)).to.equal(0)
			expect(JarRules.fill(15, 5000, 1000, 2, 8, 1)).to.equal(15)
			expect(JarRules.fill(0 / 0, 1000, 4600, 1, 8, 1)).to.equal(30)
		end)

		it("never takes coins away when the cap shrinks", function()
			-- a worker gone or the Garden off: what is in the jar stays
			expect(JarRules.fill(400, 1000, 1000 + 3600, 1, 8, 1)).to.equal(400)
		end)
	end)
end
