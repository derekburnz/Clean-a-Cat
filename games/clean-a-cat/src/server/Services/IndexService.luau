--!strict
-- IndexService: the Cat Index stamps in the save (save.index) and the full set bonus (save.indexBonusPaid).
-- SpaService stamps Washed when a cat comes back clean and WindowService stamps Resident when a stray moves in.
-- The client only shows what the server sends (CatIndex). Behind the LiveFlags switch `catIndex`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local IndexRules = require(Shared:WaitForChild("IndexRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local FLAG = "catIndex"

local IndexService = {}

local function isCat(name: string): boolean
	return CatRules.rarityOf(name) ~= nil
end

local function allCats(): { string }
	local cats = {}
	for _, rarity in CatRules.RARITIES do
		for _, name in CatRules.ROSTER[rarity] do
			table.insert(cats, name)
		end
	end
	return cats
end

-- Sends the whole index: { [cat]: { washed, resident } } for the stamped cats.
function IndexService.send(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	NetService.fire(player, "CatIndex", IndexRules.clean(save.index, isCat))
end

-- Stamps `cat` for the player. A new stamp is saved and sent; a full set of Washed stamps pays the bonus once.
-- Returns true when the stamp is new (the recap card's New! chip).
function IndexService.stamp(player: Player, cat: string, stamp: IndexRules.Stamp): boolean
	if not LiveFlags.isOn(FLAG) or not isCat(cat) then
		return false
	end
	local save = DataService.get(player)
	if save == nil then
		return false
	end
	-- Rewrite the index from its checked entries, so a broken entry never stays in the save.
	local index = IndexRules.clean(save.index, isCat)
	save.index = index
	if not IndexRules.stamp(index, cat, stamp) then
		return false
	end
	IndexService.send(player)
	local cats = allCats()
	NetService.notice(
		player,
		if stamp == "washed"
			then `New in the Cat Index: {cat} ({IndexRules.washedCount(index, cats)} of {#cats})`
			else `{cat} got a Resident stamp`
	)
	if not save.indexBonusPaid and IndexRules.complete(index, cats) then
		save.indexBonusPaid = true
		save.coins += IndexRules.BONUS_COINS
		WalletService.show(player)
		NetService.notice(player, `Cat Index complete! +{IndexRules.BONUS_COINS} coins`)
		Telemetry.economy(
			player,
			"coins",
			"source",
			IndexRules.BONUS_COINS,
			save.coins,
			"Gameplay",
			"index_bonus"
		)
	end
	return true
end

function IndexService.Init(_services: { [string]: any }) end

function IndexService.Start()
	DataService.onLoaded:Connect(function(player: Player)
		if LiveFlags.isOn(FLAG) then
			IndexService.send(player)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(function()
			if LiveFlags.isOn(FLAG) then
				for _, player in game:GetService("Players"):GetPlayers() do
					IndexService.send(player)
				end
			end
		end)
end

return IndexService
