--!strict
return function()
	local TelemetryRules = require(game:GetService("ReplicatedStorage").Shared.TelemetryRules)

	describe("TelemetryRules", function()
		it("takes lower case names only", function()
			expect(TelemetryRules.validName("shop_opened")).to.equal(true)
			expect(TelemetryRules.validName("ShopOpened")).to.equal(false)
			expect(TelemetryRules.validName("")).to.equal(false)
		end)

		it("refuses a 4th custom field, which Roblox would drop", function()
			local fields, reason = TelemetryRules.fields({ "a", "b", "c", "d" })
			expect(fields).to.equal(nil)
			expect(reason).to.be.a("string")
		end)

		it("names the fields CustomField01 to 03 and cleans them", function()
			local fields = TelemetryRules.fields({ "phone", "tier<2>" }) :: any
			expect(fields.CustomField01).to.equal("phone")
			expect(fields.CustomField02).to.equal("tier2")
			expect(fields.CustomField03).to.equal(nil)
		end)
	end)

	describe("TelemetryRules onboarding funnel", function()
		it("logs each step once per save", function()
			local logged: { [string]: boolean } = {}
			expect(TelemetryRules.markOnce(logged, "onboarding_v1:3")).to.equal(true)
			expect(TelemetryRules.markOnce(logged, "onboarding_v1:3")).to.equal(false)
			expect(TelemetryRules.markOnce(logged, "onboarding_v1:4")).to.equal(true)
			expect(logged["onboarding_v1:3"]).to.equal(true)
		end)

		it("numbers the steps in order and has a valid name for each", function()
			expect(TelemetryRules.stepNumber("joined")).to.equal(1)
			expect(TelemetryRules.stepNumber("first_move")).to.equal(3)
			expect(TelemetryRules.stepNumber("first_scrub")).to.equal(4)
			expect(TelemetryRules.stepNumber("first_upgrade")).to.equal(8)
			expect(TelemetryRules.stepNumber("first_long_build_started")).to.equal(10)
			expect(#TelemetryRules.ONBOARDING_STEPS).to.equal(10)
			expect(TelemetryRules.stepNumber("first_win")).to.equal(nil)
			expect(TelemetryRules.validName(TelemetryRules.ONBOARDING)).to.equal(true)
			for _, name in TelemetryRules.ONBOARDING_STEPS do
				expect(TelemetryRules.validName(name)).to.equal(true)
			end
			for _, name in TelemetryRules.CLIENT_STEPS do
				expect(TelemetryRules.stepNumber(name)).to.be.ok()
			end
		end)

		it("keeps saves from before the switch out of the funnel", function()
			expect(TelemetryRules.inFunnel({}, 1, 0)).to.equal(true) -- a brand new save joins
			expect(TelemetryRules.inFunnel({}, 1, 120)).to.equal(false) -- an older save does not
			expect(TelemetryRules.inFunnel({}, 3, 0)).to.equal(false) -- no joined, no later steps
			expect(TelemetryRules.inFunnel({ ["onboarding_v1:1"] = true }, 3, 500)).to.equal(true)
		end)

		it("finds the highest step logged, for left_at", function()
			expect(TelemetryRules.lastStep({})).to.equal(0)
			local step, name =
				TelemetryRules.lastStep({ ["onboarding_v1:1"] = true, ["onboarding_v1:5"] = true })
			expect(step).to.equal(5)
			expect(name).to.equal("first_reveal")
		end)

		it("counts day 2 as the next UTC day after the first join", function()
			local day = TelemetryRules.DAY_SECONDS
			local joined = 10 * day + 23 * 3600 -- late on day 10
			expect(TelemetryRules.isDay2(joined, joined + 3600)).to.equal(true) -- an hour later, day 11
			expect(TelemetryRules.isDay2(joined, joined + 600)).to.equal(false) -- still day 10
			expect(TelemetryRules.isDay2(joined, joined + 2 * day)).to.equal(false) -- day 12
		end)
	end)

	describe("TelemetryRules playtime funnel", function()
		it(
			"has a valid name for the funnel and every mark, moved first and the rest in time order",
			function()
				expect(TelemetryRules.validName(TelemetryRules.PLAYTIME)).to.equal(true)
				expect(TelemetryRules.PLAYTIME_MARKS[1].name).to.equal("moved")
				expect(TelemetryRules.PLAYTIME_MARKS[1].seconds).to.equal(nil)
				local last = 0
				for step, mark in TelemetryRules.PLAYTIME_MARKS do
					expect(TelemetryRules.validName(mark.name)).to.equal(true)
					local seconds = mark.seconds
					if step > 1 then
						expect(seconds ~= nil and seconds > last).to.equal(true)
						last = seconds or last
					end
				end
				expect(last).to.equal(3600)
			end
		)

		it("lists the marks a session has passed and not logged, never moved", function()
			expect(#TelemetryRules.playtimeDue(10, {})).to.equal(0)
			local due = TelemetryRules.playtimeDue(65, {})
			expect(#due).to.equal(2)
			expect(due[1]).to.equal(2) -- sec_30
			expect(due[2]).to.equal(3) -- min_1
			local later = TelemetryRules.playtimeDue(65, { [2] = true })
			expect(#later).to.equal(1)
			expect(later[1]).to.equal(3)
			expect(#TelemetryRules.playtimeDue(99999, {})).to.equal(
				#TelemetryRules.PLAYTIME_MARKS - 1
			)
		end)
	end)

	describe("TelemetryRules client side events", function()
		it("takes only the listed names and details", function()
			expect(TelemetryRules.clientEvent("hint_shown", "pick")).to.equal(true)
			expect(TelemetryRules.clientEvent("hint_followed_10s", "wash")).to.equal(true)
			expect(TelemetryRules.clientEvent("window_opened", "CatIndex")).to.equal(true)
			expect(TelemetryRules.clientEvent("window_opened", "Shop")).to.equal(false)
			expect(TelemetryRules.clientEvent("hint_shown", "Settings")).to.equal(false)
			expect(TelemetryRules.clientEvent("left_at", "pick")).to.equal(false)
			expect(TelemetryRules.clientEvent("hint_shown", 1)).to.equal(false)
			expect(TelemetryRules.clientEvent(nil, "pick")).to.equal(false)
			for name in TelemetryRules.CLIENT_EVENTS do
				expect(TelemetryRules.validName(name)).to.equal(true)
			end
		end)
	end)
end
