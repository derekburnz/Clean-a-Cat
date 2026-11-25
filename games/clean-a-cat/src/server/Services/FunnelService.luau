--!strict
-- FunnelService: the parts of the onboarding_v1 funnel (TelemetryRules.ONBOARDING_STEPS) that belong to no
-- feature. Behind the LiveFlags switch `onboardingFunnel` (Telemetry.onboarding checks it).
-- - joined: the save's first load.
-- - loaded, first_move and first_scrub: only the client sees these, so it reports them through ReportStep. A report
--   that arrives before the save has loaded waits for it. A lie only moves our own chart; nothing else changes.
-- - playtime_v1: the play time marks of every session (TelemetryRules.PLAYTIME_MARKS), checked every TICK seconds;
--   its first mark, moved, is the session's first_move report.
-- - The client's side events (ReportStep(name, detail), TelemetryRules.CLIENT_EVENTS): hint_shown,
--   hint_followed_10s and window_opened, only in the save's first session, window_opened only in its first 5 minutes.
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

local TICK = 5 -- seconds between play time checks

type Playtime = { id: string, startedAt: number, logged: { [number]: boolean } }

local pending: { [Player]: { string } } = {} -- client steps reported before the save loaded
local firstSession: { [Player]: boolean } = {} -- players whose `joined` was logged this session
local playtimes: { [Player]: Playtime } = {} -- this session's play time marks

local function markPlaytime(player: Player, step: number)
	local state = playtimes[player]
	if state == nil or state.logged[step] then
		return
	end
	-- marked only once sent: a mark passed while the switch was off logs when it goes on
	if Telemetry.playtime(player, state.id, step, firstSession[player] == true) then
		state.logged[step] = true
	end
end

local function logStep(player: Player, step: string)
	Telemetry.onboarding(player, step)
	if step == "first_move" then
		markPlaytime(player, 1) -- PLAYTIME_MARKS[1], moved: every session's first input
	end
end

local function onSideEvent(player: Player, rawName: unknown, rawDetail: unknown)
	if not TelemetryRules.clientEvent(rawName, rawDetail) or not firstSession[player] then
		return
	end
	local name, detail = rawName :: string, rawDetail :: string
	local state = playtimes[player]
	if
		name == "window_opened"
		and (state == nil or os.clock() - state.startedAt > TelemetryRules.WINDOW_SECONDS)
	then
		return
	end
	Telemetry.clientEvent(player, name, detail)
end

local function onReportStep(player: Player, rawStep: unknown, rawDetail: unknown)
	if rawDetail ~= nil then
		onSideEvent(player, rawStep, rawDetail)
		return
	end
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
	logStep(player, step)
end

function FunnelService.Init(_services: { [string]: any }) end

function FunnelService.Start()
	NetService.on("ReportStep", { perSecond = 2, burst = 4 }, onReportStep)
	DataService.onLoaded:Connect(function(player: Player, save)
		if player.Parent == nil then
			return -- left while the save loaded: nothing to track
		end
		Telemetry.startSession(player, save)
		playtimes[player] =
			{ id = `{player.UserId}-{os.time()}`, startedAt = os.clock(), logged = {} }
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
				logStep(player, step)
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
		playtimes[player] = nil
		Telemetry.endSession(player)
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, state in playtimes do
				for _, step in
					TelemetryRules.playtimeDue(os.clock() - state.startedAt, state.logged)
				do
					markPlaytime(player, step)
				end
			end
		end
	end)
end

return FunnelService
