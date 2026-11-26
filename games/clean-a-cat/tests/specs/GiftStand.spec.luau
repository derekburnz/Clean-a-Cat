--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GiftStand = require(Client:WaitForChild("Effects"):WaitForChild("GiftStand")) :: any

	describe("GiftStand.pulseAt", function()
		it("breathes slowly between 0 and 1, starting low", function()
			expect(GiftStand.pulseAt(0)).to.equal(0)
			expect(math.abs(GiftStand.pulseAt(GiftStand.PULSE_SECONDS / 2) - 1) < 1e-9).to.equal(
				true
			)
			for i = 0, 100 do
				local v = GiftStand.pulseAt(i * 0.07)
				expect(v >= 0 and v <= 1).to.equal(true)
			end
		end)
		it("is slow and calm: no more than one breath every two seconds", function()
			expect(GiftStand.PULSE_SECONDS >= 2).to.equal(true)
		end)
	end)

	describe("GiftStand.flashAt", function()
		it("swells once and is gone by the end, never flashing", function()
			expect(GiftStand.flashAt(0)).to.equal(0)
			expect(GiftStand.flashAt(GiftStand.FLASH_SECONDS)).to.equal(0)
			local peak = 0
			local turns = 0
			local last, rising = 0, true
			for i = 1, 99 do
				local v = GiftStand.flashAt(i * GiftStand.FLASH_SECONDS / 100)
				expect(v >= 0 and v <= 1).to.equal(true)
				if rising and v < last then
					rising = false
					turns += 1
				elseif not rising and v > last then
					turns += 1
				end
				peak = math.max(peak, v)
				last = v
			end
			expect(peak > 0.5).to.equal(true)
			expect(turns).to.equal(1) -- up once, down once
		end)
	end)

	describe("GiftStand.swayAt", function()
		it("leans the balloon only a little", function()
			for i = 0, 200 do
				local x, z = GiftStand.swayAt(i * 0.05, 0.3)
				expect(math.abs(x) <= GiftStand.SWAY + 1e-9).to.equal(true)
				expect(math.abs(z) <= GiftStand.SWAY + 1e-9).to.equal(true)
			end
		end)
	end)
	describe("GiftStand.beaconAt", function()
		it(
			"breathes a little and turns only a little; still under Reduced Motion (#659)",
			function()
				for i = 0, 100 do
					local scale, turn = GiftStand.beaconAt(i * 0.09, false)
					expect(scale >= 0.9 - 1e-9 and scale <= 1.1 + 1e-9).to.equal(true)
					expect(math.abs(turn) <= GiftStand.BEACON_TURN + 1e-9).to.equal(true)
				end
				local scale, turn = GiftStand.beaconAt(1.3, true)
				expect(scale).to.equal(1)
				expect(turn).to.equal(0)
			end
		)
		it("is at least 15 px on screen at its smallest", function()
			expect(GiftStand.BEACON_PX * 0.9 >= 15).to.equal(true)
		end)
	end)
end
