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

		describe("hotelNotify", function()
			local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)

			it("is a switch, off by default, with a string slot for dev and live", function()
				expect(table.find(LiveFlags.KEYS, NotifyRules.HOTEL_FLAG)).to.be.ok()
				expect(LiveFlags.OFF_BY_DEFAULT[NotifyRules.HOTEL_FLAG]).to.equal(true)
				expect(type(NotifyRules.HOTEL_MESSAGE_IDS[10778775478])).to.equal("string")
				expect(type(NotifyRules.HOTEL_MESSAGE_IDS[10778773655])).to.equal("string")
				expect(NotifyRules.messageId(nil, 10778775478)).to.equal(
					NotifyRules.MESSAGE_IDS[10778775478]
				)
				expect(NotifyRules.messageId(nil, 1)).to.equal("")
			end)

			it("queues the hotel for when its last guest is ready", function()
				expect(NotifyRules.hotelDueAtLeave({}, 100)).to.equal(nil)
				local stays = {
					["1"] = { endsAt = 4000 },
					["2"] = { endsAt = 9000 },
					["3"] = { endsAt = 50 },
				}
				local due = NotifyRules.hotelDueAtLeave(stays, 100) :: NotifyRules.Due
				expect(due.kind).to.equal(NotifyRules.HOTEL_KIND)
				expect(due.item).to.equal(NotifyRules.HOTEL_ITEM)
				expect(due.endsAt).to.equal(9000)
				expect(NotifyRules.hotelDueAtLeave(stays, 9000)).to.equal(nil) -- all ready already
			end)

			it("queues only the message that comes first", function()
				local build: NotifyRules.Due = { item = "VipRoom", endsAt = 30000, kind = nil }
				local hotel: NotifyRules.Due =
					{ item = NotifyRules.HOTEL_ITEM, endsAt = 9000, kind = NotifyRules.HOTEL_KIND }
				expect(NotifyRules.first(build, hotel)).to.equal(hotel)
				expect(NotifyRules.first(build, nil)).to.equal(build)
				expect(NotifyRules.first(nil, hotel)).to.equal(hotel)
				expect(NotifyRules.first(nil, nil)).to.equal(nil)
			end)

			it("reads a queued hotel message back through a check", function()
				local due = NotifyRules.cleanDue({
					item = NotifyRules.HOTEL_ITEM,
					endsAt = 77,
					kind = NotifyRules.HOTEL_KIND,
				}) :: NotifyRules.Due
				expect(due.kind).to.equal(NotifyRules.HOTEL_KIND)
				expect(due.endsAt).to.equal(77)
				expect(NotifyRules.cleanDue({
					item = "VipRoom",
					endsAt = 77,
					kind = NotifyRules.HOTEL_KIND,
				})).to.equal(nil)
				expect(NotifyRules.cleanDue({ item = "VipRoom", endsAt = 77, kind = "other" })).to.equal(
					nil
				)
			end)
		end)
	end)
end
