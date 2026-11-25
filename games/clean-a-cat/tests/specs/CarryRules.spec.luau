--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryRules = require(Shared:WaitForChild("CarryRules"))

return function()
	local function on(_flag: string): boolean
		return true
	end
	local function off(_flag: string): boolean
		return false
	end
	local function only(name: string): (string) -> boolean
		return function(flag: string): boolean
			return flag == name
		end
	end

	describe("CarryRules.carried", function()
		it("carries a customer's cat while both switches are on", function()
			expect(CarryRules.carried("Smudge", nil, nil, on)).to.equal(true)
		end)

		it("never carries with either switch off", function()
			expect(CarryRules.carried("Smudge", nil, nil, off)).to.equal(false)
			expect(CarryRules.carried("Smudge", nil, nil, only(CarryRules.FLAG))).to.equal(false)
			expect(CarryRules.carried("Smudge", nil, nil, only(CarryRules.CUSTOMERS_FLAG))).to.equal(
				false
			)
		end)

		it("never carries a stray, the opening's kitten or the prototype's cat", function()
			expect(CarryRules.carried("Smudge", true, nil, on)).to.equal(false)
			expect(CarryRules.carried("Suds", nil, true, on)).to.equal(false)
			expect(CarryRules.carried(nil, nil, nil, on)).to.equal(false)
		end)
	end)

	describe("CarryRules.within", function()
		it("measures along the ground only", function()
			expect(CarryRules.within(Vector3.new(3, 50, 4), Vector3.zero, 5)).to.equal(true)
			expect(CarryRules.within(Vector3.new(3, 0, 4.1), Vector3.zero, 5)).to.equal(false)
		end)
	end)

	describe("CarryRules.modelName", function()
		it("carries the sitting body, or the dirty body when there is none", function()
			local function has(name: string): boolean
				return name == "CleanACat_Cat_Smudge_Dirty_Sit"
			end
			expect(CarryRules.modelName("Smudge", has)).to.equal("CleanACat_Cat_Smudge_Dirty_Sit")
			expect(CarryRules.modelName("Cotton", has)).to.equal("CleanACat_Cat_Cotton_Dirty")
		end)
	end)

	describe("CarryRules.shownLine", function()
		it("puts the customer still holding the cat at the front", function()
			local kinds, needs = CarryRules.shownLine(
				{ "B", "C" },
				{ { "mud" }, {} },
				"door",
				"A",
				{ "smell" }
			)
			expect(#kinds).to.equal(3)
			expect(kinds[1]).to.equal("A")
			expect(kinds[2]).to.equal("B")
			expect(needs[1][1]).to.equal("smell")
			expect(#needs).to.equal(3)
		end)

		it("shows the line as it is once the cat is taken or with no carry", function()
			local line = { "B", "C" }
			local kinds = CarryRules.shownLine(line, { {}, {} }, "arms", "A", {})
			expect(#kinds).to.equal(2)
			expect(kinds[1]).to.equal("B")
			local same = CarryRules.shownLine(line, { {}, {} }, nil, nil, nil)
			expect(same).never.to.equal(line) -- a copy
			expect(#same).to.equal(2)
		end)
	end)
end
