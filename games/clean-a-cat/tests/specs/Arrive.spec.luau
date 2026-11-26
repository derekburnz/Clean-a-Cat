--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Arrive = require(Client:WaitForChild("Effects"):WaitForChild("Arrive")) :: any

	describe("Arrive.at", function()
		it("grows from nothing, overshoots a little and settles at full size", function()
			local s0 = Arrive.at(0)
			expect(s0 < 0.05).to.equal(true)
			local peak = 0
			for i = 0, 100 do
				local s = Arrive.at(i * Arrive.POP_SECONDS / 100)
				peak = math.max(peak, s)
				expect(s <= Arrive.POP_OVER + 1e-9).to.equal(true)
			end
			expect(peak > 1.05).to.equal(true)
			local s, d = Arrive.at(Arrive.POP_SECONDS)
			expect(s).to.equal(1)
			expect(d).to.equal(0)
		end)
		it("tilts only a little and ends straight", function()
			for i = 0, 100 do
				local _, d = Arrive.at(i * Arrive.POP_SECONDS / 100)
				expect(math.abs(d) <= Arrive.TILT).to.equal(true)
			end
			local _, d = Arrive.at(Arrive.LENGTH)
			expect(d).to.equal(0)
		end)
		it("shines once, after the pop starts, and is gone by the end", function()
			local _, _, a = Arrive.at(0.1)
			expect(a).to.equal(0)
			local _, _, b = Arrive.at(Arrive.SHINE_FROM + Arrive.SHINE_SECONDS / 2)
			expect(b > 0.9).to.equal(true)
			local _, _, c = Arrive.at(Arrive.LENGTH)
			expect(c).to.equal(0)
		end)
	end)
end
