--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheckinRules = require(Shared:WaitForChild("CheckinRules"))
local LeaveLineRules = require(Shared:WaitForChild("LeaveLineRules"))

local function state(over: { [string]: any }): LeaveLineRules.State
	local s: { [string]: any } =
		{ helpers = false, jar = false, checkin = false, ready = nil, days = 0 }
	for key, value in over do
		s[key] = value
	end
	return (s :: any) :: LeaveLineRules.State
end

return function()
	describe("LeaveLineRules", function()
		it("says nothing that is not true", function()
			expect(LeaveLineRules.top(state({}))).to.equal(nil)
			expect(LeaveLineRules.bottom(state({}))).to.equal(nil)
			expect(LeaveLineRules.top(state({ helpers = true }))).to.equal(nil)
			expect(LeaveLineRules.top(state({ jar = true }))).to.equal(nil)
			expect(LeaveLineRules.bottom(state({ checkin = true, days = 0 }))).to.equal(nil)
		end)

		it("tells about the tip jar only with a helper hired and the jar on", function()
			expect(LeaveLineRules.top(state({ helpers = true, jar = true }))).to.equal(
				"Your helpers fill the tip jar while you're away!"
			)
		end)

		it("names tomorrow's check in gift, or the one waiting now", function()
			expect(LeaveLineRules.bottom(state({ checkin = true, days = 1 }))).to.equal(
				`Come back tomorrow for day 2: {CheckinRules.REWARDS[2].text}!`
			)
			expect(LeaveLineRules.bottom(state({ checkin = true, days = 7 }))).to.equal(
				`Come back tomorrow for day 1: {CheckinRules.REWARDS[1].text}!`
			)
			expect(LeaveLineRules.bottom(state({ checkin = true, ready = 3, days = 2 }))).to.equal(
				"Your check in gift is waiting in Gifts!"
			)
		end)

		it("never hurries or blames", function()
			local lines: { string? } = {
				LeaveLineRules.top(state({ helpers = true, jar = true })),
				LeaveLineRules.bottom(state({ checkin = true, days = 3 })),
				LeaveLineRules.bottom(state({ checkin = true, ready = 1, days = 0 })),
			}
			for index = 1, 3 do
				local text: string = lines[index] or ""
				local lower = string.lower(text)
				for _, word in
					{ "hurry", "miss", "lose", "only", "last chance", "don't leave", "sad" }
				do
					expect(string.find(lower, word, 1, true)).to.equal(nil)
				end
			end
		end)
	end)
end
