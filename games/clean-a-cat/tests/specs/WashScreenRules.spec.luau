--!strict
return function()
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
	local WashScreenRules = require(game:GetService("ReplicatedStorage").Shared.WashScreenRules)

	describe("WashScreenRules", function()
		it("ships behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, WashScreenRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[WashScreenRules.FLAG]).to.equal(true)
			expect(WashScreenRules.on(function()
				return false
			end)).to.equal(false)
		end)

		it("keeps the wash camera inside the room", function()
			-- the scene's camera: about 6 studs out and 4.5 up from the cat (Effects/WashCamera)
			local spot = Vector3.new(100, 2, -40)
			expect(WashScreenRules.inRoom(spot + Vector3.new(6, 4.5, 0), spot)).to.equal(true)
			expect(WashScreenRules.inRoom(spot + Vector3.new(0, 4.5, -6), spot)).to.equal(true)
			expect(WashScreenRules.HALF - 6 >= 2).to.equal(true)
		end)

		it(
			"hides what stands out from the tub and keeps the tub, the cat and its bubbles",
			function()
				local spot = Vector3.new(0, 0, 0)
				expect(WashScreenRules.keeps(Vector3.new(1, 2, 1), spot)).to.equal(true)
				expect(WashScreenRules.keeps(Vector3.new(0, 6, 3), spot)).to.equal(true)
				expect(WashScreenRules.keeps(Vector3.new(5, 1, 0), spot)).to.equal(false)
				expect(WashScreenRules.inRoom(Vector3.new(5, 1, 0), spot)).to.equal(true)
				expect(WashScreenRules.inRoom(Vector3.new(15, 1, 0), spot)).to.equal(false)
				expect(WashScreenRules.inRoom(Vector3.new(0, 20, 0), spot)).to.equal(false)
			end
		)
	end)
end
