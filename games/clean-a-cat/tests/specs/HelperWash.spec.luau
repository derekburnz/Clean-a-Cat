--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local HelperWash = require(Client:WaitForChild("Effects"):WaitForChild("HelperWash")) :: any

return function()
	describe("HelperWash.phase", function()
		it("runs soap, scrub, rinse, dry over the wash's progress", function()
			expect(HelperWash.phase(0)).to.equal("soap")
			expect(HelperWash.phase(0.11)).to.equal("soap")
			expect(HelperWash.phase(0.12)).to.equal("scrub")
			expect(HelperWash.phase(0.59)).to.equal("scrub")
			expect(HelperWash.phase(0.6)).to.equal("rinse")
			expect(HelperWash.phase(0.84)).to.equal("rinse")
			expect(HelperWash.phase(0.85)).to.equal("dry")
			expect(HelperWash.phase(1)).to.equal("dry")
		end)
		it("has a tool for every step", function()
			for _, phase in { "soap", "scrub", "rinse", "dry" } do
				expect(type(HelperWash.TOOLS[phase])).to.equal("string")
			end
		end)
	end)

	describe("HelperWash.target", function()
		it("keeps every arm forward over the cat in every step", function()
			for _, phase in { "soap", "scrub", "rinse", "dry" } do
				for t = 0, 6, 0.05 do
					local p = HelperWash.target(phase, t, 0.3, false)
					expect(p.armR > math.rad(40) and p.armR < math.rad(95)).to.equal(true)
					expect(p.armL > math.rad(40) and p.armL < math.rad(95)).to.equal(true)
					expect(math.abs(p.sideR) <= math.rad(30)).to.equal(true)
					expect(p.headPitch > 0).to.equal(true)
				end
			end
		end)
		it("scrubs in bursts of strokes that move between patches, not one loop", function()
			local strokes, sides = 0, {}
			local was = false
			for t = 0, 12, 1 / 60 do
				local p = HelperWash.target("scrub", t, 0, false)
				if p.beat and not was then
					strokes += 1
				end
				was = p.beat
				sides[math.floor(math.deg(p.sideR) + 0.5)] = true
			end
			local burst = HelperWash.STROKES / HelperWash.STROKE_HZ + HelperWash.MOVE
			local expected = math.floor(12 / burst) * HelperWash.STROKES
			expect(strokes >= expected - 1 and strokes <= expected + HelperWash.STROKES).to.equal(
				true
			)
			local count = 0
			for _ in sides do
				count += 1
			end
			expect(count > 10).to.equal(true) -- the brush works across the coat
		end)
		it("sweeps the shower side to side while rinsing", function()
			local low, high = math.huge, -math.huge
			for t = 0, 3, 0.05 do
				local p = HelperWash.target("rinse", t, 0, false)
				low = math.min(low, p.sideR)
				high = math.max(high, p.sideR)
			end
			expect(high - low > math.rad(20)).to.equal(true)
		end)
		it("holds still with Reduced Motion: no beats and no change over time", function()
			for _, phase in { "soap", "scrub", "rinse", "dry" } do
				local a = HelperWash.target(phase, 0.4, 0.2, true)
				local b = HelperWash.target(phase, 0.9, 0.2, true)
				expect(a.beat).to.equal(false)
				expect(math.abs(a.armR - b.armR) < 1e-9).to.equal(true)
				expect(math.abs(a.armL - b.armL) < 1e-9).to.equal(true)
			end
		end)
	end)
end
