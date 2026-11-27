--!strict
return function()
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
	local GiftFlowRules = require(game:GetService("ReplicatedStorage").Shared.GiftFlowRules)
	local CrateRules = require(game:GetService("ReplicatedStorage").Shared.CrateRules)

	describe("GiftFlowRules (giftFlow, issue 919)", function()
		it("ships behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, GiftFlowRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[GiftFlowRules.FLAG]).to.equal(true)
		end)

		it("goes welcome gift, playtime gift, then gone, from what the save holds", function()
			expect(GiftFlowRules.stage(false, false)).to.equal(1)
			expect(GiftFlowRules.stage(true, false)).to.equal(2)
			expect(GiftFlowRules.stage(true, true)).to.equal(3)
			-- an old save that took the play crate before the welcome gift still has the welcome gift to claim
			expect(GiftFlowRules.stage(false, true)).to.equal(1)
			-- (groupVerify) the board stays while the verified join's coins are owed
			expect(GiftFlowRules.stage(true, false, true)).to.equal(1)
			expect(GiftFlowRules.stage(true, true, true)).to.equal(1)
			expect(GiftFlowRules.stage(true, false, false)).to.equal(2)
			expect(GiftFlowRules.stage(true, true, nil)).to.equal(3)
			expect(GiftFlowRules.standStays(1)).to.equal(true)
			expect(GiftFlowRules.standStays(2)).to.equal(true)
			expect(GiftFlowRules.standStays(3)).to.equal(false)
		end)

		it("opens the playtime gift only after the welcome gift, as a good crate", function()
			expect(GiftFlowRules.playOpen(1)).to.equal(false)
			expect(GiftFlowRules.playOpen(2)).to.equal(true)
			expect(GiftFlowRules.playOpen(3)).to.equal(false)
			expect(CrateRules.cleanKind(GiftFlowRules.PLAY_CRATE)).to.equal("good")
		end)
	end)
end
