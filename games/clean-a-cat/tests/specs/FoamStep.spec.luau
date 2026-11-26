--!strict
return function()
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
	local WashDraft = require(game:GetService("ReplicatedStorage").Shared.WashDraft)

	describe("Foam up the cat (foamStep)", function()
		it("ships behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, WashDraft.FOAM_FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[WashDraft.FOAM_FLAG]).to.equal(true)
		end)

		it("names the step Foam up the cat only while the switch is on", function()
			local on = WashDraft.bathSay(function(key: string): boolean
				return key == WashDraft.FOAM_FLAG
			end)
			expect(on.bath).to.equal("Foam up the cat")
			expect(on.bathHint).to.equal("Rub the soap on")
			local off = WashDraft.bathSay(function(): boolean
				return false
			end)
			expect(off.bath).to.equal(WashDraft.SAY.bath)
		end)
	end)
end
