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

		it("counts a figure poking into the room through a wall", function()
			-- the counter cats have CanQuery off, so they are checked by place (Sync-Agent on PR 979)
			local spot = Vector3.new(0, 0, 0)
			local h = WashScreenRules.HALF
			expect(WashScreenRules.reaches(Vector3.new(0, 2, -(h + 0.5)), 1, spot)).to.equal(true)
			expect(WashScreenRules.reaches(Vector3.new(0, 2, -(h + 5)), 1, spot)).to.equal(false)
			expect(WashScreenRules.reaches(Vector3.new(4, 2, 4), 0.5, spot)).to.equal(true)
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

		it("frames the cat clear of the step dots and the tool tray (issue 924)", function()
			-- Sync-Agent's iPhone 13 numbers: a 3.15 stud box at field of view 50
			local d = WashScreenRules.frontDistance(3.15, 50)
			local screen = 2 * d * math.tan(math.rad(50) / 2) -- studs of screen height at that distance
			local share = 3.15 / screen
			expect(math.abs(share - WashScreenRules.FRONT_FILL) < 1e-6).to.equal(true)
			-- the box's top from the top of the screen: under the dots (about a third down), above half way
			local top = 0.5 + WashScreenRules.FRONT_DROP - share / 2
			expect(top > 0.3 and top < 0.45).to.equal(true)
			-- its bottom above the tool tray (the lowest fifth)
			expect(0.5 + WashScreenRules.FRONT_DROP + share / 2 < 0.8).to.equal(true)
			expect(
				math.abs(WashScreenRules.frontLookUp(d, 50) / screen - WashScreenRules.FRONT_DROP)
					< 1e-6
			).to.equal(true)
			-- the camera stays inside the room's walls, with a stud to spare past the tub
			expect(d + 1.5 + 1 < WashScreenRules.HALF).to.equal(true)
		end)
	end)
end
