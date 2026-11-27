--!strict
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Icons =
		require(Client:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons")) :: any

	describe("Icons", function()
		-- issue 1034: a picture that will not load falls back to its stand-in, so every icon needs one
		it("has a stand-in for every icon with a picture", function()
			local missing = {}
			for name in Icons.IMAGES do
				if Icons.STAND_INS[name] == nil then
					table.insert(missing, name)
				end
			end
			table.sort(missing)
			expect(table.concat(missing, ", ")).to.equal("")
		end)
	end)
end
