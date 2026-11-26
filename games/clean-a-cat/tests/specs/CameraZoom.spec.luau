--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Zoom =
		require(Client:WaitForChild("Controllers"):WaitForChild("CameraZoomController")) :: any

	describe("CameraZoomController.cap", function()
		it("caps the zoom at MAX_ZOOM only while the switch is on", function()
			expect(Zoom.cap(true, 400)).to.equal(Zoom.MAX_ZOOM)
			expect(Zoom.cap(false, 400)).to.equal(400)
		end)
		it("never loosens a tighter zoom the player already had", function()
			expect(Zoom.cap(true, 20)).to.equal(20)
		end)
		it("keeps room to see the spa", function()
			expect(Zoom.MAX_ZOOM >= Zoom.MIN_ZOOM).to.equal(true)
			expect(Zoom.MAX_ZOOM >= 30).to.equal(true)
		end)
	end)
end
