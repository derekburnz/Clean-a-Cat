--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedbackRules = require(Shared:WaitForChild("FeedbackRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))

return function()
	describe("FeedbackRules", function()
		it("ships behind a switch that starts off, with its remote listed", function()
			expect(table.find(LiveFlags.KEYS, FeedbackRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[FeedbackRules.FLAG]).to.equal(true)
			expect(table.find(Remotes.ClientToServer, FeedbackRules.REMOTE)).to.be.ok()
		end)

		it("keys each day in UTC", function()
			expect(FeedbackRules.dayKey(0)).to.equal("1970-01-01")
			expect(FeedbackRules.dayKey(86400 * 365)).to.equal("1971-01-01")
		end)

		it("takes a short note, trimmed, and drops anything else", function()
			expect(FeedbackRules.cleanNote("  more cats please ")).to.equal("more cats please")
			expect(FeedbackRules.cleanNote("   ")).to.equal(nil)
			expect(FeedbackRules.cleanNote(nil)).to.equal(nil)
			expect(FeedbackRules.cleanNote(42)).to.equal(nil)
			expect(FeedbackRules.cleanNote(string.rep("a", FeedbackRules.NOTE_MAX))).to.be.ok()
			expect(FeedbackRules.cleanNote(string.rep("a", FeedbackRules.NOTE_MAX + 1))).to.equal(
				nil
			)
			expect(FeedbackRules.cleanNote("\255\254")).to.equal(nil)
		end)

		it("keeps a filtered note only when something is left", function()
			expect(FeedbackRules.kept("I love Suds")).to.equal("I love Suds")
			expect(FeedbackRules.kept("#### ##")).to.equal(nil)
			expect(FeedbackRules.kept(nil)).to.equal(nil)
		end)

		it("adds to the day up to its cap and starts a broken day again", function()
			local entry: FeedbackRules.Entry =
				{ choice = "love", note = nil, at = 1, placeVersion = 7 }
			local list, added = FeedbackRules.append(nil, entry)
			expect(added).to.equal(true)
			expect(#list).to.equal(1)
			local again = FeedbackRules.append("broken", entry)
			expect(#again).to.equal(1)
			local full = {}
			for i = 1, FeedbackRules.DAY_CAP do
				full[i] = entry
			end
			local same, more = FeedbackRules.append(full, entry)
			expect(more).to.equal(false)
			expect(#same).to.equal(FeedbackRules.DAY_CAP)
		end)

		it("has the four choices, each a valid analytics field", function()
			expect(#FeedbackRules.CHOICES).to.equal(4)
			for _, choice in FeedbackRules.CHOICES do
				expect(string.match(choice, "^[a-z_]+$")).to.be.ok()
			end
		end)
	end)
end
