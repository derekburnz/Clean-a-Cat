--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local DirtRules = require(Shared:WaitForChild("DirtRules"))
local LaterStepRules = require(Shared:WaitForChild("LaterStepRules"))
local QueueViewRules = require(Shared:WaitForChild("QueueViewRules"))

local function always(value: number): () -> number
	return function()
		return value
	end
end

local function dirtOnly(flag: string): boolean
	return flag == DirtRules.FLAG
end

local function noneOn(_flag: string): boolean
	return false
end

return function()
	describe("DirtRules", function()
		it("has chances that sum to 100 for every rarity", function()
			for _, rarity in CatRules.RARITIES do
				local total = 0
				local row = DirtRules.CHANCES[rarity]
				expect(#row).to.equal(DirtRules.LEVELS)
				for _, percent in row do
					total += percent
				end
				expect(total).to.equal(100)
			end
		end)

		it("makes rarer cats more likely dirtier", function()
			local function heavy(rarity: string): number
				local row = DirtRules.CHANCES[rarity]
				return row[3] + row[4]
			end
			for index = 2, #CatRules.RARITIES do
				expect(heavy(CatRules.RARITIES[index]) >= heavy(CatRules.RARITIES[index - 1])).to.equal(
					true
				)
			end
		end)

		it(
			"rolls by the chances, and the tutorial's levels for a new spa's first two customers",
			function()
				expect(DirtRules.roll("Cotton", always(0))).to.equal(1)
				expect(DirtRules.roll("Cotton", always(0.56))).to.equal(2)
				expect(DirtRules.roll("Cotton", always(0.999))).to.equal(4)
				expect(DirtRules.roll("Starcoat", always(0))).to.equal(2) -- a legendary is never level 1
				expect(DirtRules.roll("Starcoat", always(0.999), 1)).to.equal(1)
				expect(DirtRules.roll("Starcoat", always(0.999), 2)).to.equal(2)
				expect(DirtRules.roll("Starcoat", always(0.999), 3)).to.equal(4) -- the third rolls as usual
				expect(DirtRules.roll("Nobody", always(0))).to.equal(1)
			end
		)

		it("adds the bath from level 2 and the claws from level 3", function()
			expect(table.concat(DirtRules.needs("Cotton", 1), ",")).to.equal("mud,tangles")
			expect(table.concat(DirtRules.needs("Cotton", 2), ",")).to.equal("mud,tangles,smell")
			expect(table.concat(DirtRules.needs("Cotton", 3), ",")).to.equal(
				"mud,tangles,smell,claws"
			)
			expect(table.concat(DirtRules.needs("Marble", 4), ",")).to.equal(
				"mud,tangles,wet,smell,claws"
			)
			expect(table.concat(DirtRules.needs("Cotton", 9), ",")).to.equal("mud,tangles")
		end)

		it("pays more for a dirtier cat", function()
			local pay = CatRules.pay("Cotton")
			local one = DirtRules.pay(pay, 1)
			expect(one.coins).to.equal(pay.coins)
			expect(one.tip).to.equal(pay.tip)
			local four = DirtRules.pay(pay, 4)
			expect(four.coins).to.equal(pay.coins * 2)
			expect(four.tip).to.equal(pay.tip) -- the tip stays as it is (tuning pay.tip)
			expect(four.stars).to.equal(pay.stars)
			expect(DirtRules.pay(pay, nil).coins).to.equal(pay.coins)
			expect(DirtRules.pay(CatRules.pay("Tux"), 2).coins).to.equal(19) -- 15 x 1.25 = 18.75
			expect(DirtRules.pay(CatRules.pay("Tux"), 3).coins).to.equal(24) -- 15 x 1.6
		end)

		it("counts the steps with the bow and without the dryer", function()
			expect(DirtRules.steps(DirtRules.needs("Cotton", 1))).to.equal(3)
			expect(DirtRules.steps(DirtRules.needs("Cotton", 2))).to.equal(4)
			expect(DirtRules.steps(DirtRules.needs("Marble", 3))).to.equal(5)
		end)

		it("keeps only real levels", function()
			expect(DirtRules.clean(3)).to.equal(3)
			expect(DirtRules.clean(0)).to.equal(nil)
			expect(DirtRules.clean(5)).to.equal(nil)
			expect(DirtRules.clean(2.5)).to.equal(nil)
			expect(DirtRules.clean(0 / 0)).to.equal(nil)
			expect(DirtRules.clean("2")).to.equal(nil)
		end)

		it("keeps the pieces at or below the level", function()
			expect(DirtRules.keeps(1, 1)).to.equal(true)
			expect(DirtRules.keeps(2, 1)).to.equal(false)
			expect(DirtRules.keeps(4, 4)).to.equal(true)
			expect(DirtRules.keeps(nil, 1)).to.equal(true)
		end)

		it("turns the later steps on with no station while it is on", function()
			expect(CatRules.needOn("smell", dirtOnly)).to.equal(true)
			expect(CatRules.needOn("smell", noneOn)).to.equal(false)
			expect(CatRules.needOn("mud", noneOn)).to.equal(true)
			local needs = DirtRules.needs("Cotton", 3)
			expect(#CatRules.lockedNeeds(needs, {}, dirtOnly)).to.equal(0)
			expect(#CatRules.lockedNeeds(needs, {})).to.equal(2)
			expect(table.concat(LaterStepRules.steps(needs, {}, dirtOnly), ",")).to.equal(
				"smell,claws"
			)
			expect(#LaterStepRules.steps(needs, {}, noneOn)).to.equal(0)
			expect(#CatRules.liveNeeds(needs, dirtOnly)).to.equal(4)
		end)

		it("shows each card's level and pay in the queue window", function()
			local dirt = QueueViewRules.cleanDirt({ 2, "x", 4 })
			expect(dirt[1]).to.equal(2)
			expect(dirt[2]).to.equal(nil)
			expect(dirt[3]).to.equal(4)
			local needs = {
				DirtRules.needs("Cotton", 2),
				DirtRules.needs("Cotton", 1),
				DirtRules.needs("Cotton", 4),
			}
			local cards = QueueViewRules.cards(
				{ "Cotton", "Cotton", "Cotton" },
				{},
				{},
				needs,
				dirt
			)
			expect(cards[1].dirt).to.equal(2)
			expect(cards[1].pays).to.equal(13) -- 10 x 1.25 = 12.5 rounds up
			expect(cards[1].locked.smell).to.equal(nil)
			expect(cards[3].pays).to.equal(20)
			expect(cards[1].steps).to.equal(4)
			expect(cards[2].steps).to.equal(3)
			expect(cards[3].steps).to.equal(5)
			local plain = QueueViewRules.cards(
				{ "Cotton" },
				{},
				{},
				{ DirtRules.needs("Cotton", 2) }
			)
			expect(plain[1].dirt).to.equal(nil)
			expect(plain[1].pays).to.equal(10)
			expect(plain[1].locked.smell).to.equal(true)
		end)
	end)
end
