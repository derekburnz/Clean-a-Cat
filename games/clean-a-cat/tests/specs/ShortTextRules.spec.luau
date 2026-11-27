--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShortTextRules = require(Shared:WaitForChild("ShortTextRules"))

return function()
	describe("ShortTextRules", function()
		it("cuts the long lines Derek named to their few words", function()
			expect(ShortTextRules.apply("Hire at their pad · 1,200 coins")).to.equal("1,200 coins")
			expect(ShortTextRules.apply("Comes with the Extra Worker pass")).to.equal(
				"Extra Worker pass"
			)
			expect(ShortTextRules.apply("Comes when Sam is hired")).to.equal("Hire Sam first")
			expect(ShortTextRules.apply("+8% tips or pay")).to.equal("+8%")
			expect(ShortTextRules.apply("Your next gift waits for the next day you play.")).to.equal(
				"Next gift tomorrow"
			)
			expect(ShortTextRules.apply("Gold sponge, +20% on hand washes")).to.equal(
				"+20% on hand washes"
			)
		end)

		it("hides the lines the picture and title already say", function()
			expect(ShortTextRules.apply("Double coins on cats you wash by hand")).to.equal("")
			expect(ShortTextRules.apply("So you can find the spa again")).to.equal("")
		end)

		it("keeps the odds and leaves every other line alone", function()
			expect(
				ShortTextRules.apply("The chances add up to 100%. Pets you already own are kept.")
			).to.equal("The chances add up to 100%")
			expect(ShortTextRules.apply("199 Robux · Get pack")).to.equal(nil)
			expect(ShortTextRules.apply("Level 3")).to.equal(nil)
			expect(ShortTextRules.apply("+8% tips, +30% pay")).to.equal(nil)
		end)
	end)
end
