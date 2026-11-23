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

		it("adds pay bonuses only for built stations", function()
			expect(BuildRules.payBonus({})).to.equal(0)
			expect(BuildRules.payBonus({ BrushTable = true, Dryer = true })).to.equal(
				BuildRules.ITEMS.BrushTable.payBonus + BuildRules.ITEMS.Dryer.payBonus
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
end
