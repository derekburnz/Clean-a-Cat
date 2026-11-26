--!strict
return function()
	local VisitRules = require(game:GetService("ReplicatedStorage").Shared.VisitRules)

	describe("VisitRules", function()
		it("adds 10% a friend, at most 30%", function()
			expect(VisitRules.friendShare(0)).to.equal(0)
			expect(VisitRules.friendShare(1)).to.equal(0.1)
			expect(VisitRules.friendShare(3)).to.equal(0.3)
			expect(VisitRules.friendShare(5)).to.equal(0.3)
			expect(VisitRules.friendShare(0 / 0)).to.equal(0)
			expect(VisitRules.friendExtra(40, 2)).to.equal(8)
			expect(VisitRules.friendExtra(25, 1)).to.equal(3) -- 2.5 rounds up
			expect(VisitRules.friendExtra(40, 0)).to.equal(0)
		end)

		it("tells the inside from the pavement and the street", function()
			expect(VisitRules.inside(Vector3.new(5, 0.5, -2))).to.equal(true) -- the tub
			expect(VisitRules.inside(Vector3.new(-5, 0.5, -13))).to.equal(true) -- the first mat, in the door
			expect(VisitRules.inside(Vector3.new(-5, 0.5, -21.5))).to.equal(false) -- the last mat, on the pavement
			expect(VisitRules.inside(VisitRules.OUTSIDE)).to.equal(false)
			expect(VisitRules.inside(Vector3.new(30, 0.5, 0))).to.equal(false) -- the next plot
		end)

		it("takes only a true or false setting", function()
			expect(VisitRules.cleanSetting(false)).to.equal(false)
			expect(VisitRules.cleanSetting(true)).to.equal(true)
			expect(VisitRules.cleanSetting("no")).to.equal(nil)
			expect(VisitRules.cleanSetting(0)).to.equal(nil)
		end)
	end)
end
