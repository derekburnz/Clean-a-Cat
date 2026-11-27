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
		it("works spots on the helper's half of the coat in every step", function()
			for _, phase in { "soap", "scrub", "rinse", "dry" } do
				for t = 0, 8, 0.05 do
					local p = HelperWash.target(phase, t, 0.3, false)
					expect(p.u >= 0 and p.u <= 1).to.equal(true)
					expect(p.lu >= 0 and p.lu <= 1).to.equal(true)
					expect(math.abs(p.v) <= 1 and math.abs(p.lv) <= 1).to.equal(true)
					expect(p.hover >= -0.1 and p.hover <= 1.5).to.equal(true)
				end
			end
		end)
		it("scrubs with the bristles in the fur, in bursts that lift to the next patch", function()
			local strokes, was = 0, false
			local spots, high = {}, -math.huge
			for t = 0, 12, 1 / 60 do
				local p = HelperWash.target("scrub", t, 0, false)
				if p.beat and not was then
					strokes += 1
					expect(p.hover <= 0).to.equal(true) -- every stroke lands touching the coat
				end
				was = p.beat
				high = math.max(high, p.hover)
				spots[math.floor(p.u * 20 + 0.5)] = true
			end
			local burst = HelperWash.STROKES / HelperWash.STROKE_HZ + HelperWash.MOVE
			local expected = math.floor(12 / burst) * HelperWash.STROKES * 2
			expect(strokes >= expected - 2 and strokes <= expected + HelperWash.STROKES * 2).to.equal(
				true
			)
			expect(high >= HelperWash.PRESS + HelperWash.LIFT * 0.9).to.equal(true)
			local count = 0
			for _ in spots do
				count += 1
			end
			expect(count >= 4).to.equal(true) -- it works across the coat, not one spot
		end)
		it("sweeps the shower along the cat while rinsing", function()
			local low, high = math.huge, -math.huge
			for t = 0, 3, 0.05 do
				local p = HelperWash.target("rinse", t, 0, false)
				low = math.min(low, p.v)
				high = math.max(high, p.v)
			end
			expect(high - low > 0.8).to.equal(true)
		end)
		it("pats with the hands taking turns", function()
			for t = 0, 3, 0.02 do
				local p = HelperWash.target("dry", t, 0.1, false)
				expect(p.hover > 0.05 and p.lhover > 0.05).to.equal(false)
			end
		end)
		it("holds still with Reduced Motion: no beats and no change over time", function()
			for _, phase in { "soap", "scrub", "rinse", "dry" } do
				local a = HelperWash.target(phase, 0.4, 0.2, true)
				local b = HelperWash.target(phase, 0.9, 0.2, true)
				expect(a.beat).to.equal(false)
				expect(
					math.abs(a.u - b.u) + math.abs(a.v - b.v) + math.abs(a.hover - b.hover) < 1e-9
				).to.equal(true)
			end
		end)
	end)

	describe("HelperWash.solve", function()
		-- a two-link arm in a plane: shoulder at the origin, links of 1 and 0.8
		local function arm(q: { number }): { number }
			local a, b = q[1], q[1] + q[2]
			return { math.cos(a) + 0.8 * math.cos(b), math.sin(a) + 0.8 * math.sin(b) }
		end
		it("reaches a point the arm can reach", function()
			local q = { 0.2, 0.2 }
			for _ = 1, 10 do
				HelperWash.solve(q, { -math.pi, 0 }, { math.pi, math.pi }, arm, { 0.6, 1.1 }, 2)
			end
			local p = arm(q)
			expect(math.abs(p[1] - 0.6) + math.abs(p[2] - 1.1) < 1e-3).to.equal(true)
		end)
		it("keeps every angle inside its bounds and gets as close as it can", function()
			local q = { 0, 0 }
			HelperWash.solve(q, { 0, 0 }, { 0.5, 0.5 }, arm, { -1.5, 0 }, 8)
			expect(q[1] >= 0 and q[1] <= 0.5 and q[2] >= 0 and q[2] <= 0.5).to.equal(true)
		end)
	end)
end
