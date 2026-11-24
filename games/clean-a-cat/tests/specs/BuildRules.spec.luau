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
			local function on(_flag: string): boolean
				return true
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
			local allOn = function()
				return true
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
end
