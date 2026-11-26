--!strict
-- BuildService: stations and rooms that take time (BuildRules). A player at the builder board starts a build;
-- the server checks the switch, the distance, the slot, the order and the price, takes the coins and saves the
-- end time (os.time()). Every second it finishes builds whose time has passed, and on join it finishes those
-- that passed while the player was away, with a BuildFinished moment for the celebration.
-- Behind the LiveFlags switch `builds`.
--
-- Finish now (FinishRules, issue 515, with the switch finishNow on as well): a running build's board prompt offers
-- to finish it for Robux, priced by the time left, never under 15 s left. A tap (RequestFinish) is checked like a
-- build; when one of the player's saved credits covers the tier it is spent and the build finishes at once, with no
-- purchase. Otherwise Roblox's purchase prompt opens for that tier's developer product, and the build finishes when
-- PurchaseService grants the receipt. A receipt for a build that already ended becomes a credit for the next one.
-- Waiting is always free.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local FinishRules = require(Shared:WaitForChild("FinishRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PassService = require(script.Parent:WaitForChild("PassService"))
local PurchaseService = require(script.Parent:WaitForChild("PurchaseService"))
local StationService = require(script.Parent:WaitForChild("StationService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local FLAG = "builds"

local BuildService = {}

local pending: { [Player]: string } = {} -- the slot the player asked to finish while Roblox's prompt is open
local offerSeen: { [Player]: { [string]: boolean } } = {} -- builds ("item:endsAt") whose Finish now was logged

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

local function creditsOf(save: any): { [string]: number }
	save.finishCredits = FinishRules.cleanCredits(save.finishCredits)
	return save.finishCredits
end

local function finishOn(): boolean
	return LiveFlags.isOn(FLAG) and LiveFlags.isOn(FinishRules.FLAG)
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
	local credits = if finishOn() then creditsOf(save) else {}
	NetService.fire(player, "Builds", state.builds, built, os.time(), credits)
end

-- After a build finished early (paid or with a credit): the same moment and notice as one that ran its time.
local function finishedEarly(player: Player, id: string)
	NetService.fire(player, "BuildFinished", id)
	NetService.notice(player, `{BuildRules.ITEMS[id].name} is ready!`)
	StationService.refresh(player)
	send(player)
end

-- True when no long build (LONG_SECONDS or more) is built yet: a finish now is on the first long build.
local function noLongBuilt(state: BuildRules.State): boolean
	for id in state.stations do
		local item = BuildRules.item(id, LiveFlags.isOn)
		if item and item.seconds >= BuildRules.LONG_SECONDS then
			return false
		end
	end
	return true
end

-- skip_offer_seen, once per build, the first second a priced Finish now stands on the board within reach.
local function logOffers(player: Player, state: BuildRules.State, now: number)
	if not finishOn() or not nearBoard(player) then
		return
	end
	for _, build in state.builds do
		local tier = FinishRules.tier(build.endsAt - now)
		local seen = offerSeen[player] or {}
		offerSeen[player] = seen
		local key = `{build.item}:{build.endsAt}`
		if tier and not seen[key] and PurchaseService.priced(FinishRules.TIERS[tier].key) then
			seen[key] = true
			Telemetry.event(player, "skip_offer_seen", 1, { tostring(tier) })
		end
	end
end

local function finishFor(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local state = stateOf(save)
	local now = os.time()
	local done = BuildRules.finish(state, now)
	logOffers(player, state, now)
	if #done == 0 then
		return
	end
	for _, id in done do
		NetService.fire(player, "BuildFinished", id)
		NetService.notice(player, `{BuildRules.ITEMS[id].name} is ready!`)
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
	local builders = if PassService.owns(player, "SecondBuilder") then 2 else 1
	local ok, reason = BuildRules.canStart(state, id, LiveFlags.isOn, builders)
	if not ok then
		NetService.notice(player, reason or "Can't build that yet", "warning")
		return
	end
	local spent = BuildRules.start(state, id, os.time(), LiveFlags.isOn, builders)
	if spent <= 0 then
		return
	end
	WalletService.show(player)
	local item = BuildRules.item(id, LiveFlags.isOn) :: BuildRules.Item
	StationService.refresh(player)
	send(player)
	NetService.notice(player, `Building the {item.name}`)
	Telemetry.economy(player, "coins", "sink", spent, state.coins, "Shop", id)
	-- a station build is an upgrade too: a player who builds before buying a tool reaches first_upgrade here
	Telemetry.onboarding(player, "first_upgrade")
	Telemetry.onboarding(player, "first_build_started")
	if item.seconds >= BuildRules.LONG_SECONDS then
		Telemetry.onboarding(player, "first_long_build_started")
		Telemetry.event(player, "long_build_started", item.seconds / 3600, { id })
	end
end

local function onFinish(player: Player, rawSlot: unknown)
	if not finishOn() then
		return
	end
	local slot = Guard.oneOf(rawSlot, BuildRules.SLOTS)
	local save = DataService.get(player)
	if slot == nil or save == nil or not nearBoard(player) then
		return
	end
	local state = stateOf(save)
	local build = state.builds[slot]
	local tier = if build then FinishRules.tier(build.endsAt - os.time()) else nil
	if tier == nil then
		return -- nothing running there, or under 15 s left: no price
	end
	local credits = creditsOf(save)
	local credit = FinishRules.creditFor(credits, tier)
	if credit and FinishRules.spendCredit(credits, credit) then
		local id = FinishRules.finish(state, slot)
		if id then
			NetService.notice(player, "Used your saved Finish now")
			finishedEarly(player, id)
			Telemetry.event(player, "skip_credit_used", 1, { tostring(credit) })
		end
		return
	end
	if PurchaseService.prompt(player, FinishRules.TIERS[tier].key) then
		pending[player] = slot
	end
end

-- The grant for a Finish now of tier `paid`: the build asked for, or any build it covers; nothing to finish keeps
-- it as a credit. Changes only the save, then tells the player once the receipt is handled.
local function grantFinish(paid: number): PurchaseService.Grant
	return function(player: Player, save, _receipt): boolean
		local state = stateOf(save)
		local slot = FinishRules.target(state, os.time(), paid, pending[player])
		pending[player] = nil
		if slot == nil then
			FinishRules.addCredit(creditsOf(save), paid)
			task.defer(function()
				NetService.notice(player, "Your Finish now is saved for a later build")
				send(player)
			end)
			return true
		end
		local firstLong = noLongBuilt(state)
		local id = FinishRules.finish(state, slot) :: string
		task.defer(finishedEarly, player, id)
		Telemetry.event(player, "skip_bought", 1, {
			tostring(paid),
			if firstLong and BuildRules.ITEMS[id].seconds >= BuildRules.LONG_SECONDS
				then "true"
				else "false",
		})
		return true
	end
end

function BuildService.Init(_services: { [string]: any })
	-- in Init, so every grant is in before PurchaseService.Start takes receipts
	for index, tier in FinishRules.TIERS do
		PurchaseService.register(tier.key, grantFinish(index))
	end
end

function BuildService.Start()
	NetService.on("RequestBuild", { perSecond = 1, burst = 2 }, onBuild)
	NetService.on("RequestFinish", { perSecond = 1, burst = 2 }, onFinish)
	PurchaseService.closed:Connect(function(player: Player, _key: string, bought: boolean)
		if not bought then
			pending[player] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pending[player] = nil
		offerSeen[player] = nil
	end)
	DataService.onLoaded:Connect(function(player: Player, save)
		-- Read before anything finishes: was a long build running when the player left?
		Telemetry.returnedDay2(
			player,
			BuildRules.longRunningAt(stateOf(save), save.lastSeen, LiveFlags.isOn)
		)
		if LiveFlags.isOn(FLAG) then
			send(player)
			finishFor(player) -- builds that finished while the player was away wait for them here
		end
	end)
	for _, flag in { FLAG, FinishRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				if LiveFlags.isOn(FLAG) then
					for _, player in Players:GetPlayers() do
						send(player)
					end
				end
			end)
	end
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
