--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeartRules = require(Shared:WaitForChild("HeartRules"))
local QueueViewRules = require(Shared:WaitForChild("QueueViewRules"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))

local LATE = 3600 -- seconds of play well past the first minutes

return function()
	describe("HeartRules", function()
		it("gives long bars in the first minutes and rarity bars after", function()
			expect(HeartRules.lasts("Cotton", 0)).to.equal(240)
			expect(HeartRules.lasts("Starcoat", 599)).to.equal(240)
			expect(HeartRules.lasts("Cotton", LATE)).to.equal(150)
			expect(HeartRules.lasts("Tux", LATE)).to.equal(140)
			expect(HeartRules.lasts("Marble", LATE)).to.equal(120)
			expect(HeartRules.lasts("LilacCloud", LATE)).to.equal(100)
			expect(HeartRules.lasts("Starcoat", LATE)).to.equal(90)
			expect(HeartRules.lasts("Nobody", LATE)).to.equal(150)
		end)

		it("drains the bar and empties it at the end", function()
			expect(HeartRules.left(100, 150, 100)).to.equal(1)
			expect(HeartRules.left(100, 150, 175)).to.equal(0.5)
			expect(HeartRules.left(100, 150, 400)).to.equal(0)
			expect(HeartRules.left(100, 0, 400)).to.equal(1) -- a bar of no length shows full
		end)

		it("never lets a cat leave in the first ten minutes of play", function()
			expect(HeartRules.gone(0, 150, 151, 599)).to.equal(false)
			expect(HeartRules.shown(0, 150, 151, 599)).to.equal(HeartRules.SLIVER)
			expect(HeartRules.gone(0, 150, 151, LATE)).to.equal(true)
			expect(HeartRules.gone(0, 150, 149, LATE)).to.equal(false)
			expect(HeartRules.shown(0, 150, 151, LATE)).to.equal(0)
			expect(HeartRules.gone(0, 0, 999, LATE)).to.equal(false)
		end)

		it("gives a sliver bar a grumpy bar's worth back when the first minutes end", function()
			local since = HeartRules.graceSince(0, 150, 400)
			expect(math.abs(HeartRules.left(since, 150, 400) - HeartRules.GRUMPY_AT) < 1e-9).to.equal(
				true
			)
			expect(HeartRules.gone(since, 150, 400, LATE)).to.equal(false)
			expect(HeartRules.gone(since, 150, 400 + 150 * HeartRules.GRUMPY_AT + 0.01, LATE)).to.equal(
				true
			)
			expect(HeartRules.graceSince(100, 150, 120)).to.equal(100) -- a fuller bar keeps its start
			-- each place after the first waits RELEASE_STAGGER seconds longer
			local second = HeartRules.graceSince(0, 150, 400, 2)
			local third = HeartRules.graceSince(0, 150, 400, 3)
			expect(second - since).to.equal(HeartRules.RELEASE_STAGGER)
			expect(third - since).to.equal(2 * HeartRules.RELEASE_STAGGER)
		end)

		it("gives the early bonus only in the first tenth of the bar", function()
			expect(HeartRules.early(0, 150, 15)).to.equal(true)
			expect(HeartRules.early(0, 150, 16)).to.equal(false)
		end)

		it("grades the wash by seconds per hand step", function()
			expect(HeartRules.grade(24, 2)).to.equal(3) -- 12 s a step or less
			expect(HeartRules.grade(25, 2)).to.equal(2)
			expect(HeartRules.grade(40, 2)).to.equal(2) -- 20 s a step or less
			expect(HeartRules.grade(41, 2)).to.equal(1)
			expect(HeartRules.grade(108, 9)).to.equal(3)
			expect(HeartRules.grade(3, 2)).to.equal(1) -- under 2 s a step is not a hand wash
		end)

		it("pays base x stars x early x dirt, one line each, adding up", function()
			-- tuning.md's worked example: an Uncommon at level 3, 3 stars, picked early: 15 x 1.2 x 1.25 x 1.6 = 36
			local pay = HeartRules.pay("Tux", { grade = 3, early = true, dirt = 3 })
			expect(pay.coins).to.equal(36)
			expect(pay.base + pay.speed + pay.early + pay.dirt).to.equal(36)
			expect(pay.speed).to.equal(3)
			expect(pay.tip).to.equal(3)
			expect(pay.grade).to.equal(3)
			local slow = HeartRules.pay("Cotton", { grade = 1, early = false })
			expect(slow.coins).to.equal(10) -- a slow wash is never a cut
			expect(slow.speed).to.equal(0)
			expect(slow.early).to.equal(0)
			expect(slow.dirt).to.equal(0)
			expect(HeartRules.pay("Cotton", { grade = 2, early = false }).speed).to.equal(1)
			local plain = HeartRules.pay("Cotton", { early = false })
			expect(plain.coins).to.equal(10)
		end)

		it("reads a card's bar from the network", function()
			local heart = HeartRules.cleanHeart({ 100, 150, 0, 0 })
			expect(heart).never.to.equal(nil)
			local h = heart :: HeartRules.Heart
			expect(HeartRules.fill(h, 175)).to.equal(0.5)
			expect(HeartRules.fill({ since = 0, lasts = 150, stops = true, paused = false }, 999)).to.equal(
				HeartRules.SLIVER
			)
			expect(HeartRules.fill({ since = 0, lasts = 150, stops = false, paused = true }, 999)).to.equal(
				1
			)
			expect(HeartRules.cleanHeart({ "x", 150 })).to.equal(nil)
			expect(HeartRules.cleanHeart({ 1, -1 })).to.equal(nil)
			expect(HeartRules.cleanHeart(5)).to.equal(nil)
			local hearts = QueueViewRules.cleanHearts({ { 1, 150, 0, 0 }, "bad", { 2, 140, 1, 0 } })
			expect(hearts[1].lasts).to.equal(150)
			expect(hearts[2]).to.equal(nil)
			expect(hearts[3].stops).to.equal(true)
			local cards = QueueViewRules.cards({ "Cotton", "Cotton" }, {}, {}, nil, nil, hearts)
			expect((cards[1].heart :: HeartRules.Heart).lasts).to.equal(150)
			expect(cards[2].heart).to.equal(nil)
		end)

		it("lists each multiplier on its own recap line", function()
			local recap = RecapRules.make(
				"Tux",
				{ coins = 15, tip = 3, stars = 1 },
				0,
				0,
				false,
				{ speed = 3, early = 4, dirt = 14, grade = 3 }
			)
			expect(RecapRules.total(recap)).to.equal(39)
			local keys = {}
			for _, row in RecapRules.rows(recap) do
				table.insert(keys, row.key)
			end
			expect(table.concat(keys, ",")).to.equal("wash,speed,early,dirt,tip")
			local back = RecapRules.clean(recap) :: RecapRules.Recap
			expect(back.dirt).to.equal(14)
			expect(back.grade).to.equal(3)
			local old = RecapRules.clean({
				cat = "Tux",
				rarity = "Uncommon",
				coins = 15,
				tip = 3,
				bonus = 0,
				stars = 1,
			})
			expect((old :: RecapRules.Recap).speed).to.equal(0)
			expect(RecapRules.clean({
				cat = "Tux",
				rarity = "Uncommon",
				coins = 15,
				tip = 3,
				bonus = 0,
				stars = 1,
				speed = -4,
			})).to.equal(nil)
		end)
	end)
end
