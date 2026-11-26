--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local WorkerBar = require(Client:WaitForChild("Effects"):WaitForChild("WorkerBar")) :: any

	describe("WorkerBar.ease", function()
		it("catches up toward the server's value without passing it", function()
			local shown = 0
			for _ = 1, 120 do
				shown = WorkerBar.ease(shown, 0.5, 1 / 60)
				expect(shown <= 0.5 + 1e-9).to.equal(true)
			end
			expect(math.abs(shown - 0.5) < 0.01).to.equal(true)
		end)
		it("moves at the same pace whatever the frame rate", function()
			local a, b = 0, 0
			for _ = 1, 30 do
				a = WorkerBar.ease(a, 1, 1 / 30)
			end
			for _ = 1, 60 do
				b = WorkerBar.ease(b, 1, 1 / 60)
			end
			expect(math.abs(a - b) < 1e-6).to.equal(true)
		end)
		it("starts over at once for a new cat and clamps its input", function()
			expect(WorkerBar.ease(0.8, 0.1, 1 / 60)).to.equal(0.1)
			expect(WorkerBar.ease(0.5, 3, 1000) <= 1).to.equal(true)
		end)
	end)

	describe("WorkerBar.popAt", function()
		it("gives one small pop and settles", function()
			expect(WorkerBar.popAt(0)).to.equal(1)
			local mid = WorkerBar.popAt(WorkerBar.POP_SECONDS / 2)
			expect(mid > 1.1 and mid <= 1.12 + 1e-9).to.equal(true)
			expect(WorkerBar.popAt(WorkerBar.POP_SECONDS)).to.equal(1)
		end)
	end)
end
