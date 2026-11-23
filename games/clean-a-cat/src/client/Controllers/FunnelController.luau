--!strict
-- FunnelController: reports the funnel's `loaded` step (TelemetryRules.ONBOARDING_STEPS) once the game has
-- loaded and the character can move. The server (FunnelService) logs it once per save, behind the switch
-- onboardingFunnel; this only says it happened. first_scrub is reported by ScrubController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local FunnelController = {}

function FunnelController.Init(_controllers: { [string]: any }) end

function FunnelController.Start()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local player = Players.LocalPlayer
	if player.Character == nil then
		player.CharacterAdded:Wait()
	end
	Remotes.event("ReportStep"):FireServer("loaded")
end

return FunnelController
