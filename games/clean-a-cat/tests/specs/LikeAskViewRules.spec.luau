--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LikeAskViewRules = require(Shared:WaitForChild("LikeAskViewRules"))

return function()
	describe("LikeAskViewRules", function()
		it("opens with the moment the server names, else a plain line", function()
			expect(LikeAskViewRules.bubble("special").title).to.equal("What a special visitor!")
			expect(LikeAskViewRules.bubble("purchase").title).to.equal("Hope you love it!")
			expect(LikeAskViewRules.bubble("nope").title).to.equal(LikeAskViewRules.DEFAULT_TITLE)
			expect(LikeAskViewRules.bubble(nil).title).to.equal(LikeAskViewRules.DEFAULT_TITLE)
		end)

		it("never names a reward on the ask (issue 748)", function()
			for moment in LikeAskViewRules.TITLES do
				local bubble = LikeAskViewRules.bubble(moment)
				for _, words in { bubble.title, bubble.line, bubble.button or "" } do
					expect(string.find(string.lower(words), "coin", 1, true)).to.equal(nil)
					expect(string.find(string.lower(words), "gift", 1, true)).to.equal(nil)
					expect(string.find(string.lower(words), "free", 1, true)).to.equal(nil)
				end
			end
		end)

		it("sends yes for the button, no for the X, closed when it went by itself", function()
			expect(LikeAskViewRules.answer(true, false)).to.equal("yes")
			expect(LikeAskViewRules.answer(false, true)).to.equal("no")
			expect(LikeAskViewRules.answer(false, false)).to.equal("closed")
		end)
	end)
end
