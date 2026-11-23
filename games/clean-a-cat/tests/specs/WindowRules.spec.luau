--!strict
return function()
	local WindowRules = require(game:GetService("ReplicatedStorage").Shared.WindowRules)

	local function isCat(name: string): boolean
		return name == "Smudge" or name == "Tux"
	end

	describe("WindowRules.isStrayTurn", function()
		it("starts a brand new save with a stray and a returning one with a customer", function()
			expect(WindowRules.isStrayTurn(0, 0, true)).to.equal(true)
			expect(WindowRules.isStrayTurn(0, 1, false)).to.equal(false)
		end)

		it("sends a stray every few cats while the window has room", function()
			expect(WindowRules.isStrayTurn(1, 1, false)).to.equal(false)
			expect(WindowRules.isStrayTurn(WindowRules.STRAY_EVERY, 1, false)).to.equal(true)
			expect(WindowRules.isStrayTurn(WindowRules.STRAY_EVERY, WindowRules.CUSHIONS, false)).to.equal(
				false
			)
		end)
	end)

	describe("WindowRules.tips", function()
		it("pays per window cat per whole tip period", function()
			expect(WindowRules.tips(2, WindowRules.TIP_SECONDS * 3 + 4, false)).to.equal(
				2 * 3 * WindowRules.TIP_COINS
			)
			expect(WindowRules.tips(0, 1000, false)).to.equal(0)
			expect(WindowRules.tips(3, -50, true)).to.equal(0)
			expect(WindowRules.tips(3, 0 / 0, true)).to.equal(0)
		end)

		it("caps time away at the jar and window cats at the cushions", function()
			local full = WindowRules.tips(WindowRules.CUSHIONS, WindowRules.JAR_SECONDS, true)
			expect(WindowRules.tips(WindowRules.CUSHIONS, WindowRules.JAR_SECONDS * 24, true)).to.equal(
				full
			)
			expect(WindowRules.tips(WindowRules.CUSHIONS + 5, WindowRules.JAR_SECONDS, true)).to.equal(
				full
			)
		end)
	end)

	describe("WindowRules.validResidents", function()
		it("keeps well formed cats up to the cushions and drops the rest", function()
			local raw = {
				{ cat = "Smudge", bow = "BowPink", since = 5 },
				"junk",
				{ cat = "Nobody", since = 1 },
				{ cat = "Tux", bow = 7, since = 0 / 0 },
				{ cat = "Smudge" },
				{ cat = "Tux" },
				{ cat = "Smudge" },
			}
			local kept = WindowRules.validResidents(raw, isCat)
			expect(#kept).to.equal(WindowRules.CUSHIONS)
			expect(kept[1].bow).to.equal("BowPink")
			expect(kept[2].cat).to.equal("Tux")
			expect(kept[2].bow).to.equal(nil)
			expect(kept[2].since).to.equal(0)
			expect(#WindowRules.validResidents(nil, isCat)).to.equal(0)
		end)
	end)
end
