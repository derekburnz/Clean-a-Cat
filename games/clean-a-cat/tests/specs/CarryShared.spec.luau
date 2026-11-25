--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CarryShared = require(Client:WaitForChild("Effects"):WaitForChild("CarryShared")) :: any

	describe("pick", function()
		it("draws the nearest carriers first, at most max", function()
			local picked = CarryShared.pick({ 30, 5, 80, 12 }, 2, 120)
			expect(#picked).to.equal(2)
			expect(picked[1]).to.equal(2)
			expect(picked[2]).to.equal(4)
		end)

		it("leaves out carriers past the range", function()
			local picked = CarryShared.pick({ 130, 40, math.huge }, 8, 120)
			expect(#picked).to.equal(1)
			expect(picked[1]).to.equal(2)
		end)

		it("draws nobody with no carriers, and keeps a steady order on ties", function()
			expect(#CarryShared.pick({}, 8, 120)).to.equal(0)
			local picked = CarryShared.pick({ 10, 10, 10 }, 2, 120)
			expect(picked[1]).to.equal(1)
			expect(picked[2]).to.equal(2)
		end)

		it("stays inside the phone budget", function()
			expect(CarryShared.MAX.low <= CarryShared.MAX.high).to.equal(true)
			expect(CarryShared.MAX.high <= 10).to.equal(true)
		end)
	end)
end
