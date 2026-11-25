--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PromptFocus = require(Client:WaitForChild("Spa"):WaitForChild("PromptFocus"))
	local Ledger = PromptFocus.Ledger

	describe("PromptFocus.Ledger", function()
		it("gives back what each owner had", function()
			local ledger = Ledger.new()
			expect(Ledger.mute(ledger, "buySoap", true)).to.equal(true)
			expect(Ledger.mute(ledger, "ownedBrush", false)).to.equal(true)
			expect(Ledger.mute(ledger, "buySoap", false)).to.equal(false) -- held already: keeps the first
			local back = Ledger.release(ledger)
			expect(back.buySoap).to.equal(true)
			expect(back.ownedBrush).to.equal(false)
			expect(next(Ledger.release(ledger))).to.equal(nil)
		end)

		it("keeps an owner's change during the hold, not our own writes", function()
			local ledger = Ledger.new()
			Ledger.mute(ledger, "buySoap", true)
			-- our write switching it off is not the owner's
			ledger.writing.buySoap = true
			expect(Ledger.changed(ledger, "buySoap", false)).to.equal(false)
			ledger.writing.buySoap = nil
			-- the tool was bought meanwhile: its owner switched the prompt off
			expect(Ledger.changed(ledger, "buySoap", false)).to.equal(true)
			-- a build board's bell came on meanwhile
			Ledger.mute(ledger, "bell", false)
			expect(Ledger.changed(ledger, "bell", true)).to.equal(true)
			local back = Ledger.release(ledger)
			expect(back.buySoap).to.equal(false)
			expect(back.bell).to.equal(true)
		end)

		it("ignores a prompt it never held", function()
			local ledger = Ledger.new()
			expect(Ledger.changed(ledger, "other", true)).to.equal(false)
			expect(next(Ledger.release(ledger))).to.equal(nil)
		end)
	end)
end
