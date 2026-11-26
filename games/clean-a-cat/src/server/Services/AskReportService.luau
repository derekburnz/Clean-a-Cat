--!strict
-- AskReportService: the ask_shown and ask_answered events (Growth-Agent's events spec, issue 530). The client's ask
-- queue (AskController) reports each ask it puts up and how it was answered; only a known AskRules id and answer is
-- logged, at most MAX_PER_VISIT a visit, so a client cannot flood the analytics. It changes nothing else.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AskRules = require(Shared:WaitForChild("AskRules"))

local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local MAX_PER_VISIT = 60

local AskReportService = {}

local counts: { [Player]: number } = {}

local function onReport(player: Player, rawId: unknown, rawAnswer: unknown)
	if type(rawId) ~= "string" or not AskRules.known(rawId) or AskRules.QUIET[rawId] then
		return
	end
	local answer = if rawAnswer == "yes"
			or rawAnswer == "no"
			or rawAnswer == "closed"
		then rawAnswer
		else nil
	if rawAnswer ~= nil and answer == nil then
		return
	end
	local count = (counts[player] or 0) + 1
	if count > MAX_PER_VISIT then
		return
	end
	counts[player] = count
	if answer == nil then
		Telemetry.event(player, "ask_shown", 1, { rawId })
	else
		Telemetry.event(player, "ask_answered", 1, { rawId, answer :: string })
	end
end

function AskReportService.Init(_services: { [string]: any }) end

function AskReportService.Start()
	NetService.on("ReportAsk", { perSecond = 2, burst = 4 }, onReport)
	Players.PlayerRemoving:Connect(function(player: Player)
		counts[player] = nil
	end)
end

return AskReportService
