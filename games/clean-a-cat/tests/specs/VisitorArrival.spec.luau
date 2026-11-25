--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local VisitorArrival =
		require(Client:WaitForChild("Effects"):WaitForChild("VisitorArrival")) :: any

	describe("VisitorArrival.glowAt", function()
		it("starts unseen, fades in, holds and is gone by GLOW_SECONDS", function()
			expect(VisitorArrival.glowAt(0)).to.equal(1)
			local held = VisitorArrival.GLOW_IN + VisitorArrival.GLOW_HOLD / 2
			expect(VisitorArrival.glowAt(held)).to.equal(VisitorArrival.GLOW_SEEN)
			expect(VisitorArrival.glowAt(VisitorArrival.GLOW_SECONDS)).to.equal(1)
			expect(VisitorArrival.glowAt(99)).to.equal(1)
		end)
		it("never jumps and never goes past its strongest", function()
			local last = VisitorArrival.glowAt(0)
			for i = 1, 300 do
				local now = VisitorArrival.glowAt(i * VisitorArrival.GLOW_SECONDS / 300)
				expect(math.abs(now - last) < 0.05).to.equal(true)
				expect(now >= VisitorArrival.GLOW_SEEN - 1e-9 and now <= 1).to.equal(true)
				last = now
			end
		end)
	end)

	describe("VisitorArrival.star", function()
		it("bobs gently inside its limits and keeps its size near 1", function()
			for i = 0, 200 do
				local lift, degrees, scale = VisitorArrival.star(i * 0.05, 0.3)
				expect(math.abs(lift) <= VisitorArrival.STAR_BOB + 1e-9).to.equal(true)
				expect(math.abs(degrees) <= VisitorArrival.STAR_TURN + 1e-9).to.equal(true)
				expect(scale > 0.9 and scale < 1.1).to.equal(true)
			end
		end)
		it("puts two visitors out of step", function()
			local a = VisitorArrival.star(1, 0.1)
			local b = VisitorArrival.star(1, 0.6)
			expect(a ~= b).to.equal(true)
		end)
	end)
end
