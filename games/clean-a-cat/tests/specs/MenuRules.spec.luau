--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local MenuRules = require(Shared:WaitForChild("MenuRules"))

local function only(...: string): (flag: string) -> boolean
	local on: { [string]: boolean } = {}
	for _, flag in { ... } do
		on[flag] = true
	end
	return function(flag: string): boolean
		return on[flag] == true
	end
end

return function()
	describe("MenuRules", function()
		it("is off by default and each part needs its window", function()
			expect(LiveFlags.OFF_BY_DEFAULT[MenuRules.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, MenuRules.FLAG) ~= nil).to.equal(true)
			local none = only()
			expect(MenuRules.helpers(none)).to.equal(false)
			expect(MenuRules.build(none)).to.equal(false)
			expect(MenuRules.queue(none)).to.equal(false)
			local switchOnly = only("menuOnly")
			expect(MenuRules.helpers(switchOnly)).to.equal(false)
			expect(MenuRules.build(switchOnly)).to.equal(false)
			expect(MenuRules.queue(switchOnly)).to.equal(false)
			local all = only("menuOnly", "helpersWindow", "buildWindow", "queueWindow")
			expect(MenuRules.helpers(all)).to.equal(true)
			expect(MenuRules.build(all)).to.equal(true)
			expect(MenuRules.queue(all)).to.equal(true)
			local windowsOnly = only("helpersWindow", "buildWindow", "queueWindow")
			expect(MenuRules.helpers(windowsOnly)).to.equal(false)
		end)

		it("sends a guide card to its window only when that part is on", function()
			local helpers = only("menuOnly", "helpersWindow")
			expect(MenuRules.windowFor("hireJo", helpers)).to.equal("Helpers")
			expect(MenuRules.windowFor("build", helpers)).to.equal(nil)
			local build = only("menuOnly", "buildWindow")
			expect(MenuRules.windowFor("build", build)).to.equal("Build")
			expect(MenuRules.windowFor("newSoap", build)).to.equal("Build")
			expect(MenuRules.windowFor("hireJo", build)).to.equal(nil)
			-- the cards about the tub, the line and the crate keep their trail
			local all = only("menuOnly", "helpersWindow", "buildWindow", "queueWindow")
			expect(MenuRules.windowFor("firstCustomer", all)).to.equal(nil)
			expect(MenuRules.windowFor("special", all)).to.equal(nil)
			expect(MenuRules.windowFor("crate", all)).to.equal(nil)
			expect(MenuRules.windowFor("hireJo", only("helpersWindow"))).to.equal(nil)
		end)
	end)
end
