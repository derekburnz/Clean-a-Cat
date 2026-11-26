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

		it("frames the cat from the front at about eye level", function()
			local look = Vector3.new(10, 3, 5)
			local facing = Vector3.new(0, 0, -1) -- a cat facing -Z
			local from = WashScreenRules.frontFrom(look, facing, 8, 3.6)
			-- in front of his face, not off to a side
			expect(from.Z < look.Z - 7).to.equal(true)
			expect(math.abs(from.X - look.X) < 0.01).to.equal(true)
			-- at his eyes plus a little, so a gentle slope, not the old 38 degrees from above
			expect(math.abs(from.Y - (3.6 + WashScreenRules.EYE_ABOVE)) < 0.01).to.equal(true)
			expect(math.abs((from - look).Magnitude - 8) < 0.01).to.equal(true)
		end)

		it("holds the slope with no eyes and with eyes far above", function()
			local look = Vector3.new(0, 2, 0)
			local plain = WashScreenRules.frontFrom(look, Vector3.new(1, 0.5, 0), 6, nil)
			local rise = math.sin(math.rad(WashScreenRules.FRONT_PITCH)) * 6
			expect(math.abs(plain.Y - look.Y - rise) < 0.01).to.equal(true)
			expect(plain.X > 5).to.equal(true)
			local steep = WashScreenRules.frontFrom(look, Vector3.new(0, 0, 1), 6, 50)
			expect(steep.Y - look.Y <= math.sin(math.rad(WashScreenRules.MAX_PITCH)) * 6 + 1e-6).to.equal(
				true
			)
		end)
	end)
end
