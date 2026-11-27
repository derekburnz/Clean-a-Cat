--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))

type Save = {
	crates: { [string]: number },
	pets: { CrateRules.Pet },
	nextPetId: number,
	workers: { [string]: any },
}

local function newSave(): Save
	return { crates = { normal = 1 }, pets = {}, nextPetId = 1, workers = {} }
end

local function always(value: number): () -> number
	return function()
		return value
	end
end

return function()
	describe("CrateRules", function()
		it(
			"shows the gift crate's own chance per pet, adding up to 100 (giftCrate, issue 859)",
			function()
				local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
				expect(table.find(LiveFlags.KEYS, CrateRules.GIFT_FLAG)).to.be.ok()
				expect(LiveFlags.OFF_BY_DEFAULT[CrateRules.GIFT_FLAG]).to.equal(true)
				expect(table.find(CrateRules.KINDS, CrateRules.GIFT_KIND)).to.be.ok()
				local list = CrateRules.odds(CrateRules.GIFT_KIND)
				expect(#list).to.equal(7)
				local total = 0
				local byRarity: { [string]: number } = {}
				for _, entry in list do
					expect(entry.rarity).never.to.equal("Common")
					total += entry.percent
					byRarity[entry.rarity] = (byRarity[entry.rarity] or 0) + entry.percent
				end
				expect(math.abs(total - 100) < 1e-9).to.equal(true)
				for rarity, sum in byRarity do
					expect(sum).to.equal(CrateRules.CHANCES.gift[rarity])
				end
				expect(list[1].pet).to.equal("Glitch") -- 23%, Uncommon, by name among the three at 23
				expect(list[#list].pet).to.equal("Blaze")
				expect(list[#list].percent).to.equal(1)
				expect(CrateRules.roll(CrateRules.GIFT_KIND, always(0.995))).to.equal("Blaze")
				local starcoat = false
				for _, entry in list do
					starcoat = starcoat or entry.pet == "Starcoat"
				end
				expect(starcoat).to.equal(true)
			end
		)

		it("shows every pet with a chance, adding up to 100, for both crates", function()
			for _, kind in { "normal", "good" } do
				local total = 0
				local list = CrateRules.odds(kind)
				expect(#list).to.equal(8)
				for _, entry in list do
					expect(entry.percent > 0).to.equal(true)
					total += entry.percent
				end
				expect(math.abs(total - 100) < 1e-9).to.equal(true)
			end
			expect(CrateRules.odds("normal")[1].percent).to.equal(25) -- tuning crate.chance: Common 50, two pets
			expect(CrateRules.odds("good")[8].percent).to.equal(4) -- the Legendary
		end)

		it("rolls from the very list it shows", function()
			local list = CrateRules.odds("normal")
			expect(CrateRules.roll("normal", always(0))).to.equal(list[1].pet)
			expect(CrateRules.roll("normal", always(0.2499))).to.equal(list[1].pet)
			expect(CrateRules.roll("normal", always(0.25))).to.equal(list[2].pet)
			expect(CrateRules.roll("normal", always(0.9999))).to.equal(list[#list].pet)
		end)

		it("opens only a crate the save holds, the first pet beside the player", function()
			local save = newSave()
			local pet = CrateRules.open(save, "normal", always(0)) :: CrateRules.Pet
			expect(pet).to.be.ok()
			expect(pet.slot).to.equal(CrateRules.PLAYER_SLOT)
			expect(save.crates.normal).to.equal(0)
			expect(save.nextPetId).to.equal(2)
			expect(CrateRules.open(save, "normal", always(0))).to.equal(nil)
			expect(CrateRules.open(save, "fake", always(0))).to.equal(nil)
			save.crates.normal = 1
			local second = CrateRules.open(save, "normal", always(0)) :: CrateRules.Pet
			expect(second.slot).to.equal(nil) -- a double is kept, in the pen
		end)

		it("places pets only in the save's own slots", function()
			local save = newSave()
			save.crates.normal = 2
			local a = CrateRules.open(save, "normal", always(0)) :: CrateRules.Pet
			local b = CrateRules.open(save, "normal", always(0)) :: CrateRules.Pet
			expect(CrateRules.place(save, b.id, "Jo1")).to.equal(false) -- Jo is not hired
			save.workers.Jo = { mode = "first", level = 1, hiredAt = 0 }
			expect(CrateRules.place(save, b.id, "Jo1")).to.equal(true)
			expect(CrateRules.place(save, b.id, CrateRules.PLAYER_SLOT)).to.equal(true)
			expect(a.slot).to.equal(nil) -- the one there before goes to the pen
			expect(CrateRules.place(save, 999, CrateRules.PLAYER_SLOT)).to.equal(false)
		end)

		it(
			"gives the player and every worker a second slot with the Second pet slot pass",
			function()
				local save = newSave()
				save.crates.normal = 1
				local pet = CrateRules.open(save, "normal", always(0)) :: CrateRules.Pet
				save.workers.Jo = { mode = "first", level = 1, hiredAt = 0 }
				expect(#CrateRules.slots(save)).to.equal(2)
				expect(#CrateRules.slots(save, true)).to.equal(4)
				expect(CrateRules.place(save, pet.id, "player2")).to.equal(false) -- no pass
				expect(CrateRules.place(save, pet.id, "player2", true)).to.equal(true)
				expect(CrateRules.place(save, pet.id, "Jo2", true)).to.equal(true)
				expect(CrateRules.boostOf(save.pets, CrateRules.workerSlots("Jo"))).to.equal(0) -- slot 2 needs the pass
				expect(CrateRules.boostOf(save.pets, CrateRules.workerSlots("Jo", true)) > 0).to.equal(
					true
				)
			end
		)

		it("fuses three of the same pet at the same star into a fixed star up", function()
			local save = newSave()
			save.crates.normal = 4
			local ids = {}
			for _ = 1, 4 do
				table.insert(ids, (CrateRules.open(save, "normal", always(0)) :: CrateRules.Pet).id)
			end
			expect(CrateRules.fuse(save, { ids[1], ids[1], ids[2] })).to.equal(nil) -- the same pet twice
			expect(CrateRules.fuse(save, { ids[1], ids[2] })).to.equal(nil)
			local fused = CrateRules.fuse(save, { ids[1], ids[2], ids[3] }) :: CrateRules.Pet
			expect(fused.star).to.equal(2)
			expect(#save.pets).to.equal(2)
			expect(CrateRules.fuse(save, { ids[1], ids[4], 999 })).to.equal(nil)
			expect(#save.pets).to.equal(2)
		end)

		it("adds boosts, star ups included, and caps a worker's", function()
			expect(CrateRules.boost("Blaze", 1)).to.equal(0.2)
			expect(CrateRules.boost("Blaze", 3)).to.equal(0.4)
			local pets: { CrateRules.Pet } = {
				{ id = 1, kind = "Blaze", star = 3, slot = "Jo1" },
				{ id = 2, kind = "Clover", star = 1, slot = CrateRules.PLAYER_SLOT },
			}
			expect(CrateRules.boostOf(pets, { "Jo1" }, CrateRules.PET_CAP)).to.equal(
				CrateRules.PET_CAP
			)
			expect(CrateRules.boostOf(pets, { CrateRules.PLAYER_SLOT })).to.equal(0.05)
		end)

		it("sells only the normal crate, the earned one, in ones and fives", function()
			expect(CrateRules.SHOP_KIND).to.equal("normal")
			expect(CrateRules.CHANCES[CrateRules.SHOP_KIND]).to.be.ok()
			expect(#CrateRules.SHOP_KEYS).to.equal(2)
			expect(CrateRules.SHOP.CrateOne).to.equal(1)
			expect(CrateRules.SHOP.CrateFive).to.equal(5)
		end)

		it(
			"renames each old pet to a new one of the same rarity, and no old name is rolled (issue 883)",
			function()
				local rarities = {
					Cozy = "Common",
					Scrubby = "Common",
					Pebble = "Uncommon",
					Pickle = "Uncommon",
				}
				rarities.Koi = "Rare"
				rarities.Bamboo = "Rare"
				rarities.Coral = "Epic"
				rarities.Nimbus = "Legendary"
				local count = 0
				for old, new in CrateRules.RENAMED do
					count += 1
					expect(CrateRules.rarityOf(old)).to.equal(nil)
					expect(CrateRules.rarityOf(new)).to.equal(rarities[old])
					expect(CrateRules.renamed(old)).to.equal(new)
				end
				expect(count).to.equal(8)
				expect(CrateRules.renamed("Starcoat")).to.equal("Starcoat")
				-- a pet name a build does not know (an older dev server meeting a renamed pet): no rarity, no boost
				expect(CrateRules.rarityOf("NotAPet")).to.equal(nil)
				expect(CrateRules.boost("NotAPet", 2)).to.equal(0)
				for _, kind in CrateRules.KINDS do
					for _, entry in CrateRules.odds(kind) do
						expect(CrateRules.RENAMED[entry.pet]).to.equal(nil)
					end
				end
			end
		)
	end)
end
