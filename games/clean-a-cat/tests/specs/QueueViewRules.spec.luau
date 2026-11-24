--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local QueueViewRules = require(Shared:WaitForChild("QueueViewRules"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))

return function()
	describe("QueueViewRules.clean", function()
		it("keeps a line of real cats, front first", function()
			local line = QueueViewRules.clean({ "Muffin", "Marble" })
			expect(#line).to.equal(2)
			expect(line[1]).to.equal("Muffin")
			expect(line[2]).to.equal("Marble")
		end)

		it(
			"stops at anything that is not a real cat and never runs past the line's size",
			function()
				expect(#QueueViewRules.clean(nil)).to.equal(0)
				expect(#QueueViewRules.clean("Muffin")).to.equal(0)
				expect(#QueueViewRules.clean({ "Muffin", "Nobody", "Tux" })).to.equal(1)
				expect(#QueueViewRules.clean({ "Muffin", 7 })).to.equal(1)
				local long = {}
				for index = 1, SpaRules.QUEUE_SIZE + 3 do
					long[index] = "Muffin"
				end
				expect(#QueueViewRules.clean(long)).to.equal(SpaRules.QUEUE_SIZE)
			end
		)
	end)

	describe("QueueViewRules.cards", function()
		it("makes one card per customer with its rarity, needs, pay and place", function()
			local cards = QueueViewRules.cards({ "Muffin", "Marble" }, {}, {})
			expect(#cards).to.equal(2)
			expect(cards[1].place).to.equal(1)
			expect(cards[1].rarity).to.equal("Common")
			expect(cards[1].pays).to.equal(CatRules.PAY.Common.coins)
			expect(#cards[1].needs).to.equal(#CatRules.needs("Muffin"))
			expect(cards[2].place).to.equal(2)
			expect(cards[2].rarity).to.equal("Rare")
			expect(cards[2].pays).to.equal(CatRules.PAY.Rare.coins)
		end)

		it("locks a need whose station is not built and unlocks it once it is", function()
			local before = QueueViewRules.cards({ "Marble" }, {}, {})[1]
			expect(before.locked.wet).to.equal(true)
			expect(before.locked.mud).to.equal(nil)
			local after = QueueViewRules.cards({ "Marble" }, {}, { Dryer = true })[1]
			expect(after.locked.wet).to.equal(nil)
		end)

		it("marks a cat new until it has been washed", function()
			expect(QueueViewRules.cards({ "Tux" }, {}, {})[1].isNew).to.equal(true)
			local washed = { Tux = { washed = true, resident = false } }
			expect(QueueViewRules.cards({ "Tux" }, washed, {})[1].isNew).to.equal(false)
		end)

		it("makes VIPs from VIP_FROM up", function()
			local from = table.find(CatRules.RARITIES, QueueViewRules.VIP_FROM) :: number
			for index, rarity in CatRules.RARITIES do
				expect(QueueViewRules.isVip(rarity)).to.equal(index >= from)
			end
			expect(QueueViewRules.isVip("Mythic")).to.equal(false)
		end)
	end)

	describe("QueueViewRules.headline", function()
		it("asks for a pick when no VIP is waiting", function()
			local cards = QueueViewRules.cards({ "Muffin", "Tux" }, {}, {})
			expect(QueueViewRules.headline(cards, 1)).to.equal("Pick a cat to wash")
			local rare = QueueViewRules.cards({ "Marble" }, {}, {})
			expect(string.sub(QueueViewRules.headline(rare, 1), 1, 11)).to.equal("A Rare cat ")
		end)

		it("names the rarest VIP with the chance board's own percent", function()
			local cards = QueueViewRules.cards({ "Marble", "LilacCloud", "Muffin" }, {}, {})
			local percent = 0
			for _, line in CatRules.boardLines(1) do
				if line.rarity == "Epic" then
					percent = line.percent
				end
			end
			expect(QueueViewRules.headline(cards, 1)).to.equal(
				`An Epic cat is here · {CatRules.percentText(percent)} of customers`
			)
		end)
	end)

	describe("QueueViewRules.canPick", function()
		it("never offers the front, and only while the server would take the pick", function()
			expect(QueueViewRules.canPick(1, true, true)).to.equal(false)
			expect(QueueViewRules.canPick(2, true, true)).to.equal(true)
			expect(QueueViewRules.canPick(SpaRules.QUEUE_SIZE, true, true)).to.equal(true)
			expect(QueueViewRules.canPick(SpaRules.QUEUE_SIZE + 1, true, true)).to.equal(false)
			expect(QueueViewRules.canPick(2, false, true)).to.equal(false)
			expect(QueueViewRules.canPick(2, true, false)).to.equal(false)
		end)
	end)
end
