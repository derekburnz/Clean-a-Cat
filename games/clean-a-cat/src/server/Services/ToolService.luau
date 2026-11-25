--!strict
-- ToolService: the Tools board. A player standing at the board buys a tool once with coins and keeps it in the
-- save (save.tools). The server checks the switch, the price, ownership and the distance to the board; the
-- client only asks. Each owned tool shows as the Player attribute Tool_<id> = true, which the scrub reads.
-- Behind the LiveFlags switch `toolsBoard`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local FLAG = "toolsBoard"

local ToolService = {}

local function showOwned(player: Player, tools: { [string]: boolean })
	for _, id in ToolRules.IDS do
		player:SetAttribute(ToolRules.ATTRIBUTE_PREFIX .. id, if tools[id] then true else nil)
	end
end

local function nearBoard(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local offset = (root :: BasePart).Position - SpaLayout.spot("Tools", player).Position
	return offset.Magnitude <= ToolRules.SERVER_REACH
end

local function onBuy(player: Player, rawId: unknown)
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local id = Guard.oneOf(rawId, ToolRules.offered(LiveFlags.isOn)) -- a tool whose switch is off is refused
	local save = DataService.get(player)
	if id == nil or save == nil or not nearBoard(player) then
		return
	end
	local ok, reason = ToolRules.canBuy(save, id)
	if not ok then
		NetService.notice(player, reason or "Can't buy that yet", "warning")
		return
	end
	local spent = ToolRules.buy(save, id)
	if spent <= 0 then
		return
	end
	WalletService.show(player)
	showOwned(player, save.tools)
	NetService.notice(player, `{ToolRules.TOOLS[id].name} is yours`)
	Telemetry.economy(player, "coins", "sink", spent, save.coins, "Shop", id)
	Telemetry.onboarding(player, "first_upgrade")
end

function ToolService.Init(_services: { [string]: any }) end

function ToolService.Start()
	NetService.on("RequestBuyTool", { perSecond = 1, burst = 2 }, onBuy)
	DataService.onLoaded:Connect(function(player: Player, save)
		showOwned(player, save.tools)
	end)
	-- Saves that loaded before this service started.
	for _, player in Players:GetPlayers() do
		local save = DataService.get(player)
		if save then
			showOwned(player, save.tools)
		end
	end
end

return ToolService
