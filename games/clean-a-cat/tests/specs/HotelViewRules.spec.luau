--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HotelViewRules = require(Shared:WaitForChild("HotelViewRules"))

return function()
	local function state(): HotelViewRules.State
		return HotelViewRules.clean({
			open = true,
			rooms = 3,
			stays = {
				["1"] = { kind = "Marble", rarity = "Rare", hours = 4, endsAt = 1000 },
				["2"] = { kind = "Cotton", rarity = "Common", hours = 8, endsAt = 5000 },
			},
			guest = { kind = "LilacCloud", rarity = "Epic" },
			now = 900,
		})
	end

	describe("HotelViewRules", function()
		it("cleans whatever arrives", function()
			local empty = HotelViewRules.clean("nope")
			expect(empty.open).to.equal(false)
			expect(empty.rooms).to.equal(0)
			local odd =
				HotelViewRules.clean({ open = true, rooms = 99, guest = { kind = 5 }, now = "x" })
			expect(odd.rooms).to.equal(4)
			expect(odd.guest).to.equal(nil)
			expect(odd.now).to.equal(0)
		end)

		it("shows each stay's true pay for this guest and its gift chances", function()
			local options = HotelViewRules.options({ kind = "LilacCloud", rarity = "Epic" })
			expect(#options).to.equal(3)
			expect(options[1].label).to.equal("1 hour")
			expect(options[1].pay).to.equal(120)
			expect(options[2].label).to.equal("4 hours")
			expect(options[2].pay).to.equal(400)
			expect(options[3].pay).to.equal(720)
			expect(options[1].chances).to.equal("Bonus coins 90%\nBow 8% · Crate 2%")
			expect(options[3].chances).to.equal("Bonus coins 65%\nBow 23% · Crate 12%")
			expect(HotelViewRules.options(nil)[1].pay).to.equal(60)
		end)

		it("says each room's state, calmly", function()
			local s = state()
			local rooms = HotelViewRules.rooms(s, 1000)
			expect(rooms[1].status).to.equal("ready")
			expect(rooms[1].coins).to.equal(300)
			expect(rooms[1].bubble).to.equal("+300")
			expect(rooms[2].status).to.equal("asleep")
			expect(rooms[2].bubble).to.equal("1h 6m")
			expect(rooms[3].status).to.equal("free")
			expect(rooms[4].status).to.equal("locked")
			expect(HotelViewRules.leftText(30)).to.equal("under 1m")
			expect(HotelViewRules.leftText(7200)).to.equal("2h")
			expect(HotelViewRules.leftText(600)).to.equal("10m")
		end)

		it("books into the first free room, only with a guest", function()
			local s = state()
			expect(HotelViewRules.bookRoom(s)).to.equal(3)
			expect(HotelViewRules.guestLine(s)).to.equal("Lilac Cloud would like a room")
			s.guest = nil
			expect(HotelViewRules.bookRoom(s)).to.equal(nil)
			expect(HotelViewRules.guestLine(s)).to.equal("A guest will be here soon")
			s.rooms = 2
			expect(HotelViewRules.guestLine(s)).to.equal("Every room has a guest")
		end)

		it("collects every ready room together", function()
			local s = state()
			expect(HotelViewRules.collectText(s, 900)).to.equal(nil)
			expect(HotelViewRules.collectText(s, 1000)).to.equal("Collect all · 300 coins")
			local count, coins = HotelViewRules.ready(s, 6000)
			expect(count).to.equal(2)
			expect(coins).to.equal(660)
		end)

		it("never hurries", function()
			for _, line in { HotelViewRules.FINE, HotelViewRules.SUDS_LINE, HotelViewRules.TITLE } do
				local low = string.lower(line)
				for _, word in { "hurry", "limited", "robux", "last chance" } do
					expect(string.find(low, word, 1, true)).to.equal(nil)
				end
			end
		end)
	end)
end
