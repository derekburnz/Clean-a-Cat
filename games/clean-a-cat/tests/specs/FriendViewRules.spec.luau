--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FriendViewRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FriendViewRules"))

return function()
	describe("FriendViewRules.chipText", function()
		it("shows nothing with no friends or no count", function()
			expect(FriendViewRules.chipText(nil)).to.equal(nil)
			expect(FriendViewRules.chipText(0)).to.equal(nil)
			expect(FriendViewRules.chipText(0 / 0)).to.equal(nil)
			expect(FriendViewRules.chipText("2")).to.equal(nil)
		end)

		it("says the friends and the bonus, held at 30%", function()
			expect(FriendViewRules.chipText(1)).to.equal("1 friend · +10%")
			expect(FriendViewRules.chipText(2)).to.equal("2 friends · +20%")
			expect(FriendViewRules.chipText(5)).to.equal("5 friends · +30%")
		end)
	end)
end
