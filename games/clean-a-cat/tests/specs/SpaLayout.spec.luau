--!strict
return function()
	local SpaLayout = require(game:GetService("ReplicatedStorage").Shared.SpaLayout)

	describe("SpaLayout.place", function()
		it("keeps the tub where the placeholder room had it", function()
			local room = SpaLayout.place("SpotTub", false)
			local plot = SpaLayout.place("SpotTub", true)
			expect(room).to.equal(Vector3.new(0, 0, -12))
			expect(plot).to.equal(Vector3.new(0, 0.5, -12))
		end)

		it("moves plot spots by the pivot and keeps their facing", function()
			local position, yaw = SpaLayout.place("SpotSpawn", true)
			expect(position).to.equal(
				SpaLayout.PIVOT_POSITION + SpaLayout.PLOT_SPOTS.SpotSpawn.position
			)
			expect(yaw).to.equal(math.pi)
		end)

		it(
			"uses the plot's spot for one the room never had, and nil for an unknown name",
			function()
				expect(SpaLayout.place("SpotVipDoor", false)).to.equal(
					SpaLayout.PIVOT_POSITION + SpaLayout.PLOT_SPOTS.SpotVipDoor.position
				)
				expect(SpaLayout.place("SpotNowhere", true)).to.equal(nil)
			end
		)

		it("has the spots the game reads in both layouts", function()
			for _, name in { "SpotTub", "SpotSpawn", "SpotBuilder", "SpotBoard", "Tools" } do
				expect(SpaLayout.PLOT_SPOTS[name]).to.be.ok()
				expect(SpaLayout.ROOM_SPOTS[name]).to.be.ok()
			end
		end)
	end)

	describe("SpaLayout.PROPS", function()
		it("puts every prop on a plot spot, under its own name", function()
			local seen: { [string]: boolean } = {}
			for _, prop in SpaLayout.PROPS do
				expect(SpaLayout.PLOT_SPOTS[prop.spot]).to.be.ok()
				expect(seen[prop.name]).to.equal(nil)
				seen[prop.name] = true
				expect(string.sub(prop.asset, 1, 15)).to.equal("CleanACat_Prop_")
			end
			for index = 1, 4 do
				expect(seen[`Cushion{index}`]).to.equal(true)
			end
		end)
	end)

	describe("SpaLayout.lineName", function()
		it("names listed spots in a line", function()
			local name, past = SpaLayout.lineName("SpotQueue", 2, true)
			expect(name).to.equal("SpotQueue2")
			expect(past).to.equal(0)
		end)

		it("goes on past the last spot, one step at a time", function()
			local name, past, before = SpaLayout.lineName("SpotQueue", 5, true)
			expect(name).to.equal("SpotQueue3")
			expect(past).to.equal(2)
			expect(before).to.equal("SpotQueue2")
		end)

		it("has a spot for every window cushion in both layouts", function()
			for _, onPlot in { true, false } do
				local name, past = SpaLayout.lineName("SpotWindow", 4, onPlot)
				expect(name).to.equal("SpotWindow4")
				expect(past).to.equal(0)
			end
		end)
	end)
end
