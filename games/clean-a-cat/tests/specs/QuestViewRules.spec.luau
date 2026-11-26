--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestViewRules = require(Shared:WaitForChild("QuestViewRules"))

return function()
	local raw = {
		{
			id = "wash5",
			text = "Wash 5 customer cats",
			goal = 5,
			progress = 5,
			coins = 50,
			weekly = false,
			done = true,
		},
		{
			id = "bow3",
			text = "Put a bow on 3 cats",
			goal = 3,
			progress = 1,
			coins = 40,
			weekly = false,
			done = false,
		},
		{
			id = "wStars20",
			text = "Get 3 stars on 20 cats",
			goal = 20,
			progress = 99,
			coins = 300,
			weekly = true,
			done = true,
		},
		{
			id = "wSpecial2",
			text = "Wash 2 special visitors' cats",
			goal = 2,
			progress = 1,
			coins = 300,
			weekly = true,
			done = false,
		},
		{ id = "bad", text = "No goal", goal = 0, progress = 0, coins = 1 },
		"junk",
	}

	describe("QuestViewRules.clean", function()
		it("keeps whole entries, drops broken ones and holds progress to the goal", function()
			local entries = QuestViewRules.clean(raw)
			expect(#entries).to.equal(4)
			expect(entries[3].progress).to.equal(20)
			expect(#QuestViewRules.clean(nil)).to.equal(0)
		end)
	end)

	describe("QuestViewRules view", function()
		it("splits today from this week in order", function()
			local daily, weekly = QuestViewRules.split(QuestViewRules.clean(raw))
			expect(#daily).to.equal(2)
			expect(#weekly).to.equal(2)
			expect(daily[1].id).to.equal("wash5")
			expect(weekly[2].id).to.equal("wSpecial2")
			expect(QuestViewRules.doneCount(weekly)).to.equal(1)
			expect(QuestViewRules.weekNote(weekly)).to.equal("Finish all 2 for a crate")
		end)

		it("draws each quest's icon, count and bar", function()
			local entries = QuestViewRules.clean(raw)
			expect(QuestViewRules.icon("wash5")).to.equal("Paw")
			expect(QuestViewRules.icon("bow3")).to.equal("Bow")
			expect(QuestViewRules.icon("wSpecial2")).to.equal("Sparkle")
			expect(QuestViewRules.icon("unknown")).to.equal("Star")
			expect(QuestViewRules.progressText(entries[2])).to.equal("1 / 3")
			expect(math.abs(QuestViewRules.fill(entries[2]) - 1 / 3) < 0.001).to.equal(true)
			expect(QuestViewRules.fill(entries[1])).to.equal(1)
		end)

		it("never hurries the player", function()
			for _, line in
				{
					QuestViewRules.TODAY_NOTE,
					QuestViewRules.crateLine(true),
					QuestViewRules.crateLine(false),
				}
			do
				local low = string.lower(line)
				expect(string.find(low, "hurry", 1, true)).to.equal(nil)
				expect(string.find(low, "lose", 1, true)).to.equal(nil)
			end
		end)
	end)
end
