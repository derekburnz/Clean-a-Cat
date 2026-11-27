--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local StaffPose = require(Client:WaitForChild("Effects"):WaitForChild("StaffPose")) :: any

	local function pose()
		return { legL = 0.1, legR = -0.1, armL = 0.2, armR = 0, headPitch = 0.05, headYaw = 0.3 }
	end

	describe("StaffPose.freeArms", function()
		it("swings the right arm against the left", function()
			local p = pose()
			StaffPose.freeArms(p)
			expect(p.armR).to.equal(-0.2)
		end)
	end)

	describe("StaffPose.scrub", function()
		it("leaves the pose alone when not washing", function()
			local p = pose()
			StaffPose.scrub(p, 1.3, 0.4, 0, false)
			expect(p.armL).to.equal(0.2)
			expect(p.headYaw).to.equal(0.3)
		end)
		it("reaches both arms forward and rubs them in turn, within the rub", function()
			for i = 0, 100 do
				local p = pose()
				StaffPose.scrub(p, i / 37, 0.2, 1, false)
				expect(math.abs(p.armL - StaffPose.REACH) <= StaffPose.RUB + 1e-9).to.equal(true)
				expect(math.abs((p.armL + p.armR) / 2 - StaffPose.REACH) < 1e-9).to.equal(true)
				expect(p.headPitch <= -StaffPose.LOOK_DOWN + 1e-9).to.equal(true)
				expect(p.headYaw).to.equal(0)
				expect(p.legL).to.equal(0.1)
			end
		end)
		it("holds the reach without rubbing under Reduced Motion", function()
			local p = pose()
			StaffPose.scrub(p, 0.77, 0.6, 1, true)
			expect(p.armL).to.equal(StaffPose.REACH)
			expect(p.armR).to.equal(StaffPose.REACH)
			expect(p.headPitch).to.equal(-StaffPose.LOOK_DOWN)
		end)
		it("blends part way at a part amount", function()
			local p = pose()
			StaffPose.scrub(p, 0, 0, 0.5, true)
			expect(math.abs(p.armL - (0.2 + StaffPose.REACH) / 2) < 1e-9).to.equal(true)
		end)
	end)

	describe("StaffPose.carry (helperFetch, issue 884)", function()
		it("leaves the pose alone at no amount", function()
			local p = pose()
			StaffPose.carry(p, 0)
			expect(p.armL).to.equal(0.2)
		end)
		it("holds both arms forward under the cat and looks down, legs untouched", function()
			local p = pose()
			StaffPose.carry(p, 1)
			expect(math.abs(p.armL - StaffPose.CARRY) < 1e-9).to.equal(true)
			expect(math.abs(p.armR - StaffPose.CARRY) < 1e-9).to.equal(true)
			expect(math.abs(p.headPitch + StaffPose.CARRY_LOOK) < 1e-9).to.equal(true)
			expect(p.legL).to.equal(0.1)
		end)
	end)

	describe("StaffPose.hammer (humanBuilder, issue 891)", function()
		it("lifts slowly and strikes fast, from the work to the top and back", function()
			expect(StaffPose.hammerLift(0)).to.equal(0)
			expect(math.abs(StaffPose.hammerLift(1 - StaffPose.HAMMER_STRIKE) - 1) < 1e-9).to.equal(
				true
			)
			expect(math.abs(StaffPose.hammerLift(0.999999)) < 1e-4).to.equal(true)
			for i = 0, 100 do
				local h = StaffPose.hammerLift(i / 100)
				expect(h >= -1e-9 and h <= 1 + 1e-9).to.equal(true)
			end
		end)
		it("keeps the right arm between the work and the top, the left steadying", function()
			for i = 0, 60 do
				local p = pose()
				StaffPose.hammer(p, i / 23, 0.3, 1, false)
				expect(
					p.armR >= StaffPose.HAMMER_DOWN - 1e-9 and p.armR <= StaffPose.HAMMER_UP + 1e-9
				).to.equal(true)
				expect(math.abs(p.armL - StaffPose.STEADY) < 1e-9).to.equal(true)
				expect(math.abs(p.headPitch + StaffPose.HAMMER_LOOK) < 1e-9).to.equal(true)
				expect(p.legR).to.equal(-0.1)
			end
		end)
		it(
			"holds the hammer still halfway under Reduced Motion, and nothing at no amount",
			function()
				local p = pose()
				StaffPose.hammer(p, 0.4, 0, 1, true)
				local mid = (StaffPose.HAMMER_UP + StaffPose.HAMMER_DOWN) / 2
				expect(math.abs(p.armR - mid) < 1e-9).to.equal(true)
				local q = pose()
				StaffPose.hammer(q, 0.4, 0, 0, false)
				expect(q.armR).to.equal(0)
			end
		)
	end)
end
