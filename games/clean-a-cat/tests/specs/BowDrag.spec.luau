--!strict
return function()
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)

	describe("BowDrag (bowDrag)", function()
		it("ships behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, "bowDrag")).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT.bowDrag).to.equal(true)
		end)
	end)
end
