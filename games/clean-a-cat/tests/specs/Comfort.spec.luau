--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Comfort = require(Client:WaitForChild("UI"):WaitForChild("Comfort")) :: any

	describe("backdropValue", function()
		it("keeps the design value at Roblox's default preference", function()
			expect(Comfort.backdropValue(0.2, 1)).to.equal(0.2)
			expect(Comfort.backdropValue(0.2, nil)).to.equal(0.2)
		end)
		it("turns solid when the player asks for solid backgrounds", function()
			expect(Comfort.backdropValue(0.2, 0)).to.equal(0)
		end)
		it("scales in between and stays inside 0 to 1", function()
			expect(math.abs(Comfort.backdropValue(0.4, 0.5) - 0.2) < 1e-9).to.equal(true)
			expect(Comfort.backdropValue(1.5, 2)).to.equal(1)
			expect(Comfort.backdropValue(-1, 1)).to.equal(0)
		end)
		it("is for visible panels only: an invisible frame (1) would turn solid too", function()
			expect(Comfort.backdropValue(1, 0)).to.equal(0)
		end)
	end)
end
