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

		-- the #1054 bug: preloading the bare id string reported Failure for every image, so every picture swapped
		local function fakeProvider(status: Enum.AssetFetchStatus)
			local seen: { any } = {}
			local provider = {}
			function provider:PreloadAsync(items: { any })
				for _, item in items do
					table.insert(seen, item)
				end
			end
			function provider:GetAssetFetchStatus(_id: string): Enum.AssetFetchStatus
				return status
			end
			return provider, seen
		end

		it("preloads the label itself and keeps a picture that loaded", function()
			local label: any = { Parent = {} } -- an ImageLabel in a window
			local provider, seen = fakeProvider(Enum.AssetFetchStatus.Success)
			expect(Icons.check(label, "rbxassetid://1", provider)).to.equal(false)
			expect(#seen).to.equal(1)
			expect(seen[1]).to.equal(label)
			expect(type(seen[1]) ~= "string").to.equal(true)
		end)

		it("swaps only when Roblox reports the fetch as Failure", function()
			local label: any = { Parent = {} } -- an ImageLabel in a window
			local bad = fakeProvider(Enum.AssetFetchStatus.Failure)
			expect(Icons.check(label, "rbxassetid://2", bad)).to.equal(true)
			local slow = fakeProvider(Enum.AssetFetchStatus.TimedOut)
			expect(Icons.check(label, "rbxassetid://3", slow)).to.equal(false)
			local loading = fakeProvider(Enum.AssetFetchStatus.Loading)
			expect(Icons.check(label, "rbxassetid://4", loading)).to.equal(false)
		end)
	end)
end
