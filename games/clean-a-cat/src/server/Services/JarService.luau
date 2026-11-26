--!strict
-- JarService: the tip jar that fills from the workers while the player is away (JarRules, issue 517). When the save
-- loads, the time since save.jarAt fills the jar (save.jarCoins) and the stamp moves to now. While the player is on,
-- the stamp follows them every minute, and once more as the save is released, so online time never counts as away.
-- The coins wait in the jar and show on the Player attribute JarCoins; a tap on the jar (RequestCollectJar) pays them.
-- Behind the LiveFlags switch tipJar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local JarRules = require(Shared:WaitForChild("JarRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local STAMP_SECONDS = 60

local JarService = {}

-- Hired workers who fill the jar: none while the workers' switch is off.
local function workersOf(save: any): number
	if not LiveFlags.isOn(WorkerRules.FLAG) or type(save.workers) ~= "table" then
		return 0
	end
	local count = 0
	for _, id in WorkerRules.IDS do
		if type(save.workers[id]) == "table" then
			count += 1
		end
	end
	return count
end

local function show(player: Player, save: any)
	player:SetAttribute(
		JarRules.ATTRIBUTE,
		if LiveFlags.isOn(JarRules.FLAG) and save.jarCoins > 0 then save.jarCoins else nil
	)
end

-- Fills the jar for the time since its stamp and stamps it now.
local function fill(player: Player, save: any)
	local now = os.time()
	local hours, times = BuildRules.jar(save.stations, LiveFlags.isOn)
	save.jarCoins = JarRules.fill(save.jarCoins, save.jarAt, now, workersOf(save), hours, times)
	save.jarAt = now
	show(player, save)
end

local function nearJar(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return ((root :: BasePart).Position - SpaLayout.spot("SpotTipJar", player).Position).Magnitude
		<= JarRules.SERVER_REACH
end

local function onCollect(player: Player)
	if not LiveFlags.isOn(JarRules.FLAG) then
		return
	end
	local save = DataService.get(player)
	if save == nil or not nearJar(player) then
		return
	end
	local coins = math.floor(save.jarCoins)
	if not (coins > 0) then
		return
	end
	save.jarCoins = 0
	save.coins += coins
	show(player, save)
	WalletService.show(player)
	NetService.notice(player, `Your helpers left {coins} coins in the tip jar`)
	Telemetry.economy(player, "coins", "source", coins, save.coins, "Gameplay", "tip_jar")
end

function JarService.Init(_services: { [string]: any }) end

function JarService.Start()
	NetService.on("RequestCollectJar", { perSecond = 1, burst = 2 }, onCollect)
	DataService.onLoaded:Connect(function(player: Player, save)
		if LiveFlags.isOn(JarRules.FLAG) then
			fill(player, save)
		end
	end)
	-- the last stamp, as the player leaves: from here on they are away
	DataService.beforeRelease(function(_player: Player, save)
		if LiveFlags.isOn(JarRules.FLAG) then
			save.jarAt = os.time()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. JarRules.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				local save = DataService.get(player)
				if save then
					-- switched on: start the stamp from now, so no time from before counts as away
					if LiveFlags.isOn(JarRules.FLAG) then
						save.jarAt = os.time()
					end
					show(player, save)
				end
			end
		end)
	task.spawn(function()
		while true do
			task.wait(STAMP_SECONDS)
			if LiveFlags.isOn(JarRules.FLAG) then
				for _, player in Players:GetPlayers() do
					local save = DataService.get(player)
					if save then
						save.jarAt = os.time()
					end
				end
			end
		end
	end)
end

return JarService
