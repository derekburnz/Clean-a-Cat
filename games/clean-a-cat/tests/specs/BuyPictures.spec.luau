--!strict
-- Issue 1122 (Derek 2026-11-27: buyable items sharing one icon): every thing a player can buy draws its own picture.
-- Two different items may never resolve to one image id; the same item (a pass on its Shop card and in the starter
-- pack) keeps one picture everywhere.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Icons =
		require(Client:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons")) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BowRules = require(Shared:WaitForChild("BowRules")) :: any
	local BuildRules = require(Shared:WaitForChild("BuildRules")) :: any
	local BuildViewRules = require(Shared:WaitForChild("BuildViewRules")) :: any
	local Passes = require(Shared:WaitForChild("Passes")) :: any
	local ShopViewRules = require(Shared:WaitForChild("ShopViewRules")) :: any
	local StarterViewRules = require(Shared:WaitForChild("StarterViewRules")) :: any
	local ToolRules = require(Shared:WaitForChild("ToolRules")) :: any

	local function allOn(_flag: string): boolean
		return true
	end
	local function allOff(_flag: string): boolean
		return false
	end
	local function anyPrice(_key: string): number
		return 100
	end

	describe("pictures of things to buy (issue 1122)", function()
		it("gives every build, tool, paid bow, pass and starter item its own image", function()
			local imageOf: { [string]: string } = {} -- item -> image id
			local itemOf: { [string]: string } = {} -- image id -> item
			local problems: { string } = {}
			local function claim(item: string, iconName: string)
				local image = Icons.IMAGES[iconName]
				if type(image) ~= "string" or image == "" then
					table.insert(problems, `{item} has no picture ({iconName})`)
					return
				end
				local had = imageOf[item]
				if had ~= nil and had ~= image then
					table.insert(problems, `{item} draws two pictures`)
				end
				imageOf[item] = image
				local other = itemOf[image]
				if other ~= nil and other ~= item then
					table.insert(problems, `{item} and {other} share {image}`)
				end
				itemOf[image] = item
			end
			for id in BuildRules.ITEMS do
				claim(`build {id}`, BuildViewRules.buildIcon(id))
			end
			for id in ToolRules.TOOLS do
				claim(`tool {id}`, BuildViewRules.toolIcon(id))
			end
			for _, tier in BowRules.TIERS do
				if tier ~= BowRules.FIRST then -- the free first bow is not bought
					claim(`bow {tier}`, BuildViewRules.bowIcon(tier))
				end
			end
			-- the Shop's cards: with nothing owned, then with 2x owned (3x takes its place)
			for _, owned in { {}, { DoubleCoins = true } } do
				local cards = ShopViewRules.cards(anyPrice, function(key: string): boolean
					return (owned :: any)[key] == true
				end, allOn)
				for _, card in cards do
					claim(`pass {card.key}`, card.icon)
				end
			end
			for _, key in Passes.KEYS do
				expect(imageOf[`pass {key}`] ~= nil).to.equal(true)
			end
			-- the starter pack's items, with and without the Second Builder swap
			local switchSets: { (string) -> boolean } = { allOn, allOff }
			for _, isOn in switchSets do
				for _, item in StarterViewRules.items(anyPrice, isOn) do
					claim(`pass {item.key}`, item.icon)
				end
			end
			table.sort(problems)
			expect(table.concat(problems, "; ")).to.equal("")
		end)
	end)
end
