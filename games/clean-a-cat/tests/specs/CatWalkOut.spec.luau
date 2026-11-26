--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CatWalkOut = require(Client:WaitForChild("Effects"):WaitForChild("CatWalkOut")) :: any

	describe("CatWalkOut.at", function()
		it("hops, then walks, and has faded out by the end of the walk", function()
			local w = 2
			local hop, walk, fade = CatWalkOut.at(0, w)
			expect(hop + walk + fade).to.equal(0)
			hop, walk, fade = CatWalkOut.at(CatWalkOut.HOP_SECONDS, w)
			expect(hop).to.equal(1)
			expect(walk).to.equal(0)
			expect(fade).to.equal(0)
			hop, walk, fade = CatWalkOut.at(CatWalkOut.HOP_SECONDS + w, w)
			expect(walk).to.equal(1)
			expect(fade).to.equal(1)
			local _, _, mid = CatWalkOut.at(CatWalkOut.HOP_SECONDS + w - CatWalkOut.FADE / 2, w)
			expect(mid > 0 and mid < 1).to.equal(true)
		end)
		it("only fades in the last part of the walk", function()
			local _, _, early = CatWalkOut.at(CatWalkOut.HOP_SECONDS + 0.5, 3)
			expect(early).to.equal(0)
		end)
	end)

	describe("CatWalkOut.walkSeconds", function()
		it("trots at its speed within the limits", function()
			expect(CatWalkOut.walkSeconds(0)).to.equal(CatWalkOut.MIN_WALK)
			expect(CatWalkOut.walkSeconds(1000)).to.equal(CatWalkOut.MAX_WALK)
			local d = CatWalkOut.SPEED * 2
			expect(math.abs(CatWalkOut.walkSeconds(d) - 2) < 1e-9).to.equal(true)
		end)
	end)

	describe("CatWalkOut.legAngle", function()
		it("swings the diagonal pairs opposite, within LEG_SWING", function()
			local CWO = CatWalkOut
			for i = 0, 30 do
				local t = i * 0.037
				local a = CWO.legAngle(t, CWO.LEG_PHASE.LegF1)
				local b = CWO.legAngle(t, CWO.LEG_PHASE.LegF2)
				expect(math.abs(a + b) < 1e-6).to.equal(true)
				expect(math.abs(a) <= CWO.LEG_SWING + 1e-6).to.equal(true)
			end
			expect(CWO.LEG_PHASE.LegF1).to.equal(CWO.LEG_PHASE.LegB2)
		end)
	end)
end
