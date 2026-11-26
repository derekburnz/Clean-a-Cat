--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GiftViewRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GiftViewRules"))

local function state(favourite: boolean, group: boolean, claimed: boolean?): GiftViewRules.State
	return { lit = true, favourite = favourite, group = group, claimed = claimed == true }
end

return function()
	describe("GiftViewRules.steps", function()
		it(
			"asks for the favourite and the group with buttons, and the like in words only",
			function()
				local steps = GiftViewRules.steps(state(false, false))
				expect(#steps).to.equal(3)
				expect(steps[1].key).to.equal("favourite")
				expect(steps[1].action).to.equal("Favourite")
				expect(steps[2].action).to.equal("Join")
				expect(steps[3].key).to.equal("like")
				expect(steps[3].action).to.equal(nil)
				expect(steps[3].done).to.equal(false)
			end
		)

		it("ticks a step the server has and drops its button", function()
			local steps = GiftViewRules.steps(state(true, false))
			expect(steps[1].done).to.equal(true)
			expect(steps[1].action).to.equal(nil)
			expect(steps[2].done).to.equal(false)
		end)

		it("never ticks the like", function()
			local steps = GiftViewRules.steps(state(true, true, true))
			expect(steps[3].done).to.equal(false)
		end)
	end)

	describe("GiftViewRules.ready", function()
		it("needs both checked steps, never the like, and only once", function()
			expect(GiftViewRules.ready(state(false, true))).to.equal(false)
			expect(GiftViewRules.ready(state(true, false))).to.equal(false)
			expect(GiftViewRules.ready(state(true, true))).to.equal(true)
			expect(GiftViewRules.ready(state(true, true, true))).to.equal(false)
		end)

		it("says how many steps are left in plain words", function()
			expect(GiftViewRules.waitLine(state(false, false))).to.equal("Two steps to go")
			expect(GiftViewRules.waitLine(state(true, false))).to.equal("One step to go")
			expect(GiftViewRules.waitLine(state(true, true))).to.equal(nil)
			expect(GiftViewRules.claimText(state(true, true))).to.equal("Get Starcoat")
			expect(GiftViewRules.claimText(state(true, true, true))).to.equal("Starcoat is yours!")
		end)
	end)
end
