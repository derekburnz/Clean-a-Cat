--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WashMeter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WashMeter"))

return function()
	describe("WashMeter", function()
		it("is full at about nine in ten", function()
			expect(WashMeter.needed(20)).to.equal(18)
			expect(WashMeter.needed(14)).to.equal(13)
			expect(WashMeter.needed(10)).to.equal(9)
		end)

		it("never asks for none or more than all", function()
			expect(WashMeter.needed(1)).to.equal(1)
			expect(WashMeter.needed(0)).to.equal(1)
			expect(WashMeter.needed(4)).to.equal(4)
			expect(WashMeter.needed(5, 1)).to.equal(5)
			expect(WashMeter.needed(5, 2)).to.equal(5)
		end)

		it("fills the bar toward the needed count", function()
			expect(WashMeter.fill(0, 20)).to.equal(0)
			expect(WashMeter.fill(9, 20)).to.equal(0.5)
			expect(WashMeter.fill(18, 20)).to.equal(1)
			expect(WashMeter.fill(20, 20)).to.equal(1)
			expect(WashMeter.fill(0 / 0, 20)).to.equal(0)
			expect(WashMeter.fill(3, 6, 1)).to.equal(0.5)
		end)

		it("is full only at the needed count", function()
			expect(WashMeter.full(17, 20)).to.equal(false)
			expect(WashMeter.full(18, 20)).to.equal(true)
		end)
	end)
end
