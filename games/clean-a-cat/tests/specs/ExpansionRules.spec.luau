--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpansionRules = require(Shared:WaitForChild("ExpansionRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))

return function()
	describe("ExpansionRules", function()
		it("is off by default, and a new or old save starts locked", function()
			expect(LiveFlags.OFF_BY_DEFAULT[ExpansionRules.FLAG]).to.equal(true)
			expect(SaveSchema.template(0).expansionUnlocked).to.equal(false)
			local old =
				SaveSchema.migrate({ version = SaveSchema.VERSION, coins = 5 }, 0) :: SaveSchema.Save
			expect(old.expansionUnlocked).to.equal(false)
		end)

		it("unlocks once, for the price", function()
			expect(ExpansionRules.canUnlock(false, ExpansionRules.PRICE)).to.equal(true)
			local ok, reason = ExpansionRules.canUnlock(false, ExpansionRules.PRICE - 1)
			expect(ok).to.equal(false)
			expect(reason).to.equal("1 more coins to unlock")
			expect((ExpansionRules.canUnlock(true, 99999))).to.equal(false)
			expect(ExpansionRules.promptText()).to.equal(`Unlock · {ExpansionRules.PRICE} coins`)
		end)

		it("shows the Garden behind the door only once open and built", function()
			local function on(flag: string): boolean
				return flag == ExpansionRules.FLAG
			end
			local function off(_flag: string): boolean
				return false
			end
			expect(ExpansionRules.showGarden(off, false, false)).to.equal(true)
			expect(ExpansionRules.showGarden(on, false, true)).to.equal(false)
			expect(ExpansionRules.showGarden(on, true, false)).to.equal(false)
			expect(ExpansionRules.showGarden(on, true, true)).to.equal(true)
		end)
	end)
end
