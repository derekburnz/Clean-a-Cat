--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local Attention = require(Client:WaitForChild("Effects"):WaitForChild("Attention")) :: any

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function()
	describe("Attention.bob", function()
		it("goes from 1.00 to 1.08 and back over 1.6 s", function()
			expect(near(Attention.bob(0), 1)).to.equal(true)
			expect(near(Attention.bob(0.8), 1.08)).to.equal(true)
			expect(near(Attention.bob(1.6), 1)).to.equal(true)
			for t = 0, 3.2, 0.05 do
				local s = Attention.bob(t)
				expect(s >= 1 - 1e-9 and s <= 1.08 + 1e-9).to.equal(true)
			end
		end)
	end)
	describe("Attention.sparkle", function()
		it(
			"pops in from 0.3 to 1.1 with a 20 degree turn, then is gone by 45% of the cycle",
			function()
				local s0, seen0 = Attention.sparkle(0, 1)
				expect(near(s0, 0.3)).to.equal(true)
				expect(near(seen0, 1)).to.equal(true)
				local peak = Attention.SPARKLE_IN * Attention.SPARKLE_CYCLE
				local s1, seen1, turn = Attention.sparkle(peak - 1e-9, 1)
				expect(math.abs(s1 - 1.1) < 1e-3 and seen1 < 1e-3 and math.abs(turn - 20) < 1e-3).to.equal(
					true
				)
				local s2, seen2 =
					Attention.sparkle(Attention.SPARKLE_OUT * Attention.SPARKLE_CYCLE + 0.01, 1)
				expect(s2).to.equal(0)
				expect(seen2).to.equal(1)
			end
		)
		it("takes turns: each star pops 0.8 s after the one before", function()
			local a = { Attention.sparkle(0.05, 1) }
			local b = { Attention.sparkle(0.85, 2) }
			local c = { Attention.sparkle(1.65, 3) }
			for i = 1, 3 do
				expect(near(a[i], b[i]) and near(b[i], c[i])).to.equal(true)
			end
			expect(#Attention.SPOTS).to.equal(3)
		end)
	end)
end
