--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WalkRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WalkRules"))

return function()
	describe("WalkRules", function()
		it("times a walk at the model's speed, or the default", function()
			expect(WalkRules.duration(13, 6.5)).to.equal(2)
			expect(WalkRules.duration(13, nil)).to.equal(13 / WalkRules.DEFAULT_SPEED)
			expect(WalkRules.duration(-1, 6.5)).to.equal(0)
		end)

		it("is not under way before it starts, and stops at the mat", function()
			expect(WalkRules.progress(-0.1, 2)).to.equal(nil)
			expect(WalkRules.progress(1, 2)).to.equal(0.5)
			expect(WalkRules.progress(5, 2)).to.equal(1)
			expect(WalkRules.progress(0, 0)).to.equal(1)
		end)

		it("faces the way of a walk up the line, not of a step back", function()
			local mat, look = Vector3.new(0, 0, 0), Vector3.new(0, 0, 1) -- faces +Z, as the queue mats
			expect(WalkRules.facesTravel(Vector3.new(0, 0, -16), mat, look)).to.equal(true)
			expect(WalkRules.facesTravel(Vector3.new(0, 0, 4), mat, look)).to.equal(false)
			expect(WalkRules.facesTravel(Vector3.new(0, 3, 0), mat, look)).to.equal(false)
		end)
	end)
end
