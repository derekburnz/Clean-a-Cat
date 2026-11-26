--!strict
-- PassService: the game passes (shared/Passes, issue 518). A game pass is a one time Robux purchase that stays with
-- the player; Roblox keeps who owns which. This service:
--   - on join, asks Roblox (UserOwnsGamePassAsync) about every created pass and keeps each owned one in save.passes,
--     so a slow or failed check later never takes a pass away;
--   - opens Roblox's purchase prompt only when the player taps a pass's button (RequestPass), never by itself;
--   - gives a pass the moment its purchase completes (PromptGamePassPurchaseFinished on the server), with no rejoin;
--   - keeps the Player attribute Passes.ATTRIBUTE_PREFIX .. key = true for each pass owned, for the client;
--   - reads each created pass's price into the ReplicatedStorage attribute Passes.PRICE_PREFIX .. key for the buttons.
--
--   PassService.owns(player, key)          true while the switch is on and the player owns that pass
--   PassService.changed:Connect(fn)        fn(player, key) when a pass starts to count for a player (bought, found on
--                                          join, or the switch turned on); each feature applies it there
--
-- Every effect reads owns(), so turning the switch passes off takes all of them away at once (and back on gives
-- them back): the rollback. Coins are never sold. Behind the LiveFlags switch passes.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local Signal = require(Shared:WaitForChild("Signal"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local SAVE_WAIT = 15 -- seconds a completed purchase waits for the player's save to load
local PRICE_RETRY = 60 -- seconds between tries at reading a price Roblox did not give

local PassService = {}

PassService.changed = Signal.new() :: Signal.Signal<Player, string>

-- Passes Roblox said the player owns this session, also before the save loads (or if it never writes).
local ownedNow: { [Player]: { [string]: boolean } } = {}

local function on(): boolean
	return LiveFlags.isOn(Passes.FLAG)
end

function PassService.owns(player: Player, key: string): boolean
	if not on() then
		return false
	end
	local now = ownedNow[player]
	if now and now[key] then
		return true
	end
	local save = DataService.get(player)
	return save ~= nil and save.passes[key] == true
end

local function priceOf(key: string): number?
	local price = ReplicatedStorage:GetAttribute(Passes.PRICE_PREFIX .. key)
	return if type(price) == "number" and price > 0 then price else nil
end

local function show(player: Player)
	for _, key in Passes.KEYS do
		local name = Passes.ATTRIBUTE_PREFIX .. key
		local value = if PassService.owns(player, key) then true else nil
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end
end

-- Marks `key` owned for `player` (in the save when it is loaded) and tells every feature when it is new.
local function give(player: Player, key: string)
	local had = PassService.owns(player, key)
	local now = ownedNow[player]
	if now == nil then
		now = {}
		ownedNow[player] = now
	end
	now[key] = true
	local save = DataService.get(player)
	if save then
		save.passes[key] = true
	end
	show(player)
	if not had and PassService.owns(player, key) then
		PassService.changed:Fire(player, key)
	end
end

-- Asks Roblox about every created pass the save does not hold yet. Yields.
local function check(player: Player, save: SaveSchema.Save)
	for _, key in Passes.KEYS do
		local id = Passes.id(key)
		if id == nil or save.passes[key] then
			continue
		end
		local ok, owned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if player.Parent ~= Players then
			return
		end
		if ok and owned == true then
			give(player, key)
		end
	end
end

local function onRequest(player: Player, rawKey: unknown)
	if not on() then
		return
	end
	local key = Guard.oneOf(rawKey, Passes.KEYS)
	local save = DataService.get(player)
	if key == nil or save == nil or PassService.owns(player, key) then
		return
	end
	local id = Passes.id(key)
	if id == nil or priceOf(key) == nil then
		return -- not created or not priced yet: its button should not have shown
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, id)
	end)
	if not ok then
		warn(`PassService: prompt for {key} failed: {err}`)
		return
	end
	Telemetry.event(player, "purchase_step", 1, { key, "prompt" })
end

local function onFinished(player: Player, passId: number, bought: boolean)
	local key = Passes.keyOf(passId)
	if key == nil then
		return
	end
	if not bought then
		Telemetry.event(player, "purchase_step", 1, { key, "cancelled" })
		return
	end
	-- This signal fires on the server from Roblox itself, so the purchase is real; the save may still be loading.
	local deadline = os.clock() + SAVE_WAIT
	while DataService.get(player) == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.2)
	end
	if player.Parent ~= Players then
		return -- Roblox holds the pass; the next join finds it
	end
	give(player, key)
	Telemetry.event(player, "purchase_step", 1, { key, "granted" })
	if on() then
		NetService.notice(player, `{Passes.INFO[key].name} is yours. Thank you!`)
	end
end

-- Reads every created pass's price into its attribute, trying again later for any Roblox did not give.
local function readPrices()
	while true do
		local missing = false
		for _, key in Passes.KEYS do
			local id = Passes.id(key)
			if id == nil or priceOf(key) ~= nil then
				continue
			end
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.GamePass)
			end)
			local price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
			if type(price) == "number" and price > 0 then
				ReplicatedStorage:SetAttribute(Passes.PRICE_PREFIX .. key, price)
			else
				missing = true
			end
		end
		if not missing then
			return
		end
		task.wait(PRICE_RETRY)
	end
end

function PassService.Init(_services: { [string]: any }) end

function PassService.Start()
	NetService.on("RequestPass", { perSecond = 1, burst = 2 }, onRequest)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onFinished)
	DataService.onLoaded:Connect(function(player: Player, save)
		local now = ownedNow[player]
		if now then
			for key in now do
				save.passes[key] = true -- bought while the save was loading
			end
		end
		show(player)
		for _, key in Passes.KEYS do
			if PassService.owns(player, key) then
				PassService.changed:Fire(player, key)
			end
		end
		task.spawn(check, player, save)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			ownedNow[player] = nil
		end)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Passes.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				show(player)
				if on() then
					for _, key in Passes.KEYS do
						if PassService.owns(player, key) then
							PassService.changed:Fire(player, key)
						end
					end
				end
			end
		end)
	task.spawn(readPrices)
end

return PassService
