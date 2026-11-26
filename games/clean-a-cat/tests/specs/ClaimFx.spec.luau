--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ClaimFx = require(Client:WaitForChild("Effects"):WaitForChild("ClaimFx")) :: any

	describe("ClaimFx.at", function()
		it("hides each star before its turn and after its pop", function()
			local _, seen = ClaimFx.at(0, 1)
			expect(seen).to.equal(0)
			_, seen = ClaimFx.at(ClaimFx.GAP * 0.5, 2)
			expect(seen).to.equal(0)
			_, seen = ClaimFx.at(ClaimFx.total() + 0.01, 3)
			expect(seen).to.equal(0)
		end)
		it("grows to 1.1 fully shown, then shrinks and fades", function()
			local scale, seen = ClaimFx.at(ClaimFx.SECONDS * 0.4 - 1e-6, 1)
			expect(math.abs(scale - 1.1) < 0.01).to.equal(true)
			expect(seen > 0.99).to.equal(true)
			local later, fading = ClaimFx.at(ClaimFx.SECONDS * 0.9, 1)
			expect(later < scale).to.equal(true)
			expect(fading < seen).to.equal(true)
		end)
		it("never stays on screen longer than its total", function()
			expect(ClaimFx.total() <= 0.8).to.equal(true)
		end)
	end)
end
