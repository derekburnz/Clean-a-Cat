--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

return function()
	local function on(_flag: string): boolean
		return true
	end
	local function off(_flag: string): boolean
		return false
	end

	describe("SudsRules.isNext", function()
		it("gives a brand new save the kitten while the switch is on", function()
			expect(SudsRules.isNext(SudsRules.NONE, 0, 0, on)).to.equal(true)
		end)

		it("never gives him with the switch off", function()
			expect(SudsRules.isNext(SudsRules.NONE, 0, 0, off)).to.equal(false)
			expect(SudsRules.isNext(SudsRules.BOX, 0, 0, off)).to.equal(false)
		end)

		it("never gives an older save the kitten", function()
			expect(SudsRules.isNext(SudsRules.NONE, 1, 0, on)).to.equal(false)
			expect(SudsRules.isNext(SudsRules.NONE, 0, 1, on)).to.equal(false)
		end)

		it("brings him back after the box was opened, until he is washed", function()
			expect(SudsRules.isNext(SudsRules.BOX, 0, 0, on)).to.equal(true)
			expect(SudsRules.isNext(SudsRules.DONE, 0, 0, on)).to.equal(false)
		end)

		it("reads a damaged stage as never met", function()
			expect(SudsRules.cleanStage(0 / 0)).to.equal(SudsRules.NONE)
			expect(SudsRules.cleanStage(1.5)).to.equal(SudsRules.NONE)
			expect(SudsRules.cleanStage("2")).to.equal(SudsRules.NONE)
			expect(SudsRules.cleanStage(7)).to.equal(SudsRules.DONE)
			expect(SudsRules.cleanStage(-3)).to.equal(SudsRules.NONE)
		end)
	end)

	describe("SudsRules.asset", function()
		it("uses his own model when the place has it, else the stand-in's", function()
			local function has(name: string): boolean
				return name == "CleanACat_Cat_Suds_Dirty_Sit"
			end
			expect(SudsRules.asset("_Dirty_Sit", has)).to.equal("CleanACat_Cat_Suds_Dirty_Sit")
			expect(SudsRules.asset("_Sit", has)).to.equal(`CleanACat_Cat_{SudsRules.STAND_IN}_Sit`)
		end)
	end)

	describe("Suds and the roster", function()
		it("keeps him out of the Cat Index roster (Derek)", function()
			expect(CatRules.rarityOf(SudsRules.NAME)).to.equal(nil)
		end)

		it("stands in a roster cat while his models are missing", function()
			expect(CatRules.rarityOf(SudsRules.STAND_IN)).never.to.equal(nil)
		end)

		it("needs only the starting stations, so a new spa can wash him", function()
			expect(#CatRules.lockedNeeds(SudsRules.NEEDS, {})).to.equal(0)
		end)
	end)
end
