--!strict
return function()
	local ToastRules = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ToastRules")
	)

	describe("ToastRules", function()
		it("ships behind its switch, off by default", function()
			local LiveFlags = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("LiveFlags")
			)
			expect(LiveFlags.OFF_BY_DEFAULT[ToastRules.FLAG]).to.equal(true)
		end)

		it("colours a notice by what it says", function()
			expect(ToastRules.lookOf("+12 coins", "info")).to.equal("reward")
			expect(ToastRules.lookOf("The Silk bow is yours", nil)).to.equal("reward")
			expect(ToastRules.lookOf("Second Tub is ready!", nil)).to.equal("reward")
			expect(ToastRules.lookOf("859 more coins to hire Sam", nil)).to.equal("warning")
			expect(ToastRules.lookOf("Can't build that yet", nil)).to.equal("warning")
			expect(ToastRules.lookOf("Anything", "warning")).to.equal("warning")
			expect(ToastRules.lookOf("Mochi is here! Only you can wash their cat", nil)).to.equal(
				"news"
			)
		end)
		it("finds a picture for every reward notice (issue 1024)", function()
			local faces: { [string]: boolean } =
				{ Clover = true, Starcoat = true, Ginger = true, Suds = true, Mochi = true }
			local function isPortrait(name: string): boolean
				return faces[name] == true
			end
			local function pic(text: string, icon: string?): string
				local p = ToastRules.pictureOf(text, icon, isPortrait)
				return if p then `{p.kind}:{p.name}` else "none"
			end
			expect(pic("You got Clover! Common, +5% on your tips")).to.equal("portrait:Clover")
			expect(pic("A crate is yours! Tap it to open")).to.equal("icon:Crate")
			expect(pic("3 crates are yours! Tap one to open")).to.equal("icon:Crate")
			expect(pic("Ginger left you a crate!")).to.equal("icon:Crate")
			expect(pic("Your gift crate is here! Thank you for joining us")).to.equal("icon:Crate")
			expect(pic("Starcoat is yours! Thank you for joining us")).to.equal("portrait:Starcoat")
			expect(pic("Day 3: 120 coins!")).to.equal("icon:Gift")
			expect(pic("The Silk bow is yours")).to.equal("icon:Bow")
			expect(pic("+40 coins")).to.equal("icon:Coins")
			expect(pic("Clover is star 2")).to.equal("portrait:Clover")
			expect(pic("You washed Suds!")).to.equal("portrait:Suds")
			expect(pic("Sam works here now")).to.equal("icon:Helper")
			expect(pic("Second Tub is ready!")).to.equal("icon:Build")
			expect(pic("Mochi is here! Only you can wash their cat", "Mochi")).to.equal(
				"portrait:Mochi"
			)
		end)

		it("makes the big popup only for rewards worth stopping for", function()
			local pet = ToastRules.popOf("You got Clover! Common, +5% on your tips", nil)
			expect(pet and pet.title).to.equal("You got Clover!")
			expect(pet and pet.sub).to.equal("Common, +5% on your tips")
			local crate = ToastRules.popOf("A crate is yours! Tap it to open", nil)
			expect(crate and crate.title).to.equal("A crate is yours!")
			local day = ToastRules.popOf("Day 3: 120 coins!", nil)
			expect(day and day.title).to.equal("Day 3:")
			expect(day and day.sub).to.equal("120 coins!")
			local bow = ToastRules.popOf("The Silk bow is yours", nil)
			expect(bow and bow.title).to.equal("The Silk bow is yours")
			expect(bow and bow.sub).to.equal("")
			expect(ToastRules.popOf("Clover is star 2", nil) ~= nil).to.equal(true)
			expect(ToastRules.popOf("+40 coins", nil)).to.equal(nil)
			expect(ToastRules.popOf("Second Tub is ready!", nil)).to.equal(nil)
			expect(ToastRules.popOf("No crate to open", "warning")).to.equal(nil)
			expect(ToastRules.popOf("Join the group to get Starcoat", "warning")).to.equal(nil)
			local LiveFlags = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("LiveFlags")
			)
			expect(LiveFlags.OFF_BY_DEFAULT[ToastRules.POP_FLAG]).to.equal(true)
		end)
	end)
end
