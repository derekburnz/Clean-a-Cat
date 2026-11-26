--!strict
return function()
	local AskRules = require(game:GetService("ReplicatedStorage").Shared.AskRules)
	local FavouriteAskRules = require(game:GetService("ReplicatedStorage").Shared.FavouriteAskRules)
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)

	local function state(over: { [string]: any }): FavouriteAskRules.State
		local s: { [string]: any } = { visit = 1, washes = 0, favourited = false, asked = false }
		for key, value in over do
			s[key] = value
		end
		return s :: any
	end

	describe("FavouriteAskRules", function()
		it("ships behind a switch that starts off, in the ask queue as favourite", function()
			expect(table.find(LiveFlags.KEYS, FavouriteAskRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[FavouriteAskRules.FLAG]).to.equal(true)
			expect(AskRules.known(FavouriteAskRules.ASK_ID)).to.equal(true)
		end)

		it("is due on the second visit or after 10 cats, for a stand skipper, once", function()
			expect(FavouriteAskRules.due(state({}))).to.equal(false)
			expect(FavouriteAskRules.due(state({ washes = 9 }))).to.equal(false)
			expect(FavouriteAskRules.due(state({ washes = 10 }))).to.equal(true)
			expect(FavouriteAskRules.due(state({ visit = 2 }))).to.equal(true)
			expect(FavouriteAskRules.due(state({ visit = 2, favourited = true }))).to.equal(false)
			expect(FavouriteAskRules.due(state({ visit = 5, asked = true }))).to.equal(false)
		end)

		it("names no reward", function()
			local bubble = FavouriteAskRules.BUBBLE
			local words =
				string.lower(bubble.title .. " " .. bubble.line .. " " .. (bubble.button or ""))
			for _, word in { "coin", "free", "pet", "reward", "gift", "crate" } do
				expect(string.find(words, word, 1, true)).to.equal(nil)
			end
		end)
	end)
end
