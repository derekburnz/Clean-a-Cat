--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GardenAmbience =
		require(Client:WaitForChild("Effects"):WaitForChild("GardenAmbience")) :: any

	describe("GardenAmbience.breatheAt", function()
		it("moves a cloud only a hint, slowly", function()
			for i = 0, 200 do
				local lift = GardenAmbience.breatheAt(i * 0.05, 0.4)
				expect(math.abs(lift) <= GardenAmbience.BREATHE + 1e-9).to.equal(true)
			end
			expect(GardenAmbience.BREATHE <= 0.1).to.equal(true)
			expect(GardenAmbience.BREATHE_SECONDS >= 3).to.equal(true)
		end)
		it("keeps clouds out of step with each other", function()
			expect(GardenAmbience.breatheAt(1, 0) ~= GardenAmbience.breatheAt(1, 0.37)).to.equal(
				true
			)
		end)
	end)

	describe("GardenAmbience.petalRate", function()
		it("is a few petals a second, fewer on phones and with Less sparkle", function()
			expect(GardenAmbience.petalRate("low", false)).to.equal(1)
			expect(GardenAmbience.petalRate("high", false)).to.equal(2)
			expect(GardenAmbience.petalRate("high", true)).to.equal(1)
			expect(GardenAmbience.petalRate("low", true)).to.equal(0.5)
		end)
	end)
end
