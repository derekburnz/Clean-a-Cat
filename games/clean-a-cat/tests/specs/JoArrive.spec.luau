--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local JoArrive = require(Client:WaitForChild("Effects"):WaitForChild("JoArrive")) :: any

	local path = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 10), Vector3.new(5, 0, 10) }

	describe("JoArrive.along", function()
		it("walks the path leg by leg and faces the way of each leg", function()
			expect(JoArrive.length(path)).to.equal(15)
			local at, way = JoArrive.along(path, 4)
			expect((at - Vector3.new(0, 0, 4)).Magnitude < 1e-6).to.equal(true)
			expect((way - Vector3.new(0, 0, 1)).Magnitude < 1e-6).to.equal(true)
			local turned, way2 = JoArrive.along(path, 12)
			expect((turned - Vector3.new(2, 0, 10)).Magnitude < 1e-6).to.equal(true)
			expect((way2 - Vector3.new(1, 0, 0)).Magnitude < 1e-6).to.equal(true)
		end)
		it("stops at the end and never walks back past the start", function()
			local finish = JoArrive.along(path, 99)
			expect((finish - Vector3.new(5, 0, 10)).Magnitude < 1e-6).to.equal(true)
			local start = JoArrive.along(path, -3)
			expect(start.Magnitude < 1e-6).to.equal(true)
		end)
	end)

	describe("JoArrive.blend", function()
		it("eases the camera over, holds, and hands it back", function()
			expect(JoArrive.blend(0, 3)).to.equal(0)
			expect(JoArrive.blend(1.5, 3)).to.equal(1)
			expect(JoArrive.blend(3, 3)).to.equal(0)
			local early = JoArrive.blend(JoArrive.EASE / 2, 3)
			expect(early > 0 and early < 1).to.equal(true)
		end)
	end)
end
