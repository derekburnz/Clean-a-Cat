--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PhotoFx = require(Client:WaitForChild("Effects"):WaitForChild("PhotoFx")) :: any

	describe("PhotoFx.at", function()
		it("blinks three times, each gap shorter, before the flash", function()
			local b = PhotoFx.BLINKS
			expect(#b).to.equal(3)
			expect(b[3] - b[2] < b[2] - b[1]).to.equal(true)
			for _, start in b do
				expect(PhotoFx.at(start + 0.01).led).to.equal(true)
				expect(start + PhotoFx.BLINK_ON <= PhotoFx.FLASH_AT).to.equal(true)
			end
			expect(PhotoFx.at(b[1] + PhotoFx.BLINK_ON + 0.01).led).to.equal(false)
		end)
		it("flashes once, softly fading, then prints and drops the card", function()
			expect(PhotoFx.at(PhotoFx.FLASH_AT - 0.01).flash).to.equal(0)
			expect(PhotoFx.at(PhotoFx.FLASH_AT).flash).to.equal(1)
			expect(PhotoFx.at(PhotoFx.FLASH_AT + PhotoFx.FLASH_SECONDS + 1e-6).flash).to.equal(0)
			expect(PhotoFx.at(PhotoFx.PRINT_AT).slide).to.equal(0)
			expect(PhotoFx.at(PhotoFx.PRINT_AT + PhotoFx.PRINT_SECONDS + 1e-6).slide).to.equal(1)
			expect(PhotoFx.at(PhotoFx.DONE + 1e-6).drop).to.equal(1)
		end)
		it("keeps the screen brighten mild and the beat short", function()
			expect(PhotoFx.SCREEN_PEAK <= 0.35).to.equal(true)
			expect(PhotoFx.DONE <= 1.8).to.equal(true)
		end)
	end)
end
