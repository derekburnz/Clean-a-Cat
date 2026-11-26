--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CounterCrate = require(Client:WaitForChild("Effects"):WaitForChild("CounterCrate")) :: any

	describe("CounterCrate.at", function()
		it("runs set down, door, walk out and fade in order within the total", function()
			local total = CounterCrate.TOTAL
			local s, d, w, f = CounterCrate.at(0, total)
			expect(s + d + w + f).to.equal(0)
			s, d, w, f = CounterCrate.at(total, total)
			expect(s + d + w + f).to.equal(4)
			local lastS, lastD, lastW, lastF = 0, 0, 0, 0
			for i = 1, 100 do
				s, d, w, f = CounterCrate.at(i * total / 100, total)
				expect(s >= lastS and d >= lastD and w >= lastW and f >= lastF).to.equal(true)
				-- the door opens only once the crate is down, the cat walks only through an open door
				expect(d == 0 or s == 1).to.equal(true)
				expect(w == 0 or d == 1).to.equal(true)
				expect(f == 0 or w == 1).to.equal(true)
				lastS, lastD, lastW, lastF = s, d, w, f
			end
		end)
		it("scales the steps to a longer total", function()
			local _, _, w = CounterCrate.at(CounterCrate.WALK[2] * 2, CounterCrate.TOTAL * 2)
			expect(w).to.equal(1)
			local _, _, half = CounterCrate.at(CounterCrate.WALK[1] * 2, CounterCrate.TOTAL * 2)
			expect(half).to.equal(0)
		end)
	end)

	describe("CounterCrate.arcAt and reachAt", function()
		it("lifts the crate in an arc that starts and ends on the line", function()
			expect(CounterCrate.arcAt(0)).to.equal(0)
			expect(CounterCrate.arcAt(1)).to.equal(0)
			expect(math.abs(CounterCrate.arcAt(0.5) - CounterCrate.LIFT) < 1e-9).to.equal(true)
		end)
		it("reaches the arm forward and back to rest", function()
			expect(CounterCrate.reachAt(0)).to.equal(0)
			expect(CounterCrate.reachAt(CounterCrate.REACH_SECONDS)).to.equal(0)
			local mid = CounterCrate.reachAt(CounterCrate.REACH_SECONDS / 2)
			expect(mid > 0 and mid <= CounterCrate.REACH + 1e-9).to.equal(true)
		end)
	end)
end
