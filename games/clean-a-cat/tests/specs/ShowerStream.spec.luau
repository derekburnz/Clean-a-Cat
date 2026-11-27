--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ShowerStream = require(Client:WaitForChild("Effects"):WaitForChild("ShowerStream")) :: any

	describe("ShowerStream.width", function()
		it("is thin at the nozzle, wider at the fur, and wobbles a little", function()
			local w0, w1 = ShowerStream.width(0)
			expect(w0 < w1).to.equal(true)
			for _, t in { 0.01, 0.03, 0.05, 0.08 } do
				local a, b = ShowerStream.width(t)
				expect(a <= ShowerStream.WIDTH0 * (1 + ShowerStream.WOBBLE) + 1e-9).to.equal(true)
				expect(b >= ShowerStream.WIDTH1 * (1 - ShowerStream.WOBBLE) - 1e-9).to.equal(true)
			end
		end)
	end)
end
