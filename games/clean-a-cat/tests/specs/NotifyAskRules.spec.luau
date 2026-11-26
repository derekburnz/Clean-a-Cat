--!strict
return function()
	local AskRules = require(game:GetService("ReplicatedStorage").Shared.AskRules)
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
	local NotifyAskRules = require(game:GetService("ReplicatedStorage").Shared.NotifyAskRules)

	describe("NotifyAskRules", function()
		it("ships behind a switch that starts off, in the ask queue as notify", function()
			expect(table.find(LiveFlags.KEYS, NotifyAskRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[NotifyAskRules.FLAG]).to.equal(true)
			expect(AskRules.known(NotifyAskRules.ASK_ID)).to.equal(true)
			expect(AskRules.QUIET[NotifyAskRules.ASK_ID]).to.equal(nil)
		end)

		it("is due from 1:45 of play, once a save", function()
			expect(NotifyAskRules.AT).to.equal(105)
			expect(NotifyAskRules.due(104, false)).to.equal(false)
			expect(NotifyAskRules.due(105, false)).to.equal(true)
			expect(NotifyAskRules.due(4000, true)).to.equal(false)
		end)

		it("has Suds's words with its own button and names no reward", function()
			local bubble = NotifyAskRules.BUBBLE
			expect(bubble.button).to.equal("Sure!")
			expect(bubble.showMe).to.equal(false)
			local words = string.lower(bubble.title .. " " .. bubble.line)
			expect(string.find(words, "coin", 1, true)).to.equal(nil)
			expect(string.find(words, "free", 1, true)).to.equal(nil)
		end)
	end)
end
