--!strict
-- CrateShopService: normal crates for Robux (CrateRules.SHOP, issue 514; tuning crate.price). A paid random item, so
-- CLAUDE.md rule 9 and the monetization-policy skill apply in full:
--   - every player's PolicyService info is read as they join; only when it says paid random items are NOT restricted
--     does the Player attribute CrateRules.SHOP_ATTRIBUTE turn true and the shop show (Design's crate window, where
--     every pet's chance shows as a percentage before any buy). A failed read counts as restricted, so in doubt the
--     crate is hidden; the earned crates stay for everyone;
--   - a bought crate is the very normal crate that is earned, with the same chance list (CrateRules.CHANCES.normal);
--   - the prompt opens only from a tap (RequestBuyCrate), and the server checks the policy again first;
--   - PurchaseService grants it in ProcessReceipt: the crates go into the save before Roblox hears it went through.
-- No Robux product gives coins. Behind the LiveFlags switch crateShop, with pets on too.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local PurchaseService = require(script.Parent:WaitForChild("PurchaseService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local POLICY_TRIES = 3
local POLICY_WAIT = 5 -- seconds between tries at reading a player's policy
-- Studio only: a server-set Player attribute that plays a restricted player for the test plan (issue 514).
local TEST_RESTRICTED = "TestPaidRandomRestricted"

local CrateShopService = {}

-- true: this player may buy paid random items; false or nil (not read yet, or the read failed): hidden.
local allowed: { [Player]: boolean } = {}

local function on(): boolean
	return LiveFlags.isOn(CrateRules.SHOP_FLAG) and LiveFlags.isOn(CrateRules.FLAG)
end

local function mayBuy(player: Player): boolean
	if RunService:IsStudio() and player:GetAttribute(TEST_RESTRICTED) == true then
		return false
	end
	return allowed[player] == true
end

local function show(player: Player)
	local value = if on() and mayBuy(player) then true else nil
	if player:GetAttribute(CrateRules.SHOP_ATTRIBUTE) ~= value then
		player:SetAttribute(CrateRules.SHOP_ATTRIBUTE, value)
	end
end

-- Reads the player's policy, a few tries; anything but a clear "not restricted" keeps the shop hidden. Yields.
local function readPolicy(player: Player)
	for _ = 1, POLICY_TRIES do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if player.Parent ~= Players then
			return
		end
		if ok and type(info) == "table" then
			allowed[player] = (info :: any).ArePaidRandomItemsRestricted == false
			show(player)
			return
		end
		task.wait(POLICY_WAIT)
	end
	allowed[player] = false
	show(player)
end

local function onBuy(player: Player, rawKey: unknown)
	if not on() or not mayBuy(player) then
		return
	end
	local key = Guard.oneOf(rawKey, CrateRules.SHOP_KEYS)
	if key == nil or DataService.get(player) == nil then
		return
	end
	PurchaseService.prompt(player, key)
end

-- The grant for `count` crates: into the save, shown from the next frame. A receipt is honoured whatever the switch
-- or the policy says now: the player paid.
local function grant(key: string, count: number): PurchaseService.Grant
	return function(player: Player, save: SaveSchema.Save, _receipt: { [string]: any }): boolean
		local kind = CrateRules.SHOP_KIND
		save.crates[kind] = (save.crates[kind] or 0) + count
		Telemetry.event(player, "purchase_step", 1, { key, "granted" })
		task.defer(function()
			PetService.show(player)
			NetService.notice(
				player,
				if count == 1
					then "A crate is yours! Tap it to open"
					else `{count} crates are yours! Tap one to open`
			)
		end)
		return true
	end
end

function CrateShopService.Init(_services: { [string]: any })
	for _, key in CrateRules.SHOP_KEYS do
		PurchaseService.register(key, grant(key, CrateRules.SHOP[key]))
	end
end

function CrateShopService.Start()
	NetService.on("RequestBuyCrate", { perSecond = 1, burst = 2 }, onBuy)
	Players.PlayerAdded:Connect(function(player: Player)
		if RunService:IsStudio() then
			player:GetAttributeChangedSignal(TEST_RESTRICTED):Connect(function()
				show(player)
			end)
		end
		readPolicy(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(readPolicy, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		allowed[player] = nil
	end)
	for _, flag in { CrateRules.SHOP_FLAG, CrateRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				for _, player in Players:GetPlayers() do
					show(player)
				end
			end)
	end
end

return CrateShopService
