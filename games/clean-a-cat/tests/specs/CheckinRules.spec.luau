--!strict
return function()
	local CheckinRules = require(game:GetService("ReplicatedStorage").Shared.CheckinRules)

	describe("CheckinRules", function()
		it("waits for 3:45 of play before the very first card", function()
			local card = { days = 0, lastDay = 0 }
			expect(CheckinRules.ready(card, 100, 200)).to.equal(nil)
			expect(CheckinRules.ready(card, 100, 225)).to.equal(1)
		end)

		it("gives one day a day, counting days played, not days in a row", function()
			local card = { days = 0, lastDay = 0 }
			local day, reward = CheckinRules.claim(card, 100, 300)
			expect(day).to.equal(1)
			expect((reward :: CheckinRules.Reward).coins).to.equal(50)
			expect(CheckinRules.claim(card, 100, 9999)).to.equal(nil) -- twice the same day: nothing
			expect(CheckinRules.ready(card, 100, 0)).to.equal(nil)
			-- a week away: the next day played is day 2, the good crate, and no play time is needed now
			day, reward = CheckinRules.claim(card, 107, 0)
			expect(day).to.equal(2)
			expect((reward :: CheckinRules.Reward).crate).to.equal("good")
		end)

		it("starts again after day 7 and never goes back in time", function()
			local card = { days = 7, lastDay = 50 }
			expect(CheckinRules.ready(card, 51, 0)).to.equal(1)
			expect(CheckinRules.ready(card, 49, 0)).to.equal(nil) -- a clock that went back
			expect(CheckinRules.nextDay({ days = 0 / 0, lastDay = 0 })).to.equal(1)
		end)

		it("has the tuning's seven rewards", function()
			local texts = {}
			for _, reward in CheckinRules.REWARDS do
				table.insert(texts, reward.text)
			end
			expect(table.concat(texts, ", ")).to.equal(
				"50 coins, Good crate, 100 coins, Silk bow, 200 coins, 300 coins, Crate"
			)
		end)
	end)
end
