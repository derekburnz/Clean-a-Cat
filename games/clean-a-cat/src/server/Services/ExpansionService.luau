--!strict
-- ExpansionService: unlocks the back door expansion (ExpansionRules, issue 1041), behind the switch expansionDoor.
-- It shows each save's expansionUnlocked as the Player attribute ExpansionUnlocked, and takes RequestUnlockExpansion()
-- (no arguments, 1 a second): switch on, save loaded, still locked, near the door, enough coins. Then it takes the
-- coins, saves the unlock and redraws the plot, so the building site gives way to the open door for everyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpansionRules = require(Shared:WaitForChild("ExpansionRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local StationService = require(script.Parent:WaitForChild("StationService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local ExpansionService = {}

local function near(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or SpaLayout.slotOf(player) == nil then
		return false
	end
	local spot = SpaLayout.spot(ExpansionRules.SPOT, player)
	return ((root :: BasePart).Position - spot.Position).Magnitude <= ExpansionRules.SERVER_REACH
end

local function onUnlock(player: Player)
	if not LiveFlags.isOn(ExpansionRules.FLAG) then
		return
	end
	local save = DataService.get(player)
	if save == nil or not near(player) then
		return
	end
	local price = ExpansionRules.priceIn(game.GameId)
	local ok, reason = ExpansionRules.canUnlock(save.expansionUnlocked == true, save.coins, price)
	if not ok then
		NetService.notice(player, reason or "Can't unlock yet", "warning")
		return
	end
	save.coins -= price
	save.expansionUnlocked = true
	player:SetAttribute(ExpansionRules.ATTRIBUTE, true)
	WalletService.show(player)
	StationService.refresh(player)
	NetService.notice(player, "The back door is open!")
	Telemetry.economy(player, "coins", "sink", price, save.coins, "Shop", "Expansion")
end

function ExpansionService.Init(_services: { [string]: any }) end

function ExpansionService.Start()
	NetService.on(ExpansionRules.REMOTE, { perSecond = 1, burst = 2 }, onUnlock)
	DataService.onLoaded:Connect(function(player: Player, save)
		player:SetAttribute(ExpansionRules.ATTRIBUTE, save.expansionUnlocked == true)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. ExpansionRules.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				StationService.refresh(player)
			end
		end)
end

return ExpansionService
