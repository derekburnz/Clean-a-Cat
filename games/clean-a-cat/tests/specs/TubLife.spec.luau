--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local TubLife = require(Client:WaitForChild("Effects"):WaitForChild("TubLife")) :: any

	describe("TubLife.bubble", function()
		it("starts on the water, rises, then pops only at the end of its life", function()
			local life = 3
			local rise0, _, pop0 = TubLife.bubble(0, life)
			expect(rise0).to.equal(0)
			expect(pop0).to.equal(0)
			local riseMid, _, popMid = TubLife.bubble(life / 2, life)
			expect(riseMid > 0 and riseMid < 1).to.equal(true)
			expect(popMid).to.equal(0)
			local riseEnd, _, popEnd = TubLife.bubble(life, life)
			expect(riseEnd).to.equal(1)
			expect(popEnd).to.equal(1)
		end)
		it("wobbles within one either way", function()
			for i = 0, 30 do
				local _, wobble = TubLife.bubble(i * 0.1, 3)
				expect(math.abs(wobble) <= 1).to.equal(true)
			end
		end)
	end)

	describe("TubLife.ripple", function()
		it("grows and fades over each loop", function()
			local s0, seen0 = TubLife.ripple(0)
			local s1, seen1 = TubLife.ripple(TubLife.RIPPLE_SECONDS * 0.9)
			expect(s1 > s0).to.equal(true)
			expect(seen1 < seen0).to.equal(true)
		end)
	end)
end
