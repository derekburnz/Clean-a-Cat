--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Wallet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wallet"))

return function()
	describe("Wallet.format", function()
		it("groups thousands with commas below a million", function()
			expect(Wallet.format(0)).to.equal("0")
			expect(Wallet.format(7)).to.equal("7")
			expect(Wallet.format(999)).to.equal("999")
			expect(Wallet.format(1240)).to.equal("1,240")
			expect(Wallet.format(999999)).to.equal("999,999")
		end)

		it("shows a short count from a million, rounded down", function()
			expect(Wallet.format(1_000_000)).to.equal("1M")
			expect(Wallet.format(1_250_000)).to.equal("1.2M")
			expect(Wallet.format(1_999_999)).to.equal("1.9M")
			expect(Wallet.format(3_400_000_000)).to.equal("3.4B")
			expect(Wallet.format(12_000_000_000_000)).to.equal("12T")
		end)

		it("reads a bad value as 0 and drops fractions", function()
			expect(Wallet.format(-5)).to.equal("0")
			expect(Wallet.format(0 / 0)).to.equal("0")
			expect(Wallet.format(nil)).to.equal("0")
			expect(Wallet.format("12")).to.equal("0")
			expect(Wallet.format(12.9)).to.equal("12")
		end)
	end)
end
