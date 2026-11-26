--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LaterStepRules = require(Shared:WaitForChild("LaterStepRules"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))
local WashPace = require(Shared:WaitForChild("WashPace"))

local function on(flag: string): boolean
	return flag == WashPace.FLAG
end
local function all(_flag: string): boolean
	return true
end
local function off(_flag: string): boolean
	return false
end
local function ownsAll(_id: string): boolean
	return true
end
local function ownsNone(_id: string): boolean
	return false
end

return function()
	describe("WashPace", function()
		it("keeps the old amounts with the switch off", function()
			local pace = WashPace.pace(off)
			expect(pace.brushStrokes).to.equal(3)
			expect(pace.strokeGap).to.equal(0.2)
			expect(pace.swirlTravel).to.equal(12)
			expect(pace.clawHold).to.equal(0.5)
			expect(WashPace.pace(nil)).to.equal(WashPace.OFF)
		end)

		it("asks for about 4 to 5 seconds a step with it on", function()
			local pace = WashPace.pace(on)
			-- the gaps alone are a floor no fast finger can beat
			expect((pace.brushStrokes - 1) * pace.strokeGap >= 3).to.equal(true)
			expect(pace.swirlTravel > WashPace.OFF.swirlTravel).to.equal(true)
			expect(pace.clawHold * 4 >= 3).to.equal(true)
			expect(WashPace.MAX_STROKES).to.equal(8)
		end)

		it("keeps the Pro Brush's share of the strokes", function()
			expect(ToolRules.brushStrokes(3, ownsAll, all)).to.equal(2)
			expect(ToolRules.brushStrokes(8, ownsAll, all)).to.equal(6)
			expect(ToolRules.brushStrokes(8, ownsNone, all)).to.equal(8)
			expect(WashPace.toolStrokes(2, WashPace.ON)).to.equal(6)
		end)

		it("lathers and clips at the paced amounts", function()
			expect(LaterStepRules.sudsGone(12, 14)).to.equal(14)
			expect(LaterStepRules.sudsGone(12, 14, 26)).to.equal(6)
			expect(LaterStepRules.sudsGone(26, 14, 26)).to.equal(14)
			expect(LaterStepRules.held(0, 0.6)).to.equal(true)
			expect(LaterStepRules.held(0, 0.6, 0.8)).to.equal(false)
		end)
	end)
end
