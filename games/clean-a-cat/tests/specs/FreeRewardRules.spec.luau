--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local FreeRewardRules = require(Shared:WaitForChild("FreeRewardRules"))

return function()
	describe("FreeRewardRules", function()
		it(
			"gives the like gift LIKE_WAIT seconds after the ask, whether or not anyone liked",
			function()
				local wait = FreeRewardRules.LIKE_WAIT
				expect(FreeRewardRules.canClaim("like", false, 0, 0, 1000)).to.equal(false)
				expect(FreeRewardRules.canClaim("like", false, 1000, 0, 1000 + wait - 1)).to.equal(
					false
				)
				expect(FreeRewardRules.canClaim("like", false, 1000, 0, 1000 + wait)).to.equal(true)
				expect(FreeRewardRules.canClaim("like", true, 1000, 0, 5000)).to.equal(false)
				expect(FreeRewardRules.likeReadyAt(0)).to.equal(nil)
				expect(FreeRewardRules.likeReadyAt(0 / 0)).to.equal(nil)
			end
		)

		it("gives the play gift after 30 minutes of play, once", function()
			local goal = FreeRewardRules.PLAY_SECONDS
			expect(goal).to.equal(1800)
			expect(FreeRewardRules.canClaim("play", false, 0, goal - 1, 0)).to.equal(false)
			expect(FreeRewardRules.canClaim("play", false, 0, goal, 0)).to.equal(true)
			expect(FreeRewardRules.canClaim("play", true, 0, goal * 2, 0)).to.equal(false)
			expect(FreeRewardRules.canClaim("play", false, 0, 0 / 0, 0)).to.equal(false)
			expect(FreeRewardRules.canClaim("follow", false, 1, 99999, 99999)).to.equal(false)
		end)

		it("pays from the economy that exists", function()
			expect(table.find(CrateRules.KINDS, FreeRewardRules.PLAY_CRATE) ~= nil).to.equal(true)
			expect(FreeRewardRules.LIKE_COINS > 0).to.equal(true)
		end)
	end)
end
