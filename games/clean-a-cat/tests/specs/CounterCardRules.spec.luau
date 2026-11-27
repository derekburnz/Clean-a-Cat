--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CounterCardRules = require(Shared:WaitForChild("CounterCardRules"))
local HeartRules = require(Shared:WaitForChild("HeartRules"))

return function()
	describe("CounterCardRules", function()
		it("is on only with counterLine and heartBar on too", function()
			local flags: { [string]: boolean } =
				{ counterCards = true, counterLine = true, heartBar = true }
			local function isOn(name: string): boolean
				return flags[name] == true
			end
			expect(CounterCardRules.on(isOn)).to.equal(true)
			flags.heartBar = false
			expect(CounterCardRules.on(isOn)).to.equal(false)
			flags.heartBar = true
			flags.counterCards = false
			expect(CounterCardRules.on(isOn)).to.equal(false)
		end)

		it("reads the fill safely", function()
			expect(CounterCardRules.fill(0.5)).to.equal(0.5)
			expect(CounterCardRules.fill(1.4)).to.equal(1)
			expect(CounterCardRules.fill(-2)).to.equal(0)
			expect(CounterCardRules.fill("full")).to.equal(nil)
			expect(CounterCardRules.fill(0 / 0)).to.equal(nil)
		end)

		it("turns the bar gold, then coral as the cat turns grumpy", function()
			expect(CounterCardRules.barColor(1)).to.equal(CounterCardRules.FULL)
			expect(CounterCardRules.barColor(0.5)).to.equal(CounterCardRules.MID)
			expect(CounterCardRules.barColor(HeartRules.GRUMPY_AT)).to.equal(CounterCardRules.LOW)
			expect(CounterCardRules.barColor(0)).to.equal(CounterCardRules.LOW)
		end)

		it("names each place's mat and washes the owner's shirt towards cream", function()
			expect(CounterCardRules.matName(3)).to.equal("CleanACat_Area_SpaPlotBig_CounterMat3")
			expect(CounterCardRules.matName(0)).to.equal(nil)
			expect(CounterCardRules.matName(1.5)).to.equal(nil)
			expect(CounterCardRules.matName("1")).to.equal(nil)
			local shirt = Color3.fromHex("FFB3C7")
			local washed = CounterCardRules.matColor(shirt)
			expect(washed.R >= shirt.R and washed.G >= shirt.G and washed.B >= shirt.B).to.equal(
				true
			)
		end)

		it(
			"puts every second place's card a row up, so neighbours never cover each other",
			function()
				expect(CounterCardRules.up(1)).to.equal(CounterCardRules.UP)
				expect(CounterCardRules.up(2)).to.equal(
					CounterCardRules.UP + CounterCardRules.STAGGER
				)
				expect(CounterCardRules.up(3)).to.equal(CounterCardRules.UP)
				expect(CounterCardRules.up(nil)).to.equal(CounterCardRules.UP)
			end
		)
		it("keeps every slim bar in one row, narrower than the gap between places", function()
			expect(CounterCardRules.up(1, true)).to.equal(CounterCardRules.SLIM_UP)
			expect(CounterCardRules.up(2, true)).to.equal(CounterCardRules.SLIM_UP)
			expect(CounterCardRules.SLIM_SIZE.X < 3.2).to.equal(true)
			expect(CounterCardRules.SLIM_PX.X >= 30 and CounterCardRules.SLIM_PX.Y >= 8).to.equal(
				true
			)
			expect(CounterCardRules.slimLift(1)).to.equal(0)
			expect(CounterCardRules.slimLift(2) > 1).to.equal(true)
			expect(CounterCardRules.slimLift(nil)).to.equal(0)
		end)
	end)
end
