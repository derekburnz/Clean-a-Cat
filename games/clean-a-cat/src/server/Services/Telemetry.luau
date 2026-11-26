--!strict
-- Telemetry: the one place the game sends analytics to Roblox (AnalyticsService). Server only: Roblox records
-- nothing from a client or from Studio, and a client could send anything.
--
--   Telemetry.funnelStep(player, "onboarding_v1", 2, "first_win")   once per save (remembered in save.funnel)
--   Telemetry.onboarding(player, "first_scrub")   a step of TelemetryRules.ONBOARDING_STEPS, with its milestone_time
--   Telemetry.playtime(player, session, 3, first)  a mark of TelemetryRules.PLAYTIME_MARKS, once per session
--   Telemetry.startSession(player, save) / endSession(player)  FunnelService: where this session's play time starts
--   Telemetry.event(player, "shop_opened", 1, { "phone", "tier_2" })  a custom event, 3 fields at most
--   Telemetry.economy(player, "coins", "source", 50, balance, "Gameplay", "quest_reward")
--
-- Every call is wrapped in pcall: analytics must never break gameplay. A wrong call (a bad name, a 4th field)
-- warns in Studio and the log and is not sent. In Studio the last LOG_SIZE calls are kept in Telemetry.recent for QA.
-- Read the results in Creator Hub > Analytics (funnels and custom events), about a day late.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataService = require(script.Parent.DataService)
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local TelemetryRules = require(Shared:WaitForChild("TelemetryRules"))

local FUNNEL_FLAG = "onboardingFunnel"

local Telemetry = {}

local LOG_SIZE = 200
Telemetry.recent = {} :: { string }

-- This session's start: the save's play time when it loaded and the os.time() then. The save's own playSeconds
-- moves on each autosave, so it is read once, at load.
local sessions: { [Player]: { play: number, at: number } } = {}

function Telemetry.startSession(player: Player, save: { playSeconds: number })
	sessions[player] = { play = save.playSeconds, at = os.time() }
end

function Telemetry.endSession(player: Player)
	sessions[player] = nil
end

-- Seconds this save has been played, this session included; nil before its save loaded. Also
-- Telemetry.played(player), for the check in card's first wait.
local function playedSeconds(player: Player): number?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	return session.play + math.max(0, os.time() - session.at)
end

function Telemetry.played(player: Player): number?
	return playedSeconds(player)
end

-- Seconds of this session so far; 0 before the save loaded.
function Telemetry.sessionSeconds(player: Player): number
	local session = sessions[player]
	return if session then math.max(0, os.time() - session.at) else 0
end

local function remember(line: string)
	if not RunService:IsStudio() then
		return
	end
	table.insert(Telemetry.recent, line)
	if #Telemetry.recent > LOG_SIZE then
		table.remove(Telemetry.recent, 1)
	end
end

local function send(what: string, fn: () -> ())
	local ok, err = pcall(function()
		fn()
		return nil :: any
	end)
	if not ok then
		warn(`Telemetry: {what} failed: {err}`)
	end
end

-- One step of a funnel, sent once per save. Steps are numbered from 1 in the order players reach them.
-- Returns true when it was sent (the first time for this save).
function Telemetry.funnelStep(
	player: Player,
	funnel: string,
	step: number,
	stepName: string,
	fields: { string }?
): boolean
	if not TelemetryRules.validName(funnel) or not TelemetryRules.validName(stepName) then
		warn(`Telemetry: bad funnel or step name {funnel} {stepName}`)
		return false
	end
	local custom, reason = TelemetryRules.fields(fields)
	if custom == nil then
		warn(`Telemetry: {funnel} {stepName}: {reason}`)
		return false
	end
	local save = DataService.get(player)
	if save == nil or not TelemetryRules.markOnce(save.funnel, `{funnel}:{step}`) then
		return false
	end
	remember(`funnel {funnel} {step} {stepName}`)
	send(`funnel {funnel}`, function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			funnel,
			tostring(player.UserId),
			step,
			stepName,
			custom
		)
	end)
	return true
end

