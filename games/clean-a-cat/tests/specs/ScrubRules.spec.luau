--!strict
return function()
	local ScrubRules = require(game:GetService("ReplicatedStorage").Shared.ScrubRules)

	describe("ScrubRules.patchDirections", function()
		it("gives the asked count of unit directions, capped at the maximum", function()
			local directions = ScrubRules.patchDirections(ScrubRules.PATCH_COUNT)
			expect(#directions).to.equal(ScrubRules.PATCH_COUNT)
			for _, direction in directions do
				expect(direction.Magnitude).to.be.near(1, 1e-6)
				expect(direction.Y >= -0.36).to.equal(true)
			end
			expect(#ScrubRules.patchDirections(500)).to.equal(ScrubRules.MAX_PATCHES)
		end)

		it("keeps every patch out of the cone it is told to avoid", function()
			local head = Vector3.new(0, 0.6, 0.8)
			local directions = ScrubRules.patchDirections(16, head, 0.8)
			expect(#directions).to.equal(16)
			for _, direction in directions do
				expect(direction:Dot(head) < 0.8).to.equal(true)
			end
		end)

		it("is the same every time", function()
			local a = ScrubRules.patchDirections(16)
			local b = ScrubRules.patchDirections(16)
			for index in a do
				expect(a[index] == b[index]).to.equal(true)
			end
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
