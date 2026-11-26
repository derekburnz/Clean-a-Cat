--!strict
return function()
	local LikeAskRules = require(game:GetService("ReplicatedStorage").Shared.LikeAskRules)
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
	local AskRules = require(game:GetService("ReplicatedStorage").Shared.AskRules)

	local function state(fields: { [string]: any }): any
		return {
			visit = fields.visit or 1,
			noVisit = fields.noVisit or 0,
			nos = fields.nos or 0,
			saidYes = fields.saidYes == true,
			inTutorial = fields.inTutorial == true,
			likePaid = fields.likePaid == true,
			askedThisVisit = fields.askedThisVisit == true,
			lastBadAt = fields.lastBadAt or -math.huge,
			now = fields.now or 1000,
		}
	end

	describe("LikeAskRules", function()
		it(
			"ships behind a switch that starts off, in the ask queue after the favourite ask",
			function()
				expect(table.find(LiveFlags.KEYS, LikeAskRules.FLAG)).to.be.ok()
				expect(LiveFlags.OFF_BY_DEFAULT[LikeAskRules.FLAG]).to.equal(true)
				local favourite = table.find(AskRules.IDS, "favourite") :: number
				-- two ids, so ask_shown and ask_answered split the purchase ask from the good moments (Growth)
				for _, id in { "likeAsk", "likeAskPurchase" } do
					local at = table.find(AskRules.IDS, id)
					expect(at).to.be.ok()
					expect((at :: number) > favourite).to.equal(true)
					expect(AskRules.QUIET[id]).to.equal(nil)
				end
			end
		)

		it(
			"never asks again after a yes or two nos, and never in the tutorial (Review-QA)",
			function()
				expect(LikeAskRules.blocked(state({ visit = 9, saidYes = true }))).to.equal(true)
				expect(LikeAskRules.blocked(state({ visit = 9, nos = 1, noVisit = 2 }))).to.equal(
					false
				)
				expect(
					LikeAskRules.blocked(
						state({ visit = 99, nos = LikeAskRules.MAX_NOS, noVisit = 2 })
					)
				).to.equal(true)
				expect(LikeAskRules.blocked(state({ inTutorial = true }))).to.equal(true)
				expect(LikeAskRules.blocked(state({}))).to.equal(false)
			end
		)

		it("takes only the good moments and the three answers", function()
			for _, moment in LikeAskRules.MOMENTS do
				expect(LikeAskRules.cleanMoment(moment)).to.equal(moment)
			end
			expect(LikeAskRules.cleanMoment("lost")).to.equal(nil)
			expect(LikeAskRules.cleanMoment(1)).to.equal(nil)
			expect(LikeAskRules.cleanAnswer("no")).to.equal("no")
			expect(LikeAskRules.cleanAnswer("closed")).to.equal("closed")
			expect(LikeAskRules.cleanAnswer("maybe")).to.equal(nil)
		end)

		it("asks once a visit, never once the like row is paid", function()
			expect(LikeAskRules.blocked(state({}))).to.equal(false)
			expect(LikeAskRules.blocked(state({ askedThisVisit = true }))).to.equal(true)
			expect(LikeAskRules.blocked(state({ likePaid = true }))).to.equal(true)
		end)

		it("waits three visits after a no", function()
			expect(LikeAskRules.blocked(state({ visit = 5, noVisit = 5 }))).to.equal(true)
			expect(LikeAskRules.blocked(state({ visit = 8, noVisit = 5 }))).to.equal(true)
			expect(LikeAskRules.blocked(state({ visit = 9, noVisit = 5 }))).to.equal(false)
		end)

		it("never asks within two minutes of a lost cat or a cancelled purchase", function()
			expect(LikeAskRules.blocked(state({ lastBadAt = 900, now = 1000 }))).to.equal(true)
			expect(LikeAskRules.blocked(state({ lastBadAt = 880, now = 1000 }))).to.equal(false)
		end)

		it("asks at once after a good moment, two minutes after a purchase", function()
			expect(LikeAskRules.dueAt("special", 50)).to.equal(50)
			expect(LikeAskRules.dueAt("stars", 50)).to.equal(50)
			expect(LikeAskRules.dueAt("purchase", 50, true)).to.equal(
				50 + LikeAskRules.PURCHASE_DELAY
			)
			expect(LikeAskRules.dueAt("purchase", 50, false)).to.equal(nil) -- its own switch off
			expect(LikeAskRules.dueAt("purchase", 50)).to.equal(nil)
			expect(table.find(LiveFlags.KEYS, LikeAskRules.PURCHASE_FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[LikeAskRules.PURCHASE_FLAG]).to.equal(true)
			expect(LikeAskRules.PURCHASE_DELAY >= 120).to.equal(true)
		end)
	end)
end
