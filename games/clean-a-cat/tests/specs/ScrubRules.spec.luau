--!strict
return function()
	local ScrubRules = require(game:GetService("ReplicatedStorage").Shared.ScrubRules)

	describe("ScrubRules.pieceNumber", function()
		it("reads the number at the end of a piece's name only", function()
			expect(ScrubRules.pieceNumber("CleanACat_Cat_Smudge_Dirty_Mud07", "Mud")).to.equal(7)
			expect(ScrubRules.pieceNumber("CleanACat_Cat_Tux_Dirty_Tangle12", "Tangle")).to.equal(
				12
			)
			expect(ScrubRules.pieceNumber("CleanACat_Cat_Smudge_Dirty_Mud07", "Tangle")).to.equal(
				nil
			)
			expect(ScrubRules.pieceNumber("CleanACat_Cat_Smudge_Dirty_Body", "Mud")).to.equal(nil)
			expect(ScrubRules.pieceNumber("CleanACat_Cat_Mud07_Extra", "Mud")).to.equal(nil)
		end)
	end)

	describe("ScrubRules.rub", function()
		it("clears a patch only after enough rubbing, once", function()
			local state = ScrubRules.newState(4)
			local half = ScrubRules.RUB_TO_CLEAR / 2
			expect(ScrubRules.rub(state, 1, half)).to.equal(false)
			expect(ScrubRules.rub(state, 1, half)).to.equal(true)
			expect(ScrubRules.rub(state, 1, half)).to.equal(false)
			expect(state.clearedCount).to.equal(1)
			expect(ScrubRules.patchesLeft(state)).to.equal(3)
		end)

		it("ignores bad input", function()
			local state = ScrubRules.newState(4)
			expect(ScrubRules.rub(state, 99, 10)).to.equal(false)
			expect(ScrubRules.rub(state, 1, 0 / 0)).to.equal(false)
			expect(ScrubRules.rub(state, 1, -5)).to.equal(false)
			expect(state.rub[1]).to.equal(0)
		end)

		it("counts at most one step's worth from a single jump", function()
			local state = ScrubRules.newState(4)
			ScrubRules.rub(state, 1, 1000)
			expect(state.rub[1]).to.equal(math.min(1000, ScrubRules.MAX_RUB_PER_STEP))
		end)
	end)

	describe("ScrubRules reveal", function()
		it("reveals at the threshold and pops the rest off", function()
			local state = ScrubRules.newState(10)
			local needed = math.ceil(10 * ScrubRules.REVEAL_FRACTION)
			for index = 1, needed - 1 do
				ScrubRules.rub(state, index, ScrubRules.RUB_TO_CLEAR)
			end
			expect(ScrubRules.shouldReveal(state)).to.equal(false)
			ScrubRules.rub(state, needed, ScrubRules.RUB_TO_CLEAR)
			expect(ScrubRules.shouldReveal(state)).to.equal(true)

			local rest = ScrubRules.reveal(state)
			expect(#rest).to.equal(10 - needed)
			expect(state.revealed).to.equal(true)
			expect(ScrubRules.patchesLeft(state)).to.equal(0)
			expect(ScrubRules.shouldReveal(state)).to.equal(false)
			expect(ScrubRules.rub(state, 10, ScrubRules.RUB_TO_CLEAR)).to.equal(false)
		end)
	end)
end
