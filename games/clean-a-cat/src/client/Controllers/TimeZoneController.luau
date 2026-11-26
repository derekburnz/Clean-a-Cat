--!strict
-- TimeZoneController: tells the server this device's time zone once, in whole hours from UTC, so the check in card
-- and the quest book count the player's own days (CheckinService saves it once and never takes another). Sent at
-- start and again when the switch checkinCard or quests goes on; the server ignores every report after the first it keeps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheckinRules = require(Shared:WaitForChild("CheckinRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local QUESTS_FLAG = "quests" -- QuestRules.FLAG

local TimeZoneController = {}

local sent = false

-- Whole hours this device's clock is ahead of UTC.
local function offsetHours(): number
	local now = DateTime.now()
	local here = now:ToLocalTime() :: any -- { Year, Month, Day, Hour, Minute, Second, Millisecond }
	local asUtc = DateTime.fromUniversalTime(
		here.Year,
		here.Month,
		here.Day,
		here.Hour,
		here.Minute,
		here.Second
	)
	return math.round((asUtc.UnixTimestamp - now.UnixTimestamp) / 3600)
end

local function report()
	if sent or not (LiveFlags.isOn(CheckinRules.FLAG) or LiveFlags.isOn(QUESTS_FLAG)) then
		return
	end
	local ok, hours = pcall(offsetHours)
	if ok then
		sent = true
		Remotes.event("ReportTimeZone"):FireServer(math.clamp(hours, -12, 14))
	end
end

function TimeZoneController.Init(_controllers: { [string]: any }) end

function TimeZoneController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheckinRules.FLAG)
		:Connect(report)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. QUESTS_FLAG)
		:Connect(report)
	-- a moment after start, so the save has loaded on the server
	task.delay(5, report)
end

return TimeZoneController
