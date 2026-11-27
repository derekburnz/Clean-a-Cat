--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local StaffCarry = require(Client:WaitForChild("Effects"):WaitForChild("StaffCarry")) :: any

-- Jo's arms raised forward about 62 degrees: shoulders at 0.5 studs up, hands 1.0 in front and 0.05 down
local ARMS = {
	Vector3.new(-0.9, 0.5, 0),
	Vector3.new(-0.9, -0.05, -1.05),
	Vector3.new(0.9, 0.5, 0),
	Vector3.new(0.9, -0.05, -1.05),
}

return function()
	describe("StaffCarry.spot", function()
		it(
			"lays a loaf on the arms' top surface, in front of the chest and between the hands",
			function()
				local at = StaffCarry.spot(ARMS, 0.8, Vector3.new(1.0, 0.9, 2.2), true)
				expect(at.Z < -0.4).to.equal(true) -- clear of the chest
				expect(at.Z >= -1.05).to.equal(true) -- not past the hands
				expect(math.abs(at.X - StaffCarry.SIDE) < 1e-6).to.equal(true)
				-- resting on the arms: the arm's top at that depth, plus the small gap
				local t = at.Z / -1.05
				local top = 0.5 + (-0.05 - 0.5) * t + StaffCarry.ARM_HALF
				expect(math.abs(at.Y - (top + StaffCarry.GAP)) < 1e-6).to.equal(true)
			end
		)
		it("keeps a big cat on the arms, never out past the hands", function()
			local at = StaffCarry.spot(ARMS, 0.8, Vector3.new(3, 1.2, 3), true)
			expect(at.Z >= -1.05).to.equal(true)
		end)
		it("sits a cat with no loaf on the arms facing out", function()
			local at = StaffCarry.spot(ARMS, 0.8, Vector3.new(1.0, 1.4, 1.2), false)
			expect(at.Z < -0.4 and at.Z >= -1.05).to.equal(true)
			expect(math.abs(at.X) < 1e-6).to.equal(true)
		end)
	end)
end
