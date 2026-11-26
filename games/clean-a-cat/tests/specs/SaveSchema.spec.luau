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

	describe("SaveSchema for the agreed design (issue 523)", function()
		it("gives an old save every new field with its default", function()
			local save = SaveSchema.migrate({ version = 1, coins = 9, stars = 3 }, 100) :: any
			expect(save.coins).to.equal(9)
			expect(save.bow).to.equal("Ribbon")
			expect(save.nextPetId).to.equal(1)
			expect(save.visiting).to.equal(true)
			expect(save.starterEndsAt).to.equal(0)
			expect(save.giftClaimed).to.equal(false)
			expect(save.starterOpened).to.equal(false)
			expect(save.visits).to.equal(0)
			expect(save.asks).to.be.a("table")
			expect(save.quests.day).to.equal(0)
			expect(save.quests.weeklyCrate).to.equal(false)
			expect(save.checkin.days).to.equal(0)
			for _, key in { "bows", "workers", "pets", "crates", "receipts", "bench" } do
				expect(save[key]).to.be.a("table")
				expect(next(save[key])).to.equal(nil)
			end
		end)

		it("fills the missing or broken fields of a record and keeps the rest", function()
			local save = SaveSchema.migrate({
				version = 1,
				quests = { tz = -5, day = 20000, progress = { wash5 = 3 }, week = "x" },
				checkin = { days = 4 },
			}, 100) :: any
			expect(save.quests.tz).to.equal(-5)
			expect(save.quests.day).to.equal(20000)
			expect(save.quests.progress.wash5).to.equal(3)
			expect(save.quests.week).to.equal(0)
			expect(save.quests.claimed).to.be.a("table")
			expect(save.checkin.days).to.equal(4)
			expect(save.checkin.lastDay).to.equal(0)
		end)

		it("gives an old save the Free Rewards fields and keeps a paid row", function()
			local old = SaveSchema.migrate({ version = 1 }, 100) :: any
			expect(old.freeRewards.play).to.equal(false)
			expect(old.freeRewards.like).to.equal(false)
			expect(old.likeAskedAt).to.equal(0)
			local paid = SaveSchema.migrate(
				{ version = 1, freeRewards = { like = true }, likeAskedAt = 50 },
				100
			) :: any
			expect(paid.freeRewards.like).to.equal(true)
			expect(paid.freeRewards.play).to.equal(false)
			expect(paid.likeAskedAt).to.equal(50)
		end)

		it("round trips every new field", function()
			local save = SaveSchema.template(100) :: any
			save.bows.Silk = true
			save.bow = "Silk"
			save.workers.Jo =
				{ mode = "rarest", level = 2, name = "Jojo", station = "Tub2", hiredAt = 50 }
			table.insert(save.pets, { id = 1, kind = "Pip", star = 2, slot = "player" })
			save.nextPetId = 2
			save.crates.good = 1
			save.starterEndsAt = 999
			table.insert(
				save.bench,
				{ kind = "Tux", dirt = 3, needs = { "mud", "tangles", "smell", "claws" } }
			)
			local back = SaveSchema.migrate(save, 200) :: any
			expect(back.bows.Silk).to.equal(true)
			expect(back.workers.Jo.mode).to.equal("rarest")
			expect(back.workers.Jo.name).to.equal("Jojo")
			expect(back.pets[1].star).to.equal(2)
			expect(back.crates.good).to.equal(1)
			expect(back.starterEndsAt).to.equal(999)
			expect(back.bench[1].dirt).to.equal(3)
			expect(back.createdAt).to.equal(100)
		end)

		it("never grants one receipt twice and keeps only the newest", function()
			local save = SaveSchema.template(1)
			expect(SaveSchema.addReceipt(save, "a")).to.equal(true)
			expect(SaveSchema.addReceipt(save, "a")).to.equal(false)
			for n = 1, SaveSchema.RECEIPTS_KEPT + 5 do
				SaveSchema.addReceipt(save, `r{n}`)
			end
			expect(#save.receipts).to.equal(SaveSchema.RECEIPTS_KEPT)
			expect(table.find(save.receipts, "a")).to.equal(nil)
		end)

		it("stamps the starter pack's end once from first join and never moves it", function()
			local save = SaveSchema.template(1000)
			expect(save.starterEndsAt).to.equal(0)
			expect(SaveSchema.stampStarter(save)).to.equal(1000 + SaveSchema.STARTER_SECONDS)
			save.createdAt = 5000 -- even a changed join time leaves a stamped end alone
			expect(SaveSchema.stampStarter(save)).to.equal(1000 + SaveSchema.STARTER_SECONDS)
			-- a save from before the pack starts its 72 hours at the join that stamps it
			local old = SaveSchema.template(10)
			expect(SaveSchema.stampStarter(old, 50000)).to.equal(50000 + SaveSchema.STARTER_SECONDS)
			local fresh = SaveSchema.template(70000)
			expect(SaveSchema.stampStarter(fresh, 70000)).to.equal(
				70000 + SaveSchema.STARTER_SECONDS
			)
			local back = SaveSchema.migrate(SaveSchema.template(1) :: any, 2) :: SaveSchema.Save
			back.starterEndsAt = 777
			local again = SaveSchema.migrate(back :: any, 99999) :: SaveSchema.Save
			expect(again.starterEndsAt).to.equal(777)
		end)

		it("counts days in the player's own time zone for quests and the check in card", function()
			local save = SaveSchema.template(1)
			expect(SaveSchema.day(save, 86400 - 1)).to.equal(0)
			save.quests.tz = 1
			expect(SaveSchema.day(save, 86400 - 1)).to.equal(1)
			save.quests.tz = -5
			expect(SaveSchema.day(save, 86400 + 3600)).to.equal(0)
		end)

		it("resets the spa and keeps what the player owns on a Grand Reopening", function()
			local save = SaveSchema.template(1)
			save.coins = 500
			save.stars = 40
			save.stations.Tub2 = true
			save.workers.Jo = { mode = "first", level = 3, hiredAt = 1 }
			save.index.Tux = { washed = true, resident = false }
			table.insert(save.pets, { id = 1, kind = "Pip", star = 1, slot = "Jo1" })
			table.insert(save.pets, { id = 2, kind = "Bun", star = 1, slot = "player" })
			save.crates.normal = 2
			SaveSchema.reopen(save, 2)
			expect(save.coins).to.equal(0)
			expect(save.stars).to.equal(0)
			expect(save.stations.Tub2).to.equal(nil)
			expect(save.workers.Jo).to.equal(nil)
			expect(save.index.Tux.washed).to.equal(true)
			expect(save.pets[1].slot).to.equal(nil) -- back to the pen: its worker is gone
			expect(save.pets[2].slot).to.equal("player")
			expect(save.crates.normal).to.equal(2)
			expect(save.reopens).to.equal(1)
		end)
	end)
end
