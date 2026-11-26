--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

type Save = { coins: number, workers: { [string]: any } }

local function newSave(coins: number): Save
	return { coins = coins, workers = {} }
end

return function()
	describe("WorkerRules", function()
		it("has tuning section 7's prices, times and levels", function()
			expect(WorkerRules.WORKERS.Jo.price).to.equal(150)
			expect(WorkerRules.WORKERS.Sam.price).to.equal(1200)
			expect(WorkerRules.WORKERS.Lou.pass).to.equal(true)
			expect(WorkerRules.washSeconds(1, 1)).to.equal(50)
			expect(WorkerRules.washSeconds(4, 1)).to.equal(150)
			expect(WorkerRules.washSeconds(2, 5)).to.equal(75 * 0.8)
			expect(WorkerRules.LEVEL_COST[5]).to.equal(3000)
		end)

		it("pays a small share of base times dirt, more each level", function()
			local common = CatRules.ROSTER.Common[1]
			expect(WorkerRules.pay(common, 1, 1)).to.equal(3) -- 10 x 0.25 = 2.5, rounded
			expect(WorkerRules.pay(common, 4, 1)).to.equal(5) -- 10 x 2 x 0.25
			expect(WorkerRules.pay(common, 2, 5)).to.equal(5) -- 12.5 x 0.37 = 4.6
			expect(WorkerRules.pay(common, 1, 1) < CatRules.pay(common).coins).to.equal(true)
		end)

		it("hires a coin worker once and never sells the pass worker", function()
			local save = newSave(1000)
			expect(WorkerRules.hire(save, "Jo", 5)).to.equal(150)
			expect(save.coins).to.equal(850)
			expect(save.workers.Jo.mode).to.equal("first")
			expect(save.workers.Jo.level).to.equal(1)
			expect(WorkerRules.hire(save, "Jo", 6)).to.equal(0)
			expect(WorkerRules.hire(save, "Lou", 6)).to.equal(0)
			expect(WorkerRules.hire(save, "Sam", 6)).to.equal(0) -- 850 is short of 1200
			expect(save.coins).to.equal(850)
		end)

		it("levels a worker up to the top and stops there", function()
			local save = newSave(10_000)
			WorkerRules.hire(save, "Jo", 1)
			for level = 2, WorkerRules.MAX_LEVEL do
				local spent = WorkerRules.levelUp(save, "Jo")
				expect(spent).to.equal(WorkerRules.LEVEL_COST[level])
			end
			expect(save.workers.Jo.level).to.equal(WorkerRules.MAX_LEVEL)
			expect((WorkerRules.levelUp(save, "Jo"))).to.equal(0)
			expect((WorkerRules.levelUp(save, "Sam"))).to.equal(0)
		end)

		it("picks by mode, ties going to the front", function()
			local line: { WorkerRules.Entry } = {
				{ kind = CatRules.ROSTER.Common[1], dirt = 1, left = 0.9 },
				{ kind = CatRules.ROSTER.Rare[1], dirt = 2, left = 0.2 },
				{ kind = CatRules.ROSTER.Common[2], dirt = 4, left = 0.5 },
			}
			expect(WorkerRules.pick("first", line)).to.equal(1)
			expect(WorkerRules.pick(nil, line)).to.equal(1)
			expect(WorkerRules.pick("leaving", line)).to.equal(2)
			expect(WorkerRules.pick("rarest", line)).to.equal(2)
			expect(WorkerRules.pick("dirtiest", line)).to.equal(3)
			expect(WorkerRules.pick("first", {})).to.equal(nil)
			local tied: { WorkerRules.Entry } = {
				{ kind = CatRules.ROSTER.Common[1], dirt = 3, left = 1 },
				{ kind = CatRules.ROSTER.Common[2], dirt = 3, left = 1 },
			}
			expect(WorkerRules.pick("dirtiest", tied)).to.equal(1)
			expect(WorkerRules.pick("leaving", tied)).to.equal(1)
		end)

		it("steps through the modes and refuses a made up one", function()
			expect(WorkerRules.nextMode("first")).to.equal("leaving")
			expect(WorkerRules.nextMode("dirtiest")).to.equal("first")
			expect(WorkerRules.nextMode("nope")).to.equal("leaving")
			expect(WorkerRules.cleanMode("fastest")).to.equal(nil)
			expect(WorkerRules.cleanLevel(9)).to.equal(WorkerRules.MAX_LEVEL)
			expect(WorkerRules.cleanLevel(0 / 0)).to.equal(1)
		end)

		it(
			"keeps the guard rail: three top workers earn less than the player's own washing",
			function()
				-- tuning section 7: a player washing Common level 2 cats at 2 stars makes about 0.49 coins a second
				local playerRate = (10 * 1.25 * 1.1 + 4) / 36
				local common = CatRules.ROSTER.Common[1]
				local workerRate = 3
					* WorkerRules.pay(common, 2, WorkerRules.MAX_LEVEL)
					/ WorkerRules.washSeconds(2, WorkerRules.MAX_LEVEL)
				expect(workerRate < playerRate).to.equal(true)
			end
		)
	end)
end
