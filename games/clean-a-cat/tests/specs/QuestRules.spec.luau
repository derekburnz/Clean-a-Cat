--!strict
return function()
	local QuestRules = require(game:GetService("ReplicatedStorage").Shared.QuestRules)

	local function allOn(_flag: string): boolean
		return true
	end

	local function book(): QuestRules.Book
		return { day = 0, daily = {}, progress = {}, claimed = {}, week = 0, weeklyCrate = false }
	end

	local function seq(values: { number }): () -> number
		local i = 0
		return function()
			i += 1
			return values[(i - 1) % #values + 1]
		end
	end

	describe("QuestRules.refresh", function()
		it("draws two different daily quests a day and clears them on the next day", function()
			local b = book()
			expect(QuestRules.refresh(b, 10, 2, allOn, seq({ 0, 0 }))).to.equal(true)
			expect(#b.daily).to.equal(2)
			expect(b.daily[1] ~= b.daily[2]).to.equal(true)
			b.progress[b.daily[1]] = 3
			expect(QuestRules.refresh(b, 10, 2, allOn, seq({ 0.5 }))).to.equal(false) -- same day: kept
			expect(b.progress[b.daily[1]]).to.equal(3)
			local before = b.daily[1]
			QuestRules.refresh(b, 11, 2, allOn, seq({ 0.99, 0.99 }))
			expect(b.progress[before]).to.equal(nil)
		end)

		it("never draws a quest whose switch is off", function()
			local b = book()
			QuestRules.refresh(b, 1, 1, function(flag: string)
				return flag ~= "heartBar" and flag ~= "dirtLevels"
			end, seq({ 0, 0 }))
			table.sort(b.daily)
			expect(table.concat(b.daily, ",")).to.equal("bow3,wash5")
		end)

		it("starts the week on Monday 00:00 UTC", function()
			local monday = 1764547200 -- 2025-12-01 00:00 UTC, a Monday
			expect(QuestRules.week(monday)).to.equal(QuestRules.week(monday + 6 * 86400 + 86399))
			expect(QuestRules.week(monday - 1)).to.equal(QuestRules.week(monday) - 1)
		end)
	end)

	describe("QuestRules.count", function()
		it(
			"pays a daily quest once when done and the weekly crate once all weekly ones are",
			function()
				local b = book()
				b.daily = { "wash5", "dirty2" }
				local done = {}
				for _ = 1, 5 do
					local finished = QuestRules.count(b, { wash = 1 }, allOn)
					for _, q in finished do
						table.insert(done, q.id)
					end
				end
				expect(table.concat(done, ",")).to.equal("wash5")
				expect(#(QuestRules.count(b, { wash = 1 }, allOn))).to.equal(0) -- paid already
				local crate = false
				for _ = 1, 20 do
					local _, got = QuestRules.count(
						b,
						{ threeStars = 1, special = 1, dirt4 = 1, dirty = 1 },
						allOn
					)
					crate = crate or got
				end
				expect(crate).to.equal(true)
				expect(b.weeklyCrate).to.equal(true)
				local _, again = QuestRules.count(b, { threeStars = 1 }, allOn)
				expect(again).to.equal(false)
			end
		)

		it("has the tuning's pool and weekly list", function()
			expect(#QuestRules.DAILY).to.equal(5)
			expect(#QuestRules.WEEKLY).to.equal(3)
			expect((QuestRules.get("dirty2") :: QuestRules.Quest).coins).to.equal(60)
			expect((QuestRules.get("wStars20") :: QuestRules.Quest).goal).to.equal(20)
		end)
	end)
end
