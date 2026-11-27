--!strict
return function()
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
	local OutdoorWalkRules = require(game:GetService("ReplicatedStorage").Shared.OutdoorWalkRules)
	local SpaRules = require(game:GetService("ReplicatedStorage").Shared.SpaRules)

	describe("OutdoorWalkRules (outdoorWalk, issue 886)", function()
		it("ships behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, OutdoorWalkRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[OutdoorWalkRules.FLAG]).to.equal(true)
		end)

		it("ends the tutorial at its own play time", function()
			expect(OutdoorWalkRules.tutorialDone(SpaRules.TUTORIAL_ENDS_AT - 1)).to.equal(false)
			expect(OutdoorWalkRules.tutorialDone(SpaRules.TUTORIAL_ENDS_AT)).to.equal(true)
			expect(OutdoorWalkRules.tutorialDone(0 / 0)).to.equal(false)
		end)

		it("walks faster only outdoors after the tutorial", function()
			local fast, normal = OutdoorWalkRules.OUTDOOR_SPEED, OutdoorWalkRules.INDOOR_SPEED
			expect(fast > normal).to.equal(true)
			expect(OutdoorWalkRules.speedFor(true, false)).to.equal(fast)
			expect(OutdoorWalkRules.speedFor(true, true)).to.equal(normal)
			expect(OutdoorWalkRules.speedFor(false, false)).to.equal(normal)
			expect(OutdoorWalkRules.speedFor(false, true)).to.equal(normal)
		end)
	end)
end
