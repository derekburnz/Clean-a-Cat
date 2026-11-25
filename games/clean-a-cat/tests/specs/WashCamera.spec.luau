--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local WashCamera = require(Client:WaitForChild("Effects"):WaitForChild("WashCamera")) :: any
	local S = WashCamera.SCENE

	describe("wash scene", function()
		it(
			"fills about half the screen's height with a cat in the tub (Derek: a separate view)",
			function()
				local fill = WashCamera.sceneFill(S.height, WashCamera.sceneDistance())
				expect(math.abs(fill - S.fill) < 1e-6).to.equal(true)
				expect(fill >= 0.5 and fill <= 0.6).to.equal(true)
			end
		)

		it("is closer than the old close-up and narrower than the player's view", function()
			local old = WashCamera.SHOT
			local oldDistance = math.sqrt(old.ahead ^ 2 + (old.up - old.lookUp) ^ 2)
			expect(WashCamera.sceneDistance() < oldDistance).to.equal(true)
			expect(S.fov < 70 and S.fov >= 40).to.equal(true)
		end)

		it("looks down at the tub from outside its rim, high enough to see into it", function()
			-- the spec runner has no CFrame, so this checks the shot's numbers; sceneShot builds it from them
			local d = WashCamera.sceneDistance()
			local pitch = math.rad(S.pitch)
			expect(d * math.cos(pitch) > 2).to.equal(true) -- the tub is about 3.3 wide
			expect(S.pitch >= 20 and S.pitch <= 45).to.equal(true)
			expect(S.lookUp + d * math.sin(pitch) < 8).to.equal(true) -- well under the spa's ceiling
		end)

		it(
			"framed on the cat's box, a 3 stud cat in the tub gets the tub shot's distance",
			function()
				expect(math.abs(WashCamera.sceneDistanceFor(3) - WashCamera.sceneDistance()) < 1e-6).to.equal(
					true
				)
				-- a taller box backs the camera off in step, so he fills the same share at every station
				expect(WashCamera.sceneDistanceFor(3.6) > WashCamera.sceneDistanceFor(3)).to.equal(
					true
				)
				local d = WashCamera.sceneDistanceFor(3.6)
				expect(math.abs(WashCamera.sceneFill(3.6 * S.boxToScreen, d) - S.fill) < 1e-6).to.equal(
					true
				)
			end
		)

		it("blurs only past the cat, gently", function()
			expect(S.focusRadius >= S.height / 2).to.equal(true)
			expect(S.blur > 0 and S.blur <= 0.6).to.equal(true)
			expect(S.blurLow > 0 and S.blurLow <= S.blur).to.equal(true)
		end)
	end)
end
