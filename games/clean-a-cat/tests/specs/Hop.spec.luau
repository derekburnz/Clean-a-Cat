--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Hop = require(Client:WaitForChild("Effects"):WaitForChild("Hop")) :: any

	describe("Hop.at", function()
		it("leaves the ground in a small arc and lands where it started", function()
			local a, p = Hop.at(0)
			expect(a).to.equal(0)
			expect(p).to.equal(0)
			local peak = 0
			for i = 1, 99 do
				local lift, pitch = Hop.at(i * Hop.SECONDS / 100)
				expect(lift >= 0 and lift <= Hop.HEIGHT + 1e-9).to.equal(true)
				expect(math.abs(pitch) <= Hop.TIP + 1e-9).to.equal(true)
				peak = math.max(peak, lift)
			end
			expect(peak > Hop.HEIGHT * 0.9).to.equal(true)
			local b, q = Hop.at(Hop.SECONDS)
			expect(b).to.equal(0)
			expect(q).to.equal(0)
		end)
		it("tips nose up going up and nose down coming down", function()
			local _, up = Hop.at(Hop.SECONDS * 0.2)
			local _, down = Hop.at(Hop.SECONDS * 0.8)
			expect(up > 0).to.equal(true)
			expect(down < 0).to.equal(true)
		end)
	end)
end
