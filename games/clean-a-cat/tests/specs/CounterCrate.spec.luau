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
	describe("CustomerMotion.armIn", function()
		local Client = game:GetService("StarterPlayer")
			:WaitForChild("StarterPlayerScripts")
			:WaitForChild("Client")
		local Motion = require(Client:WaitForChild("Effects"):WaitForChild("CustomerMotion")) :: any
		it(
			"turns the empty hand back in by CarryArmOut, only while the carrier is hidden",
			function()
				expect(math.abs(Motion.armIn(true, 20, false) - math.rad(20)) < 1e-6).to.equal(true)
				expect(Motion.armIn(false, 20, false)).to.equal(0)
				expect(Motion.armIn(true, nil, false)).to.equal(0)
			end
		)
		it("waits for the reach that sets the crate down", function()
			expect(Motion.armIn(true, 20, true)).to.equal(0)
		end)
	end)

	describe("CounterCrate walking in (issue 871)", function()
		it(
			"counts a customer away from their WalkTo mat as walking, and one on it or with none as arrived",
			function()
				local mat = Vector3.new(10, 3, -20)
				expect(CounterCrate.walking(Vector3.new(4, 3, -20), mat)).to.equal(true)
				expect(CounterCrate.walking(Vector3.new(10.1, 9, -20.1), mat)).to.equal(false)
				expect(CounterCrate.walking(Vector3.new(4, 3, -20), nil)).to.equal(false)
			end
		)
		it(
			"keeps the server's times unless the customer arrived after the set-down was due",
			function()
				local a, b = CounterCrate.shifted(100, 102.4, nil)
				expect(a).to.equal(100)
				expect(b).to.equal(102.4)
				a, b = CounterCrate.shifted(100, 102.4, 99)
				expect(a).to.equal(100)
				a, b = CounterCrate.shifted(100, 102.4, 103)
				expect(a).to.equal(103)
				expect(math.abs(b - 105.4) < 1e-9).to.equal(true)
			end
		)
	end)

	describe("CounterCrate.waitsForWalk and span (issue 871, Review-QA on 993)", function()
		it(
			"hides a newcomer whose two times are equal while they walk, with the whole set-down after",
			function()
				expect(CounterCrate.waitsForWalk(100, 100, true)).to.equal(true)
				expect(CounterCrate.span(100, 100, true)).to.equal(CounterCrate.TOTAL)
			end
		)
		it(
			"leaves a step-up whose cat is already set down (both times equal, no WalkFile) shown",
			function()
				expect(CounterCrate.waitsForWalk(100, 100, nil)).to.equal(false)
				expect(CounterCrate.span(100, 100, nil)).to.equal(0)
			end
		)
		it(
			"waits for any customer with a set-down still to come, keeping the server's span",
			function()
				expect(CounterCrate.waitsForWalk(100, 102.4, nil)).to.equal(true)
				expect(math.abs(CounterCrate.span(100, 102.4, true) - 2.4) < 1e-9).to.equal(true)
			end
		)
	end)
end
