--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StandRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StandRules"))

return function()
	describe("StandRules.rootHeight", function()
		it(
			"stands a default R6 body with its root 3 studs up (2 stud legs, a 2 stud root)",
			function()
				expect(StandRules.rootHeight(false, 0, 2)).to.equal(3)
			end
		)

		it("stands an R15 body HipHeight below its root part", function()
			expect(StandRules.rootHeight(true, 2, 2)).to.equal(3)
			expect(StandRules.rootHeight(true, 1.35, 2)).to.equal(2.35)
		end)

		it("adds an R6 body's HipHeight on top of its legs", function()
			expect(StandRules.rootHeight(false, 0.5, 2)).to.equal(3.5)
		end)
	end)
end
