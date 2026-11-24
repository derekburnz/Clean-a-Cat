--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsRules"))

return function()
	describe("SettingsRules.defaults", function()
		it("starts with full volume and both comfort toggles off, as a fresh copy", function()
			local s = SettingsRules.defaults()
			expect(s.music).to.equal(1)
			expect(s.sounds).to.equal(1)
			expect(s.lessShake).to.equal(false)
			expect(s.lessSparkle).to.equal(false)
			s.music = 0
			expect(SettingsRules.DEFAULTS.music).to.equal(1)
		end)
	end)

	describe("SettingsRules.level", function()
		it("keeps a level inside 0 to 1 and reads a broken one as the default", function()
			expect(SettingsRules.level(0.4, 1)).to.equal(0.4)
			expect(SettingsRules.level(-2, 1)).to.equal(0)
			expect(SettingsRules.level(3, 1)).to.equal(1)
			expect(SettingsRules.level(0 / 0, 0.5)).to.equal(0.5)
			expect(SettingsRules.level("1", 0.5)).to.equal(0.5)
			expect(SettingsRules.level(nil, 1)).to.equal(1)
		end)
	end)

	describe("SettingsRules.fromPointer and thumbCentre", function()
		it("maps the thumb's travel to 0..1 and back", function()
			-- a 200 px track at x 100 with a 40 px thumb: the thumb's middle travels from 120 to 280
			expect(SettingsRules.fromPointer(120, 100, 200, 40)).to.equal(0)
			expect(SettingsRules.fromPointer(280, 100, 200, 40)).to.equal(1)
			expect(SettingsRules.fromPointer(200, 100, 200, 40)).to.equal(0.5)
			expect(SettingsRules.fromPointer(0, 100, 200, 40)).to.equal(0)
			expect(SettingsRules.fromPointer(999, 100, 200, 40)).to.equal(1)
			expect(SettingsRules.thumbCentre(0, 200, 40)).to.equal(20)
			expect(SettingsRules.thumbCentre(1, 200, 40)).to.equal(180)
			expect(SettingsRules.thumbCentre(0.5, 200, 40)).to.equal(100)
		end)

		it("never divides by zero on a track no wider than its thumb", function()
			expect(SettingsRules.fromPointer(50, 0, 40, 40)).to.equal(0)
			expect(SettingsRules.thumbCentre(1, 30, 40)).to.equal(20)
		end)
	end)

	describe("SettingsRules.step", function()
		it("moves up a quarter and wraps from full to 0", function()
			expect(SettingsRules.step(0)).to.equal(0.25)
			expect(SettingsRules.step(0.25)).to.equal(0.5)
			expect(SettingsRules.step(0.6)).to.equal(0.75)
			expect(SettingsRules.step(0.75)).to.equal(1)
			expect(SettingsRules.step(1)).to.equal(0)
		end)
	end)
end
