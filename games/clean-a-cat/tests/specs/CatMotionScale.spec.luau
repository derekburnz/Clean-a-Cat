--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CatMotion = require(Client:WaitForChild("Effects"):WaitForChild("CatMotion")) :: any

	describe("CatMotion.scaleRatio", function()
		it("gives the growth when a cat is scaled after its rig was built (issue 903)", function()
			expect(math.abs(CatMotion.scaleRatio(1, 1.4) - 1.4) < 1e-6).to.equal(true)
			expect(math.abs(CatMotion.scaleRatio(1.4, 1) - 1 / 1.4) < 1e-6).to.equal(true)
		end)
		it("leaves an unchanged or broken scale alone", function()
			expect(CatMotion.scaleRatio(1, 1)).to.equal(nil)
			expect(CatMotion.scaleRatio(1, 1 + 1e-6)).to.equal(nil)
			expect(CatMotion.scaleRatio(0, 1)).to.equal(nil)
		end)
	end)
end
