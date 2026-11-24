--!strict
-- IndexWindowController: feeds the Cat Index window (UI/CatIndex, switch catIndexWindow, #238) from IndexController's
-- stamps and the star tier the server mirrors onto the player. New! marks the cats washed for the first time since
-- the window last closed, for this session only (the first index the server sends at join marks nothing). It only
-- shows things; it fires no remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local IndexRules = require(Shared:WaitForChild("IndexRules"))
local IndexViewRules = require(Shared:WaitForChild("IndexViewRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local IndexWindowController = {}

local index: any = nil
local last: { [string]: IndexRules.Entry }? = nil
local newCats: { [string]: boolean } = {}

local function tier(): number
	return CatRules.cleanTier(Players.LocalPlayer:GetAttribute(CatRules.TIER_ATTRIBUTE))
end

local function show()
	local entries: { [string]: IndexRules.Entry } = if index then index.entries else {}
	UI.setIndex(entries, newCats, tier())
end

function IndexWindowController.Init(controllers: { [string]: any })
	index = controllers.IndexController
end

function IndexWindowController.Start()
	if index then
		index.changed:Connect(function()
			local now: { [string]: IndexRules.Entry } = index.entries
			local before = last
			if before ~= nil then
				for _, cat in IndexViewRules.newlyWashed(before, now) do
					newCats[cat] = true
				end
			end
			last = table.clone(now)
			show()
		end)
	end
	UI.onIndexClosed(function()
		newCats = {}
		show()
	end)
	Players.LocalPlayer:GetAttributeChangedSignal(CatRules.TIER_ATTRIBUTE):Connect(show)
	show()
end

return IndexWindowController