-- A step of the first session funnel (TelemetryRules.ONBOARDING_STEPS), once per save, behind the switch
-- onboardingFunnel. The first time, a milestone_time event follows with the seconds played to reach it.
function Telemetry.onboarding(player: Player, stepName: string): boolean
	local step = TelemetryRules.stepNumber(stepName)
	if step == nil then
		warn(`Telemetry: {stepName} is not an onboarding step`)
		return false
	end
	if not LiveFlags.isOn(FUNNEL_FLAG) then
		return false
	end
	local current = DataService.get(player)
	if current == nil or not TelemetryRules.inFunnel(current.funnel, step, current.playSeconds) then
		return false
	end
	if not Telemetry.funnelStep(player, TelemetryRules.ONBOARDING, step, stepName) then
		return false
	end
	-- The seconds of play it took to get here, every session counted (the first session's steps: since its load).
	local played = playedSeconds(player)
	if played then
		Telemetry.event(player, "milestone_time", played, { stepName })
	end
	return true
end

-- A mark of the play time funnel (TelemetryRules.PLAYTIME_MARKS), behind onboardingFunnel. `session` names this
-- session (FunnelService keeps which marks it logged, so each logs once per session). The one field says whether
-- this is the save's first session. True when it was sent.
function Telemetry.playtime(
	player: Player,
	session: string,
	step: number,
	firstSession: boolean
): boolean
	local mark = TelemetryRules.PLAYTIME_MARKS[step]
	if mark == nil or not LiveFlags.isOn(FUNNEL_FLAG) then
		return false
	end
	local custom =
		TelemetryRules.fields({ if firstSession then "first_session" else "later_session" })
	remember(`funnel {TelemetryRules.PLAYTIME} {step} {mark.name}`)
	send(`funnel {TelemetryRules.PLAYTIME}`, function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			TelemetryRules.PLAYTIME,
			session,
			step,
			mark.name,
			custom
		)
	end)
	return true
end

-- A side event the client reported (TelemetryRules.CLIENT_EVENTS), once per save for each name and detail, behind
-- onboardingFunnel. Value: the seconds played so far.
function Telemetry.clientEvent(player: Player, name: string, detail: string)
	if not LiveFlags.isOn(FUNNEL_FLAG) or not TelemetryRules.clientEvent(name, detail) then
		return
	end
	local save = DataService.get(player)
	if save == nil or not TelemetryRules.markOnce(save.funnel, `{name}:{detail}`) then
		return
	end
	Telemetry.event(player, name, playedSeconds(player) or 0, { detail })
end

-- returned_day_2, once per save: the player is back on the day after their first join. The one field says
-- whether a long build was running when they left, which tells us if the day 2 hook works.
-- Behind the switch onboardingFunnel.
function Telemetry.returnedDay2(player: Player, longBuildRunning: boolean)
	if not LiveFlags.isOn(FUNNEL_FLAG) then
		return
	end
	local save = DataService.get(player)
	if save == nil or not TelemetryRules.isDay2(save.createdAt, os.time()) then
		return
	end
	-- Only saves in the funnel (their first session logged joined), like every onboarding step.
	if not TelemetryRules.inFunnel(save.funnel, 2, save.playSeconds) then
		return
	end
	if not TelemetryRules.markOnce(save.funnel, "returned_day_2") then
		return
	end
	Telemetry.event(
		player,
		"returned_day_2",
		1,
		{ if longBuildRunning then "long_build" else "no_long_build" }
	)
end

-- A custom event with a number value (a count, seconds, an amount) and up to 3 short fields.
function Telemetry.event(player: Player, name: string, value: number?, fields: { string }?)
	if not TelemetryRules.validName(name) then
		warn(`Telemetry: bad event name {name}`)
		return
	end
	local custom, reason = TelemetryRules.fields(fields)
	if custom == nil then
		warn(`Telemetry: {name}: {reason}`)
		return
	end
	remember(`event {name} {value or 1}`)
	send(`event {name}`, function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, custom)
	end)
end

-- Currency in (a source) or out (a sink). transactionType is an Enum.AnalyticsEconomyTransactionType name, such
-- as "Gameplay", "Shop" or "IAP"; sku names what it was for.
function Telemetry.economy(
	player: Player,
	currency: string,
	flow: "source" | "sink",
	amount: number,
	balance: number,
	transactionType: string,
	sku: string,
	fields: { string }?
)
	if amount <= 0 then
		return
	end
	local custom, reason = TelemetryRules.fields(fields)
	if custom == nil then
		warn(`Telemetry: economy {sku}: {reason}`)
		return
	end
	remember(`economy {flow} {currency} {amount} {sku}`)
	send(`economy {sku}`, function()
		AnalyticsService:LogEconomyEvent(
			player,
			if flow == "source"
				then Enum.AnalyticsEconomyFlowType.Source
				else Enum.AnalyticsEconomyFlowType.Sink,
			currency,
			amount,
			math.max(0, math.floor(balance)),
			transactionType,
			sku,
			custom
		)
	end)
end

return Telemetry
