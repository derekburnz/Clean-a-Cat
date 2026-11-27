--!strict
return function()
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags)
	local WashSidesRules = require(game:GetService("ReplicatedStorage").Shared.WashSidesRules)

	describe("WashSidesRules (washSides, issue 899)", function()
		it("ships behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, WashSidesRules.FLAG)).to.be.ok()
			expect(LiveFlags.OFF_BY_DEFAULT[WashSidesRules.FLAG]).to.equal(true)
		end)

		it("turns the scrub, the lather and the rinse once, half way", function()
			for _, step in { "scrub", "lather", "rinse" } do
				expect(WashSidesRules.due(step, 0.49, {})).to.equal(false)
				expect(WashSidesRules.due(step, 0.5, {})).to.equal(true)
				expect(WashSidesRules.due(step, 0.8, { [step] = true })).to.equal(false)
				expect(WashSidesRules.due(step, 1, {})).to.equal(false) -- a full bar shakes off instead
			end
			for _, step in { "brush", "claws" } do
				expect(WashSidesRules.due(step, 0.6, {})).to.equal(false)
			end
			expect(WashSidesRules.due(nil, 0.6, {})).to.equal(false)
			expect(WashSidesRules.due("scrub", 0 / 0, {})).to.equal(false)
		end)

		it("brings the hidden rest round to the camera", function()
			local toCamera = Vector3.new(0, 1, 5) -- the camera in front, on +Z
			-- what is left sits on his back (-Z): about half a turn
			local yaw = WashSidesRules.yawFor(
				"scrub",
				{ Vector3.new(0, 0.5, -1), Vector3.new(0.2, 0.4, -1) },
				toCamera
			)
			expect(yaw).to.be.ok()
			expect(math.abs(math.abs(yaw :: number) - math.pi) < 0.25).to.equal(true)
			-- what is left already faces the camera: no turn
			expect(WashSidesRules.yawFor("rinse", { Vector3.new(0, 0.5, 1) }, toCamera)).to.equal(
				nil
			)
			expect(WashSidesRules.yawFor("rinse", {}, toCamera)).to.equal(nil)
			-- the lather turns a quarter
			expect(WashSidesRules.yawFor("lather", {}, toCamera)).to.equal(
				WashSidesRules.LATHER_TURN
			)
		end)
	end)
end
