--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local BubbleWipe = require(Client:WaitForChild("Effects"):WaitForChild("BubbleWipe")) :: any

	describe("BubbleWipe.grow", function()
		it("starts empty and every column is full when covered", function()
			for column = 1, BubbleWipe.COLUMNS do
				expect(BubbleWipe.grow(0, column) <= 1e-6 or column == 1).to.equal(true)
				expect(BubbleWipe.grow(BubbleWipe.COVER, column) >= 1).to.equal(true)
			end
			expect(BubbleWipe.covered(BubbleWipe.COVER)).to.equal(true)
			expect(BubbleWipe.covered(BubbleWipe.COVER - 0.01)).to.equal(false)
		end)
		it("sweeps from the left: a left column is ahead of a right one", function()
			local t = BubbleWipe.COVER / 2
			expect(BubbleWipe.grow(t, 1) > BubbleWipe.grow(t, BubbleWipe.COLUMNS)).to.equal(true)
		end)
		it("never overshoots past OVER", function()
			for i = 0, 60 do
				expect(BubbleWipe.grow(i * 0.005, 1) <= BubbleWipe.OVER + 1e-6).to.equal(true)
			end
		end)
	end)

	describe("BubbleWipe.shrink", function()
		it("goes from full to gone in the same direction", function()
			expect(BubbleWipe.shrink(0, 1)).to.equal(1)
			local t = BubbleWipe.UNCOVER / 2
			expect(BubbleWipe.shrink(t, 1) < BubbleWipe.shrink(t, BubbleWipe.COLUMNS)).to.equal(
				true
			)
			for column = 1, BubbleWipe.COLUMNS do
				expect(BubbleWipe.shrink(BubbleWipe.UNCOVER, column)).to.equal(0)
			end
		end)
	end)

	it("is quick: in and out each within 0.3 s", function()
		expect(BubbleWipe.COVER <= 0.3 and BubbleWipe.UNCOVER <= 0.3).to.equal(true)
	end)
end
