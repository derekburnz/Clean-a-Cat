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
	end)
end
