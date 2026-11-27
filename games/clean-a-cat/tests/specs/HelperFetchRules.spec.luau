--!strict
return function()
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
	local HelperFetchRules = require(game:GetService("ReplicatedStorage").Shared.HelperFetchRules)

	describe("HelperFetchRules (helperFetch, issue 884)", function()
		it("ships behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, HelperFetchRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[HelperFetchRules.FLAG]).to.equal(true)
		end)

		it("stops short of the cat on the helper's own side, on the floor", function()
			local from = Vector3.new(0, 0.5, 10)
			local stop = HelperFetchRules.stopFor(from, Vector3.new(0, 3.2, -10))
			expect(math.abs(stop.Y - 0.5) < 1e-6).to.equal(true)
			expect(math.abs(stop.Z - (-10 + HelperFetchRules.SHORT_OF)) < 1e-6).to.equal(true)
			-- a cat closer than that: they stay put
			expect(HelperFetchRules.stopFor(from, Vector3.new(0, 3, 9))).to.equal(from)
		end)

		it(
			"walks out empty, picks the cat up half way through the stop and carries it back",
			function()
				local from, to = Vector3.new(0, 0, 0), Vector3.new(0, 0, -18)
				local walk = HelperFetchRules.walkSeconds(from, to)
				expect(math.abs(walk - 18 / HelperFetchRules.SPEED) < 1e-6).to.equal(true)
				local pick = HelperFetchRules.PICK_SECONDS
				local out = HelperFetchRules.pose("fetch", from, to, walk / 2)
				expect(out.holding).to.equal(false)
				expect(math.abs(out.position.Z - -9) < 1e-6).to.equal(true)
				expect(out.facing.Z < 0).to.equal(true)
				expect(HelperFetchRules.pose("fetch", from, to, walk + pick * 0.25).holding).to.equal(
					false
				)
				expect(HelperFetchRules.pose("fetch", from, to, walk + pick * 0.75).holding).to.equal(
					true
				)
				local back = HelperFetchRules.pose("fetch", from, to, walk + pick + walk / 2)
				expect(back.holding).to.equal(true)
				expect(back.facing.Z > 0).to.equal(true)
				local home = HelperFetchRules.pose(
					"fetch",
					from,
					to,
					HelperFetchRules.totalSeconds(from, to) + 0.01
				)
				expect(home.done).to.equal(true)
				expect(home.holding).to.equal(false)
				expect(math.abs(HelperFetchRules.pickAt(from, to) - (walk + pick / 2)) < 1e-6).to.equal(
					true
				)
			end
		)

		it("carries the clean cat out and walks back empty", function()
			local from, to = Vector3.new(0, 0, 0), Vector3.new(9, 0, 0)
			local walk = HelperFetchRules.walkSeconds(from, to)
			expect(HelperFetchRules.pose("return", from, to, walk / 2).holding).to.equal(true)
			expect(
				HelperFetchRules.pose(
					"return",
					from,
					to,
					walk + HelperFetchRules.PICK_SECONDS + 0.1
				).holding
			).to.equal(false)
		end)

		it("keeps every walk between its bounds", function()
			local here = Vector3.new(1, 0, 1)
			expect(HelperFetchRules.walkSeconds(here, here)).to.equal(HelperFetchRules.MIN_WALK)
			expect(HelperFetchRules.walkSeconds(here, Vector3.new(500, 0, 0))).to.equal(
				HelperFetchRules.MAX_WALK
			)
			expect(HelperFetchRules.pose("fetch", here, Vector3.new(5, 0, 1), 0 / 0).done).to.equal(
				false
			)
		end)
		it(
			"keeps to the aisles on the big spa, never the straight line through the tubs",
			function()
				-- the big plot's own spots (Sync on 844315b): Jo's stand, station 2, the tub, counter cat 1
				local aisle = HelperFetchRules.aisle(
					Vector3.new(-17.5, 0.25, 9.5),
					Vector3.new(-7, 0.25, -4),
					Vector3.new(5, 0.25, -5),
					Vector3.new(3.4, 3.13, -17.9)
				)
				expect(math.abs(aisle.front - 2.75) < 1e-6).to.equal(true)
				expect(math.abs(aisle.lane - -1) < 1e-6).to.equal(true)
				expect(math.abs(aisle.counter - (-17.9 + HelperFetchRules.SHORT_OF)) < 1e-6).to.equal(
					true
				)
				local from = Vector3.new(-20.1, 0.25, 9.9)
				local via, stop = HelperFetchRules.route(from, Vector3.new(13, 3.13, -17.9), aisle)
				expect(#via).to.equal(3)
				expect(math.abs(stop.X - 13) < 1e-6 and math.abs(stop.Z - aisle.counter) < 1e-6).to.equal(
					true
				)
				expect(math.abs(stop.Y - from.Y) < 1e-6).to.equal(true)
				-- down the lane, clear of station 3 at X -13.5 and the tub at X 5
				expect(math.abs(via[2].X - -1) < 1e-6 and math.abs(via[3].X - -1) < 1e-6).to.equal(
					true
				)
				-- a cat at the door line (no counter): the straight line, as before
				local none, straight =
					HelperFetchRules.route(from, Vector3.new(-5, 0.25, -16), aisle)
				expect(#none).to.equal(0)
				expect(straight).to.equal(
					HelperFetchRules.stopFor(from, Vector3.new(-5, 0.25, -16))
				)
				local plain = HelperFetchRules.route(from, Vector3.new(13, 3.13, -17.9), nil)
				expect(#plain).to.equal(0)
			end
		)

		it("writes the corners as text and reads them back, and bad text as none", function()
			local corners = { Vector3.new(-20.1, 0.25, 2.75), Vector3.new(-1, 0.25, -15.9) }
			local back = HelperFetchRules.decode(HelperFetchRules.encode(corners))
			expect(#back).to.equal(2)
			expect((back[2] - corners[2]).Magnitude < 0.01).to.equal(true)
			expect(#HelperFetchRules.decode("")).to.equal(0)
			expect(#HelperFetchRules.decode("1,2;x")).to.equal(0)
			expect(#HelperFetchRules.decode(nil)).to.equal(0)
		end)

		it("walks the corners out and back, facing each stretch", function()
			local from, to = Vector3.new(0, 0, 0), Vector3.new(10, 0, -10)
			local via = { Vector3.new(0, 0, -10) }
			local walk = HelperFetchRules.walkSeconds(from, to, via)
			expect(math.abs(walk - 20 / HelperFetchRules.SPEED) < 1e-6).to.equal(true)
			local early = HelperFetchRules.pose("fetch", from, to, walk / 4, via)
			expect(math.abs(early.position.Z - -5) < 1e-6 and math.abs(early.position.X) < 1e-6).to.equal(
				true
			)
			expect(early.facing.Z < -0.99).to.equal(true)
			local late = HelperFetchRules.pose("fetch", from, to, walk * 0.75, via)
			expect(math.abs(late.position.X - 5) < 1e-6 and math.abs(late.position.Z - -10) < 1e-6).to.equal(
				true
			)
			expect(late.facing.X > 0.99).to.equal(true)
			local pick = HelperFetchRules.PICK_SECONDS
			local back = HelperFetchRules.pose("fetch", from, to, walk + pick + walk * 0.75, via)
			expect(math.abs(back.position.Z - -5) < 1e-6).to.equal(true)
			expect(back.facing.Z > 0.99).to.equal(true)
			expect(back.holding).to.equal(true)
			expect(
				math.abs(HelperFetchRules.totalSeconds(from, to, via) - (2 * walk + pick)) < 1e-6
			).to.equal(true)
		end)
	end)
end
