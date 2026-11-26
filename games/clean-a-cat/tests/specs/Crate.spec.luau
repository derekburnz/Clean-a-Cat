--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Crate = require(Client:WaitForChild("Effects"):WaitForChild("Crate")) :: any

	describe("Crate.fallAt", function()
		it("falls from the top, bounces once and ends on the spot", function()
			expect(Crate.fallAt(0)).to.equal(Crate.DROP_HEIGHT)
			expect(Crate.fallAt(Crate.FALL_SECONDS)).to.equal(0)
			local mid = Crate.fallAt(Crate.FALL_SECONDS + Crate.BOUNCE_SECONDS / 2)
			expect(math.abs(mid - Crate.BOUNCE) < 1e-9).to.equal(true)
			expect(Crate.fallAt(Crate.FALL_SECONDS + Crate.BOUNCE_SECONDS)).to.equal(0)
			for i = 0, 100 do
				local h = Crate.fallAt(i * 0.01)
				expect(h >= 0 and h <= Crate.DROP_HEIGHT).to.equal(true)
			end
		end)
	end)

	describe("Crate.lidAt", function()
		it("swings open at once, a little past, and settles fully open", function()
			expect(Crate.lidAt(0)).to.equal(0)
			-- no wait before it moves: a third of the way open within the first tenth of a second
			expect(Crate.lidAt(0.1) > 0.33).to.equal(true)
			local peak = 0
			for i = 0, 100 do
				peak = math.max(peak, Crate.lidAt(i * 0.01))
			end
			expect(peak <= 1 + Crate.LID_OVER + 1e-9).to.equal(true)
			expect(Crate.lidAt(Crate.LID_SECONDS + Crate.LID_SETTLE)).to.equal(1)
		end)
		it("never goes back toward closed after opening, so nothing teases", function()
			local open = false
			for i = 0, 100 do
				local v = Crate.lidAt(i * 0.01)
				if v >= 1 then
					open = true
				end
				if open then
					expect(v >= 1 - 1e-9).to.equal(true)
				end
			end
		end)
	end)

	describe("Crate.popAt", function()
		it("pops from nothing to full size with a soft overshoot", function()
			expect(Crate.popAt(0)).to.equal(0)
			local peak = 0
			for i = 0, 40 do
				peak = math.max(peak, Crate.popAt(i * Crate.POP_SECONDS / 40))
			end
			expect(peak > 1 and peak < 1.2).to.equal(true)
			expect(Crate.popAt(Crate.POP_SECONDS)).to.equal(1)
		end)
	end)

	describe("Crate.spinAt", function()
		it("turns once with a hop and lands where it started", function()
			local turn, hop = Crate.spinAt(0)
			expect(turn).to.equal(0)
			expect(hop).to.equal(0)
			turn, hop = Crate.spinAt(Crate.SPIN_SECONDS)
			expect(turn).to.equal(1)
			expect(hop).to.equal(0)
			local _, top = Crate.spinAt(Crate.SPIN_SECONDS / 2)
			expect(math.abs(top - Crate.HOP) < 1e-9).to.equal(true)
		end)
	end)
end
