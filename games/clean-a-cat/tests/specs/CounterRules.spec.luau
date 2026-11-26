--!strict
return function()
	local CounterRules = require(game:GetService("ReplicatedStorage").Shared.CounterRules)
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)

	describe("CounterRules", function()
		it("ships behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, CounterRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[CounterRules.FLAG]).to.equal(true)
		end)

		it("maps a shown place to the server's line, with or without a cat at the door", function()
			-- the door cat is shown first: place 1 is it, place 2 the line's first
			expect(CounterRules.entryFor(1, true, 3)).to.equal(0)
			expect(CounterRules.entryFor(2, true, 3)).to.equal(1)
			expect(CounterRules.entryFor(4, true, 3)).to.equal(3)
			expect(CounterRules.entryFor(5, true, 3)).to.equal(nil)
			expect(CounterRules.entryFor(1, false, 3)).to.equal(1)
			expect(CounterRules.entryFor(3, false, 3)).to.equal(3)
			expect(CounterRules.entryFor(4, false, 3)).to.equal(nil)
			expect(CounterRules.entryFor(0, false, 3)).to.equal(nil)
		end)

		it("takes a cat from the back and puts the door cat back in front", function()
			local line = { "Tux", "Ginger", "Calico" }
			local orders = { { id = "t" }, { id = "g" }, { id = "c" } }
			local kind, order =
				CounterRules.swapIn(line, orders, 3, { kind = "Siamese", order = { id = "s" } })
			expect(kind).to.equal("Calico")
			expect((order :: any).id).to.equal("c")
			expect(line[1]).to.equal("Siamese")
			expect(line[2]).to.equal("Tux")
			expect(line[3]).to.equal("Ginger")
			expect(#line).to.equal(3)
			expect(orders[1].id).to.equal("s")
			expect(orders[3].id).to.equal("g")
			expect(#orders).to.equal(3)
		end)

		it("takes without a door cat and leaves the rest in order", function()
			local line = { "Tux", "Ginger" }
			local orders = { 1, 2 }
			local kind, order = CounterRules.swapIn(line, orders, 2, nil)
			expect(kind).to.equal("Ginger")
			expect(order).to.equal(2)
			expect(#line).to.equal(1)
			expect(line[1]).to.equal("Tux")
			expect(#orders).to.equal(1)
		end)

		it("refuses a place not in the line, or a line out of step with its orders", function()
			local line = { "Tux" }
			local orders = { 1 }
			expect(CounterRules.swapIn(line, orders, 2, nil)).to.equal(nil)
			expect(CounterRules.swapIn(line, orders, 0, nil)).to.equal(nil)
			expect(CounterRules.swapIn(line, { 1, 2 }, 1, nil)).to.equal(nil)
			expect(#line).to.equal(1)
		end)
	end)
end
