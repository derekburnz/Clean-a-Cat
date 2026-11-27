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

		it("needs the group join only under giftGroupOnly (issue 1068)", function()
			local function groupOnly(flag: string): boolean
				return flag == GiftRules.GROUP_ONLY_FLAG
			end
			local function none(_flag: string): boolean
				return false
			end
			local noFav = { favourite = false, group = true, claimed = false }
			expect(GiftRules.canClaim(noFav, groupOnly)).to.equal(true)
			expect(GiftRules.canClaim(noFav, none)).to.equal(false)
			expect(
				GiftRules.canClaim({ favourite = true, group = false, claimed = false }, groupOnly)
			).to.equal(false)
			expect(
				GiftRules.canClaim({ favourite = false, group = true, claimed = true }, groupOnly)
			).to.equal(false)
			local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
			expect(table.find(LiveFlags.KEYS, GiftRules.GROUP_ONLY_FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[GiftRules.GROUP_ONLY_FLAG]).to.equal(true)
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

		it("gives the gift crate once instead of the pet (giftCrate, issue 859)", function()
			local save = { crates = {} :: { [string]: number }, giftClaimed = false }
			expect(GiftRules.giveCrate(save, CrateRules.GIFT_KIND)).to.equal(true)
			expect(save.crates.gift).to.equal(1)
			expect(save.giftClaimed).to.equal(true)
			expect(GiftRules.giveCrate(save, CrateRules.GIFT_KIND)).to.equal(false)
			expect(save.crates.gift).to.equal(1)
		end)

		it("is a known pet with a rarity, and in no crate but the gift crate", function()
			expect(CrateRules.rarityOf(GiftRules.PET)).to.equal("Uncommon")
			for _, kind in { "normal", "good" } do
				for _, entry in CrateRules.odds(kind) do
					expect(entry.pet).never.to.equal(GiftRules.PET)
				end
			end
		end)

		describe("groupVerify (issue 1111)", function()
			local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
			local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

			it("is a switch, off by default, with its remote listed", function()
				expect(table.find(LiveFlags.KEYS, GiftRules.VERIFY_FLAG)).to.be.ok()
				expect(LiveFlags.OFF_BY_DEFAULT[GiftRules.VERIFY_FLAG]).to.equal(true)
				expect(table.find(Remotes.ClientToServer, GiftRules.VERIFY_REMOTE)).to.be.ok()
			end)

			it("answers one tap per cooldown", function()
				expect(GiftRules.verifyReady(nil, 5)).to.equal(true)
				expect(GiftRules.verifyReady(100, 100 + GiftRules.VERIFY_COOLDOWN - 1)).to.equal(
					false
				)
				expect(GiftRules.verifyReady(100, 100 + GiftRules.VERIFY_COOLDOWN)).to.equal(true)
			end)

			it("gives only on a verified join, and each part once", function()
				local none = GiftRules.verifyGrant(false, false, false)
				expect(none.pet).to.equal(false)
				expect(none.coins).to.equal(false)
				local both = GiftRules.verifyGrant(true, false, false)
				expect(both.pet).to.equal(true)
				expect(both.coins).to.equal(true)
				local coinsOnly = GiftRules.verifyGrant(true, true, false)
				expect(coinsOnly.pet).to.equal(false)
				expect(coinsOnly.coins).to.equal(true)
				local nothing = GiftRules.verifyGrant(true, true, true)
				expect(nothing.pet).to.equal(false)
				expect(nothing.coins).to.equal(false)
			end)

			it("asks for the group only when the check fails", function()
				expect(string.find(string.lower(GiftRules.NOT_YET_TEXT), "like")).to.equal(nil)
				expect(string.find(GiftRules.NOT_YET_TEXT, "group")).to.be.ok()
			end)
		end)
	end)
end
