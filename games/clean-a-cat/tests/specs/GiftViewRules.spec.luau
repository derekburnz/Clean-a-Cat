--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreeRewardRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FreeRewardRules"))
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

		it(
			"with giftGroupOnly needs the group join alone, and asks the favourite with no gift tied",
			function()
				local only = state(false, false)
				only.groupOnly = true
				expect(GiftViewRules.ready(only)).to.equal(false)
				expect(GiftViewRules.waitLine(only)).to.equal("One step to go")
				expect(GiftViewRules.steps(only)[1].line).to.equal(GiftViewRules.FAVOURITE_ASK)
				only.group = true
				expect(GiftViewRules.ready(only)).to.equal(true)
				expect(GiftViewRules.waitLine(only)).to.equal(nil)
				only.claimed = true
				expect(GiftViewRules.ready(only)).to.equal(false)
			end
		)

		it("says how many steps are left in plain words", function()
			expect(GiftViewRules.waitLine(state(false, false))).to.equal("Two steps to go")
			expect(GiftViewRules.waitLine(state(true, false))).to.equal("One step to go")
			expect(GiftViewRules.waitLine(state(true, true))).to.equal(nil)
			expect(GiftViewRules.claimText(state(true, true))).to.equal("Get Starcoat")
			expect(GiftViewRules.claimText(state(true, true, true))).to.equal("Starcoat is yours!")
			-- with giftCrate (issue 859) the stand gives a crate to open
			expect(GiftViewRules.claimText(state(true, true), true)).to.equal(
				"Open your gift crate"
			)
			expect(GiftViewRules.claimText(state(true, true, true), true)).to.equal(
				"Your gift crate is here!"
			)
		end)
	end)

	describe("GiftViewRules free rewards rows (issue 730)", function()
		local function free(
			likeAsked: boolean,
			likeIn: number,
			likeClaimed: boolean,
			played: number,
			playClaimed: boolean
		): GiftViewRules.State
			return {
				lit = true,
				favourite = false,
				group = false,
				claimed = false,
				free = {
					likeAsked = likeAsked,
					likeIn = likeIn,
					likeClaimed = likeClaimed,
					played = played,
					playClaimed = playClaimed,
				},
			}
		end

		it("puts the like first, then favourite and group, then play time", function()
			local steps = GiftViewRules.steps(free(false, 0, false, 0, false))
			expect(#steps).to.equal(4)
			expect(steps[1].key).to.equal("like")
			expect(steps[1].action).to.equal("Like")
			-- Issue 748: the first line keeps the coins apart from the like (Derek's word 2026-11-26).
			expect(steps[1].line).to.equal(`A gift either way, {FreeRewardRules.LIKE_COINS} coins`)
			expect(steps[2].key).to.equal("favourite")
			expect(steps[3].key).to.equal("group")
			expect(steps[4].key).to.equal("play")
			expect(steps[4].action).to.equal(nil)
		end)

		it("counts the like down, says the gift comes either way, then offers Claim", function()
			local waiting = GiftViewRules.steps(free(true, 7, false, 0, false))[1]
			expect(waiting.style).to.equal("wait")
			expect(waiting.action).to.equal("7 s")
			expect(string.find(waiting.line, "either way", 1, true) ~= nil).to.equal(true)
			local ready = GiftViewRules.steps(free(true, 0, false, 0, false))[1]
			expect(ready.key).to.equal("likeClaim")
			expect(ready.style).to.equal("claim")
			local done = GiftViewRules.steps(free(true, 0, true, 0, false))[1]
			expect(done.done).to.equal(true)
			expect(done.action).to.equal(nil)
		end)

		it("offers the play gift only after 30 minutes", function()
			expect(GiftViewRules.steps(free(false, 0, false, 1799, false))[4].action).to.equal(nil)
			expect(GiftViewRules.steps(free(false, 0, false, 1800, false))[4].key).to.equal(
				"playClaim"
			)
			expect(GiftViewRules.steps(free(false, 0, false, 1800, true))[4].done).to.equal(true)
		end)

		it("keeps Starcoat on favourite and group only", function()
			local s = free(true, 0, true, 5000, true)
			expect(GiftViewRules.ready(s)).to.equal(false)
		end)
		describe("GiftViewRules with giftFlow", function()
			local free = {
				likeAsked = false,
				likeIn = 10,
				likeClaimed = false,
				played = 600,
				playClaimed = false,
			}
			it("shows the welcome gifts as one Claim all", function()
				local st: GiftViewRules.State = {
					lit = true,
					favourite = true,
					group = true,
					claimed = false,
					free = free,
					stage = 1,
				}
				local steps = GiftViewRules.steps(st)
				expect(#steps).to.equal(3)
				expect(steps[1].key).to.equal("like")
				expect(steps[1].action).to.equal("Like")
				expect(GiftViewRules.claimText(st, true)).to.equal("Claim all")
				expect(GiftViewRules.hasClaim(st)).to.equal(true)
				expect(GiftViewRules.title(st)).to.equal("Welcome gifts")
				expect(GiftViewRules.prize(st, true).line).to.equal(
					"A free pet inside, plus 150 coins"
				)
			end)
			it("shows the playtime gift alone at stage 2", function()
				local st: GiftViewRules.State = {
					lit = true,
					favourite = true,
					group = true,
					claimed = true,
					free = free,
					stage = 2,
				}
				local steps = GiftViewRules.steps(st)
				expect(#steps).to.equal(1)
				expect(steps[1].key).to.equal("play")
				expect(steps[1].line).to.equal("A good crate · 20 min to go")
				expect(GiftViewRules.hasClaim(st)).to.equal(false)
				expect(GiftViewRules.title(st)).to.equal("Playtime gift")
				expect(GiftViewRules.prize(st, true).name).to.equal("Good crate")
			end)
		end)
	end)

	describe("GiftViewRules, the groupVerify board (issue 1111)", function()
		local function board(verify: string, group: boolean, claimed: boolean, paid: boolean): GiftViewRules.State
			return {
				lit = true,
				favourite = false,
				group = group,
				claimed = claimed,
				verify = verify,
				coinsPaid = paid,
			}
		end
		it("says exactly what is checked, and nothing about the like", function()
			local st = board("", false, false, false)
			expect(GiftViewRules.isBoard(st)).to.equal(true)
			local steps = GiftViewRules.steps(st)
			expect(#steps).to.equal(1)
			expect(steps[1].key).to.equal("group")
			expect(steps[1].action).to.equal("Join")
			expect(steps[1].line).to.equal("For 150 coins and the Starcoat")
			expect(GiftViewRules.steps(st, true)[1].line).to.equal("For 150 coins and a gift crate")
			expect(GiftViewRules.title(st)).to.equal("Free gift")
			expect(GiftViewRules.claimText(st)).to.equal("Verify")
			expect(GiftViewRules.ready(st)).to.equal(true)
			expect(GiftViewRules.waitLine(st)).to.equal("Join the group, then tap Verify")
			local asks = GiftViewRules.asks(st)
			expect(#asks).to.equal(1)
			for _, word in { "coin", "gift", "reward", "free", "claim" } do
				expect(string.find(string.lower(asks[1]), word, 1, true)).to.equal(nil)
			end
		end)
		it("answers each Verify tap, and keeps Verify live inside the server's wait", function()
			expect(GiftViewRules.waitLine(board("notYet", false, false, false))).to.equal(
				"Join the group, then tap Verify"
			)
			local waiting = board("wait", true, false, false)
			expect(GiftViewRules.waitLine(waiting)).to.equal("One moment, then tap Verify again")
			expect(GiftViewRules.ready(waiting)).to.equal(true)
			expect(GiftViewRules.waitLine(board("joined", true, true, false))).to.equal(
				"Thank you! Your gifts are in"
			)
		end)
		it("drops the coins once paid, and ends once both gifts are in", function()
			local paid = board("", false, false, true)
			expect(GiftViewRules.steps(paid)[1].line).to.equal("For the Starcoat")
			local done = board("joined", true, true, true)
			expect(GiftViewRules.ready(done)).to.equal(false)
			expect(GiftViewRules.claimText(done)).to.equal("Starcoat is yours!")
			expect(GiftViewRules.waitLine(done)).to.equal(nil)
		end)
		it("is not the board with the switch off or at the playtime stage", function()
			local off = board("", false, false, false)
			off.verify = nil
			expect(GiftViewRules.isBoard(off)).to.equal(false)
			expect(#GiftViewRules.asks(off)).to.equal(0)
			local play = board("", true, true, false)
			play.stage = 2
			expect(GiftViewRules.isBoard(play)).to.equal(false)
		end)
	end)
end
