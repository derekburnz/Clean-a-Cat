--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Audio = Client:WaitForChild("Audio")
	local CueRules = require(Audio:WaitForChild("CueRules")) :: any
	local Cues = require(Audio:WaitForChild("Cues")) :: any

	describe("the cue table", function()
		it("has no problems", function()
			expect(#CueRules.validate(Cues)).to.equal(0)
		end)
	end)

	describe("CueRules.validate", function()
		it("flags a bad id, a bad group and a bad pitch", function()
			local problems = CueRules.validate({
				a = { ids = { "1234" }, group = "Sfx", volume = 0.5 },
				b = { ids = {}, group = "Loud", volume = 0.5 },
				c = { ids = {}, group = "Sfx", volume = 0.5, pitch = { 1.2, 1.0 } },
			})
			expect(#problems).to.equal(3)
		end)

		it("flags more than ten preloads", function()
			local cues = {}
			for i = 1, 11 do
				cues[`c{i}`] = { ids = {}, group = "Sfx", volume = 0.5, preload = true }
			end
			expect(#CueRules.validate(cues)).to.equal(1)
		end)
	end)

	describe("CueRules.canPlay", function()
		it("drops plays inside minGap", function()
			expect(CueRules.canPlay(nil, 5, 0.1)).to.equal(true)
			expect(CueRules.canPlay(5, 5.05, 0.1)).to.equal(false)
			expect(CueRules.canPlay(5, 5.2, 0.1)).to.equal(true)
			expect(CueRules.canPlay(5, 5, nil)).to.equal(true)
		end)
	end)

	describe("CueRules.pickId", function()
		local cue = {
			ids = { "rbxassetid://1", "rbxassetid://2", "rbxassetid://3" },
			group = "Sfx",
			volume = 0.5,
		}

		it("is silent with no ids", function()
			expect(CueRules.pickId({ ids = {}, group = "Sfx", volume = 0.5 }, 0.5, nil)).to.equal(
				nil
			)
		end)

		it("uses the variant when it exists", function()
			expect(CueRules.pickId(cue, 0, 2)).to.equal("rbxassetid://2")
			expect(CueRules.pickId(cue, 0, 9)).to.equal("rbxassetid://1")
		end)

		it("keeps a roll of 1 inside the list", function()
			expect(CueRules.pickId(cue, 1, nil)).to.equal("rbxassetid://3")
		end)
	end)

	describe("pitch helpers", function()
		it("keeps the random pitch inside the range", function()
			local cue = { ids = {}, group = "Sfx", volume = 0.5, pitch = { 0.9, 1.1 } }
			expect(CueRules.pitchFor(cue, 0)).to.be.near(0.9, 1e-9)
			expect(CueRules.pitchFor(cue, 2)).to.be.near(1.1, 1e-9)
			expect(CueRules.pitchFor({ ids = {}, group = "Sfx", volume = 0.5 }, 0.3)).to.equal(1)
		end)

		it("raises the mud plop and caps it", function()
			expect(CueRules.mudPlopPitch(0)).to.be.near(0.9, 1e-9)
			expect(CueRules.mudPlopPitch(5)).to.be.near(1.0, 1e-9)
			expect(CueRules.mudPlopPitch(100)).to.be.near(1.3, 1e-9)
		end)

		it("maps drag speed to the sponge loop speed", function()
			expect(CueRules.scrubLoopSpeed(0)).to.be.near(0.9, 1e-9)
			expect(CueRules.scrubLoopSpeed(5000)).to.be.near(1.15, 1e-9)
		end)
	end)

	describe("CueRules.nextVoice and nextTrack", function()
		it("cycles voices", function()
			expect(CueRules.nextVoice(0, 3)).to.equal(1)
			expect(CueRules.nextVoice(3, 3)).to.equal(1)
			expect(CueRules.nextVoice(1, 1)).to.equal(1)
		end)

		it("alternates only tracks that have files", function()
			local has = function(name: string): boolean
				return name ~= "c"
			end
			expect(CueRules.nextTrack({ "a", "b", "c" }, nil, has)).to.equal("a")
			expect(CueRules.nextTrack({ "a", "b", "c" }, "a", has)).to.equal("b")
			expect(CueRules.nextTrack({ "a", "b", "c" }, "b", has)).to.equal("a")
			expect(CueRules.nextTrack({ "c" }, nil, has)).to.equal(nil)
		end)
	end)
end
