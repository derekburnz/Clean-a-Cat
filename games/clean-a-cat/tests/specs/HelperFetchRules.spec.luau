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
	end)
end
