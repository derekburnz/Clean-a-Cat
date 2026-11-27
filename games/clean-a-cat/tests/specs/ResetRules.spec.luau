--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local ResetRules = require(Shared:WaitForChild("ResetRules"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))

return function()
	describe("ResetRules", function()
		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[ResetRules.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, ResetRules.FLAG) ~= nil).to.equal(true)
		end)

		it("lets the dev game, Studio and the group's owner reset, nobody else", function()
			expect(ResetRules.allowed(2, 2, false, 0)).to.equal(true) -- the dev game
			expect(ResetRules.allowed(1, 2, true, 0)).to.equal(true) -- Studio
			expect(ResetRules.allowed(1, 2, false, 255)).to.equal(true) -- the owner on live
			expect(ResetRules.allowed(1, 2, false, 254)).to.equal(false)
			expect(ResetRules.allowed(1, 2, false, 0)).to.equal(false)
		end)

		it("starts a new save and keeps only the receipts and the passes", function()
			local save = SaveSchema.template(100)
			save.coins = 5000
			save.tutorialStep = 9
			save.suds = 3
			save.workers.Jo = { mode = "first", level = 2, hiredAt = 120 }
			save.receipts = { "a", "b" }
			save.passes.DoubleCoins = true
			local fresh = ResetRules.fresh(save, 500)
			expect(fresh.coins).to.equal(0)
			expect(fresh.tutorialStep).to.equal(0)
			expect(fresh.suds).to.equal(0)
			expect(next(fresh.workers)).to.equal(nil)
			expect(fresh.createdAt).to.equal(500)
			expect(fresh.version).to.equal(SaveSchema.VERSION)
			expect(#fresh.receipts).to.equal(2)
			expect(fresh.passes.DoubleCoins).to.equal(true)
			-- a copy: the old save changing later can't reach the new one
			table.insert(save.receipts, "c")
			expect(#fresh.receipts).to.equal(2)
		end)
	end)
end
