--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LaterStepRules = require(Shared:WaitForChild("LaterStepRules"))
local WashDraft = require(Shared:WaitForChild("WashDraft"))

return function()
	local function on(_flag: string): boolean
		return true
	end
	local function off(_flag: string): boolean
		return false
	end

	describe("LaterStepRules.steps", function()
		it("takes the bath, then the claws, for a cat that needs both", function()
			local steps = LaterStepRules.steps(
				{ "mud", "tangles", "wet", "claws", "smell" },
				{},
				on
			)
			expect(table.concat(steps, ",")).to.equal("smell,claws")
		end)

		it("skips a need whose station is not built or whose switch is off", function()
			local needs = { "mud", "tangles", "wet", "smell", "claws" }
			expect(table.concat(LaterStepRules.steps(needs, { "claws" }, on), ",")).to.equal(
				"smell"
			)
			expect(#LaterStepRules.steps(needs, {}, off)).to.equal(0)
			local function clawsOnly(flag: string): boolean
				return flag == "pawdicure"
			end
			expect(table.concat(LaterStepRules.steps(needs, {}, clawsOnly), ",")).to.equal("claws")
		end)

		it("has no later step for a cat with only the first needs", function()
			expect(#LaterStepRules.steps({ "mud", "tangles", "wet" }, {}, on)).to.equal(0)
		end)
	end)

	describe("LaterStepRules.sudsGone and held", function()
		it("clears the suds in step with the swirl, all of them at the full swirl", function()
			expect(LaterStepRules.sudsGone(0, 6)).to.equal(0)
			expect(LaterStepRules.sudsGone(WashDraft.SWIRL_TRAVEL / 2, 6)).to.equal(3)
			expect(LaterStepRules.sudsGone(WashDraft.SWIRL_TRAVEL, 6)).to.equal(6)
			expect(LaterStepRules.sudsGone(WashDraft.SWIRL_TRAVEL * 5, 6)).to.equal(6)
			expect(LaterStepRules.sudsGone(5, 0)).to.equal(0)
		end)

		it("counts a hold once it lasts CLAW_HOLD", function()
			expect(LaterStepRules.held(10, 10 + WashDraft.CLAW_HOLD / 2)).to.equal(false)
			expect(LaterStepRules.held(10, 10 + WashDraft.CLAW_HOLD)).to.equal(true)
		end)
	end)
end
