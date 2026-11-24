--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrailRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrailRules"))

return function()
	describe("TrailRules.marks", function()
		it("lays arrows on the floor between the feet and the spot, facing the spot", function()
			local marks = TrailRules.marks(Vector3.new(0, 5, 0), Vector3.new(0, 9, 20), 2, 0)
			expect(#marks > 3).to.equal(true)
			for _, mark in marks do
				local position = mark.position
				expect(position.Y).to.equal(2)
				expect(math.abs(position.X) < 1e-6).to.equal(true)
				expect(position.Z >= TrailRules.START_GAP - 1e-6).to.equal(true)
				expect(position.Z <= 20 - TrailRules.END_GAP + 1e-6).to.equal(true)
				expect(mark.direction:Dot(Vector3.new(0, 0, 1)) > 0.999).to.equal(true)
				expect(mark.fade >= 0 and mark.fade <= 1).to.equal(true)
			end
		end)

		it("slides the arrows toward the spot as the phase grows", function()
			local before = TrailRules.marks(Vector3.zero, Vector3.new(30, 0, 0), 0, 0.1)
			local after = TrailRules.marks(Vector3.zero, Vector3.new(30, 0, 0), 0, 0.6)
			expect(after[1].position.X > before[1].position.X).to.equal(true)
		end)

		it("shows nothing when the player is already at the spot, and never too many", function()
			expect(#TrailRules.marks(Vector3.zero, Vector3.new(2, 0, 0), 0, 0)).to.equal(0)
			local far = TrailRules.marks(Vector3.zero, Vector3.new(5000, 0, 0), 0, 0)
			expect(#far).to.equal(TrailRules.MAX_MARKS)
		end)

		it("fades the arrows in at the feet and out at the spot", function()
			local marks = TrailRules.marks(Vector3.zero, Vector3.new(40, 0, 0), 0, 0)
			expect(marks[1].fade).to.equal(1)
			local middle = marks[math.floor(#marks / 2)]
			expect(middle.fade).to.equal(0)
		end)
	end)
end
