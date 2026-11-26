--!strict
return function()
	local FreeRewardRules = require(game:GetService("ReplicatedStorage").Shared.FreeRewardRules)
	local CrateRules = require(game:GetService("ReplicatedStorage").Shared.CrateRules)

	local function state(fields: { [string]: any }): any
		return {
			claimed = fields.claimed or { play = false, like = false },
			likeAskedAt = fields.likeAskedAt or 0,
			played = fields.played or 0,
			now = fields.now or 1000,
		}
	end

	describe("FreeRewardRules", function()
		it("takes only the two keys", function()
			expect(FreeRewardRules.cleanKey("like")).to.equal("like")
			expect(FreeRewardRules.cleanKey("play")).to.equal("play")
			expect(FreeRewardRules.cleanKey("group")).to.equal(nil)
			expect(FreeRewardRules.cleanKey(1)).to.equal(nil)
			expect(FreeRewardRules.cleanKey(nil)).to.equal(nil)
		end)

		it("lists the like row first", function()
			expect(FreeRewardRules.KEYS[1]).to.equal("like")
			expect(FreeRewardRules.KEYS[2]).to.equal("play")
		end)

		it("pays a crate kind that exists", function()
			expect(CrateRules.cleanKind(FreeRewardRules.PLAY_CRATE)).to.equal(
				FreeRewardRules.PLAY_CRATE
			)
		end)

		it("needs the like asked, then 10 seconds, liked or not", function()
			expect(FreeRewardRules.LIKE_WAIT).to.equal(10)
			expect(FreeRewardRules.likeReadyAt(0)).to.equal(nil)
			expect(FreeRewardRules.likeReadyAt(500)).to.equal(510)
			expect(FreeRewardRules.refusal(state({}), "like")).to.equal("notAsked")
			expect(FreeRewardRules.refusal(state({ likeAskedAt = 995, now = 1000 }), "like")).to.equal(
				"wait"
			)
			expect(FreeRewardRules.refusal(state({ likeAskedAt = 990, now = 1000 }), "like")).to.equal(
				nil
			)
		end)

		it("needs 30 minutes of play for the crate", function()
			expect(FreeRewardRules.refusal(state({ played = 1799 }), "play")).to.equal("notYet")
			expect(FreeRewardRules.refusal(state({ played = 1800 }), "play")).to.equal(nil)
		end)

		it("pays each row once", function()
			local claimed = { play = true, like = true }
			expect(FreeRewardRules.refusal(state({ claimed = claimed, played = 5000 }), "play")).to.equal(
				"claimed"
			)
			expect(
				FreeRewardRules.refusal(
					state({ claimed = claimed, likeAskedAt = 1, now = 1000 }),
					"like"
				)
			).to.equal("claimed")
			-- one row paid leaves the other open
			local onlyPlay = { play = true, like = false }
			expect(
				FreeRewardRules.refusal(
					state({ claimed = onlyPlay, likeAskedAt = 1, now = 1000 }),
					"like"
				)
			).to.equal(nil)
		end)

		it("keeps the stand's gift while Starcoat or a row is left", function()
			expect(FreeRewardRules.giftLeft(false, false, false, false)).to.equal(true)
			expect(FreeRewardRules.giftLeft(true, false, false, false)).to.equal(false)
			expect(FreeRewardRules.giftLeft(true, true, false, true)).to.equal(true)
			expect(FreeRewardRules.giftLeft(true, true, true, false)).to.equal(true)
			expect(FreeRewardRules.giftLeft(true, true, true, true)).to.equal(false)
		end)
	end)
end
