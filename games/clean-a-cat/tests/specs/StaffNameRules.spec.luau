--!strict
return function()
	local StaffNameRules = require(game:GetService("ReplicatedStorage").Shared.StaffNameRules)

	describe("StaffNameRules", function()
		it("trims, collapses spaces and keeps letters, numbers and spaces", function()
			expect(StaffNameRules.clean("  Mister   Bubbles  ")).to.equal("Mister Bubbles")
			expect(StaffNameRules.clean("Jo!!<b>2</b>")).to.equal("Job2b")
			expect(StaffNameRules.clean("   ")).to.equal("")
		end)

		it("cuts at 16 characters and refuses what is not a name", function()
			expect(StaffNameRules.clean("abcdefghijklmnopqrstuvwxyz")).to.equal("abcdefghijklmnop")
			expect(StaffNameRules.clean("abcdefghijklmno pq")).to.equal("abcdefghijklmno") -- no space left at the end
			expect(StaffNameRules.clean(12)).to.equal(nil)
			expect(StaffNameRules.clean(string.rep("a", 101))).to.equal(nil)
		end)

		it("shows the default for an empty, failed or hidden name", function()
			expect(StaffNameRules.shown("Fluff", "Fluff", "Jo")).to.equal("Fluff")
			expect(StaffNameRules.shown("", "", "Jo")).to.equal("Jo")
			expect(StaffNameRules.shown("Fluff", nil, "Sam")).to.equal("Sam")
			expect(StaffNameRules.shown("Rude", "####", "Lou")).to.equal("Lou")
		end)
	end)
end
