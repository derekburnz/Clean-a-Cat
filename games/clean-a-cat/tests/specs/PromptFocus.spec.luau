--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PromptFocus = require(Client:WaitForChild("Spa"):WaitForChild("PromptFocus"))
	local Ledger = PromptFocus.Ledger

	describe("PromptFocus.Ledger", function()
		it("gives each held prompt its own reach back", function()
			local ledger = Ledger.new()
			expect(Ledger.mute(ledger, "buySoap", 8)).to.equal(true)
			expect(Ledger.mute(ledger, "bell", 10)).to.equal(true)
			expect(Ledger.mute(ledger, "buySoap", 0)).to.equal(false) -- held already: keeps the first reach
			local back = Ledger.release(ledger)
			expect(back.buySoap).to.equal(8)
			expect(back.bell).to.equal(10)
			expect(next(Ledger.release(ledger))).to.equal(nil)
		end)

		it("leaves a prompt with no reach alone", function()
			local ledger = Ledger.new()
			expect(Ledger.mute(ledger, "hidden", 0)).to.equal(false)
			expect(next(Ledger.release(ledger))).to.equal(nil)
		end)

		it("keeps a reach its owner set during the hold", function()
			expect(Ledger.restoreTo(8, 0)).to.equal(8)
			expect(Ledger.restoreTo(8, 12)).to.equal(12)
		end)
	end)
end
