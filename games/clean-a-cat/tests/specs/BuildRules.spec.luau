--!strict
return function()
	local BuildRules = require(game:GetService("ReplicatedStorage").Shared.BuildRules)

	local function state(coins: number): BuildRules.State
		return { coins = coins, stations = {}, builds = {} }
	end

	describe("BuildRules.start and finish", function()
		it("takes the price, sets the end time and finishes once the time has passed", function()
			local s = state(100)
			expect(BuildRules.start(s, "BrushTable", 1000)).to.equal(40)
			expect(s.coins).to.equal(60)
			expect(s.builds.station.endsAt).to.equal(1000 + BuildRules.ITEMS.BrushTable.seconds)
			expect(#BuildRules.finish(s, 1005)).to.equal(0)
			local done = BuildRules.finish(s, 5000) -- came back late: nothing is lost
			expect(done[1]).to.equal("BrushTable")
			expect(s.stations.BrushTable).to.equal(true)
			expect(s.builds.station).to.equal(nil)
			expect(BuildRules.start(s, "BrushTable", 6000)).to.equal(0) -- already built
		end)

		it("builds a room and a station at the same time but one per slot", function()
			local s = state(1000)
			s.stations.BrushTable = true
			s.stations.Dryer = true
			expect(BuildRules.start(s, "VipRoom", 0) > 0).to.equal(true)
			local t: BuildRules.State = { coins = 1000, stations = {}, builds = {} }
			expect(BuildRules.start(t, "BrushTable", 0) > 0).to.equal(true)
			local ok, reason = BuildRules.canStart(t, "Dryer")
			expect(ok).to.equal(false) -- the station slot is busy
			expect(reason).to.be.ok()
		end)

		it("refuses too few coins, NaN coins, an unknown item and a missing first build", function()
			expect(BuildRules.start(state(39), "BrushTable", 0)).to.equal(0)
			expect(BuildRules.start(state(0 / 0), "BrushTable", 0)).to.equal(0)
			expect(BuildRules.start(state(1000), "Rocket", 0)).to.equal(0)
			expect(BuildRules.start(state(1000), "Dryer", 0)).to.equal(0)
		end)
	end)

	describe("BuildRules tables", function()
		it("lists every id in ITEMS with a real slot and a requirement that exists", function()
			for _, id in BuildRules.IDS do
				local item = BuildRules.ITEMS[id]
				expect(item).to.be.ok()
				expect(table.find(BuildRules.SLOTS, item.slot)).to.be.ok()
				if item.requires then
					expect(BuildRules.ITEMS[item.requires]).to.be.ok()
				end
			end
		end)

		it("offers the Bubble Bath and Pawdicure only with their switches on (#267)", function()
			local function on(flag: string): boolean
				return flag ~= "tubBuilds" and flag ~= "noVipRoom" and flag ~= "catHotel" -- every switch but the tubs' (below), noVipRoom and catHotel
			end
			local function off(_flag: string): boolean
				return false
			end
			expect(table.concat(BuildRules.offered(off), ",")).to.equal("BrushTable,Dryer,VipRoom")
			expect(table.concat(BuildRules.offered(on), ",")).to.equal(
				"BrushTable,Dryer,BubbleBath,Pawdicure,VipRoom"
			)
			expect(BuildRules.ITEMS.BubbleBath.requires).to.equal("Dryer")
			expect(BuildRules.ITEMS.Pawdicure.requires).to.equal("BubbleBath")
		end)

		it("builds the Bubble Bath only after the Dryer, in the station slot", function()
			local s: BuildRules.State =
				{ coins = 10000, stations = { BrushTable = true }, builds = {} }
			expect(BuildRules.canStart(s, "BubbleBath")).to.equal(false)
			s.stations.Dryer = true
			expect(BuildRules.start(s, "BubbleBath", 0)).to.equal(BuildRules.ITEMS.BubbleBath.price)
			expect(s.builds.station.item).to.equal("BubbleBath")
		end)

		it("adds pay bonuses only for built stations", function()
			local allOn = function(flag: string): boolean
				return flag ~= "tubBuilds" -- with the tubs on the old stations stop paying (below)
			end
			expect(BuildRules.payBonus({}, allOn)).to.equal(0)
			expect(BuildRules.payBonus({ BrushTable = true, Dryer = true }, allOn)).to.equal(
				BuildRules.ITEMS.BrushTable.payBonus + BuildRules.ITEMS.Dryer.payBonus
			)
		end)

		it("pays nothing for a built station whose switch is off", function()
			local built = { Dryer = true, BubbleBath = true, Pawdicure = true }
			local function only(name: string)
				return function(flag: string)
					return flag == name
				end
			end
			local dryer = BuildRules.ITEMS.Dryer.payBonus
			expect(BuildRules.payBonus(built, only(""))).to.equal(dryer)
			expect(BuildRules.payBonus(built, only("bubbleBath"))).to.equal(
				dryer + BuildRules.ITEMS.BubbleBath.payBonus
			)
			expect(BuildRules.payBonus(built, only("pawdicure"))).to.equal(
				dryer + BuildRules.ITEMS.Pawdicure.payBonus
			)
		end)
	end)

	describe("BuildRules.cleanBuilds", function()
		it("keeps well formed builds in their own slot only", function()
			local builds = BuildRules.cleanBuilds({
				station = { item = "Dryer", endsAt = 50 },
				room = { item = "BrushTable", endsAt = 50 }, -- wrong slot
				extra = { item = "VipRoom", endsAt = 50 },
			})
			expect(builds.station.item).to.equal("Dryer")
			expect(builds.room).to.equal(nil)
			expect(builds.extra).to.equal(nil)
			expect(BuildRules.cleanBuilds({ room = { item = "VipRoom", endsAt = 0 / 0 } }).room).to.equal(
				nil
			)
			expect(next(BuildRules.cleanBuilds("junk"))).to.equal(nil)
		end)
	end)

	describe("BuildRules.longRunningAt", function()
		it("is true only while a long build is still running", function()
			local s = state(1000)
			s.stations.BrushTable = true
			s.stations.Dryer = true
			expect(BuildRules.longRunningAt(s, 0)).to.equal(false)
			BuildRules.start(s, "VipRoom", 0)
			local ends = BuildRules.ITEMS.VipRoom.seconds
			expect(BuildRules.longRunningAt(s, ends - 1)).to.equal(true)
			expect(BuildRules.longRunningAt(s, ends)).to.equal(false)
		end)

		it("does not count a short build", function()
			local s = state(1000)
			BuildRules.start(s, "BrushTable", 0)
			expect(BuildRules.longRunningAt(s, 1)).to.equal(false)
		end)
	end)
	describe("BuildRules tubs, VIP Room and Garden (tubBuilds)", function()
		local function onWith(flags: { string }): (string) -> boolean
			return function(flag: string): boolean
				return table.find(flags, flag) ~= nil
			end
		end
		local all = onWith({ "tubBuilds", "dirtLevels", "bubbleBath", "pawdicure" })
		local off = onWith({ "bubbleBath", "pawdicure" })

		it(
			"offers the tubs in place of the old stations only with tubBuilds and dirtLevels on",
			function()
				local offered = BuildRules.offered(all)
				expect(table.find(offered, "SecondTub")).to.be.ok()
				expect(table.find(offered, "Garden")).to.be.ok()
				expect(table.find(offered, "VipRoom")).to.be.ok()
				expect(table.find(offered, "BrushTable")).to.equal(nil)
				expect(table.find(offered, "Pawdicure")).to.equal(nil)
				local before = BuildRules.offered(off)
				expect(table.find(before, "SecondTub")).to.equal(nil)
				expect(table.find(before, "Garden")).to.equal(nil)
				expect(table.find(before, "BrushTable")).to.be.ok()
				-- tubBuilds without dirtLevels: the old stations stay and the tubs wait
				local half = BuildRules.offered(onWith({ "tubBuilds" }))
				expect(table.find(half, "BrushTable")).to.be.ok()
				expect(table.find(half, "SecondTub")).to.equal(nil)
			end
		)

		it("builds the tubs in order, one build at a time", function()
			local s = state(100000)
			expect(BuildRules.start(s, "ThirdTub", 0, all)).to.equal(0) -- the Second Tub first
			expect(BuildRules.start(s, "SecondTub", 0, all)).to.equal(60)
			expect(s.builds.station.endsAt).to.equal(15)
			-- one builder: the Garden waits though it is a room
			local ok = BuildRules.canStart(s, "Garden", all)
			expect(ok).to.equal(false)
			BuildRules.finish(s, 15)
			expect(BuildRules.start(s, "Garden", 15, all)).to.equal(25000)
			expect(s.builds.room.endsAt).to.equal(15 + 24 * 3600)
			-- with the switch off, a room and a station still build together
			expect(BuildRules.canStart(s, "ThirdTub", off)).to.equal(true)
		end)

		it("builds a room and a tub at once with the Second Builder", function()
			local s = state(100000)
			expect(BuildRules.start(s, "SecondTub", 0, all, 2)).to.equal(60)
			expect(BuildRules.start(s, "Garden", 0, all, 2)).to.equal(25000)
			-- each slot still builds one thing: the Third Tub waits for the Second
			BuildRules.finish(s, 15)
			expect(BuildRules.canStart(s, "ThirdTub", all, 2)).to.equal(true)
			expect(BuildRules.start(s, "ThirdTub", 15, all, 2)).to.equal(1000)
			expect(BuildRules.canStart(s, "FourthTub", all, 2)).to.equal(false)
		end)

		it(
			"gives the VIP Room its new price and time and no first build under tubBuilds",
			function()
				local vip = BuildRules.item("VipRoom", all) :: BuildRules.Item
				expect(vip.price).to.equal(15000)
				expect(vip.seconds).to.equal(12 * 3600)
				expect(vip.requires).to.equal(nil)
				expect((BuildRules.item("VipRoom", off) :: BuildRules.Item).price).to.equal(100)
				local s = state(15000)
				expect(BuildRules.start(s, "VipRoom", 0, all)).to.equal(15000)
				expect(BuildRules.longRunningAt(s, 11 * 3600, all)).to.equal(true)
			end
		)

		it("grows the bench, shortens the refill and pays the hand bonus per built tub", function()
			local stations: { [string]: boolean } = {}
			expect(BuildRules.benchSize(stations, all)).to.equal(3)
			expect(BuildRules.refillSeconds(stations, all)).to.equal(6)
			expect(BuildRules.handBonus(stations, all)).to.equal(0)
			stations.SecondTub = true
			stations.ThirdTub = true
			stations.FourthTub = true
			expect(BuildRules.benchSize(stations, all)).to.equal(6)
			expect(BuildRules.refillSeconds(stations, all)).to.equal(3)
			expect(BuildRules.handBonus(stations, all)).to.equal(6)
			expect(BuildRules.payBonus(stations, all)).to.equal(0) -- never in the pay every cat gets
			-- the switch off takes it all away
			expect(BuildRules.benchSize(stations, off)).to.equal(3)
			expect(BuildRules.handBonus(stations, off)).to.equal(0)
		end)

		it("stops the old stations paying once they leave the board", function()
			local stations = { BrushTable = true, Dryer = true }
			expect(BuildRules.payBonus(stations, off)).to.equal(7)
			expect(BuildRules.payBonus(stations, all)).to.equal(0)
		end)

		it("makes the jar hold 12 hours and fill 25% faster with the Garden", function()
			local hours, times = BuildRules.jar({}, all)
			expect(hours).to.equal(8)
			expect(times).to.equal(1)
			hours, times = BuildRules.jar({ Garden = true }, all)
			expect(hours).to.equal(12)
			expect(times).to.equal(1.25)
			expect(BuildRules.hasVip({ VipRoom = true }, all)).to.equal(true)
			expect(BuildRules.hasVip({ VipRoom = true }, off)).to.equal(false)
		end)

		it(
			"never offers more rows than the board has keys for, the bell included (#574)",
			function()
				local flags = BuildRules.itemFlags()
				for mask = 0, 2 ^ #flags - 1 do
					local function isOn(flag: string): boolean
						local at = table.find(flags, flag)
						return at ~= nil and (mask // 2 ^ (at - 1)) % 2 == 1
					end
					expect(#BuildRules.boardOffered(isOn) + 1 <= BuildRules.MAX_ROWS).to.equal(true)
				end
			end
		)

		it("lists every switch the items depend on once", function()
			local flags = BuildRules.itemFlags()
			expect(table.find(flags, "tubBuilds")).to.be.ok()
			expect(table.find(flags, "dirtLevels")).to.be.ok()
			local seen: { [string]: boolean } = {}
			for _, flag in flags do
				expect(seen[flag]).to.equal(nil)
				seen[flag] = true
			end
		end)
		it("reads a running build's time left for its sign", function()
			expect(BuildRules.leftText(0)).to.equal("Done")
			expect(BuildRules.leftText(-5)).to.equal("Done")
			expect(BuildRules.leftText(40)).to.equal("40s left")
			expect(BuildRules.leftText(59.2)).to.equal("1m left")
			expect(BuildRules.leftText(61)).to.equal("2m left")
			expect(BuildRules.leftText(3600)).to.equal("1h 0m left")
			expect(BuildRules.leftText(23 * 3600 + 59 * 60 + 44)).to.equal("24h 0m left")
			expect(BuildRules.leftText(2 * 3600 + 14 * 60 + 10)).to.equal("2h 15m left")
		end)

		it("ships the Build window's reach behind a switch that starts off", function()
			local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
			expect(table.find(LiveFlags.KEYS, BuildRules.WINDOW_FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[BuildRules.WINDOW_FLAG]).to.equal(true)
		end)
	end)
	describe("BuildRules.oldRefund", function()
		local function switches(on: { [string]: boolean }): (string) -> boolean
			return function(flag: string): boolean
				return on[flag] == true
			end
		end
		local both = switches({ builds = true, tubBuilds = true, dirtLevels = true })

		it(
			"pays back each old station built, once, only while tubBuilds and dirtLevels are both on",
			function()
				local stations =
					{ BrushTable = true, Dryer = true, SecondTub = true, VipRoom = true }
				local coins, ids = BuildRules.oldRefund(stations, {}, both)
				expect(coins).to.equal(
					BuildRules.ITEMS.BrushTable.price + BuildRules.ITEMS.Dryer.price
				)
				expect(#ids).to.equal(2)
				local refunded = {}
				for _, id in ids do
					refunded[id] = true
				end
				local again, none = BuildRules.oldRefund(stations, refunded, both)
				expect(again).to.equal(0)
				expect(#none).to.equal(0)
				local onlyTubs = switches({ builds = true, tubBuilds = true })
				local off, offIds = BuildRules.oldRefund(stations, {}, onlyTubs)
				expect(off).to.equal(0)
				expect(#offIds).to.equal(0)
			end
		)

		it(
			"never pays for an item that is out only because its own switch or builds is off",
			function()
				local stations = { BrushTable = true, BubbleBath = true, Pawdicure = true }
				local noTubs = switches({ builds = true, dirtLevels = true })
				local coins, ids = BuildRules.oldRefund(stations, {}, noTubs)
				expect(coins).to.equal(0)
				expect(#ids).to.equal(0)
				local nothingOn = switches({})
				local none = BuildRules.oldRefund(stations, {}, nothingOn)
				expect(none).to.equal(0)
			end
		)

		it(
			"takes the VIP Room out under noVipRoom and pays back what it cost (issue 1063)",
			function()
				local noVip = switches({ builds = true, tubBuilds = true, noVipRoom = true })
				expect(BuildRules.shown("VipRoom", noVip)).to.equal(false)
				expect(table.find(BuildRules.offered(noVip), "VipRoom")).to.equal(nil)
				expect(BuildRules.hasVip({ VipRoom = true }, noVip)).to.equal(false)
				expect(table.find(BuildRules.itemFlags(), "noVipRoom")).to.be.ok()
				local coins, ids = BuildRules.oldRefund({ VipRoom = true }, {}, noVip)
				expect(coins).to.equal(15000) -- its tubBuilds price, not the old board's 100
				expect(ids[1]).to.equal("VipRoom")
				local tubs = switches({ builds = true, tubBuilds = true })
				expect(BuildRules.shown("VipRoom", tubs)).to.equal(true)
				expect(BuildRules.hasVip({ VipRoom = true }, tubs)).to.equal(true)
				expect(BuildRules.oldRefund({ VipRoom = true }, {}, tubs)).to.equal(0)
				local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
				expect(table.find(LiveFlags.KEYS, "noVipRoom")).to.be.ok()
				expect(LiveFlags.OFF_BY_DEFAULT.noVipRoom).to.equal(true)
			end
		)

		it("ends a VIP Room still building under noVipRoom, so the builder is free", function()
			local noVip = switches({ builds = true, tubBuilds = true, noVipRoom = true })
			local s: BuildRules.State = {
				coins = 0,
				stations = {},
				builds = { room = { item = "VipRoom", endsAt = 99999 } },
			}
			local ended = BuildRules.endTakenOut(s, noVip)
			expect(ended[1]).to.equal("VipRoom")
			expect(s.builds.room).to.equal(nil)
			expect(s.stations.VipRoom).to.equal(true)
			local keep: BuildRules.State = {
				coins = 0,
				stations = {},
				builds = { room = { item = "VipRoom", endsAt = 99999 } },
			}
			local tubs = switches({ builds = true, tubBuilds = true })
			expect(#BuildRules.endTakenOut(keep, tubs)).to.equal(0)
			expect(keep.builds.room).to.be.ok()
		end)

		it("covers the Bubble Bath and Pawdicure at their board prices", function()
			local coins = BuildRules.oldRefund({ BubbleBath = true, Pawdicure = true }, {}, both)
			expect(coins).to.equal(
				BuildRules.ITEMS.BubbleBath.price + BuildRules.ITEMS.Pawdicure.price
			)
		end)
	end)
end
