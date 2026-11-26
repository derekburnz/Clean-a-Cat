--!strict
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BuildViewRules = require(Shared:WaitForChild("BuildViewRules"))

	local function flags(on: { string }): (string) -> boolean
		return function(name: string): boolean
			return table.find(on, name) ~= nil
		end
	end
	local TUBS = flags({ "builds", "toolsBoard", "bowTiers", "tubBuilds", "dirtLevels" })

	local function find(rows: { BuildViewRules.Row }, id: string): BuildViewRules.Row
		for _, row in rows do
			if row.id == id then
				return row
			end
		end
		error("no row " .. id)
	end

	describe("BuildViewRules.time", function()
		it("gives the two largest parts", function()
			expect(BuildViewRules.time(45)).to.equal("45s")
			expect(BuildViewRules.time(300)).to.equal("5m")
			expect(BuildViewRules.time(5400)).to.equal("1h 30m")
			expect(BuildViewRules.time(8 * 3600)).to.equal("8h")
			expect(BuildViewRules.time(26 * 3600)).to.equal("1d 2h")
		end)
	end)

	describe("BuildViewRules.builds", function()
		it("is empty without the builds switch", function()
			expect(#BuildViewRules.builds({}, {}, 0, flags({}))).to.equal(0)
		end)

		it(
			"offers a build with its price and time, and locks one that needs another first",
			function()
				local rows = BuildViewRules.builds({}, {}, 0, TUBS)
				local second = find(rows, "SecondTub")
				expect(second.state).to.equal("buy")
				expect(second.action).to.equal("Build")
				expect(second.say).to.equal("60 coins · 15s")
				local third = find(rows, "ThirdTub")
				expect(third.state).to.equal("locked")
				expect(third.say).to.equal("Build the Second Tub first")
			end
		)

		it("counts down a running build and holds the rest with one builder", function()
			local rows = BuildViewRules.builds(
				{ station = { item = "ThirdTub", endsAt = 1000 + 600 } },
				{ SecondTub = true },
				1000,
				TUBS
			)
			expect(find(rows, "SecondTub").state).to.equal("done")
			local third = find(rows, "ThirdTub")
			expect(third.state).to.equal("running")
			expect(third.say).to.equal("Ready in 10m")
			local garden = find(rows, "Garden")
			expect(garden.state).to.equal("locked")
			expect(garden.say).to.equal("Wait for the Third Tub to finish")
		end)

		it("lets the other slot start with the Second Builder", function()
			local rows = BuildViewRules.builds(
				{ station = { item = "ThirdTub", endsAt = 2000 } },
				{ SecondTub = true },
				1000,
				TUBS,
				2
			)
			expect(find(rows, "Garden").state).to.equal("buy")
		end)
	end)

	describe("BuildViewRules.upgrades", function()
		it("sells tools not owned and the next bow", function()
			local rows = BuildViewRules.upgrades(TUBS, function(): boolean
				return false
			end, "Silk")
			expect(find(rows, "BubbleSoap").action).to.equal("Buy")
			local bow = find(rows, "Satin")
			expect(bow.kind).to.equal("bow")
			expect(bow.name).to.equal("Satin bow")
		end)

		it("marks an owned tool as yours", function()
			local rows = BuildViewRules.upgrades(TUBS, function(id: string): boolean
				return id == "BubbleSoap"
			end, nil)
			expect(find(rows, "BubbleSoap").state).to.equal("done")
		end)

		it("shows the best bow as owned at the top tier", function()
			local rows = BuildViewRules.upgrades(TUBS, function(): boolean
				return false
			end, "Golden")
			expect(find(rows, "Golden").state).to.equal("done")
		end)

		it("is empty without the Tools board switch", function()
			expect(#BuildViewRules.upgrades(flags({ "bowTiers" }), function(): boolean
				return false
			end, nil)).to.equal(0)
		end)
	end)

	describe("BuildViewRules.sameShape", function()
		local function row(id: string, say: string, state: string?): BuildViewRules.Row
			return {
				kind = "build",
				id = id,
				name = id,
				say = say,
				state = state or "building",
				action = nil,
				icon = "Build",
			}
		end

		it("is true when only the words change, as a countdown ticks", function()
			expect(BuildViewRules.sameShape({ row("tub2", "5m") }, { row("tub2", "4m") })).to.equal(
				true
			)
		end)

		it("is false when a row's state, order or count changes", function()
			expect(
				BuildViewRules.sameShape({ row("tub2", "5s") }, { row("tub2", "Built", "done") })
			).to.equal(false)
			expect(
				BuildViewRules.sameShape(
					{ row("a", "1m"), row("b", "2m") },
					{ row("b", "2m"), row("a", "1m") }
				)
			).to.equal(false)
			expect(BuildViewRules.sameShape({ row("a", "1m") }, {})).to.equal(false)
		end)
	end)
end
