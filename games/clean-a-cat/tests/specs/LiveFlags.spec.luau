--!strict
return function()
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)

	describe("LiveFlags.resolve", function()
		it("keeps a plain switch on unless the store says false", function()
			expect(LiveFlags.resolve("someKillSwitch", nil)).to.equal(true)
			expect(LiveFlags.resolve("someKillSwitch", "junk")).to.equal(true)
			expect(LiveFlags.resolve("someKillSwitch", false)).to.equal(false)
		end)

		it("keeps an off-by-default switch off unless the store says true", function()
			expect(LiveFlags.resolve("exampleFeature", nil)).to.equal(false)
			expect(LiveFlags.resolve("exampleFeature", 1)).to.equal(false)
			expect(LiveFlags.resolve("exampleFeature", true)).to.equal(true)
		end)

		it("reads a switch inside the one entry for every switch", function()
			local all = { exampleFeature = true, someKillSwitch = false }
			expect(LiveFlags.resolve("exampleFeature", LiveFlags.storedIn(all, "exampleFeature"))).to.equal(
				true
			)
			expect(LiveFlags.resolve("someKillSwitch", LiveFlags.storedIn(all, "someKillSwitch"))).to.equal(
				false
			)
			-- a switch missing from the entry, or an entry that is not a table, reads as a missing entry
			expect(LiveFlags.storedIn(all, "otherKey")).to.equal(nil)
			expect(LiveFlags.storedIn("junk", "exampleFeature")).to.equal(nil)
			expect(LiveFlags.storedIn(nil, "exampleFeature")).to.equal(nil)
			expect(
				LiveFlags.resolve(
					"exampleFeature",
					LiveFlags.storedIn({ exampleFeature = "yes" }, "exampleFeature")
				)
			).to.equal(false)
			expect(LiveFlags.resolve("someKillSwitch", LiveFlags.storedIn({}, "someKillSwitch"))).to.equal(
				true
			)
		end)

		it("never names a switch like the entry that holds them all", function()
			for _, key in LiveFlags.KEYS do
				expect(key ~= LiveFlags.ALL_ENTRY).to.equal(true)
				expect(string.find(key, "^[%a%d]+$") ~= nil).to.equal(true)
			end
		end)

		it("lists every off-by-default key in KEYS", function()
			for key in LiveFlags.OFF_BY_DEFAULT do
				expect(table.find(LiveFlags.KEYS, key) ~= nil).to.equal(true)
			end
		end)
	end)
end
