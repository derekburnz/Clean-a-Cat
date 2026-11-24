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
			local order =
				{ B.honk, B.frontHit, B.slide, B.drop, B.backHit, B.land, B.settle, B.done }
			for i = 2, #order do
				expect(order[i] > order[i - 1]).to.equal(true)
			end
			expect(B.done <= 5.5).to.equal(true)
			-- Derek 2026-11-24: "start it further back and slower"
			expect(TruckDrop.speed() <= 22).to.equal(true)
			-- the watched intro holds the shot until the box is down and still
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
			-- a thud for each face it rolls onto: three tumbles, then the settle
			local tumbles = 0
			for _, name in all do
				if name == "tumble" then
					tumbles += 1
				end
			end
			expect(tumbles).to.equal(3)
		end)
	end)

	describe("truck", function()
		it("puts each axle over the pothole on its beat", function()
			local half = TruckDrop.WHEELBASE / 2
			expect(near(TruckDrop.truckX(B.frontHit) + half, TruckDrop.BUMP_X)).to.equal(true)
			expect(near(TruckDrop.truckX(B.backHit) - half, TruckDrop.BUMP_X)).to.equal(true)
		end)
		it(
			"times both axles to a pothole passed in, and the box still stops on the origin",
			function()
				local half = TruckDrop.WHEELBASE / 2
				for _, bx in { -11, -7.5, -4 } do
					expect(near(TruckDrop.truckX(B.frontHit, bx) + half, bx)).to.equal(true)
					expect(near(TruckDrop.truckX(B.backHit, bx) - half, bx)).to.equal(true)
					local rest = TruckDrop.box(B.settle, false, bx)
					expect(near(rest.x, 0) and near(rest.y, 0) and near(rest.z, 0)).to.equal(true)
					expect(near(TruckDrop.lookX(B.done, bx), 0)).to.equal(true)
				end
			end
		)
		it("falls back to BUMP_X for no pothole, a broken one or one too far away", function()
			expect(TruckDrop.bumpAt(nil)).to.equal(TruckDrop.BUMP_X)
			expect(TruckDrop.bumpAt(0 / 0)).to.equal(TruckDrop.BUMP_X)
			expect(TruckDrop.bumpAt(TruckDrop.BUMP_RANGE + 1)).to.equal(TruckDrop.BUMP_X)
			expect(TruckDrop.bumpAt(-6)).to.equal(-6)
		end)
		it("matches the plot: SpotBump sits BUMP_X along the road from SpotBox", function()
			local SpaLayout = require(game:GetService("ReplicatedStorage").Shared.SpaLayout) :: any
			local box = SpaLayout.PLOT_SPOTS.SpotBox
			local bump = SpaLayout.PLOT_SPOTS.SpotBump
			-- the road runs along the box spot's right vector; yaw turns it about Y
			local dx = bump.position.X - box.position.X
			local dz = bump.position.Z - box.position.Z
			local along = dx * math.cos(box.yaw) - dz * math.sin(box.yaw)
			expect(math.abs(along - TruckDrop.BUMP_X) <= 1).to.equal(true)
		end)
		it(
			"puts the pothole close in front of the player (Derek: closer to being right in front of you)",
			function()
				local SpaLayout =
					require(game:GetService("ReplicatedStorage").Shared.SpaLayout) :: any
				local player = SpaLayout.PLOT_SPOTS.SpotOpening.position
				local bump = SpaLayout.PLOT_SPOTS.SpotBump.position
				expect(math.abs(bump.X - player.X) <= 3).to.equal(true)
			end
		)
		it("starts and ends off to the sides", function()
			expect(TruckDrop.truckX(0) < -30).to.equal(true)
			expect(TruckDrop.truckX(B.done) > 30).to.equal(true)
		end)
		it("dips into the pothole and not at all with reduced motion", function()
			expect(TruckDrop.truck(0.5, false).lift).to.equal(0)
			local hit = TruckDrop.truck(B.frontHit + 0.08, false)
			expect(hit.lift < 0).to.equal(true) -- down into it
			expect(hit.pitch < 0).to.equal(true) -- nose first
			local calm = TruckDrop.truck(B.frontHit + 0.08, true)
			expect(calm.lift).to.equal(0)
			expect(calm.pitch).to.equal(0)
		end)
		it(
			"kicks the door open at the front wheels' drop, only briefly, then slams it shut",
			function()
				expect(TruckDrop.truck(B.frontHit - 0.01, false).door).to.equal(0)
				expect(TruckDrop.truck(B.slide, false).door > math.rad(60)).to.equal(true)
				expect(TruckDrop.truck(B.drop, true).door).to.equal(TruckDrop.DOOR.open)
				local shut = B.drop + TruckDrop.DOOR.hold + TruckDrop.DOOR.closeSeconds
				expect(shut - B.frontHit <= 0.8).to.equal(true)
				expect(TruckDrop.truck(shut + 0.5, false).door).to.equal(0)
				expect(TruckDrop.truck(shut + 0.01, true).door).to.equal(0)
			end
		)
	end)

	describe("box", function()
		local W, H = TruckDrop.BOX.width, TruckDrop.BOX.height
		it("is hidden in the truck until it slides out of the open door", function()
			expect(TruckDrop.box(B.slide - 0.01, false).visible).to.equal(false)
			expect(TruckDrop.box(B.slide, false).visible).to.equal(true)
		end)
		it("slides out with the truck and tips off the door's edge", function()
			local lx, ly, lz = TruckDrop.launch()
			local tip = TruckDrop.box(B.drop, false)
			expect(near(tip.x, lx, 1e-3) and near(tip.y + H / 2, ly, 1e-3) and near(tip.z, lz)).to.equal(
				true
			)
			-- still inside at the start of the slide, moving with the truck
			local start = TruckDrop.box(B.slide, false)
			expect(start.x > TruckDrop.truckX(B.slide) - TruckDrop.TAILGATE.back).to.equal(true)
		end)
		it("falls with the truck's way and weight: no float toward the player", function()
			local lx = TruckDrop.launch()
			local cx0 = TruckDrop.rollCenter(TruckDrop.ROLL.tilt)
			local drift = (cx0 - lx) / (B.land - B.drop)
			-- it carries on along the road at most at the truck's speed, and not much slower
			expect(drift > 0.4 * TruckDrop.speed() and drift <= TruckDrop.speed()).to.equal(true)
			-- it never rises above the door: it falls, it is not thrown up
			local _, ly = TruckDrop.launch()
			for i = 0, 10 do
				local t = B.drop + i / 10 * (B.land - B.drop)
				expect(TruckDrop.box(t, false).y + H / 2 <= ly + 0.05).to.equal(true)
			end
		end)
		it("lands on its leading edge and rolls a whole turn to stop flat on the origin", function()
			-- the roll's geometry: a whole turn ends flat over x = 0, and its quarters join up
			local cx, cy = TruckDrop.rollCenter(2 * math.pi)
			expect(near(cx, 0, 1e-6) and near(cy, H / 2, 1e-6)).to.equal(true)
			for k = 1, 3 do
				local a = k * math.pi / 2
				local x1, y1 = TruckDrop.rollCenter(a - 1e-6)
				local x2, y2 = TruckDrop.rollCenter(a + 1e-6)
				expect(near(x1, x2, 1e-4) and near(y1, y2, 1e-4)).to.equal(true)
			end
			expect(math.abs(TruckDrop.box(B.land, false).roll - TruckDrop.ROLL.tilt) < 1e-3).to.equal(
				true
			)
			local mid = TruckDrop.box((B.land + TruckDrop.rollEnd()) / 2, false)
			expect(mid.roll > math.pi / 2 and mid.roll < 2 * math.pi).to.equal(true)
			local rest = TruckDrop.box(B.settle + 0.01, true)
			expect(rest.x).to.equal(0)
			expect(rest.y).to.equal(0)
			expect(rest.z).to.equal(0)
			expect(rest.roll).to.equal(0)
			expect(rest.squash).to.equal(1)
		end)
		it("slaps down flat at the end of the roll", function()
			local slap =
				TruckDrop.box(TruckDrop.rollEnd() + TruckDrop.LANDING.squashSeconds / 2, false)
			expect(slap.squash < 1).to.equal(true)
		end)
		it("slides to a stop without turning under reduced motion", function()
			for i = 0, 10 do
				local t = B.drop + i / 10 * (B.settle - B.drop)
				expect(TruckDrop.box(t, true).roll).to.equal(0)
			end
			expect(near(TruckDrop.box(B.settle, true).x, 0)).to.equal(true)
		end)
		it("rolls about 8 studs, so the pothole sits about that far up the road", function()
			local roll = 2 * (W + H)
			expect(roll > 7 and roll < 9).to.equal(true)
			expect(math.abs(TruckDrop.BUMP_X) < roll).to.equal(true)
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
		it("follows the box and ends framed on its resting spot", function()
			expect(near(TruckDrop.lookX(B.land), TruckDrop.box(B.land, true).x)).to.equal(true)
			expect(near(TruckDrop.lookX(B.done), 0)).to.equal(true)
		end)
	end)
end
