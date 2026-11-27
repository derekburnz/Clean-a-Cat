--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BowRules = require(Shared:WaitForChild("BowRules"))
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local HotelRules = require(Shared:WaitForChild("HotelRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))

return function()
	describe("HotelRules", function()
		it("ships behind a switch that starts off, with its remotes listed", function()
			expect(table.find(LiveFlags.KEYS, HotelRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[HotelRules.FLAG]).to.equal(true)
			expect(table.find(Remotes.ClientToServer, HotelRules.BOOK_REMOTE)).to.be.ok()
			expect(table.find(Remotes.ClientToServer, HotelRules.COLLECT_REMOTE)).to.be.ok()
			expect(table.find(Remotes.ServerToClient, HotelRules.STATE_EVENT)).to.be.ok()
			expect(table.find(Remotes.ServerToClient, "HotelPaid")).to.be.ok()
		end)

		it(
			"opens through timed builds that are never board rows (Derek: construction time)",
			function()
				local function all(_flag: string): boolean
					return true
				end
				local hotel = BuildRules.ITEMS[HotelRules.ID]
				expect(hotel.price).to.equal(1500)
				expect(hotel.seconds).to.equal(20 * 60)
				expect(BuildRules.ITEMS.HotelRoom3.seconds).to.equal(30 * 60)
				expect(BuildRules.ITEMS.HotelRoom4.seconds).to.equal(3600)
				expect(BuildRules.ITEMS.HotelRoom3.requires).to.equal(HotelRules.ID)
				expect(table.find(BuildRules.offered(all), HotelRules.ID)).to.be.ok()
				expect(table.find(BuildRules.boardOffered(all), HotelRules.ID)).to.equal(nil)
				for _, id in { HotelRules.ID, "HotelRoom3", "HotelRoom4" } do
					expect(HotelRules.isBuild(id)).to.equal(true)
				end
				expect(HotelRules.isBuild("Garden")).to.equal(false)
			end
		)

		it("is open once built or once the old door was unlocked", function()
			expect(HotelRules.open({}, false)).to.equal(false)
			expect(HotelRules.open({ CatHotel = true }, false)).to.equal(true)
			expect(HotelRules.open({}, true)).to.equal(true)
		end)

		it("has two rooms, then three and four in order", function()
			expect(HotelRules.rooms({})).to.equal(2)
			expect(HotelRules.rooms({ HotelRoom3 = true })).to.equal(3)
			expect(HotelRules.rooms({ HotelRoom3 = true, HotelRoom4 = true })).to.equal(4)
			expect(HotelRules.rooms({ HotelRoom4 = true })).to.equal(2)
		end)

		it("pays the stay times the rarity", function()
			expect(HotelRules.pay(1, "Common")).to.equal(60)
			expect(HotelRules.pay(4, "Uncommon")).to.equal(250)
			expect(HotelRules.pay(8, "Legendary")).to.equal(1080)
			expect(HotelRules.pay(2, "Common")).to.equal(0)
			expect(HotelRules.bonus(360)).to.equal(90)
		end)

		it("rolls gifts by the shown chances, each row summing to 100", function()
			for _, hours in HotelRules.HOURS do
				local total = 0
				for _, gift in HotelRules.GIFTS do
					total += HotelRules.GIFT_CHANCES[hours][gift]
				end
				expect(total).to.equal(100)
			end
			expect(HotelRules.gift(1, 0)).to.equal("coins")
			expect(HotelRules.gift(1, 0.95)).to.equal("bow")
			expect(HotelRules.gift(1, 0.99)).to.equal("crate")
			expect(HotelRules.gift(8, 0.7)).to.equal("bow")
			expect(HotelRules.gift(8, 0.9)).to.equal("crate")
		end)

		it("never rolls a special visitor as a guest", function()
			local n = 0
			for i = 1, 200 do
				local guest = HotelRules.rollGuest(function()
					n = (n * 7 + i) % 97
					return n / 97
				end, 3)
				expect(HotelRules.RARITY_TIMES[guest.rarity]).to.be.ok()
			end
		end)

		it("books a free open room and pays each stay once", function()
			local stays: { [string]: HotelRules.Stay } = {}
			local guest = { kind = "Muffin", rarity = "Common" }
			expect((HotelRules.canBook(stays, 2, 3, 1, guest))).to.equal(false) -- room 3 not open
			expect((HotelRules.canBook(stays, 2, 1, 2, guest))).to.equal(false) -- 2 hours is not a stay
			expect((HotelRules.canBook(stays, 2, 1, 1, nil))).to.equal(false) -- no guest
			expect((HotelRules.canBook(stays, 2, 1, 4, guest))).to.equal(true)
			HotelRules.book(stays, 1, 4, guest, 1000)
			expect(stays["1"].endsAt).to.equal(1000 + 4 * 3600)
			expect((HotelRules.canBook(stays, 2, 1, 1, guest))).to.equal(false) -- taken
			expect(HotelRules.freeRoom(stays, 2)).to.equal(2)
			expect(#HotelRules.checkOut(stays, nil, 1000 + 3600)).to.equal(0) -- still asleep
			local out = HotelRules.checkOut(stays, nil, 1000 + 4 * 3600)
			expect(#out).to.equal(1)
			expect(out[1].room).to.equal(1)
			expect(stays["1"]).to.equal(nil)
			expect(#HotelRules.checkOut(stays, nil, 99999)).to.equal(0) -- paid once
		end)

		it("reads only well formed stays from a save", function()
			local clean = HotelRules.cleanStays({
				["1"] = { kind = "Muffin", hours = 1, endsAt = 50 },
				["2"] = { kind = "NoSuchCat", hours = 1, endsAt = 50 },
				["3"] = { kind = "Tux", hours = 3, endsAt = 50 },
				["4"] = { kind = "Tux", hours = 8, endsAt = 0 / 0 },
				["5"] = { kind = "Tux", hours = 8, endsAt = 50 },
			})
			expect(clean["1"].rarity).to.equal("Common")
			expect(clean["2"]).to.equal(nil)
			expect(clean["3"]).to.equal(nil)
			expect(clean["4"]).to.equal(nil)
			expect(clean["5"]).to.equal(nil)
			expect(next(HotelRules.cleanStays("broken"))).to.equal(nil)
		end)

		it("gives the next bow tier, nil once every tier is owned", function()
			expect(HotelRules.nextBow(BowRules.TIERS, {})).to.equal("Silk")
			expect(HotelRules.nextBow(BowRules.TIERS, { Silk = true })).to.equal("Satin")
			expect(HotelRules.nextBow(BowRules.TIERS, { Silk = true, Satin = true, Golden = true })).to.equal(
				nil
			)
		end)

		it(
			"puts the Garden at the side yard only with noVipRoom on too, in its side looks (#1050)",
			function()
				local function flags(list: { string }): (string) -> boolean
					return function(key: string): boolean
						return table.find(list, key) ~= nil
					end
				end
				expect(HotelRules.gardenAtSide(flags({ HotelRules.FLAG, HotelRules.NO_VIP_FLAG }))).to.equal(
					true
				)
				expect(HotelRules.gardenAtSide(flags({ HotelRules.FLAG }))).to.equal(false)
				expect(HotelRules.gardenAtSide(flags({ HotelRules.NO_VIP_FLAG }))).to.equal(false)
				local SpaLayout = require(game:GetService("ReplicatedStorage").Shared.SpaLayout)
				expect(SpaLayout.PLOT_SPOTS[HotelRules.GARDEN_SPOT]).to.be.ok()
				expect(SpaLayout.BIG_SPOTS[HotelRules.GARDEN_SPOT]).to.be.ok()
				for _, name in
					{
						HotelRules.GARDEN_LOCKED_ASSET,
						HotelRules.GARDEN_BUILDING_ASSET,
						HotelRules.GARDEN_AREA_ASSET,
					}
				do
					expect(string.find(name, "^CleanACat_Area_GardenSide")).to.be.ok()
				end
			end
		)
	end)
end
