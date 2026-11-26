--!strict
return function()
	local GiftRules = require(game:GetService("ReplicatedStorage").Shared.GiftRules)
	local CrateRules = require(game:GetService("ReplicatedStorage").Shared.CrateRules)

	describe("GiftRules", function()
		it("lights at 7:00 of play", function()
			expect(GiftRules.lit(419)).to.equal(false)
			expect(GiftRules.lit(420)).to.equal(true)
		end)

		it("needs the favourite and the group, never the like, and only once", function()
			expect(GiftRules.canClaim({ favourite = true, group = true, claimed = false })).to.equal(
				true
			)
			expect(GiftRules.canClaim({ favourite = false, group = true, claimed = false })).to.equal(
				false
			)
			expect(GiftRules.canClaim({ favourite = true, group = false, claimed = false })).to.equal(
				false
			)
			expect(GiftRules.canClaim({ favourite = true, group = true, claimed = true })).to.equal(
				false
			)
		end)

		it("gives Starcoat once, into the empty player slot", function()
			local save = { pets = {}, nextPetId = 4, giftClaimed = false }
			local pet = GiftRules.give(save, CrateRules.PLAYER_SLOT)
			expect(pet).to.be.ok()
			expect((pet :: any).kind).to.equal("Starcoat")
			expect((pet :: any).id).to.equal(4)
			expect((pet :: any).slot).to.equal(CrateRules.PLAYER_SLOT)
			expect(save.nextPetId).to.equal(5)
			expect(GiftRules.give(save, CrateRules.PLAYER_SLOT)).to.equal(nil)
			expect(#save.pets).to.equal(1)
		end)

		it("leaves a taken slot alone", function()
			local save: any = {
				pets = { { id = 1, kind = "Cozy", star = 1, slot = CrateRules.PLAYER_SLOT } },
				nextPetId = 2,
				giftClaimed = false,
			}
			local pet = GiftRules.give(save, CrateRules.PLAYER_SLOT)
			expect((pet :: any).slot).to.equal(nil)
		end)

		it("is a known pet with a rarity, and never in a crate", function()
			expect(CrateRules.rarityOf(GiftRules.PET)).to.equal("Uncommon")
			for _, kind in CrateRules.KINDS do
				for _, entry in CrateRules.odds(kind) do
					expect(entry.pet).never.to.equal(GiftRules.PET)
				end
			end
		end)
	end)
end
