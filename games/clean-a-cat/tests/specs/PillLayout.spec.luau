--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PillLayout = require(Client:WaitForChild("Spa"):WaitForChild("PillLayout"))

	local SIZE = Vector2.new(160, 44)
	local function pill(key: string, x: number, y: number, distance: number, wins: boolean?): any
		return {
			key = key,
			center = Vector2.new(x, y),
			size = SIZE,
			wins = wins == true,
			distance = distance,
		}
	end

	describe("PillLayout.keep", function()
		it("shows pills that stand apart", function()
			local kept = PillLayout.keep({ pill("crate", 100, 100, 6), pill("brush", 100, 200, 4) })
			expect(kept.crate).to.equal(true)
			expect(kept.brush).to.equal(true)
		end)

		it("hides the farther of two overlapping pills", function()
			local kept = PillLayout.keep({ pill("crate", 100, 100, 3), pill("brush", 130, 110, 5) })
			expect(kept.crate).to.equal(true)
			expect(kept.brush).to.equal(nil)
		end)

		it("lets a winning pill beat a nearer one", function()
			local kept =
				PillLayout.keep({ pill("crate", 100, 100, 2), pill("take", 120, 100, 9, true) })
			expect(kept.take).to.equal(true)
			expect(kept.crate).to.equal(nil)
		end)

		it("keeps the margin between pills", function()
			local touching = PillLayout.keep({ pill("a", 0, 0, 1), pill("b", 162, 0, 2) })
			expect(touching.b).to.equal(nil)
			local apart = PillLayout.keep({ pill("a", 0, 0, 1), pill("b", 165, 0, 2) })
			expect(apart.b).to.equal(true)
		end)

		it("checks a pill against every kept one", function()
			local kept =
				PillLayout.keep({ pill("a", 0, 0, 1), pill("b", 0, 100, 2), pill("c", 20, 90, 3) })
			expect(kept.a).to.equal(true)
			expect(kept.b).to.equal(true)
			expect(kept.c).to.equal(nil)
		end)
	end)
end
