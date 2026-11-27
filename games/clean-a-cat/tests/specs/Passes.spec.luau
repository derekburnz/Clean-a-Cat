--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Passes = require(Shared:WaitForChild("Passes"))

local function owning(list: { string }): (key: string) -> boolean
	return function(key: string): boolean
		return table.find(list, key) ~= nil
	end
end

return function()
	describe("Passes", function()
		it("lists the six passes, none created yet", function()
			expect(#Passes.KEYS).to.equal(6)
			for _, key in Passes.KEYS do
				expect(Passes.IDS[key]).to.be.ok()
				expect(Passes.INFO[key]).to.be.ok()
				expect(Passes.id(key)).to.equal(nil) -- 0: hidden until the owner creates it
			end
			expect(Passes.keyOf(0)).to.equal(nil)
			expect(Passes.id("Nope")).to.equal(nil)
		end)

		it(
			"lists the same passes for the dev and the live experience, and none elsewhere",
			function()
				local Products = require(Shared:WaitForChild("Products"))
				for _, byGame in { Passes.IDS_BY_GAME, Products.IDS_BY_GAME } do
					local none = if byGame == Passes.IDS_BY_GAME then Passes.NONE else Products.NONE
					for _, gameId in { Products.DEV_GAME_ID, Products.LIVE_GAME_ID } do
						local set = byGame[gameId]
						expect(set).to.be.ok()
						for key in none do
							expect(type(set[key])).to.equal("number")
						end
						for key in set do
							expect(none[key]).to.equal(0)
						end
					end
					expect(Products.pick(byGame, 0, none)).to.equal(none)
					expect(Products.pick(byGame, Products.DEV_GAME_ID, none)).to.equal(
						byGame[Products.DEV_GAME_ID]
					)
				end
				expect(Products.DEV_GAME_ID ~= Products.LIVE_GAME_ID).to.equal(true)
			end
		)

		it("doubles a hand wash with 2x Coins and adds 20% with the Golden Sponge", function()
			expect(Passes.handExtra(20, owning({}))).to.equal(0)
			expect(Passes.handExtra(20, owning({ "DoubleCoins" }))).to.equal(20)
			expect(Passes.handExtra(20, owning({ "GoldenSponge" }))).to.equal(4)
			expect(Passes.handExtra(20, owning({ "DoubleCoins", "GoldenSponge" }))).to.equal(28)
			expect(Passes.handExtra(0, owning({ "DoubleCoins" }))).to.equal(0)
			-- other passes pay nothing
			expect(Passes.handExtra(20, owning({ "Lou", "SecondBuilder", "SecondPetSlot" }))).to.equal(
				0
			)
		end)

		it("triples a hand wash with 3x Coins in place of 2x, never both", function()
			expect(Passes.handExtra(20, owning({ "TripleCoins" }))).to.equal(40)
			expect(Passes.handExtra(20, owning({ "DoubleCoins", "TripleCoins" }))).to.equal(40)
			expect(Passes.handExtra(20, owning({ "TripleCoins", "GoldenSponge" }))).to.equal(52)
			expect(Passes.handLine(owning({ "DoubleCoins", "TripleCoins" }))).to.equal("3x Coins")
			expect(Passes.handLine(owning({ "TripleCoins", "GoldenSponge" }))).to.equal(
				"3x Coins and Golden Sponge"
			)
		end)

		it("offers 3x Coins only once 2x is owned, with coinLadder on", function()
			local function on(flag: string): boolean
				return flag == Passes.LADDER_FLAG
			end
			local function off(_flag: string): boolean
				return false
			end
			expect(Passes.offered("TripleCoins", owning({}), on)).to.equal(false)
			expect(Passes.offered("TripleCoins", owning({ "DoubleCoins" }), on)).to.equal(true)
			expect(Passes.offered("TripleCoins", owning({ "DoubleCoins" }), off)).to.equal(false)
			expect(Passes.offered("TripleCoins", owning({ "TripleCoins" }), off)).to.equal(true) -- shows Owned
			expect(Passes.offered("DoubleCoins", owning({}), off)).to.equal(true)
			expect(Passes.offered("Lou", owning({}), off)).to.equal(true)
		end)

		it("names the recap line from one of its known words", function()
			expect(Passes.handLine(owning({}))).to.equal(nil)
			for _, list in
				{
					{ "DoubleCoins" },
					{ "GoldenSponge" },
					{ "DoubleCoins", "GoldenSponge" },
					{ "TripleCoins" },
					{ "TripleCoins", "GoldenSponge" },
				}
			do
				local line = Passes.handLine(owning(list)) :: string
				expect(table.find(Passes.LINES, line)).to.be.ok()
			end
		end)
	end)
end
