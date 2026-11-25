--!strict
-- FunnelController: reports what only the client sees to the server's funnel (FunnelService, behind the switch
-- onboardingFunnel), which logs it; this only says it happened.
-- - loaded: the game has loaded and the character can move.
-- - first_move: the session's first input (a key, a tap, a click or a gamepad button). The onboarding funnel logs
--   it once per save and the play time funnel once per session (its first mark, moved).
-- - window_opened: the first time each window shows in the session's first 5 minutes (TelemetryRules.WINDOW_SECONDS),
--   so window reports never crowd the funnel steps out of ReportStep's rate limit (Review-QA on #437). The server
--   keeps only the first session's.
-- first_scrub is reported by ScrubController, the opening's hints by OpeningController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local TelemetryRules = require(Shared:WaitForChild("TelemetryRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local FunnelController = {}

local INPUTS = {
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.Gamepad1] = true,
}

local function reportFirstInput()
	local connection: RBXScriptConnection? = nil
	connection = UserInputService.InputBegan:Connect(function(input: InputObject)
		if not INPUTS[input.UserInputType] then
			return
		end
		local own = connection
		if own then
			own:Disconnect()
			connection = nil
		end
		Remotes.event("ReportStep"):FireServer("first_move")
	end)
end

function FunnelController.Init(_controllers: { [string]: any }) end

function FunnelController.Start()
	local windowNames = TelemetryRules.CLIENT_EVENTS.window_opened
	local startedAt = os.clock()
	local sent: { [string]: boolean } = {}
	UI.onOpened(function(opened: string)
		local name = if table.find(windowNames, opened) then opened else "other"
		if sent[name] or os.clock() - startedAt > TelemetryRules.WINDOW_SECONDS then
			return
		end
		sent[name] = true
		Remotes.event("ReportStep"):FireServer("window_opened", name)
	end)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local player = Players.LocalPlayer
	if player.Character == nil then
		player.CharacterAdded:Wait()
	end
	Remotes.event("ReportStep"):FireServer("loaded")
	reportFirstInput()
end

return FunnelController
