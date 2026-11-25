--!strict
return function()
	local LineLooks = require(game:GetService("ServerScriptService").Server.Util.LineLooks)

	local function looksOf(line: LineLooks.Line?): string
		return if line then table.concat(line.looks, ",") else "nil"
	end

	describe("LineLooks", function()
		it("gives a new line the first look numbers", function()
			local line = LineLooks.show(nil, { "Tux", "Smudge", "Marble" })
			expect(looksOf(line)).to.equal("0,1,2")
			expect(line.nextLook).to.equal(3)
		end)

		it("keeps every look on a resend", function()
			local line = LineLooks.show(nil, { "Tux", "Smudge", "Marble" })
			expect(looksOf(LineLooks.show(line, { "Tux", "Smudge", "Marble" }))).to.equal("0,1,2")
		end)

		it("moves the looks up on a serve and adds one at the back", function()
			local line = LineLooks.show(nil, { "Tux", "Smudge", "Marble" })
			local served = LineLooks.served(line, "Tux")
			expect(looksOf(served)).to.equal("1,2")
			expect(looksOf(LineLooks.show(served, { "Smudge", "Marble", "Ginger" }))).to.equal(
				"1,2,3"
			)
		end)

		it("takes the picked look to the front with its cat", function()
			local line = LineLooks.show(nil, { "Tux", "Smudge", "Marble" })
			local picked = LineLooks.picked(line, 3)
			expect(looksOf(picked)).to.equal("2,0,1")
			expect(looksOf(LineLooks.show(picked, { "Marble", "Tux", "Smudge" }))).to.equal("2,0,1")
		end)

		it("keeps the picked look when every waiting cat is the same kind", function()
			-- Sync-Agent's Studio case: three Tux. The resend after a pick looks like nothing moved.
			local line = LineLooks.show(nil, { "Tux", "Tux", "Tux" })
			local picked = LineLooks.picked(line, 3)
			local shown = LineLooks.show(picked, { "Tux", "Tux", "Tux" })
			expect(looksOf(shown)).to.equal("2,0,1")
			expect(shown.nextLook).to.equal(3)
		end)

		it("still shifts on a serve when every waiting cat is the same kind", function()
			local line = LineLooks.show(nil, { "Tux", "Tux", "Tux" })
			local shown = LineLooks.show(LineLooks.served(line, "Tux"), { "Tux", "Tux", "Tux" })
			expect(looksOf(shown)).to.equal("1,2,3")
		end)

		it("refuses a pick of the front or past the line, and a serve of another cat", function()
			local line = LineLooks.show(nil, { "Tux", "Smudge", "Marble" })
			expect(LineLooks.picked(line, 1)).to.equal(nil)
			expect(LineLooks.picked(line, 4)).to.equal(nil)
			expect(LineLooks.picked(line, 2.5)).to.equal(nil)
			expect(LineLooks.served(line, "Marble")).to.equal(nil)
			expect(LineLooks.served(nil, "Tux")).to.equal(nil)
		end)

		it("tells where each customer stood before, 0 for a walk-in", function()
			expect(table.concat(LineLooks.cameFrom(nil, { 0, 1, 2 }), ",")).to.equal("0,0,0")
			-- a serve: 1 and 2 move up a place, 3 is new
			expect(table.concat(LineLooks.cameFrom({ 0, 1, 2 }, { 1, 2, 3 }), ",")).to.equal(
				"2,3,0"
			)
			-- a pick: 2 goes to the front, the others step back
			expect(table.concat(LineLooks.cameFrom({ 0, 1, 2 }, { 2, 0, 1 }), ",")).to.equal(
				"3,1,2"
			)
			-- a resend: nobody moves
			expect(table.concat(LineLooks.cameFrom({ 0, 1, 2 }, { 0, 1, 2 }), ",")).to.equal(
				"1,2,3"
			)
		end)

		it("drops a customer who left, keeping the rest in order", function()
			local line = LineLooks.show(nil, { "Tux", "Smudge", "Marble" })
			local after = LineLooks.left(line, 2) :: LineLooks.Line
			expect(table.concat(after.kinds, ",")).to.equal("Tux,Marble")
			expect(looksOf(after)).to.equal("0,2")
			expect(after.nextLook).to.equal(3)
			expect(LineLooks.left(line, 4)).to.equal(nil)
			expect(LineLooks.left(nil, 1)).to.equal(nil)
		end)
	end)
end
