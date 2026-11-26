--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))

return function()
	describe("BubbleRules list", function()
		it("has one entry per id, each with words that fit a short card", function()
			local ids: { [string]: boolean } = {}
			for _, b in BubbleRules.BUBBLES do
				expect(ids[b.id]).to.equal(nil)
				ids[b.id] = true
				expect(#b.title > 0 and #b.title <= 24).to.equal(true)
				expect(#b.line > 0 and #b.line <= 40).to.equal(true)
				expect(BubbleRules.get(b.id)).to.equal(b)
			end
			expect(#BubbleRules.IDS).to.equal(#BubbleRules.BUBBLES)
		end)

		it("ships behind its switch, off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[BubbleRules.FLAG]).to.equal(true)
		end)

		it("gives a new save an empty list", function()
			expect(next(SaveSchema.template(0).bubbles)).to.equal(nil)
		end)
	end)

	describe("BubbleRules.OPENING", function()
		it("names only known bubbles", function()
			for id in BubbleRules.OPENING do
				expect(BubbleRules.get(id)).never.to.equal(nil)
			end
		end)
	end)

	describe("BubbleRules.pick", function()
		it("shows nothing when nothing is due", function()
			expect(BubbleRules.pick({}, {})).to.equal(nil)
		end)

		it("shows the first due bubble in list order", function()
			local b = BubbleRules.pick({ build = true, newSoap = true }, {})
			expect(b and b.id).to.equal("newSoap")
		end)

		it("never shows a bubble this save already showed", function()
			local b = BubbleRules.pick({ build = true, newSoap = true }, { newSoap = true })
			expect(b and b.id).to.equal("build")
			expect(BubbleRules.pick({ openSpa = true }, { openSpa = true })).to.equal(nil)
		end)
	end)

	describe("BubbleRules seen list", function()
		it("keeps only known ids set to true", function()
			local seen =
				BubbleRules.cleanSeen({ openSpa = true, build = false, nope = true, [1] = true })
			expect(seen.openSpa).to.equal(true)
			expect(seen.build).to.equal(nil)
			expect(seen.nope).to.equal(nil)
			expect(next(BubbleRules.cleanSeen("broken"))).to.equal(nil)
		end)

		it("packs and unpacks the attribute", function()
			local text = BubbleRules.pack({ build = true, openSpa = true })
			expect(text).to.equal("openSpa,build")
			local back = BubbleRules.unpack(text)
			expect(back and back.openSpa).to.equal(true)
			expect(back and back.build).to.equal(true)
			expect(BubbleRules.pack({})).to.equal("")
		end)

		it("reads no list before the save loads, and drops unknown ids", function()
			expect(BubbleRules.unpack(nil)).to.equal(nil)
			local back = BubbleRules.unpack("nope,,firstCustomer")
			expect(back and back.firstCustomer).to.equal(true)
			expect(back and back.nope).to.equal(nil)
		end)
	end)
end
