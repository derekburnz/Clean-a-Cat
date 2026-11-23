--!strict
return function()
	local SaveSchema = require(game:GetService("ReplicatedStorage").Shared.SaveSchema)

	describe("SaveSchema.migrate", function()
		it("gives a new player the template", function()
			local save = SaveSchema.migrate(nil, 100)
			expect(save).to.be.ok()
			expect((save :: any).version).to.equal(SaveSchema.VERSION)
			expect((save :: any).createdAt).to.equal(100)
		end)

		it("fills fields an old save lacks and keeps the rest", function()
			local save =
				SaveSchema.migrate({ version = SaveSchema.VERSION, coins = 42 }, 100) :: any
			expect(save.coins).to.equal(42)
			expect(save.funnel).to.be.a("table")
			expect(save.playSeconds).to.equal(0)
		end)

		it("gives a save from before the first slice every slice field", function()
			local old = {
				version = 1,
				createdAt = 5,
				lastSeen = 6,
				playSeconds = 70,
				coins = 25,
				funnel = { joined = true },
			}
			local save = SaveSchema.migrate(old, 100) :: any
			expect(save.coins).to.equal(25)
			expect(save.createdAt).to.equal(5)
			expect(save.funnel.joined).to.equal(true)
			expect(save.stars).to.equal(0)
			expect(save.tutorialStep).to.equal(0)
			expect(save.indexBonusPaid).to.equal(false)
			for _, key in { "residents", "tools", "stations", "builds", "index" } do
				expect(save[key]).to.be.a("table")
				expect(next(save[key])).to.equal(nil)
			end
		end)

		it("keeps slice fields a returning player already has", function()
			local save = SaveSchema.migrate({
				version = 1,
				coins = 3,
				stars = 4,
				residents = { { cat = "Smudge", bow = "BowPink", since = 10 } },
				builds = { room = { item = "VipRoom", endsAt = 999 } },
				index = { Smudge = { washed = true, resident = true } },
				tutorialStep = 6,
			}, 100) :: any
			expect(save.stars).to.equal(4)
			expect(save.residents[1].cat).to.equal("Smudge")
			expect(save.builds.room.endsAt).to.equal(999)
			expect(save.index.Smudge.resident).to.equal(true)
			expect(save.tutorialStep).to.equal(6)
		end)

		it("resets a field of the wrong kind or a broken number", function()
			local save = SaveSchema.migrate({
				version = 1,
				coins = "lots",
				stars = 0 / 0,
				residents = 7,
				playSeconds = math.huge,
			}, 100) :: any
			expect(save.coins).to.equal(0)
			expect(save.stars).to.equal(0)
			expect(save.residents).to.be.a("table")
			expect(save.playSeconds).to.equal(0)
		end)

		it(
			"keeps keys it does not know, so an older server never drops a newer server's fields",
			function()
				local save =
					SaveSchema.migrate({ version = 1, futureThing = { a = 1 } }, 100) :: any
				expect(save.futureThing.a).to.equal(1)
			end
		)

		it("gives every new player separate tables", function()
			local a = SaveSchema.migrate(nil, 1) :: any
			local b = SaveSchema.migrate(nil, 1) :: any
			a.tools.BubbleSoap = true
			expect(b.tools.BubbleSoap).to.equal(nil)
		end)

		it("refuses a save newer than this server", function()
			local save, reason = SaveSchema.migrate({ version = SaveSchema.VERSION + 1 }, 100)
			expect(save).to.equal(nil)
			expect(reason).to.be.a("string")
		end)
	end)
end
