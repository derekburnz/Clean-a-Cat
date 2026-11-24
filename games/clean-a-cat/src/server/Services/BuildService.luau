--!strict
-- BuildService: stations and rooms that take time (BuildRules). A player at the builder board starts a build;
-- the server checks the switch, the distance, the slot, the order and the price, takes the coins and saves the
-- end time (os.time()). Every second it finishes builds whose time has passed, and on join it finishes those
-- that passed while the player was away, with a BuildFinished moment for the celebration. No paid skips.
-- Behind the LiveFlags switch `builds`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local StationService = require(script.Parent:WaitForChild("StationService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local FLAG = "builds"

local BuildService = {}

local function nearBoard(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return ((root :: BasePart).Position - SpaLayout.spot("SpotBuilder", player).Position).Magnitude
		<= BuildRules.SERVER_REACH
end

-- The save's builds as BuildRules works on them, with the running builds read through a check.
local function stateOf(save: any): BuildRules.State
	save.builds = BuildRules.cleanBuilds(save.builds)
	return save :: BuildRules.State
end

-- Tells the client the running builds, the finished stations and the server's clock for the countdowns.
local function send(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local state = stateOf(save)
	local built = {}
	for _, id in BuildRules.IDS do
		if state.stations[id] then
			table.insert(built, id)
		end
	end
	NetService.fire(player, "Builds", state.builds, built, os.time())
end

local function finishFor(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local done = BuildRules.finish(stateOf(save), os.time())
	if #done == 0 then
		return
	end
	for _, id in done do
		NetService.fire(player, "BuildFinished", id)
		NetService.notice(player, `{BuildRules.ITEMS[id].name} is ready!`)
		if id == "Dryer" then
			Telemetry.onboarding(player, "dryer_built")
		end
	end
	StationService.refresh(player)
	send(player)
end

local function onBuild(player: Player, rawId: unknown)
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local id = Guard.oneOf(rawId, BuildRules.offered(LiveFlags.isOn)) -- an item whose switch is off is refused
	local save = DataService.get(player)
	if id == nil or save == nil or not nearBoard(player) then
		return
	end
	local state = stateOf(save)
	local ok, reason = BuildRules.canStart(state, id)
	if not ok then
		NetService.notice(player, reason or "Can't build that yet", "warning")
		return
	end
	local spent = BuildRules.start(state, id, os.time())
	if spent <= 0 then
		return
	end
	WalletService.show(player)
	local item = BuildRules.ITEMS[id]
	StationService.refresh(player)
	send(player)
	NetService.notice(player, `Building the {item.name}`)
	Telemetry.economy(player, "coins", "sink", spent, state.coins, "Shop", id)
	Telemetry.onboarding(player, "first_build")
	if item.seconds >= BuildRules.LONG_SECONDS then
		Telemetry.event(player, "long_build_started", item.seconds / 3600, { id })
	end
end

function BuildService.Init(_services: { [string]: any }) end

function BuildService.Start()
	NetService.on("RequestBuild", { perSecond = 1, burst = 2 }, onBuild)
	DataService.onLoaded:Connect(function(player: Player, save)
		-- Read before anything finishes: was a long build running when the player left?
		Telemetry.returnedDay2(player, BuildRules.longRunningAt(stateOf(save), save.lastSeen))
		if LiveFlags.isOn(FLAG) then
			send(player)
			finishFor(player) -- builds that finished while the player was away wait for them here
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(function()
			if LiveFlags.isOn(FLAG) then
				for _, player in Players:GetPlayers() do
					send(player)
				end
			end
		end)
	task.spawn(function()
		while true do
			task.wait(1)
			if LiveFlags.isOn(FLAG) then
				for _, player in Players:GetPlayers() do
					finishFor(player)
				end
			end
		end
	end)
end

return BuildService
