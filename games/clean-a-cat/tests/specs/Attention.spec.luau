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
	describe("Attention never loops", function()
		it("plays 3 bobs by default and is over a moment after the last", function()
			expect(Attention.DEFAULT_BOBS).to.equal(3)
			local over = Attention.length(3)
			expect(over > 3 * Attention.BOB_SECONDS and over < 3 * Attention.BOB_SECONDS + 1.2).to.equal(
				true
			)
			expect(near(Attention.length(1), Attention.BOB_SECONDS + 0.45 * 2.4)).to.equal(true)
		end)
		it("starts no new sparkle once the bobs are over, but lets one under way finish", function()
			local playFor = 3 * Attention.BOB_SECONDS -- 4.8 s
			-- star 1 pops at 0, 2.4 and 4.8: the one at 4.8 is not shown
			local s, seen = Attention.sparkle(4.85, 1, playFor)
			expect(s).to.equal(0)
			expect(seen).to.equal(1)
			-- star 3 pops at 1.6 and 4.0: the one at 4.0 is still fading at 4.9
			local s3 = Attention.sparkle(4.9, 3, playFor)
			expect(s3 > 0).to.equal(true)
			-- with no limit the same moment shows star 1 again
			local again = Attention.sparkle(4.85, 1)
			expect(again > 0).to.equal(true)
		end)
	end)
end
