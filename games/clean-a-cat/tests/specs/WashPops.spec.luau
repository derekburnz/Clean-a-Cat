--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local WashPops = require(Client:WaitForChild("Effects"):WaitForChild("WashPops")) :: any
	local Controller =
		require(Client:WaitForChild("Controllers"):WaitForChild("WashPopsController")) :: any

	describe("WashPops.word", function()
		it("grows past full size, settles, then fades", function()
			local s0, _, seen0 = WashPops.word(0, 1)
			expect(math.abs(s0 - 0.6) < 1e-6).to.equal(true)
			expect(seen0).to.equal(0)
			local sPeak = WashPops.word(0.12 - 1e-6, 1)
			expect(sPeak > 1.1).to.equal(true)
			local sMid, riseMid, seenMid = WashPops.word(0.5, 1)
			expect(sMid).to.equal(1)
			expect(seenMid).to.equal(1)
			expect(math.abs(riseMid - 0.5) < 1e-6).to.equal(true)
			local _, _, seenEnd = WashPops.word(1, 1)
			expect(math.abs(seenEnd) < 1e-6).to.equal(true)
		end)
	end)

	describe("WashPops.marksPassed", function()
		it("names each mark a move crosses, once", function()
			expect(#WashPops.marksPassed(0, 0.2)).to.equal(0)
			local one = WashPops.marksPassed(0.2, 0.4)
			expect(#one).to.equal(1)
			expect(one[1]).to.equal(1)
			expect(#WashPops.marksPassed(0, 1)).to.equal(2)
			expect(#WashPops.marksPassed(0.4, 0.5)).to.equal(0)
		end)
	end)

	describe("WashPops.chain", function()
		it("counts hits close together and starts again after a gap", function()
			local c = WashPops.newChain()
			expect(WashPops.chain(c, 10)).to.equal(1)
			expect(WashPops.chain(c, 10.5)).to.equal(2)
			expect(WashPops.chain(c, 11)).to.equal(3)
			expect(WashPops.chain(c, 11 + WashPops.CHAIN + 0.1)).to.equal(1)
		end)
	end)

	describe("WashPopsController.chimePitch", function()
		it("rises with the combo and stays soft", function()
			local low = Controller.chimePitch(10)
			local high = Controller.chimePitch(20)
			expect(high > low).to.equal(true)
			expect(Controller.chimePitch(200) <= 1.5).to.equal(true)
		end)
	end)

	describe("WashPops words", function()
		it("has a done word for every wash step", function()
			for _, step in { "scrub", "rinse", "claws", "brush", "bow" } do
				expect(type(WashPops.DONE_WORDS[step])).to.equal("string")
			end
		end)
	end)
end
