--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CustomerLeave =
		require(Client:WaitForChild("Effects"):WaitForChild("CustomerLeave")) :: any

	describe("CustomerLeave.at", function()
		it("turns a quarter, walks off and fades out by the end", function()
			local turn, walked, seen = CustomerLeave.at(0)
			expect(turn).to.equal(0)
			expect(walked).to.equal(0)
			expect(seen).to.equal(0)
			turn = CustomerLeave.at(CustomerLeave.TURN_SECONDS)
			expect(turn).to.equal(1)
			local _, w, s = CustomerLeave.at(CustomerLeave.LEAVE_SECONDS)
			expect(s).to.equal(1)
			expect(w > 5).to.equal(true)
		end)
		it("stays fully seen until the fade starts and walks at a steady pace", function()
			local fadeFrom = CustomerLeave.LEAVE_SECONDS - CustomerLeave.FADE_SECONDS
			local _, _, s = CustomerLeave.at(fadeFrom - 0.01)
			expect(s).to.equal(0)
			local _, a = CustomerLeave.at(1)
			local _, b = CustomerLeave.at(1.5)
			expect(math.abs((b - a) - CustomerLeave.WALK_SPEED * 0.5) < 1e-6).to.equal(true)
		end)
		it(
			"sets off at once and is a body's width clear of the spot in about half a second (#570)",
			function()
				local _, early = CustomerLeave.at(0.15)
				expect(early > 0).to.equal(true)
				local _, clear = CustomerLeave.at(0.6)
				expect(clear > 1.2).to.equal(true)
				local last = 0
				for i = 1, 100 do
					local _, w = CustomerLeave.at(i * CustomerLeave.LEAVE_SECONDS / 100)
					expect(w >= last).to.equal(true)
					last = w
				end
			end
		)
		it("turns a quarter to one side, never round and back down the line", function()
			expect(math.abs(CustomerLeave.SIDE)).to.equal(1)
		end)
	end)
end
