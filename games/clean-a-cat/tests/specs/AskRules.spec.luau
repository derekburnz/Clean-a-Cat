--!strict
return function()
	local AskRules = require(game:GetService("ReplicatedStorage").Shared.AskRules)

	describe("AskRules", function()
		it("shows one ask at a time, a minute apart", function()
			local q = AskRules.new()
			expect(AskRules.want(q, "notify", 0)).to.equal(true)
			expect(AskRules.want(q, "checkin", 0)).to.equal(true)
			expect(AskRules.pick(q, 0, true)).to.equal("notify")
			expect(AskRules.pick(q, 5, true)).to.equal(nil) -- notify is still up
			expect(AskRules.done(q, "notify", "yes", 10)).to.equal(true)
			expect(AskRules.pick(q, 69, true)).to.equal(nil) -- 59 s after the end
			expect(AskRules.pick(q, 70, true)).to.equal("checkin")
		end)

		it("waits for a free screen and never drops an ask", function()
			local q = AskRules.new()
			AskRules.want(q, "gift", 0)
			for t = 0, 600, 30 do
				expect(AskRules.pick(q, t, false)).to.equal(nil)
			end
			expect(AskRules.pick(q, 630, true)).to.equal("gift")
		end)

		it("goes in IDS order, and wanting again keeps the place", function()
			local q = AskRules.new()
			AskRules.want(q, "menu_build", 0)
			AskRules.want(q, "checkin", 5)
			AskRules.want(q, "menu_build", 9)
			expect(q.waiting.menu_build).to.equal(0)
			expect(AskRules.pick(q, 10, true)).to.equal("checkin")
		end)

		it("takes an ask now only when nothing is up and the gap is over", function()
			local q = AskRules.new()
			expect(AskRules.takeNow(q, "bubble", 0)).to.equal(true)
			expect(q.shown).to.equal("bubble")
			expect(AskRules.takeNow(q, "checkin", 1)).to.equal(false) -- the bubble is up
			AskRules.done(q, "bubble", "closed", 6)
			expect(AskRules.takeNow(q, "bubble", 30)).to.equal(false) -- inside the minute
			AskRules.want(q, "bubble", 30)
			expect(AskRules.takeNow(q, "bubble", 66)).to.equal(true)
			expect(q.waiting.bubble).to.equal(nil)
			expect(AskRules.takeNow(q, "nope", 200)).to.equal(false)
		end)

		it("skips an ask that had nothing to show without starting the gap", function()
			local q = AskRules.new()
			AskRules.want(q, "bubble", 0)
			AskRules.want(q, "menu_build", 0)
			expect(AskRules.pick(q, 0, true)).to.equal("bubble")
			expect(AskRules.skip(q, "bubble")).to.equal(true)
			expect(AskRules.skip(q, "bubble")).to.equal(false)
			expect(AskRules.pick(q, 1, true)).to.equal("menu_build")
		end)

		it("takes a no as final for the visit", function()
			local q = AskRules.new()
			AskRules.want(q, "favourite", 0)
			expect(AskRules.pick(q, 0, true)).to.equal("favourite")
			AskRules.done(q, "favourite", "no", 3)
			expect(AskRules.want(q, "favourite", 100)).to.equal(false)
			expect(AskRules.pick(q, 200, true)).to.equal(nil)
			-- a closed ask may come back
			AskRules.want(q, "checkin", 200)
			expect(AskRules.pick(q, 200, true)).to.equal("checkin")
			AskRules.done(q, "checkin", "closed", 201)
			expect(AskRules.want(q, "checkin", 300)).to.equal(true)
		end)

		it("lets a quiet ask through without the gap, and it ends as it shows", function()
			local q = AskRules.new()
			AskRules.want(q, "notify", 0)
			AskRules.pick(q, 0, true)
			AskRules.want(q, "starterButton", 1)
			expect(AskRules.pick(q, 2, true)).to.equal(nil) -- not over another ask
			AskRules.done(q, "notify", "closed", 4)
			expect(AskRules.pick(q, 5, true)).to.equal("starterButton")
			expect(q.shown).to.equal(nil)
			expect(q.lastEnd).to.equal(4) -- the gap still counts from notify
		end)

		it("ignores unknown ids and moves on from a stale ask", function()
			local q = AskRules.new()
			expect(AskRules.want(q, "nope", 0)).to.equal(false)
			AskRules.want(q, "notify", 0)
			AskRules.pick(q, 0, true)
			expect(AskRules.stale(q, AskRules.MAX_SHOWN - 1)).to.equal(false)
			expect(AskRules.stale(q, AskRules.MAX_SHOWN)).to.equal(true)
			expect(AskRules.done(q, "checkin", "yes", 1)).to.equal(false)
		end)
	end)
end
