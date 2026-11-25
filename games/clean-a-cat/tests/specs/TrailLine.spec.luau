--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local TrailLine = require(Client:WaitForChild("Effects"):WaitForChild("TrailLine")) :: any
local _ = ReplicatedStorage

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-4)
end

return function()
	local L = TrailLine.LOOK
	describe("TrailLine.layout", function()
		it("cuts the band where the arrowhead starts, with the tip on the spot", function()
			local layout = TrailLine.layout({ Vector3.new(0, 1, 0), Vector3.new(0, 1, 20) })
			expect(#layout.legs).to.equal(1)
			expect(near(layout.length, 20 - L.arrowLength)).to.equal(true)
			expect(near(layout.base.Z, 20 - L.arrowLength)).to.equal(true)
			expect(near(layout.tip.Z, 20)).to.equal(true)
		end)
		it("finds the arrowhead's base across a bend", function()
			local layout = TrailLine.layout({
				Vector3.new(0, 0, 0),
				Vector3.new(0, 0, 10),
				Vector3.new(2, 0, 10),
			})
			-- the last leg is 2 long, so the base is 3 back up the first leg
			expect(#layout.legs).to.equal(1)
			expect(near(layout.base.Z, 10 - (L.arrowLength - 2))).to.equal(true)
		end)
		it("draws only the arrowhead when the spot is closer than its length", function()
			local layout = TrailLine.layout({ Vector3.new(0, 0, 0), Vector3.new(0, 0, 3) })
			expect(#layout.legs).to.equal(0)
			expect(near(layout.tip.Z, 3)).to.equal(true)
		end)
		it("draws nothing without two points", function()
			expect(TrailLine.layout({ Vector3.zero }).tip).to.equal(nil)
		end)
	end)
	describe("TrailLine.dashes", function()
		it("spaces the dashes and keeps each whole on the band", function()
			local at = TrailLine.dashes(20, 0)
			expect(#at > 0).to.equal(true)
			for i, d in at do
				expect(d >= 0 and d + L.dashLength <= 20).to.equal(true)
				if i > 1 then
					expect(near(d - at[i - 1], L.dashGap)).to.equal(true)
				end
			end
		end)
		it("moves toward the spot as time passes and passes a point about once a second", function()
			local a = TrailLine.dashes(30, 0)[1]
			local b = TrailLine.dashes(30, 1)[1]
			expect(b > a).to.equal(true)
			local perSecond = L.dashSpeed / L.dashGap
			expect(perSecond >= 0.8 and perSecond <= 1.25).to.equal(true)
		end)
	end)
	describe("the look", function()
		it("matches the spec: a see-through band and a bigger arrowhead", function()
			expect(L.width).to.equal(1.6)
			expect(L.arrowWidth).to.equal(3.8)
			expect(L.arrowLength).to.equal(5)
			expect(L.fillSeen >= 0.5).to.equal(true)
			expect(L.glowSeen > L.fillSeen).to.equal(true)
		end)
	end)
end
