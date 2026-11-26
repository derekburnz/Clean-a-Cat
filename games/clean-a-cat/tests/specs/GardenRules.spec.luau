--!strict
return function()
	local GardenRules = require(game:GetService("ReplicatedStorage").Shared.GardenRules)

	describe("GardenRules", function()
		it("seats only pets in the pen, best star first, then in save order", function()
			local pets: any = {
				{ kind = "A", star = 1 },
				{ kind = "B", star = 2, slot = "player" }, -- beside the player
				{ kind = "C", star = 3 },
				{ kind = "D", star = 1 },
				{ kind = "E", star = 3, slot = "Jo1" }, -- beside a worker
				{ kind = "F", star = 2 },
			}
			local seated = GardenRules.pets(pets, 8)
			expect(#seated).to.equal(4)
			expect(seated[1].kind).to.equal("C")
			expect(seated[2].kind).to.equal("F")
			expect(seated[3].kind).to.equal("A")
			expect(seated[4].kind).to.equal("D")
			expect(seated[1].star).to.equal(3)
		end)

		it("never seats more pets than spots", function()
			local pets: any = {}
			for i = 1, 12 do
				table.insert(pets, { kind = `P{i}`, star = 1 })
			end
			expect(#GardenRules.pets(pets, 8)).to.equal(8)
			expect(#GardenRules.pets(pets, 0)).to.equal(0)
			expect(#GardenRules.pets({}, 8)).to.equal(0)
		end)

		it("names the spots play and sit in turn", function()
			expect(GardenRules.spotName(1)).to.equal("SpotPetPlay1")
			expect(GardenRules.spotName(2)).to.equal("SpotPetSit1")
			expect(GardenRules.spotName(3)).to.equal("SpotPetPlay2")
			expect(GardenRules.spotName(8)).to.equal("SpotPetSit4")
		end)

		it("reads the spot count safely", function()
			expect(GardenRules.spotCount(8)).to.equal(8)
			expect(GardenRules.spotCount(2.5)).to.equal(GardenRules.DEFAULT_SPOTS)
			expect(GardenRules.spotCount(nil)).to.equal(GardenRules.DEFAULT_SPOTS)
			expect(GardenRules.spotCount(-1)).to.equal(GardenRules.DEFAULT_SPOTS)
		end)
	end)
end
