--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HelperViewRules = require(Shared:WaitForChild("HelperViewRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local function reader(values: { [string]: unknown }): (name: string) -> unknown
	return function(name: string): unknown
		return values[name]
	end
end

return function()
	describe("HelperViewRules.rows", function()
		it("has one row per helper in order, none hired on a new save", function()
			local rows = HelperViewRules.rows(reader({}), {})
			expect(#rows).to.equal(#WorkerRules.IDS)
			for index, row in rows do
				expect(row.id).to.equal(WorkerRules.IDS[index])
				expect(row.hired).to.equal(false)
				expect(row.level).to.equal(nil)
				expect(row.nextCost).to.equal(nil)
			end
			expect(rows[1].price).to.equal(WorkerRules.WORKERS.Jo.price)
			expect(HelperViewRules.say(rows[1])).to.equal(
				`Hire at their pad · {WorkerRules.WORKERS.Jo.price} coins`
			)
			expect(rows[3].pass).to.equal(true)
			expect(rows[3].price).to.equal(nil)
			expect(HelperViewRules.say(rows[3])).to.equal("Comes with the Lou pass")
			expect(HelperViewRules.anyHired(reader({}))).to.equal(false)
		end)

		it("shows a hired helper's level, next cost and mode", function()
			local rows = HelperViewRules.rows(
				reader({ WorkerLevel_Jo = 2, WorkerMode_Jo = "rarest", WorkerLevel_Sam = 1 }),
				{ Jo = "Bubbles" }
			)
			local jo = rows[1]
			expect(jo.hired).to.equal(true)
			expect(jo.name).to.equal("Bubbles")
			expect(jo.level).to.equal(2)
			expect(jo.nextCost).to.equal(WorkerRules.LEVEL_COST[3])
			expect(jo.price).to.equal(nil)
			expect(HelperViewRules.modeText(jo)).to.equal("Takes: Rarest first")
			expect(HelperViewRules.levelText(jo)).to.equal(
				`Level up · {WorkerRules.LEVEL_COST[3]}`
			)
			expect(rows[2].mode).to.equal(WorkerRules.DEFAULT_MODE)
			expect(rows[2].name).to.equal("Sam")
			expect(HelperViewRules.anyHired(reader({ WorkerLevel_Lou = 1 }))).to.equal(true)
		end)

		it("has no Level up at the top level and cleans bad values", function()
			local rows = HelperViewRules.rows(
				reader({
					WorkerLevel_Jo = WorkerRules.MAX_LEVEL,
					WorkerLevel_Sam = "9",
					WorkerMode_Sam = "fastest",
				}),
				{ Sam = "" }
			)
			expect(rows[1].nextCost).to.equal(nil)
			expect(HelperViewRules.levelText(rows[1])).to.equal(nil)
			expect(HelperViewRules.say(rows[1])).to.equal(`Level {WorkerRules.MAX_LEVEL}, the top`)
			expect(rows[2].level).to.equal(1)
			expect(rows[2].mode).to.equal(WorkerRules.DEFAULT_MODE)
			expect(rows[2].name).to.equal("Sam")
		end)

		it("finds the pet beside a helper, first slot first", function()
			local pets: { HelperViewRules.Pet } = {
				{ id = 1, kind = "Ooze", star = 1, slot = "Jo2" },
				{ id = 2, kind = "Angler", star = 2, slot = "Jo1" },
				{ id = 3, kind = "Dragon", star = 1, slot = "Sam2" },
				{ id = 4, kind = "Blaze", star = 1 },
			}
			local jo = HelperViewRules.petOf("Jo", pets)
			expect(jo and jo.kind).to.equal("Angler")
			local sam = HelperViewRules.petOf("Sam", pets)
			expect(sam and sam.kind).to.equal("Dragon")
			expect(HelperViewRules.petOf("Lou", pets)).to.equal(nil)
		end)
	end)
end
