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
end
