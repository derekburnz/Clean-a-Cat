--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local BrushShine = require(Client:WaitForChild("Effects"):WaitForChild("BrushShine")) :: any

	describe("shine", function()
		it("crosses the whole coat from top to bottom", function()
			-- at the start it is above the coat, at the end below it
			expect(BrushShine.band(1, 0)).to.equal(0)
			expect(BrushShine.band(0, 1)).to.equal(0)
			-- the top lights before the bottom
			expect(BrushShine.band(0.9, 0.25) > BrushShine.band(0.1, 0.25)).to.equal(true)
			expect(BrushShine.band(0.1, 0.75) > BrushShine.band(0.9, 0.75)).to.equal(true)
			-- every height is lit at some point of the sweep
			for h = 0, 1, 0.1 do
				local best = 0
				for u = 0, 1, 0.02 do
					best = math.max(best, BrushShine.band(h, u))
				end
				expect(best > 0.8).to.equal(true)
			end
		end)
		it("lifts a part toward the shine colour, and leaves it as it was without shine", function()
			local dry = Color3.fromRGB(200, 150, 100)
			local plain = BrushShine.tint(dry, 1, 0)
			expect(plain).to.equal(Color3.new(dry.R, dry.G, dry.B))
			local lit = BrushShine.tint(dry, 1, 1)
			expect(lit.B > dry.B).to.equal(true)
		end)
	end)

	describe("colour change", function()
		it("goes gradually from the wet look to dry", function()
			local dry = Color3.fromRGB(200, 150, 100)
			local darken = 0.3
			local last = -1
			for strokes = 0, 4 do
				local wet = 1 - strokes / 4
				local c = BrushShine.tint(dry, 1 - darken * wet, 0)
				expect(c.R > last).to.equal(true)
				last = c.R
			end
			expect(math.abs(last - dry.R) < 1e-6).to.equal(true)
		end)
	end)
end
