--!strict
return function()
	local NotifyRules = require(game:GetService("ReplicatedStorage").Shared.NotifyRules)

	describe("NotifyRules", function()
		it("lists a message id slot for the dev and the live experience", function()
			expect(type(NotifyRules.MESSAGE_IDS[10778775478])).to.equal("string")
			expect(type(NotifyRules.MESSAGE_IDS[10778773655])).to.equal("string")
		end)

		it("gives the bell only to builds of an hour or more", function()
			expect(NotifyRules.isLong("VipRoom")).to.equal(true)
			expect(NotifyRules.isLong("Dryer")).to.equal(false)
			expect(NotifyRules.isLong("Rocket")).to.equal(false)
		end)

		it("queues one message, for the long build that finishes last", function()
			expect(NotifyRules.dueAtLeave({}, 100)).to.equal(nil)
			local short = { station = { item = "Dryer", endsAt = 5000 } }
			expect(NotifyRules.dueAtLeave(short, 100)).to.equal(nil)
			local builds = {
				station = { item = "Dryer", endsAt = 90000 },
				room = { item = "VipRoom", endsAt = 30000 },
			}
			local due = NotifyRules.dueAtLeave(builds, 100) :: NotifyRules.Due
			expect(due.item).to.equal("VipRoom")
			expect(due.endsAt).to.equal(30000)
			expect(NotifyRules.dueAtLeave(builds, 30000)).to.equal(nil) -- already finished
		end)

		it("sends at most one message a day", function()
			local day = NotifyRules.DAY_SECONDS
			expect(NotifyRules.canSend(nil, 5 * day)).to.equal(true)
			expect(NotifyRules.canSend(5 * day + 10, 5 * day + 3600)).to.equal(false)
			expect(NotifyRules.canSend(5 * day + 10, 6 * day + 1)).to.equal(true)
		end)

		it("rounds the come back line up to whole hours", function()
			expect(NotifyRules.comeBackText(8 * 3600)).to.equal(
				"Ready in 8 h. Come back to see it!"
			)
			expect(NotifyRules.comeBackText(7 * 3600 + 1)).to.equal(
				"Ready in 8 h. Come back to see it!"
			)
			expect(NotifyRules.comeBackText(30)).to.equal("Ready in 1 h. Come back to see it!")
		end)

		it("reads a queued message back through a check", function()
			local due = NotifyRules.cleanDue({ item = "VipRoom", endsAt = 1234 }) :: NotifyRules.Due
			expect(due.endsAt).to.equal(1234)
			expect(NotifyRules.cleanDue({ item = "Dryer", endsAt = 1 })).to.equal(nil)
			expect(NotifyRules.cleanDue({ item = "VipRoom", endsAt = 0 / 0 })).to.equal(nil)
			expect(NotifyRules.cleanDue("junk")).to.equal(nil)
		end)
	end)
end
