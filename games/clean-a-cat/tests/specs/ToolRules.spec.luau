--!strict
return function()
	local ToolRules = require(game:GetService("ReplicatedStorage").Shared.ToolRules)

	local function wallet(coins: number): ToolRules.Wallet
		return { coins = coins, tools = {} }
	end

	describe("ToolRules.buy", function()
		it("takes the price once and keeps the tool", function()
			local w = wallet(45)
			expect(ToolRules.buy(w, "BubbleSoap")).to.equal(30)
			expect(w.coins).to.equal(15)
			expect(w.tools.BubbleSoap).to.equal(true)
			expect(ToolRules.buy(w, "BubbleSoap")).to.equal(0)
			expect(w.coins).to.equal(15)
		end)

		it("refuses too few coins, an unknown tool and NaN coins", function()
			local poor = wallet(29)
			expect(ToolRules.buy(poor, "BubbleSoap")).to.equal(0)
			expect(poor.coins).to.equal(29)
			expect(poor.tools.BubbleSoap).to.equal(nil)
			expect(ToolRules.buy(wallet(1000), "GoldenSponge")).to.equal(0)
			expect(ToolRules.buy(wallet(0 / 0), "BubbleSoap")).to.equal(0)
		end)

		it("lists every board id in TOOLS", function()
			for _, id in ToolRules.IDS do
				expect(ToolRules.TOOLS[id]).to.be.ok()
			end
		end)
	end)

	describe("ToolRules.spongeRadius", function()
		it("widens the scrub only for an owned tool", function()
			local base = 0.9
			expect(ToolRules.spongeRadius(base, function()
				return false
			end)).to.equal(base)
			local wide = ToolRules.spongeRadius(base, function(id)
				return id == "BubbleSoap"
			end)
			expect(wide).to.equal(ToolRules.TOOLS.BubbleSoap.spongeRadius)
			expect(wide > base).to.equal(true)
		end)
	end)
end
