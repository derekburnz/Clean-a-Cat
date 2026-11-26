--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Passes = require(Shared:WaitForChild("Passes"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local StarterRules = require(Shared:WaitForChild("StarterRules"))

local function none(_key: string): boolean
	return false
end

return function()
	describe("StarterRules", function()
		it("holds three real passes and nothing random", function()
			expect(#StarterRules.CONTENTS).to.equal(3)
			for _, key in StarterRules.CONTENTS do
				expect(Passes.IDS[key]).to.be.ok()
			end
			expect(StarterRules.SHOW_FROM).to.equal(SpaRules.TUTORIAL_ENDS_AT)
		end)

		it("is offered from the tutorial's end until its end, and never after", function()
			local ends = 100000
			expect(StarterRules.offered(ends, 1000, StarterRules.SHOW_FROM - 1, none)).to.equal(
				false
			)
			expect(StarterRules.offered(ends, 1000, StarterRules.SHOW_FROM, none)).to.equal(true)
			expect(StarterRules.offered(ends, ends - 1, 9999, none)).to.equal(true)
			expect(StarterRules.offered(ends, ends, 9999, none)).to.equal(false)
			expect(StarterRules.offered(0, 1000, 9999, none)).to.equal(false) -- never stamped
		end)

		it("is hidden from a player who owns any one of the three", function()
			for _, key in StarterRules.CONTENTS do
				local owns = function(k: string): boolean
					return k == key
				end
				expect(StarterRules.offered(100000, 1000, 9999, owns)).to.equal(false)
			end
			local lou = function(k: string): boolean
				return k == "Lou"
			end
			expect(StarterRules.offered(100000, 1000, 9999, lou)).to.equal(true)
		end)

		it("counts whole hours since the offer started", function()
			local length = 72 * 3600
			expect(StarterRules.hoursIn(length, 0, length)).to.equal(0)
			expect(StarterRules.hoursIn(length + 1000, 1000 + 2 * 3600 + 5, length)).to.equal(2)
		end)
	end)
end
