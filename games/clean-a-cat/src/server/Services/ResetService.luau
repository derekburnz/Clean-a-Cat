--!strict
-- ResetService: "Reset my game" (ResetRules, issue 1037), behind the switch resetSave. On each join it works out
-- whether the player may reset (the dev game, Studio, or the group's owner) and shows it as the Player attribute
-- CanResetSave for Settings. RequestResetSave (no arguments, once in 5 seconds) checks the switch, the save and that
-- again, then hands DataService a new save to store as it lets go of this one and kicks the player with the rejoin
-- line; the rejoin starts at the opening. Nothing here takes a value from the client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GiftRules = require(Shared:WaitForChild("GiftRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Products = require(Shared:WaitForChild("Products"))
local ResetRules = require(Shared:WaitForChild("ResetRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local ResetService = {}

local mayReset: { [Player]: boolean } = {}

local function check(player: Player)
	local rank = 0
	if not RunService:IsStudio() and game.GameId ~= Products.DEV_GAME_ID then
		local ok, result = pcall(function()
			return player:GetRankInGroup(GiftRules.GROUP_ID)
		end)
		rank = if ok and type(result) == "number" then result else 0
	end
	local allowed =
		ResetRules.allowed(game.GameId, Products.DEV_GAME_ID, RunService:IsStudio(), rank)
	if player.Parent ~= Players then
		return
	end
	mayReset[player] = allowed
	player:SetAttribute(ResetRules.ATTRIBUTE, allowed and LiveFlags.isOn(ResetRules.FLAG))
end

local function onReset(player: Player)
	if not LiveFlags.isOn(ResetRules.FLAG) or mayReset[player] ~= true then
		return
	end
	local save = DataService.get(player)
	if save == nil then
		return
	end
	if not DataService.replaceOnRelease(player, ResetRules.fresh(save, os.time())) then
		NetService.notice(player, "Can't reset right now. Try again in a minute.", "warning")
		return
	end
	Telemetry.event(player, "save_reset", Telemetry.sessionSeconds(player) // 60)
	player:Kick(ResetRules.KICK_TEXT)
end

function ResetService.Init(_services: { [string]: any }) end

function ResetService.Start()
	NetService.on(ResetRules.REMOTE, { perSecond = 0.2, burst = 1 }, onReset)
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		mayReset[player] = nil
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. ResetRules.FLAG)
		:Connect(function()
			for player, allowed in mayReset do
				player:SetAttribute(
					ResetRules.ATTRIBUTE,
					allowed and LiveFlags.isOn(ResetRules.FLAG)
				)
			end
		end)
end

return ResetService
