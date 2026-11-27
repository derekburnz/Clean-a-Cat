--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Passes = require(Shared:WaitForChild("Passes"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local StarterRules = require(Shared:WaitForChild("StarterRules"))

local function none(_key: string): boolean
	return false
end

return function()
	describe("StarterRules", function()
		it("holds three real passes and nothing random", function()
			expect(#StarterRules.CONTENTS).to.equal(3)
			for _, key in StarterRules.CONTENTS do
				expect(Passes.IDS[key]).to.be.ok()
			end
			expect(StarterRules.SHOW_FROM).to.equal(SpaRules.TUTORIAL_ENDS_AT)
		end)

		it("is offered from the tutorial's end until its end, and never after", function()
			local ends = 100000
			expect(StarterRules.offered(ends, 1000, StarterRules.SHOW_FROM - 1, none)).to.equal(
				false
			)
			expect(StarterRules.offered(ends, 1000, StarterRules.SHOW_FROM, none)).to.equal(true)
			expect(StarterRules.offered(ends, ends - 1, 9999, none)).to.equal(true)
			expect(StarterRules.offered(ends, ends, 9999, none)).to.equal(false)
			expect(StarterRules.offered(0, 1000, 9999, none)).to.equal(false) -- never stamped
		end)

		it("is hidden from a player who owns any one of the three", function()
			for _, key in StarterRules.CONTENTS do
				local owns = function(k: string): boolean
					return k == key
				end
				expect(StarterRules.offered(100000, 1000, 9999, owns)).to.equal(false)
			end
			local lou = function(k: string): boolean
				return k == "Lou"
			end
			expect(StarterRules.offered(100000, 1000, 9999, lou)).to.equal(true)
		end)

		it("counts whole hours since the offer started", function()
			local length = 72 * 3600
			expect(StarterRules.hoursIn(length, 0, length)).to.equal(0)
			expect(StarterRules.hoursIn(length + 1000, 1000 + 2 * 3600 + 5, length)).to.equal(2)
		end)

		it(
			"gives the golden pet once, never from a crate, no stronger than the best crate pet (1090)",
			function()
				local CrateRules = require(Shared:WaitForChild("CrateRules"))
				local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
				expect(table.find(LiveFlags.KEYS, StarterRules.PET_FLAG)).to.be.ok()
				expect(LiveFlags.OFF_BY_DEFAULT[StarterRules.PET_FLAG]).to.equal(true)
				expect(CrateRules.rarityOf(StarterRules.PET)).to.equal(StarterRules.PET_RARITY)
				expect(CrateRules.BOOST[StarterRules.PET_RARITY] <= CrateRules.BOOST.Legendary).to.equal(
					true
				)
				for _, kind in CrateRules.KINDS do
					for _, odds in CrateRules.odds(kind) do
						expect(odds.pet ~= StarterRules.PET).to.equal(true)
					end
				end
				local save = { pets = {}, nextPetId = 3, starterPet = false }
				local pet = StarterRules.givePet(save, CrateRules.PLAYER_SLOT)
				expect(pet).to.be.ok()
				expect((pet :: any).slot).to.equal(CrateRules.PLAYER_SLOT)
				expect(save.nextPetId).to.equal(4)
				expect(StarterRules.givePet(save, CrateRules.PLAYER_SLOT)).to.equal(nil)
				expect(#save.pets).to.equal(1)
			end
		)

		it("knows a save that bought the pack from its three passes", function()
			expect(StarterRules.boughtBefore({})).to.equal(false)
			expect(StarterRules.boughtBefore({ GoldenSponge = true, SecondPetSlot = true })).to.equal(
				false
			)
			expect(StarterRules.boughtBefore({
				GoldenSponge = true,
				SecondPetSlot = true,
				DoubleCoins = true,
			})).to.equal(true)
		end)
	end)
end
