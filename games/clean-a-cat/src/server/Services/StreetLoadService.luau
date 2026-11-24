--!strict
-- StreetLoadService: a test aid for the low-end phone frame check (#40). It fills every street plot that has no
-- player with a full plot's worth of server-drawn models, so one tester on a phone sees a full street:
-- - a door line of MAX_SHOWN customers holding the heaviest dirty cats (the most parts, counted from
--   ReplicatedStorage.Assets),
-- - every station built,
-- - the builder kitten, and the VIP door as a building site.
-- A slot a player joins is redrawn as theirs by their own services. A slot a player leaves is filled again.
-- These are only models: there are no saves, no remotes and no pay.
-- Needs the street placed (switch spaPlot). Behind the LiveFlags switch `streetLoadTest`, off by default, and
-- only ever turned on in the dev place for a frame check, never in the live game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local CatRules = require(Shared:WaitForChild("CatRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FigureService = require(script.Parent:WaitForChild("FigureService"))
local StationService = require(script.Parent:WaitForChild("StationService"))

local FLAG = "streetLoadTest"
local LINE_LENGTH = 3 -- FigureService shows three customers, one on each queue mat
local VIP_BUILD_SECONDS = 3600 -- the VIP door shows as a building site for this long once filled

local StreetLoadService = {}

local filled: { [number]: boolean } = {}

local function owner(slot: number): Player?
	for _, player in Players:GetPlayers() do
		if SpaLayout.slotOf(player) == slot then
			return player
		end
	end
	return nil
end

local function partCount(model: Instance): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- The LINE_LENGTH cat kinds whose dirty model has the most parts, heaviest first.
local function heaviestKinds(): { string }
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local counted: { { kind: string, parts: number } } = {}
	for _, names in CatRules.ROSTER do
		for _, kind in names do
			local model = if assets
				then assets:FindFirstChild(`CleanACat_Cat_{kind}_Dirty`)
				else nil
			if model then
				table.insert(counted, { kind = kind, parts = partCount(model) })
			end
		end
	end
	table.sort(
		counted,
		function(a: { kind: string, parts: number }, b: { kind: string, parts: number }): boolean
			return a.parts > b.parts
		end
	)
	local kinds: { string } = {}
	for index = 1, math.min(LINE_LENGTH, #counted) do
		table.insert(kinds, counted[index].kind)
	end
	return kinds
end

local function fill(slot: number)
	if owner(slot) ~= nil or SpaLayout.plotModel(slot) == nil then
		return
	end
	filled[slot] = true
	local stations: { [string]: boolean } = {}
	for _, entry in SpaLayout.STATIONS do
		stations[entry.id] = true
	end
	local vip = BuildRules.ITEMS[SpaLayout.VIP_ID]
	local builds =
		{ [vip.slot] = { item = SpaLayout.VIP_ID, endsAt = os.time() + VIP_BUILD_SECONDS } }
	StationService.drawSlot(slot, stations, builds)
	FigureService.drawSlot(slot, heaviestKinds())
end

local function empty(slot: number)
	if not filled[slot] then
		return
	end
	filled[slot] = nil
	if owner(slot) == nil then
		StationService.clearSlot(slot)
		FigureService.clearSlot(slot)
	end
end

local function refresh()
	local on = LiveFlags.isOn(FLAG)
		and ReplicatedStorage:GetAttribute(SpaLayout.PLACED_ATTRIBUTE) == true
	for slot = 1, SpaLayout.PLOT_COUNT do
		if on then
			if not filled[slot] then
				task.spawn(fill, slot)
			end
		else
			empty(slot)
		end
	end
end

function StreetLoadService.Init(_services: { [string]: any }) end

function StreetLoadService.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(function()
		-- The street was placed again (or taken away): its plots are new models, so every slot is drawn afresh.
		table.clear(filled)
		refresh()
	end)
	local function watch(player: Player)
		player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(function()
			-- A player took a slot: their own services draw it from now on. StationService redraws its stations on
			-- this same change; the stand-in door line goes, and SpaService sends the player's own when it starts.
			for slot in filled do
				if owner(slot) ~= nil then
					filled[slot] = nil
					FigureService.clearSlot(slot)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local slot = SpaLayout.slotOf(player)
		if slot ~= nil and LiveFlags.isOn(FLAG) then
			-- Fill it again once its owner's services have cleared it.
			task.delay(1, function()
				if owner(slot) == nil then
					filled[slot] = nil
					refresh()
				end
			end)
		end
	end)
	refresh()
end

return StreetLoadService
