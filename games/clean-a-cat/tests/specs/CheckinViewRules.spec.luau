--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheckinRules = require(Shared:WaitForChild("CheckinRules"))
local CheckinViewRules = require(Shared:WaitForChild("CheckinViewRules"))

return function()
	describe("CheckinViewRules.read", function()
		it("keeps only whole days in range", function()
			local ready, days = CheckinViewRules.read(2, 1)
			expect(ready).to.equal(2)
			expect(days).to.equal(1)
			ready, days = CheckinViewRules.read(nil, nil)
			expect(ready).to.equal(nil)
			expect(days).to.equal(0)
			ready, days = CheckinViewRules.read(9, "3")
			expect(ready).to.equal(nil)
			expect(days).to.equal(0)
			ready = CheckinViewRules.read(0 / 0, 0)
			expect(ready).to.equal(nil)
		end)
	end)

	describe("CheckinViewRules.tiles", function()
		it("draws one tile per reward, coins as a number, day 2 big", function()
			local tiles = CheckinViewRules.tiles(1, 0)
			expect(#tiles).to.equal(CheckinRules.DAYS)
			expect(tiles[1].what).to.equal("50")
			expect(tiles[1].icon).to.equal("Coins")
			expect(tiles[1].today).to.equal(true)
			expect(tiles[2].what).to.equal("Good crate")
			expect(tiles[2].icon).to.equal("Gift")
			expect(tiles[2].big).to.equal(true)
			expect(tiles[2].crate).to.equal("good")
			expect(tiles[4].icon).to.equal("Bow")
			expect(tiles[7].crate).to.equal("normal")
		end)

		it("ticks the days taken and glows the one waiting", function()
			local tiles = CheckinViewRules.tiles(2, 1)
			expect(tiles[1].got).to.equal(true)
			expect(tiles[2].got).to.equal(false)
			expect(tiles[2].today).to.equal(true)
		end)

		it("starts fresh when day 1 waits after a full card", function()
			local tiles = CheckinViewRules.tiles(1, 7)
			for _, tile in tiles do
				expect(tile.got).to.equal(false)
			end
			local all = CheckinViewRules.tiles(nil, 7)
			for _, tile in all do
				expect(tile.got).to.equal(true)
				expect(tile.today).to.equal(false)
			end
		end)
	end)

	describe("CheckinViewRules words", function()
		it("names what the button claims", function()
			expect(CheckinViewRules.claimText(1)).to.equal("Claim 50 coins")
			expect(CheckinViewRules.claimText(2)).to.equal("Claim the good crate")
			expect(CheckinViewRules.claimText(4)).to.equal("Claim the Silk bow")
			expect(CheckinViewRules.claimText(7)).to.equal("Claim the crate")
			expect(CheckinViewRules.claimText(nil)).to.equal(nil)
		end)

		it("says when the next gift comes, never a warning", function()
			expect(CheckinViewRules.note(1, 0)).to.equal(
				"Your next gift waits for the next day you play."
			)
			expect(CheckinViewRules.note(nil, 2)).to.equal("Day 3 waits for the next day you play.")
			expect(CheckinViewRules.note(nil, 7)).to.equal(
				"All seven taken! A new card starts the next day you play."
			)
			for ready = 1, CheckinRules.DAYS do
				local line = string.lower(CheckinViewRules.note(ready, ready - 1))
				expect(string.find(line, "lose", 1, true)).to.equal(nil)
				expect(string.find(line, "streak", 1, true)).to.equal(nil)
			end
		end)
	end)
end
