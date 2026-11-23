--!strict
return function()
	local SpaRules = require(game:GetService("ReplicatedStorage").Shared.SpaRules)

	local function styledCat(now: number)
		local cat = SpaRules.newCat(1, now)
		SpaRules.scrubbed(cat)
		for i = 1, SpaRules.BRUSH_STROKES do
			SpaRules.brushStroke(cat, now + i)
		end
		SpaRules.pickBow(cat, SpaRules.BOWS[1])
		return cat
	end

	describe("SpaRules visit order", function()
		it("goes dirty, clean, fluffed, styled, done and pays once", function()
			local cat = SpaRules.newCat(7, 100)
			expect(cat.stage).to.equal("dirty")
			expect(SpaRules.scrubbed(cat)).to.equal(true)
			expect(SpaRules.scrubbed(cat)).to.equal(false)
			for i = 1, SpaRules.BRUSH_STROKES - 1 do
				local counted, fluffed = SpaRules.brushStroke(cat, 100 + i)
				expect(counted).to.equal(true)
				expect(fluffed).to.equal(false)
			end
			local counted, fluffed = SpaRules.brushStroke(cat, 110)
			expect(counted).to.equal(true)
			expect(fluffed).to.equal(true)
			expect(cat.stage).to.equal("fluffed")
			expect(SpaRules.pickBow(cat, "BowBlue")).to.equal(true)
			expect(cat.bow).to.equal("BowBlue")
			expect(SpaRules.askPhoto(cat, 100 + SpaRules.MIN_VISIT_SECONDS)).to.equal(0)
			expect(SpaRules.photo(cat, 100 + SpaRules.MIN_VISIT_SECONDS)).to.equal(
				SpaRules.PHOTO_COINS
			)
			expect(cat.stage).to.equal("done")
			expect(SpaRules.photo(cat, 1000)).to.equal(0)
			expect(SpaRules.askPhoto(cat, 1000)).to.equal(nil)
		end)

		it("refuses steps out of order", function()
			local cat = SpaRules.newCat(1, 0)
			local counted = SpaRules.brushStroke(cat, 10)
			expect(counted).to.equal(false)
			expect(SpaRules.pickBow(cat, "BowPink")).to.equal(false)
			expect(SpaRules.photo(cat, 100)).to.equal(0)
			expect(cat.stage).to.equal("dirty")
		end)
	end)

	describe("SpaRules checks", function()
		it("counts strokes that arrive bunched together", function()
			local cat = SpaRules.newCat(1, 0)
			SpaRules.scrubbed(cat)
			for _ = 1, SpaRules.BRUSH_STROKES do
				SpaRules.brushStroke(cat, 1)
			end
			expect(cat.stage).to.equal("fluffed")
		end)

		it("refuses an unknown bow", function()
			local cat = SpaRules.newCat(1, 0)
			SpaRules.scrubbed(cat)
			for i = 1, SpaRules.BRUSH_STROKES do
				SpaRules.brushStroke(cat, i)
			end
			expect(SpaRules.pickBow(cat, "BowRainbow")).to.equal(false)
			expect(cat.stage).to.equal("fluffed")
		end)

		it("makes an early photo wait until the visit is long enough, then pays once", function()
			local cat = styledCat(0)
			expect(SpaRules.photo(cat, 100)).to.equal(0) -- not asked for yet
			expect(SpaRules.askPhoto(cat, 4)).to.equal(SpaRules.MIN_VISIT_SECONDS - 4)
			expect(SpaRules.askPhoto(cat, 5)).to.equal(nil) -- already waiting
			expect(SpaRules.photo(cat, SpaRules.MIN_VISIT_SECONDS - 0.1)).to.equal(0)
			expect(cat.stage).to.equal("styled")
			expect(SpaRules.photo(cat, SpaRules.MIN_VISIT_SECONDS)).to.equal(SpaRules.PHOTO_COINS)
			expect(SpaRules.photo(cat, SpaRules.MIN_VISIT_SECONDS + 1)).to.equal(0)
		end)
	end)
end
