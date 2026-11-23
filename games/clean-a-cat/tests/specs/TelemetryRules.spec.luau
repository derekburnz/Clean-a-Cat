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
			expect(TelemetryRules.stepNumber("first_scrub")).to.equal(3)
			expect(TelemetryRules.stepNumber("dryer_built")).to.equal(10)
			expect(TelemetryRules.stepNumber("first_win")).to.equal(nil)
			expect(TelemetryRules.validName(TelemetryRules.ONBOARDING)).to.equal(true)
			for _, name in TelemetryRules.ONBOARDING_STEPS do
				expect(TelemetryRules.validName(name)).to.equal(true)
			end
			for _, name in TelemetryRules.CLIENT_STEPS do
				expect(TelemetryRules.stepNumber(name)).to.be.ok()
			end
		end)

		it("finds the highest step logged, for left_at", function()
			expect(TelemetryRules.lastStep({})).to.equal(0)
			local step, name =
				TelemetryRules.lastStep({ ["onboarding_v1:1"] = true, ["onboarding_v1:4"] = true })
			expect(step).to.equal(4)
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
end
