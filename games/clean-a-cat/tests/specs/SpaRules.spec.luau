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

	describe("SpaRules.canReplace and restart", function()
		it("swaps a done cat at once and an unfinished one only after a visit's time", function()
			local cat = SpaRules.newCat(1, 100)
			SpaRules.scrubbed(cat)
			expect(SpaRules.canReplace(cat, 101)).to.equal(false)
			expect(SpaRules.canReplace(cat, 100 + SpaRules.MIN_VISIT_SECONDS)).to.equal(true)
			local done = styledCat(100)
			SpaRules.askPhoto(done, 100 + SpaRules.MIN_VISIT_SECONDS)
			SpaRules.photo(done, 100 + SpaRules.MIN_VISIT_SECONDS)
			expect(done.stage).to.equal("done")
			expect(SpaRules.canReplace(done, 0)).to.equal(true)
		end)

		it("puts the same cat back to dirty without resetting its arrival or paying", function()
			local cat = styledCat(100)
			cat.kind = "Smudge"
			expect(SpaRules.askPhoto(cat, 101)).to.equal(SpaRules.MIN_VISIT_SECONDS - 1)
			SpaRules.restart(cat)
			expect(cat.stage).to.equal("dirty")
			expect(cat.arrivedAt).to.equal(100)
			expect(cat.kind).to.equal("Smudge")
			expect(cat.photoTaken).to.equal(false)
			expect(cat.bow).to.equal(nil)
			expect(cat.strokes).to.equal(0)
			-- The held photo finds the cat dirty again and pays nothing.
			expect(SpaRules.photo(cat, 100 + SpaRules.MIN_VISIT_SECONDS)).to.equal(0)
		end)
	end)

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
			expect(SpaRules.pickBow(cat, "BowMint")).to.equal(true)
			expect(cat.bow).to.equal("BowMint")
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

	describe("SpaRules.tanglesGone", function()
		it("takes an even share per stroke and all of them on the last", function()
			expect(SpaRules.tanglesGone(0, 6)).to.equal(0)
			expect(SpaRules.tanglesGone(1, 6)).to.equal(2)
			expect(SpaRules.tanglesGone(SpaRules.BRUSH_STROKES, 7)).to.equal(7)
			expect(SpaRules.tanglesGone(SpaRules.BRUSH_STROKES + 5, 7)).to.equal(7)
			expect(SpaRules.tanglesGone(2, 0)).to.equal(0)
		end)

		it("takes them all in one stroke when the cat needs one (Pro Brush, #267)", function()
			expect(SpaRules.tanglesGone(0, 6, 1)).to.equal(0)
			expect(SpaRules.tanglesGone(1, 6, 1)).to.equal(6)
			expect(SpaRules.tanglesGone(1, 6, 0)).to.equal(6) -- a bad count is at least one stroke
		end)

		it("fluffs a cat after its own stroke count", function()
			local cat = SpaRules.newCat(1, 0)
			SpaRules.scrubbed(cat)
			cat.brushStrokes = 1
			local counted, fluffed = SpaRules.brushStroke(cat, 1)
			expect(counted).to.equal(true)
			expect(fluffed).to.equal(true)
			expect(cat.stage).to.equal("fluffed")
		end)
	end)
	describe("SpaRules.pickNext", function()
		it("moves the picked customer to the front and keeps the rest in order", function()
			local queue = { "Smudge", "Marble", "Ginger" }
			expect(SpaRules.pickNext(queue, 3)).to.equal(true)
			expect(table.concat(queue, ",")).to.equal("Ginger,Smudge,Marble")
			expect(SpaRules.pickNext(queue, 2)).to.equal(true)
			expect(table.concat(queue, ",")).to.equal("Smudge,Ginger,Marble")
		end)

		it(
			"refuses the front, a missing place or a fraction, and never adds or drops a customer",
			function()
				local queue = { "Smudge", "Marble", "Ginger" }
				expect(SpaRules.pickNext(queue, 1)).to.equal(false)
				expect(SpaRules.pickNext(queue, 4)).to.equal(false)
				expect(SpaRules.pickNext(queue, 0)).to.equal(false)
				expect(SpaRules.pickNext(queue, 2.5)).to.equal(false)
				expect(table.concat(queue, ",")).to.equal("Smudge,Marble,Ginger")
			end
		)

		it(
			"moves a parallel list of looks the same way, so a look stays with its customer",
			function()
				local queue = { "Smudge", "Marble", "Ginger" }
				local looks = { 4, 5, 6 }
				expect(SpaRules.pickNext(queue, 3) and SpaRules.pickNext(looks, 3)).to.equal(true)
				expect(table.concat(queue, ",")).to.equal("Ginger,Smudge,Marble")
				expect(table.concat(looks, ",")).to.equal("6,4,5")
			end
		)
	end)
end
