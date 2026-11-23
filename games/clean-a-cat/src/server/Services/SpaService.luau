--!strict
-- SpaService: one cat's visit per player, server authoritative. It hands out a cat, checks each step the client
-- reports (scrub, brush strokes, bow, photo) against SpaRules and pays the photo coins once, into the save.
-- The client only reports what the player did; it never says how many coins. Behind `scrubPrototype`.
-- Cats live in memory only: a rejoin starts a fresh cat. Coins are saved through DataService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))

local FLAG = "scrubPrototype"
local MAX_CAT_ID = 2 ^ 31

local SpaService = {}

local cats: { [Player]: SpaRules.Cat } = {}
local nextId: { [Player]: number } = {}

local function newCat(player: Player): SpaRules.Cat
	local id = (nextId[player] or 0) + 1
	nextId[player] = id
	local cat = SpaRules.newCat(id, os.clock())
	cats[player] = cat
	return cat
end

-- The player's current cat when `rawId` names it and the switch is on; nil otherwise.
local function currentCat(player: Player, rawId: unknown): SpaRules.Cat?
	if not LiveFlags.isOn(FLAG) then
		return nil
	end
	local id = Guard.int(rawId, 1, MAX_CAT_ID)
	local cat = cats[player]
	if id == nil or cat == nil or cat.id ~= id then
		return nil
	end
	return cat
end

local function onRequestCat(player: Player)
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local cat = cats[player]
	-- A dirty cat is resent (the client may have missed it); any other cat is replaced by a fresh dirty one.
	-- Starting over never pays: the photo still needs MIN_VISIT_SECONDS from the new cat's arrival.
	if cat == nil or cat.stage ~= "dirty" then
		cat = newCat(player)
	end
	NetService.fire(player, "CatReady", (cat :: SpaRules.Cat).id)
end

local function onScrubbed(player: Player, rawId: unknown)
	local cat = currentCat(player, rawId)
	if cat then
		SpaRules.scrubbed(cat)
	end
end

local function onBrushStroke(player: Player, rawId: unknown)
	local cat = currentCat(player, rawId)
	if cat then
		SpaRules.brushStroke(cat, os.clock())
	end
end

local function onPickBow(player: Player, rawId: unknown, rawBow: unknown)
	local cat = currentCat(player, rawId)
	local bow = Guard.oneOf(rawBow, SpaRules.BOWS)
	if cat and bow then
		SpaRules.pickBow(cat, bow)
	end
end

local function onPhoto(player: Player, rawId: unknown)
	local cat = currentCat(player, rawId)
	if not cat then
		return
	end
	-- Pay only into a loaded save; with no save yet the cat stays styled and the player can tap again.
	local save = DataService.get(player)
	if save == nil or cat.stage ~= "styled" then
		return
	end
	local coins = SpaRules.photo(cat, os.clock())
	if coins <= 0 then
		return
	end
	save.coins += coins
	NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
	NetService.notice(player, `+{coins} coins`)
end

function SpaService.Init(_services: { [string]: any }) end

function SpaService.Start()
	NetService.on("RequestCat", { perSecond = 1, burst = 2 }, onRequestCat)
	NetService.on("ReportScrubbed", { perSecond = 2 }, onScrubbed)
	NetService.on("ReportBrushStroke", { perSecond = 8 }, onBrushStroke)
	NetService.on("RequestPickBow", { perSecond = 2 }, onPickBow)
	NetService.on("RequestPhoto", { perSecond = 2 }, onPhoto)

	-- Switch turned off: drop every cat, so turning it on again starts clean.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(function()
			if not LiveFlags.isOn(FLAG) then
				table.clear(cats)
			end
		end)
	Players.PlayerRemoving:Connect(function(player: Player)
		cats[player] = nil
		nextId[player] = nil
	end)
end

return SpaService
