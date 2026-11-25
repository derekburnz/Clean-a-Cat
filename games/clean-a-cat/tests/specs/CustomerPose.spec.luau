--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local CustomerPose = require(Client:WaitForChild("Effects"):WaitForChild("CustomerPose")) :: any

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-4)
end

return function()
	describe("CustomerPose", function()
		it("finds Model-Agent's joints by suffix", function()
			expect(CustomerPose.jointKey("CleanACat_NPC_Customer_Sunny_LegL")).to.equal("LegL")
			expect(CustomerPose.jointKey("CleanACat_NPC_Customer_Mo_Head")).to.equal("Head")
			expect(CustomerPose.jointKey("Body")).to.equal("Body")
			expect(CustomerPose.jointKey("CleanACat_NPC_Customer_Mo_Hat")).to.equal(nil)
		end)
		it("steps at a cadence that keeps the feet from sliding", function()
			local legs, swing, speed = 2.2, CustomerPose.LEG_SWING, 6.5
			local cycles = CustomerPose.cadence(speed, legs, swing)
			-- two steps a cycle, each one stride long, cover exactly the distance walked
			expect(near(cycles * 2 * CustomerPose.stride(legs, swing), speed)).to.equal(true)
			expect(cycles > 0.8 and cycles < 2).to.equal(true) -- a believable pace for 6 to 7 studs a second
			expect(CustomerPose.cadence(5, 0, swing)).to.equal(0)
		end)
		it("stands still when slow and walks fully when fast, easing between", function()
			expect(CustomerPose.walkAmount(0)).to.equal(0)
			expect(CustomerPose.walkAmount(CustomerPose.WALK_FROM)).to.equal(0)
			expect(CustomerPose.walkAmount(CustomerPose.WALK_FULL)).to.equal(1)
			local mid =
				CustomerPose.walkAmount((CustomerPose.WALK_FROM + CustomerPose.WALK_FULL) / 2)
			expect(near(mid, 0.5)).to.equal(true)
		end)
		it(
			"swings the legs opposite, the free arm with the other leg, and keeps the carrying arm nearly still",
			function()
				local pose = CustomerPose.newPose()
				CustomerPose.sample(pose, 0.25, 1, 0, 0)
				expect(near(pose.legL, CustomerPose.LEG_SWING)).to.equal(true)
				expect(near(pose.legR, -CustomerPose.LEG_SWING)).to.equal(true)
				expect(pose.armL < 0).to.equal(true) -- back while the left leg is forward
				expect(math.abs(pose.armR) <= math.rad(3)).to.equal(true)
			end
		)
		it(
			"looks round and nods only when standing, and holds the head with reduced motion",
			function()
				local pose = CustomerPose.newPose()
				local biggest = 0
				for t = 0, 30, 0.25 do
					local pitch, yaw = CustomerPose.idle(t, 0.3, false)
					expect(math.abs(yaw) <= CustomerPose.LOOK + 1e-6).to.equal(true)
					expect(pitch >= 0 and pitch <= CustomerPose.NOD + 1e-6).to.equal(true)
					biggest = math.max(biggest, math.abs(yaw))
					CustomerPose.sample(pose, 0.1, 1, pitch, yaw)
					expect(pose.headYaw).to.equal(0) -- walking: eyes ahead
				end
				expect(biggest > CustomerPose.LOOK * 0.5).to.equal(true)
				local p, y = CustomerPose.idle(12, 0.3, true)
				expect(p).to.equal(0)
				expect(y).to.equal(0)
			end
		)
		it("approaches a target at the same pace whatever the frame rate", function()
			local a = CustomerPose.approach(0, 1, 6, 0.1)
			local b = CustomerPose.approach(CustomerPose.approach(0, 1, 6, 0.05), 1, 6, 0.05)
			expect(near(a, b)).to.equal(true)
		end)
		it("taps a foot only once the cat's heart bar is low, faster as it empties", function()
			expect(CustomerPose.tapEvery(0.4)).to.equal(CustomerPose.TAP_EVERY[1])
			expect(near(CustomerPose.tapEvery(0), CustomerPose.TAP_EVERY[2])).to.equal(true)
			local function lifted(fill: number, standing: number, still: boolean): boolean
				for i = 0, 60 do
					local pose = CustomerPose.newPose()
					CustomerPose.mood(pose, fill, i * 0.05, 0.2, standing, still)
					if pose.legL > 0 then
						return true
					end
				end
				return false
			end
			expect(lifted(0.8, 1, false)).to.equal(false)
			expect(lifted(0.2, 1, false)).to.equal(true)
			expect(lifted(0.2, 0, false)).to.equal(false)
			expect(lifted(0.2, 1, true)).to.equal(false)
		end)
		it("hangs the head as the cat leaves, with reduced motion too", function()
			local pose = CustomerPose.newPose()
			CustomerPose.mood(pose, 0, 1, 0.2, 1, true)
			expect(near(pose.headPitch, -CustomerPose.HEAD_DOWN)).to.equal(true)
			expect(pose.legL).to.equal(0)
		end)
	end)
end
