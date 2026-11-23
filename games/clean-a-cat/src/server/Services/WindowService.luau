--!strict
-- WindowService: the display window. Strays that SpaService cleaned live here for good (save.residents, up to
-- WindowRules.CUSHIONS) and tip coins while the player is online and, up to the 1 hour jar, while away. The
-- client only draws what the server sends (Residents, WindowTips). Behind the LiveFlags switch `strays`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local WindowRules = require(Shared:WaitForChild("WindowRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))

local FLAG = "strays"

local WindowService = {}

local function isCat(name: string): boolean
	return CatRules.rarityOf(name) ~= nil
end

-- The player's window cats, checked: only well formed entries count, up to the cushions.
function WindowService.residents(player: Player): { WindowRules.Resident }
	local save = DataService.get(player)
	return if save then WindowRules.validResidents(save.residents, isCat) else {}
end

-- Tells the client which cats sit in the window, in order.
function WindowService.send(player: Player)
	local list = {}
	for _, resident in WindowService.residents(player) do
		table.insert(list, { cat = resident.cat, bow = resident.bow })
	end
	NetService.fire(player, "Residents", list)
end

-- Moves a cleaned stray into the window. False when the window is full or the save is not loaded.
function WindowService.addResident(player: Player, cat: string, bow: string?): boolean
	local save = DataService.get(player)
	if save == nil or not isCat(cat) then
		return false
	end
	-- Rewrite the list from its checked entries, so a broken entry never sits between real cats.
	local residents = WindowRules.validResidents(save.residents, isCat)
	if #residents >= WindowRules.CUSHIONS then
		return false
	end
	table.insert(residents, { cat = cat, bow = bow, since = os.time() })
	save.residents = residents
	WindowService.send(player)
	return true
end

local function pay(player: Player, coins: number)
	local save = DataService.get(player)
	if save == nil or coins <= 0 then
		return
	end
	save.coins += coins
	NetService.fire(player, "WindowTips", coins, save.coins)
end

-- Tips saved in the jar while the player was away, paid once as the save loads.
local function onLoaded(player: Player, save: any)
	if not LiveFlags.isOn(FLAG) then
		return
	end
	WindowService.send(player)
	local count = #WindowService.residents(player)
	local away = os.time() - (if type(save.lastSeen) == "number" then save.lastSeen else os.time())
	local coins = WindowRules.tips(count, away, true)
	if coins > 0 then
		pay(player, coins)
		NetService.notice(player, `Your window cats saved {coins} coins in the tip jar`)
	end
end

function WindowService.Init(_services: { [string]: any }) end

function WindowService.Start()
	DataService.onLoaded:Connect(onLoaded)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(function()
			if LiveFlags.isOn(FLAG) then
				for _, player in Players:GetPlayers() do
					WindowService.send(player)
				end
			end
		end)
	-- Online tips: every TIP_SECONDS each window cat tips.
	task.spawn(function()
		while true do
			task.wait(WindowRules.TIP_SECONDS)
			if LiveFlags.isOn(FLAG) then
				for _, player in Players:GetPlayers() do
					local count = #WindowService.residents(player)
					pay(player, WindowRules.tips(count, WindowRules.TIP_SECONDS, false))
				end
			end
		end
	end)
end

return WindowService
