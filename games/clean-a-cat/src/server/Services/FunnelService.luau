--!strict
-- FunnelService: the parts of the onboarding_v1 funnel (TelemetryRules.ONBOARDING_STEPS) that belong to no
-- feature. Behind the LiveFlags switch `onboardingFunnel` (Telemetry.onboarding checks it).
-- - joined: the save's first load.
-- - loaded and first_scrub: only the client sees these, so it reports them through ReportStep. A report that
--   arrives before the save has loaded waits for it. A lie only moves our own chart; nothing else changes.
-- - left_at: when a player leaves during their first session, the last step they reached (value and field).
-- The feature steps (first_reveal and on) are logged where they happen: SpaService, ToolService, BuildService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guard = require(Shared:WaitForChild("Guard"))
local TelemetryRules = require(Shared:WaitForChild("TelemetryRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local FunnelService = {}

local pending: { [Player]: { string } } = {} -- client steps reported before the save loaded
local firstSession: { [Player]: boolean } = {} -- players whose `joined` was logged this session

local function onReportStep(player: Player, rawStep: unknown)
	local step = Guard.oneOf(rawStep, TelemetryRules.CLIENT_STEPS)
	if step == nil then
		return
	end
	if DataService.get(player) == nil then
		local waiting = pending[player] or {}
		pending[player] = waiting
		if not table.find(waiting, step) then
			table.insert(waiting, step)
		end
		return
	end
	Telemetry.onboarding(player, step)
end

function FunnelService.Init(_services: { [string]: any }) end

function FunnelService.Start()
	NetService.on("ReportStep", { perSecond = 1, burst = 2 }, onReportStep)
	DataService.onLoaded:Connect(function(player: Player)
		if Telemetry.onboarding(player, "joined") then
			firstSession[player] = true
		end
		local waiting = pending[player]
		pending[player] = nil
		if waiting then
			-- In funnel order, so loaded comes before first_scrub.
			table.sort(waiting, function(a: string, b: string): boolean
				return (TelemetryRules.stepNumber(a) or 0) < (TelemetryRules.stepNumber(b) or 0)
			end)
			for _, step in waiting do
				Telemetry.onboarding(player, step)
			end
		end
	end)
	-- Runs once, as the save is written for the last time.
	DataService.beforeRelease(function(player: Player, save)
		if firstSession[player] then
			firstSession[player] = nil
			local step, name = TelemetryRules.lastStep(save.funnel)
			Telemetry.event(player, "left_at", step, { name })
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pending[player] = nil
	end)
end

return FunnelService
