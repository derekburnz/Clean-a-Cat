--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local TruckDrop = require(Client:WaitForChild("Effects"):WaitForChild("TruckDrop")) :: any
	local B = TruckDrop.BEATS

	local function near(a: number, b: number, tolerance: number?): boolean
		return math.abs(a - b) < (tolerance or 1e-6)
	end

	describe("beats", function()
		it("run in order and stay short: about 5 seconds, slower since Derek's dev test", function()
			local order = { B.honk, B.frontHit, B.backHit, B.drop, B.land, B.settle, B.done }
			for i = 2, #order do
				expect(order[i] > order[i - 1]).to.equal(true)
			end
			expect(B.done <= 5.5).to.equal(true)
			-- Derek 2026-11-24: "start it further back and slower"
			expect(TruckDrop.speed() <= 22).to.equal(true)
			-- the bump kicks the box out: it leaves just after the back wheels' hit, once the door is open
			expect(B.drop > B.backHit and B.drop - B.backHit <= TruckDrop.DOOR.seconds + 0.05).to.equal(
				true
			)
			-- the watched intro holds the shot until the box is down and still (Derek: a watched intro)
			expect(B.done >= B.settle + 0.5).to.equal(true)
		end)
		it("events are sorted and found once each", function()
			local all = TruckDrop.eventsBetween(-1, 10)
			expect(#all).to.equal(#TruckDrop.EVENTS)
			local split = #TruckDrop.eventsBetween(-1, B.land - 0.01)
				+ #TruckDrop.eventsBetween(B.land - 0.01, 10)
			expect(split).to.equal(#TruckDrop.EVENTS)
			for i = 2, #TruckDrop.EVENTS do
				expect(TruckDrop.EVENTS[i].at >= TruckDrop.EVENTS[i - 1].at).to.equal(true)
			end
		end)
	end)

	describe("truck", function()
		it("puts each axle over the bump on its beat", function()
			local half = TruckDrop.WHEELBASE / 2
			expect(near(TruckDrop.truckX(B.frontHit) + half, TruckDrop.BUMP_X)).to.equal(true)
			expect(near(TruckDrop.truckX(B.backHit) - half, TruckDrop.BUMP_X)).to.equal(true)
		end)
		it("times both axles to a bump passed in, wherever it sits", function()
			local half = TruckDrop.WHEELBASE / 2
			for _, bx in { -11, -3, 4 } do
				expect(near(TruckDrop.truckX(B.frontHit, bx) + half, bx)).to.equal(true)
				expect(near(TruckDrop.truckX(B.backHit, bx) - half, bx)).to.equal(true)
				local landed = TruckDrop.box(B.land, false, bx)
				expect(near(landed.x, 0) and near(landed.z, 0)).to.equal(true)
				expect(near(TruckDrop.lookX(B.done, bx), 0)).to.equal(true)
			end
		end)
		it("falls back to BUMP_X for no bump, a broken one or one too far away", function()
			expect(TruckDrop.bumpAt(nil)).to.equal(TruckDrop.BUMP_X)
			expect(TruckDrop.bumpAt(0 / 0)).to.equal(TruckDrop.BUMP_X)
			expect(TruckDrop.bumpAt(TruckDrop.BUMP_RANGE + 1)).to.equal(TruckDrop.BUMP_X)
			expect(TruckDrop.bumpAt(-6)).to.equal(-6)
		end)
		it("matches the plot fallback: SpotBump sits BUMP_X along the road from SpotBox", function()
			local SpaLayout = require(game:GetService("ReplicatedStorage").Shared.SpaLayout) :: any
			local box = SpaLayout.PLOT_SPOTS.SpotBox
			local bump = SpaLayout.PLOT_SPOTS.SpotBump
			-- the road runs along the box spot's right vector; yaw turns it about Y
			local dx = bump.position.X - box.position.X
			local dz = bump.position.Z - box.position.Z
			local along = dx * math.cos(box.yaw) - dz * math.sin(box.yaw)
			expect(math.abs(along - TruckDrop.BUMP_X) <= 1).to.equal(true)
		end)
		it("starts and ends off to the sides", function()
			expect(TruckDrop.truckX(0) < -30).to.equal(true)
			expect(TruckDrop.truckX(B.done) > 30).to.equal(true)
		end)
		it("jolts only at the bump and not at all with reduced motion", function()
			expect(TruckDrop.truck(0.5, false).lift).to.equal(0)
			expect(TruckDrop.truck(B.frontHit + 0.1, false).lift > 0).to.equal(true)
			expect(TruckDrop.truck(B.frontHit + 0.1, false).pitch > 0).to.equal(true)
			local calm = TruckDrop.truck(B.frontHit + 0.1, true)
			expect(calm.lift).to.equal(0)
			expect(calm.pitch).to.equal(0)
		end)
		it("opens the door at the back wheels' hit", function()
			expect(TruckDrop.truck(B.backHit - 0.01, false).door).to.equal(0)
			expect(near(TruckDrop.truck(B.backHit + 1, true).door, TruckDrop.DOOR.open)).to.equal(
				true
			)
		end)
	end)

	describe("box", function()
		it("is hidden in the truck before the drop", function()
			expect(TruckDrop.box(B.drop - 0.01, false).visible).to.equal(false)
		end)
		it("leaves from the tailgate and lands on the origin", function()
			local lx, ly, lz = TruckDrop.launch()
			local start = TruckDrop.box(B.drop, false)
			expect(near(start.x, lx) and near(start.y, ly) and near(start.z, lz)).to.equal(true)
			local landed = TruckDrop.box(B.land, false)
			expect(near(landed.x, 0) and near(landed.y, 0) and near(landed.z, 0)).to.equal(true)
			-- one whole flip, landing on its back edge (short of flat by ARC.flop), slammed flat by the squash's end
			local a = TruckDrop.ARC
			expect(near(TruckDrop.box(B.land - 1e-4, false).tumble, -(a.spin - a.flop), 1e-2)).to.equal(
				true
			)
			local flat =
				TruckDrop.box(B.land + TruckDrop.LANDING.squashSeconds - 1e-4, false).tumble
			expect(near(math.cos(flat), 1, 1e-3)).to.equal(true)
			expect(TruckDrop.box(B.land + 0.05, true).tumble).to.equal(0)
		end)
		it(
			"is kicked out the back: drifts on along the road slower than the truck, and barely rises",
			function()
				local lx, ly = TruckDrop.launch()
				local drift = (0 - lx) / (B.land - B.drop)
				expect(drift > 0 and drift < TruckDrop.speed()).to.equal(true)
				local peak = 0
				for i = 0, 20 do
					local t = TruckDrop.BEATS.drop
						+ i / 20 * (TruckDrop.BEATS.land - TruckDrop.BEATS.drop)
					peak = math.max(peak, TruckDrop.box(t, false).y)
				end
				expect(peak - ly < 0.75).to.equal(true)
			end
		)
		it("arcs above the straight line", function()
			local mid = TruckDrop.box((B.drop + B.land) / 2, false)
			local _, ly = TruckDrop.launch()
			expect(mid.y > ly / 2).to.equal(true)
		end)
		it("squashes on landing, bounces twice, then rests", function()
			expect(TruckDrop.box(B.land + 0.05, false).squash < 1).to.equal(true)
			local l = TruckDrop.LANDING
			expect(TruckDrop.box(B.land + l.squashSeconds + l.bounceSeconds / 2, false).y > 0).to.equal(
				true
			)
			local second = B.land + l.squashSeconds + l.bounceSeconds + l.bounce2Seconds / 2
			expect(TruckDrop.box(second, false).y > 0).to.equal(true)
			expect(TruckDrop.box(second, false).y < l.bounce).to.equal(true)
			local rest = TruckDrop.box(B.settle + TruckDrop.LANDING.squashSeconds + 0.01, true)
			expect(rest.y).to.equal(0)
			expect(rest.squash).to.equal(1)
			expect(rest.roll).to.equal(0)
		end)
		it("is back on the ground by the settle beat", function()
			local l = TruckDrop.LANDING
			expect(B.land + l.squashSeconds + l.bounceSeconds + l.bounce2Seconds <= B.settle + 1e-6).to.equal(
				true
			)
		end)
	end)

	describe("wiggle", function()
		it("waits after the settle, then rocks and rests in turn", function()
			local w = TruckDrop.WIGGLE
			expect(TruckDrop.wiggleIndex(B.settle + w.start - 0.01)).to.equal(nil)
			expect(TruckDrop.wiggleIndex(B.settle + w.start + 0.1)).to.equal(0)
			expect(TruckDrop.wiggleIndex(B.settle + w.start + w.seconds + 0.05)).to.equal(nil)
			expect(TruckDrop.wiggleIndex(B.settle + w.start + w.every + 0.1)).to.equal(1)
			expect(TruckDrop.wiggle(B.settle + w.start + w.seconds + 0.05)).to.equal(0)
		end)
		it("meows on every other wiggle from the first", function()
			expect(TruckDrop.wiggleMeows(0)).to.equal(true)
			expect(TruckDrop.wiggleMeows(1)).to.equal(false)
			expect(TruckDrop.wiggleMeows(2)).to.equal(true)
		end)
	end)

	describe("open", function()
		it("swings the flaps fully and lifts the kitten to the rim", function()
			local flap0, rise0 = TruckDrop.open(0, false)
			expect(flap0).to.equal(0)
			expect(rise0).to.equal(0)
			local flap, rise = TruckDrop.open(TruckDrop.openSeconds(), false)
			expect(near(flap, TruckDrop.OPEN.flap)).to.equal(true)
			expect(near(rise, 1)).to.equal(true)
		end)
		it("overshoots only without reduced motion", function()
			local peak = 0
			local calmPeak = 0
			for i = 0, 40 do
				local e = i / 40 * TruckDrop.OPEN.flapSeconds
				peak = math.max(peak, (TruckDrop.open(e, false)))
				calmPeak = math.max(calmPeak, (TruckDrop.open(e, true)))
			end
			expect(peak > TruckDrop.OPEN.flap).to.equal(true)
			expect(near(calmPeak, TruckDrop.OPEN.flap)).to.equal(true)
		end)
	end)

	describe("hop", function()
		it("starts at the rim, ends on the ground and arcs between", function()
			local a0, h0 = TruckDrop.hop(0, false)
			expect(a0).to.equal(0)
			expect(h0).to.equal(0)
			local a1, h1 = TruckDrop.hop(TruckDrop.HOP.seconds, false)
			expect(near(a1, 1)).to.equal(true)
			expect(near(h1, 0)).to.equal(true)
			local _, mid = TruckDrop.hop(TruckDrop.HOP.seconds / 2, false)
			local _, calm = TruckDrop.hop(TruckDrop.HOP.seconds / 2, true)
			expect(near(mid, TruckDrop.HOP.height)).to.equal(true)
			expect(calm > 0 and calm < mid).to.equal(true)
		end)
		it("open's onDone waits for the shake-off", function()
			expect(TruckDrop.openDoneSeconds() > TruckDrop.openSeconds()).to.equal(true)
			expect(TruckDrop.openDoneSeconds() < 1.5).to.equal(true)
		end)
	end)

	describe("camera", function()
		it("ends the flight framed on the landing spot", function()
			expect(near(TruckDrop.lookX(B.land), 0)).to.equal(true)
			expect(near(TruckDrop.lookX(B.done), 0)).to.equal(true)
		end)
	end)
end
