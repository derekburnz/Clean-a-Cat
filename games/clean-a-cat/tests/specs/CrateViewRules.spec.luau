--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))

return function()
	describe("CrateViewRules.rows", function()
		it("lists every pet in the crate with the chance the roll uses", function()
			for _, kind in CrateRules.KINDS do
				local rows = CrateViewRules.rows(kind, {})
				local odds = CrateRules.odds(kind)
				expect(#rows).to.equal(#odds)
				for index, row in rows do
					expect(row.pet).to.equal(odds[index].pet)
					expect(row.chance).to.equal(CrateViewRules.percentText(odds[index].percent))
				end
				expect(math.abs(CrateViewRules.total(kind) - 100) < 0.001).to.equal(true)
			end
		end)

		it("writes the normal crate's numbers as tuning.md has them", function()
			local rows = CrateViewRules.rows("normal", { Clover = true })
			expect(rows[1].pet).to.equal("Clover")
			expect(rows[1].chance).to.equal("25%")
			expect(rows[1].boost).to.equal("+5%")
			expect(rows[1].owned).to.equal(true)
			expect(rows[2].owned).to.equal(false)
			expect(rows[#rows].rarity).to.equal("Legendary")
			expect(rows[#rows].chance).to.equal("2%")
			expect(rows[#rows].boost).to.equal("+20%")
		end)
	end)

	describe("CrateViewRules text", function()
		it("writes whole percents plain and others to one place", function()
			expect(CrateViewRules.percentText(25)).to.equal("25%")
			expect(CrateViewRules.percentText(12.5)).to.equal("12.5%")
			expect(CrateViewRules.percentText(6.666)).to.equal("6.7%")
		end)

		it("names the crate and counts what the player holds", function()
			expect(CrateViewRules.title("good")).to.equal("Good crate")
			expect(CrateViewRules.title("normal")).to.equal("Crate")
			expect(CrateViewRules.title(CrateRules.GIFT_KIND)).to.equal("Gift crate")
			expect(CrateViewRules.haveLine("normal", 1)).to.equal("You have 1 crate")
			expect(CrateViewRules.haveLine("normal", 3)).to.equal("You have 3 crates")
			expect(CrateViewRules.haveLine("good", 1)).to.equal("Your day 2 gift")
			expect(CrateViewRules.haveLine("normal", 0)).to.equal("No crates yet")
		end)

		it("collects the kinds the player owns", function()
			local owned = CrateViewRules.ownedKinds({
				{ id = 1, kind = "Angler", star = 1 },
				{ id = 2, kind = "Angler", star = 2, slot = "player" },
			})
			expect(owned.Angler).to.equal(true)
			expect(owned.Clover).to.equal(nil)
		end)
	end)

	describe("CrateViewRules pets window", function()
		local pets: { CrateRules.Pet } = {
			{ id = 1, kind = "Clover", star = 1 },
			{ id = 2, kind = "Clover", star = 1, slot = "player" },
			{ id = 3, kind = "Clover", star = 1 },
			{ id = 4, kind = "Angler", star = 2, slot = "Jo1" },
			{ id = 5, kind = "Blaze", star = 1 },
		}

		it("groups by pet and star, rarest first, slotted ids first", function()
			local groups = CrateViewRules.groups(pets)
			expect(#groups).to.equal(3)
			expect(groups[1].kind).to.equal("Blaze")
			expect(groups[2].kind).to.equal("Angler")
			local cozy = groups[3]
			expect(cozy.count).to.equal(3)
			expect(cozy.ids[1]).to.equal(2)
			expect(#cozy.free).to.equal(2)
			expect(cozy.canFuse).to.equal(true)
			expect(groups[1].canFuse).to.equal(false)
			local ids = CrateViewRules.fuseIds(cozy) :: { number }
			expect(#ids).to.equal(3)
			expect(ids[1]).to.equal(2)
			expect(CrateViewRules.fuseIds(groups[2])).to.equal(nil)
		end)

		it("lists you, then the helpers, locking those not hired", function()
			local rows = CrateViewRules.slotRows(pets, { Jo = true })
			expect(#rows).to.equal(4)
			expect(rows[1].who).to.equal("You")
			expect(rows[1].say).to.equal("Clover: tips +5%")
			expect(rows[2].who).to.equal("Jo")
			expect(rows[2].say).to.equal("Angler, 2 stars: pay +18%")
			expect(rows[3].locked).to.equal(true)
			expect(rows[3].say).to.equal("Comes when Sam is hired")
		end)

		it("gives each row a second slot with the Second pet slot pass", function()
			local two: { CrateRules.Pet } = {
				{ id = 1, kind = "Clover", star = 1, slot = "player" },
				{ id = 2, kind = "Angler", star = 2, slot = "player2" },
				{ id = 3, kind = "Blaze", star = 1, slot = "Jo2" },
			}
			local rows = CrateViewRules.slotRows(two, { Jo = true }, true)
			expect(rows[1].slot2).to.equal("player2")
			expect((rows[1].pet2 :: CrateRules.Pet).id).to.equal(2)
			expect(rows[1].say).to.equal("Clover +5%, Angler +18%")
			expect(rows[2].slot2).to.equal("Jo2")
			expect(rows[2].say).to.equal("Blaze +20%")
			expect(rows[3].say).to.equal("Comes when Sam is hired")
			expect(rows[3].pet2).to.equal(nil)
			local one = CrateViewRules.slotRows(two, { Jo = true })
			expect(one[1].slot2).to.equal(nil)
			expect(one[1].pet2).to.equal(nil)
		end)

		it("takes a pet off its slot on a second tap, else puts a free one in", function()
			local groups = CrateViewRules.groups(pets)
			local cozy = groups[3]
			local id, slot = CrateViewRules.placeFor(cozy, "player", pets)
			expect(id).to.equal(2)
			expect(slot).to.equal(nil)
			id, slot = CrateViewRules.placeFor(cozy, "Jo1", pets)
			expect(id).to.equal(1)
			expect(slot).to.equal("Jo1")
		end)
	end)
	describe("CrateViewRules.shopRows", function()
		local prices: { [string]: number } = { CrateOne = 49, CrateFive = 199 }
		local function price(key: string): unknown
			return prices[key]
		end

		it("lists the Robux rows in the shop's order with their real prices", function()
			local rows = CrateViewRules.shopRows("normal", true, price)
			expect(#rows).to.equal(2)
			expect(rows[1].key).to.equal("CrateOne")
			expect(rows[1].label).to.equal("1 crate")
			expect(rows[1].price).to.equal(49)
			expect(rows[2].label).to.equal("5 crates")
			expect(rows[2].price).to.equal(199)
		end)

		it("shows nothing when the player may not buy, or on the good crate", function()
			expect(#CrateViewRules.shopRows("normal", false, price)).to.equal(0)
			expect(#CrateViewRules.shopRows("good", true, price)).to.equal(0)
		end)

		it("leaves out a row whose price is missing or not real", function()
			local rows = CrateViewRules.shopRows("normal", true, function(key: string): unknown
				return if key == "CrateFive" then 199 elseif key == "CrateOne" then 0 / 0 else nil
			end)
			expect(#rows).to.equal(1)
			expect(rows[1].key).to.equal("CrateFive")
			expect(#CrateViewRules.shopRows("normal", true, function(): unknown
				return -5
			end)).to.equal(0)
		end)

		describe("CrateViewRules.effectText", function()
			it("says what a pet gives with petLines, with its true boost", function()
				local function on(flag: string): boolean
					return flag == CrateViewRules.LINES_FLAG
				end
				expect(CrateViewRules.boostText("Clover", 1)).to.equal("+5%")
				expect(CrateViewRules.boostText("Angler", 2)).to.equal("+18%")
				expect(CrateViewRules.boostText("Blaze", 3)).to.equal("+40%")
				expect(CrateViewRules.effectText(0.05, on)).to.equal("+5% tips or pay")
				expect(CrateViewRules.effectText(0.05)).to.equal("+5% boost")
				-- a helper's pets raise their pay by at most PET_CAP, so a boost over it says both true numbers
				expect(CrateViewRules.effectText(CrateRules.boost("Blaze", 3), on)).to.equal(
					"+40% tips, +30% pay"
				)
				expect(CrateViewRules.effectText(CrateRules.boost("Blaze", 2), on)).to.equal(
					"+30% tips or pay"
				)
				expect(CrateViewRules.effectText(CrateRules.boost("Blaze", 3))).to.equal(
					"+40% boost"
				)
			end)
		end)
	end)
end
