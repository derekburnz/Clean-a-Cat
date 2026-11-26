--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local UiSounds = require(Client:WaitForChild("Audio"):WaitForChild("UiSounds")) :: any
	local Cues = require(Client:WaitForChild("Audio"):WaitForChild("Cues")) :: any

	describe("UiSounds.pick", function()
		it("takes the first request when nothing waits", function()
			expect(UiSounds.pick(nil, "close")).to.equal("close")
		end)
		it("lets open win over close in either order", function()
			expect(UiSounds.pick("close", "open")).to.equal("open")
			expect(UiSounds.pick("open", "close")).to.equal("open")
		end)
	end)

	describe("UiSounds cues", function()
		it("names cues that exist and stay quiet", function()
			for _, cue in UiSounds.CUES do
				expect(Cues[cue]).to.be.ok()
				expect(Cues[cue].volume <= 0.3).to.equal(true)
			end
		end)
	end)
end
