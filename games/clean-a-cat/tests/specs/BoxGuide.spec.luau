--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local BoxGuide =
		require(Client:WaitForChild("Controllers"):WaitForChild("BoxGuideController")) :: any
	local TrailLine = require(Client:WaitForChild("Effects"):WaitForChild("TrailLine")) :: any

	describe("BoxGuideController.want", function()
		it("shows only past FAR and hides only back within NEAR", function()
			expect(BoxGuide.want(false, BoxGuide.FAR - 1)).to.equal(false)
			expect(BoxGuide.want(false, BoxGuide.FAR + 1)).to.equal(true)
			-- in between, it keeps what it was: no flicker at the edge
			local between = (BoxGuide.FAR + BoxGuide.NEAR) / 2
			expect(BoxGuide.want(true, between)).to.equal(true)
			expect(BoxGuide.want(false, between)).to.equal(false)
			expect(BoxGuide.want(true, BoxGuide.NEAR - 1)).to.equal(false)
			expect(BoxGuide.NEAR < BoxGuide.FAR).to.equal(true)
		end)
	end)

	describe("PillPointerController", function()
		local Pointer =
			require(Client:WaitForChild("Controllers"):WaitForChild("PillPointerController")) :: any
		it("lines the pointer gui's lower part up with the pill", function()
			-- pill 44 px at step 0; arrow 40 px: the middle is 20 px above the pill's middle
			local y = Pointer.offsetY(0, 44, 40)
			expect(math.abs(y * (44 + 40) - 20) < 1e-6).to.equal(true)
			-- a stepped pill (PillStep 1) moves its pointer with it
			local stepped = Pointer.offsetY(1, 44, 40)
			expect(math.abs(stepped * (44 + 40) - (44 + 20)) < 1e-6).to.equal(true)
		end)
		it("bobs a few px and rests at 0", function()
			expect(Pointer.bob(0)).to.equal(0)
			for i = 0, 40 do
				local b = Pointer.bob(i * 0.05)
				expect(b >= 0 and b <= Pointer.BOB).to.equal(true)
			end
		end)
	end)

	describe("TrailLine.LOOK_BOLD", function()
		it("keeps the arrow length and dash spacing, so the layout holds for both looks", function()
			local a, b = TrailLine.LOOK, TrailLine.LOOK_BOLD
			expect(b.arrowLength).to.equal(a.arrowLength)
			expect(b.dashGap).to.equal(a.dashGap)
			expect(b.dashLength).to.equal(a.dashLength)
		end)
		it("is less see-through than the first look", function()
			expect(TrailLine.LOOK_BOLD.fillSeen < TrailLine.LOOK.fillSeen).to.equal(true)
			expect(TrailLine.LOOK_BOLD.edgeSeen < TrailLine.LOOK.edgeSeen).to.equal(true)
		end)
	end)
end
