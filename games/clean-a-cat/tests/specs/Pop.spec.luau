--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Pop = require(Client:WaitForChild("Effects"):WaitForChild("Pop")) :: any

	describe("Pop.scale", function()
		it("starts small, peaks at 1.08 and settles at 1", function()
			expect(Pop.scale(0)).to.equal(0.6)
			expect(math.abs(Pop.scale(Pop.PEAK_AT) - 1.08) < 1e-6).to.equal(true)
			expect(Pop.scale(Pop.SECONDS)).to.equal(1)
			expect(Pop.done(Pop.SECONDS)).to.equal(true)
		end)
		it("takes its own start and peak", function()
			expect(Pop.scale(0, 0.7, 1)).to.equal(0.7)
			expect(Pop.scale(Pop.PEAK_AT, 0.7, 1)).to.equal(1)
		end)
		it("is done within 0.2 s", function()
			expect(Pop.SECONDS <= 0.2).to.equal(true)
		end)
	end)
end
