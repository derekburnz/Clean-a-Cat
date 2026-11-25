--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CatPose = require(Client:WaitForChild("Effects"):WaitForChild("CatPose")) :: any

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("jointKey", function()
		it("reads plain and generated joint names", function()
			expect(CatPose.jointKey("Head")).to.equal("Head")
			expect(CatPose.jointKey("CleanACat_Cat_Cotton_Head")).to.equal("Head")
			expect(CatPose.jointKey("CleanACat_Cat_Inky_Dirty_EarL")).to.equal("EarL")
			expect(CatPose.jointKey("CleanACat_Cat_Cotton_Body")).to.equal("Body")
		end)
		it("ignores mud, tangles and lookalike names", function()
			expect(CatPose.jointKey("CleanACat_Cat_Cotton_Dirty_Mud02")).to.equal(nil)
			expect(CatPose.jointKey("CleanACat_Cat_Cotton_Dirty_Tangle03")).to.equal(nil)
			expect(CatPose.jointKey("Forehead")).to.equal(nil)
			expect(CatPose.jointKey("Bow")).to.equal(nil)
		end)
	end)

	describe("schedule", function()
		it("hash stays in [0, 1) and repeats", function()
			for n = 0, 50 do
				local h = CatPose.hash(0.37, n)
				expect(h >= 0 and h < 1).to.equal(true)
				expect(CatPose.hash(0.37, n)).to.equal(h)
			end
		end)
		it("gaps stay inside their range", function()
			for n = 0, 50 do
				local g = CatPose.gap(CatPose.BLINK_GAP, 0.81, n)
				expect(g >= CatPose.BLINK_GAP[1] and g <= CatPose.BLINK_GAP[2]).to.equal(true)
			end
		end)
	end)

	describe("sample", function()
		it("keeps every angle small at rest", function()
			local pose = CatPose.newPose()
			local state = CatPose.newState(0.2, 0)
			for t = 0, 30, 0.05 do
				CatPose.sample(pose, state, t, false)
				expect(math.abs(pose.headPitch) <= math.rad(2) + 1e-9).to.equal(true)
				expect(math.abs(pose.tailYaw) <= math.rad(14) + 1e-9).to.equal(true)
				expect(math.abs(pose.earL) <= math.rad(18)).to.equal(true)
				expect(pose.blink >= 0 and pose.blink <= 1).to.equal(true)
			end
		end)
		it("blinks within the first gap and opens again", function()
			local pose = CatPose.newPose()
			local state = CatPose.newState(0.5, 0)
			local start = state.blinkAt
			expect(start >= CatPose.BLINK_GAP[1] and start <= CatPose.BLINK_GAP[2]).to.equal(true)
			CatPose.sample(pose, state, start + CatPose.BLINK_SECONDS / 2, false)
			expect(near(pose.blink, 1)).to.equal(true)
			CatPose.sample(pose, state, start + CatPose.BLINK_SECONDS + 0.01, false)
			expect(pose.blink).to.equal(0)
			expect(state.blinkAt > start).to.equal(true)
		end)
		it("catches the schedule up after a long pause", function()
			local pose = CatPose.newPose()
			local state = CatPose.newState(0.5, 0)
			CatPose.sample(pose, state, 600, false)
			expect(state.blinkAt + CatPose.BLINK_SECONDS > 600).to.equal(true)
			expect(state.twitchAt + CatPose.TWITCH_SECONDS > 600).to.equal(true)
		end)
		it("Reduce Motion stops idle, twitch, shake and wiggle but keeps the blink", function()
			local pose = CatPose.newPose()
			local state = CatPose.newState(0.3, 0)
			state.shakeAt = 10
			state.wiggleAt = 10
			CatPose.sample(pose, state, 10.2, true)
			expect(pose.headPitch).to.equal(0)
			expect(pose.headRoll).to.equal(0)
			expect(pose.tailYaw).to.equal(0)
			expect(pose.earL).to.equal(0)
			expect(pose.earR).to.equal(0)
			CatPose.sample(pose, state, state.blinkAt + CatPose.BLINK_SECONDS / 2, true)
			expect(pose.blink > 0.9).to.equal(true)
		end)
		it("shakes only for SHAKE_SECONDS", function()
			local pose = CatPose.newPose()
			local state = CatPose.newState(0.3, 0)
			state.shakeAt = 5
			expect(CatPose.busy(state, 5.1)).to.equal(true)
			CatPose.sample(pose, state, 5 + 0.0625 / 2 * 1, false)
			local during = pose.headRoll
			expect(math.abs(during) > math.rad(5)).to.equal(true)
			CatPose.sample(pose, state, 5 + CatPose.SHAKE_SECONDS, false)
			expect(pose.headRoll).to.equal(0)
			expect(CatPose.busy(state, 5 + CatPose.SHAKE_SECONDS)).to.equal(false)
		end)
		it("wiggles the tail up during the happy wiggle", function()
			local pose = CatPose.newPose()
			local state = CatPose.newState(0.3, 0)
			local idle = CatPose.newPose()
			local idleState = CatPose.newState(0.3, 0)
			state.wiggleAt = 8
			CatPose.sample(pose, state, 8 + CatPose.WIGGLE_SECONDS / 2, false)
			CatPose.sample(idle, idleState, 8 + CatPose.WIGGLE_SECONDS / 2, false)
			expect(pose.tailPitch - idle.tailPitch > math.rad(19)).to.equal(true)
		end)
	end)

	describe("curves", function()
		it("hump and wobble are zero outside their window", function()
			expect(CatPose.hump(-0.1, 1)).to.equal(0)
			expect(CatPose.hump(1, 1)).to.equal(0)
			expect(near(CatPose.hump(0.5, 1), 1)).to.equal(true)
			expect(CatPose.wobble(1.2, 1, 3)).to.equal(0)
			expect(near(CatPose.wobble(0, 1, 3), 0)).to.equal(true)
		end)
	end)

	describe("step", function()
		it("runs near cats at full rate, far ones at half, and stops past FAR", function()
			expect(CatPose.step(10, "low")).to.equal(CatPose.STEP.low)
			expect(CatPose.step(45, "low")).to.equal(CatPose.STEP.low * 2)
			expect(CatPose.step(45, "high")).to.equal(CatPose.STEP.high * 2)
			expect(CatPose.step(61, "high")).to.equal(nil)
		end)
		it("lets phones move fewer cats", function()
			expect(CatPose.MAX_CATS.low < CatPose.MAX_CATS.high).to.equal(true)
		end)
	end)
	describe("mood", function()
		it("is happy with a full bar, grumpy as it drops and gone when empty", function()
			local h, g, x = CatPose.mood(1)
			expect(h).to.equal(1)
			expect(g).to.equal(0)
			expect(x).to.equal(0)
			h, g, x = CatPose.mood(0.25)
			expect(h).to.equal(0)
			expect(g).to.equal(1)
			expect(x).to.equal(0)
			h, g, x = CatPose.mood(0)
			expect(h).to.equal(0)
			expect(g).to.equal(0)
			expect(x).to.equal(1)
		end)
		it("changes smoothly as the bar drains", function()
			local last = { CatPose.mood(1) }
			for i = 999, 0, -1 do
				local now = { CatPose.mood(i / 1000) }
				for k = 1, 3 do
					expect(math.abs(now[k] - last[k]) < 0.02).to.equal(true)
				end
				last = now
			end
		end)
		it("clamps a fill outside 0 to 1", function()
			local a = { CatPose.mood(-2) }
			local b = { CatPose.mood(0) }
			expect(a[3]).to.equal(b[3])
			local c = { CatPose.mood(5) }
			expect(c[1]).to.equal(1)
		end)
		it(
			"lifts the tail when happy, puts the ears out when grumpy and drops everything when leaving",
			function()
				local state = CatPose.newState(0.3, 0)
				local function at(fill: number)
					local pose = CatPose.newPose()
					CatPose.sample(pose, state, 0, true)
					CatPose.applyMood(pose, state, 0, fill, true)
					return pose
				end
				local happy, grumpy, gone = at(1), at(0.25), at(0)
				expect(happy.tailPitch < 0).to.equal(true)
				expect(happy.earL).to.equal(0)
				expect(grumpy.earL < 0 and grumpy.earR > 0).to.equal(true)
				expect(grumpy.headPitch < 0).to.equal(true)
				expect(gone.earR > grumpy.earR).to.equal(true)
				expect(gone.headPitch < grumpy.headPitch).to.equal(true)
				expect(gone.tailPitch > 0).to.equal(true)
			end
		)
		it(
			"reads the mood from the cat or its customer, and lets go once the cat is carried away",
			function()
				-- plain tables stand in for the instances: customer > carrier > cat
				local customer = { parent = nil :: any, fill = true }
				local carrier = { parent = customer, fill = false }
				local cat = { parent = carrier, fill = false }
				local function parentOf(n: any): any
					return n.parent
				end
				local function hasFill(n: any): boolean
					return n.fill
				end
				expect(CatPose.moodHolder(cat, parentOf, hasFill)).to.equal(customer)
				expect(CatPose.within(cat, customer, parentOf)).to.equal(true)
				-- the player lifts the cat out and carries it to the tub
				local tub = { parent = nil :: any, fill = false }
				cat.parent = tub
				expect(CatPose.within(cat, customer, parentOf)).to.equal(false)
				expect(CatPose.moodHolder(cat, parentOf, hasFill)).to.equal(nil)
				-- a cat that carries the attribute itself reads its own
				cat.fill = true
				expect(CatPose.moodHolder(cat, parentOf, hasFill)).to.equal(cat)
				expect(CatPose.within(cat, cat, parentOf)).to.equal(true)
			end
		)
		it("looks only a few steps up", function()
			local top = { parent = nil :: any, fill = true }
			local node: any = top
			for _ = 1, CatPose.MOOD_REACH + 1 do
				node = { parent = node, fill = false }
			end
			local function parentOf(n: any): any
				return n.parent
			end
			expect(CatPose.moodHolder(node, parentOf, function(n: any)
				return n.fill
			end)).to.equal(nil)
			expect(CatPose.within(node, top, parentOf)).to.equal(false)
		end)
		it("lashes the grumpy tail only with motion on", function()
			local state = CatPose.newState(0, 0)
			local moving, still = false, true
			for i = 0, 32 do
				local t = i * 0.05
				local a, b = CatPose.newPose(), CatPose.newPose()
				CatPose.applyMood(a, state, t, 0.25, false)
				CatPose.applyMood(b, state, t, 0.25, true)
				if math.abs(a.tailYaw) > math.rad(5) then
					moving = true
				end
				if b.tailYaw ~= 0 then
					still = false
				end
			end
			expect(moving).to.equal(true)
			expect(still).to.equal(true)
		end)
	end)
end
