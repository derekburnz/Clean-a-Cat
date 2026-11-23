--!strict
-- NotifyService: the build finished notification (#38), behind the LiveFlags switch `longBuildOffer`.
-- - The client's bell only asks Roblox for the opt-in prompt; it reports what happened through ReportOptIn, which
--   is logged as notify_opt_in and changes nothing else.
-- - When a player leaves with a long build running, one message is queued in a MemoryStore sorted map, sorted by
--   the time the last long build finishes (NotifyRules.dueAtLeave). Coming back removes it.
-- - Every server checks the queue each CHECK_SECONDS and sends what is due through Open Cloud user notifications:
--   a claim first (so two servers never send the same one), at most one a day per player (NotifyRules.canSend).
--   Roblox delivers only to players who opted in; for anyone else the call fails and nothing happens.
-- Sending needs two things from the owner, kept out of this public repo: the notification's message id
-- (ServerStorage attribute NotifyMessageId, set in Studio) and an Open Cloud key with user notification write
-- access, saved as the experience secret SECRET_NAME. Without them nothing is sent and the log says so once.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local NotifyRules = require(Shared:WaitForChild("NotifyRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local FLAG = "longBuildOffer"
local QUEUE = "CleanACat_NotifyQueue"
local SENT = "CleanACat_NotifySent" -- last send time per player, kept two days
local SECRET_NAME = "CleanACat_NotifyKey"
local MESSAGE_ATTRIBUTE = "NotifyMessageId"
local CHECK_SECONDS = 60
local BATCH = 20
local CLAIM_SECONDS = 300 -- a claimed message another server failed to send comes back after this

local NotifyService = {}

local queue: MemoryStoreSortedMap? = nil
local sent: MemoryStoreSortedMap? = nil
local warned = false

local function warnOnce(text: string)
	if not warned then
		warned = true
		warn(`[NotifyService] {text}`)
	end
end

local function maps(): (MemoryStoreSortedMap, MemoryStoreSortedMap)
	if queue == nil or sent == nil then
		queue = MemoryStoreService:GetSortedMap(QUEUE)
		sent = MemoryStoreService:GetSortedMap(SENT)
	end
	return queue :: MemoryStoreSortedMap, sent :: MemoryStoreSortedMap
end

local function onReportOptIn(player: Player, rawResult: unknown)
	local result = Guard.oneOf(rawResult, NotifyRules.RESULTS)
	if result == nil or not LiveFlags.isOn(FLAG) then
		return
	end
	Telemetry.event(player, "notify_opt_in", 1, { result })
end

-- Queues the message for a player leaving with a long build running.
local function queueAtLeave(player: Player, save: any)
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local now = os.time()
	local due = NotifyRules.dueAtLeave(BuildRules.cleanBuilds(save.builds), now)
	if due == nil then
		return
	end
	local wait =
		math.clamp(due.endsAt - now + NotifyRules.DAY_SECONDS, 60, NotifyRules.MAX_WAIT_SECONDS)
	local map = maps()
	local ok, err = pcall(function()
		map:SetAsync(
			tostring(player.UserId),
			{ item = due.item, endsAt = due.endsAt },
			wait,
			due.endsAt
		)
	end)
	if not ok then
		warn("[NotifyService] could not queue a message:", err)
	end
end

-- The player is back: nothing to tell them.
local function unqueue(player: Player)
	local map = maps()
	pcall(function()
		map:RemoveAsync(tostring(player.UserId))
	end)
end

local function send(userId: number, item: string): boolean
	local messageId = ServerStorage:GetAttribute(MESSAGE_ATTRIBUTE)
	if type(messageId) ~= "string" or messageId == "" then
		warnOnce(
			`no message id: set the ServerStorage attribute {MESSAGE_ATTRIBUTE} to the notification's id`
		)
		return false
	end
	local okSecret, secret = pcall(function()
		return HttpService:GetSecret(SECRET_NAME)
	end)
	if not okSecret then
		warnOnce(`no Open Cloud key: add the experience secret {SECRET_NAME}`)
		return false
	end
	local body = HttpService:JSONEncode({
		source = { universe = `universes/{game.GameId}` },
		payload = {
			message_id = messageId,
			type = "MOMENT",
			parameters = { buildName = { string_value = BuildRules.ITEMS[item].name } },
			join_experience = { launch_data = "build_done" },
			analytics_data = { category = "build_done" },
		},
	})
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = `https://apis.roblox.com/cloud/v2/users/{userId}/notifications`,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = secret :: any },
			Body = body,
		})
	end)
	return ok and (response :: any).Success == true
end

-- Claims one due message, so no other server sends it; true when this server got it.
local function claim(map: MemoryStoreSortedMap, key: string, jobId: string): boolean
	local ok, result = pcall(function()
		return map:UpdateAsync(key, function(value: any, sortKey: any)
			if type(value) ~= "table" or (value.claimedBy ~= nil and value.claimedBy ~= jobId) then
				return nil -- gone, or another server has it
			end
			value.claimedBy = jobId
			return value, sortKey
		end, CLAIM_SECONDS)
	end)
	return ok and type(result) == "table" and (result :: any).claimedBy == jobId
end

local function sendDue()
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local map, sentMap = maps()
	local now = os.time()
	local ok, items = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, BATCH, nil, { sortKey = now + 1 })
	end)
	if not ok or type(items) ~= "table" then
		return
	end
	for _, entry in items :: { any } do
		local key = entry.key
		local userId = tonumber(key)
		local due = NotifyRules.cleanDue(entry.value)
		if type(key) ~= "string" or userId == nil or due == nil then
			pcall(function()
				map:RemoveAsync(key)
			end)
			continue
		end
		if
			due.endsAt > now
			or Players:GetPlayerByUserId(userId)
			or not claim(map, key, game.JobId)
		then
			continue
		end
		local okLast, last = pcall(function()
			return sentMap:GetAsync(key)
		end)
		local lastSent = if okLast and type(last) == "number" then last else nil
		if NotifyRules.canSend(lastSent, now) and send(userId, due.item) then
			pcall(function()
				sentMap:SetAsync(key, now, 2 * NotifyRules.DAY_SECONDS)
			end)
		end
		pcall(function()
			map:RemoveAsync(key)
		end)
	end
end

function NotifyService.Init(_services: { [string]: any }) end

function NotifyService.Start()
	NetService.on("ReportOptIn", { perSecond = 1, burst = 2 }, onReportOptIn)
	DataService.beforeRelease(queueAtLeave)
	DataService.onLoaded:Connect(function(player: Player)
		if LiveFlags.isOn(FLAG) then
			unqueue(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			sendDue()
		end
	end)
end

return NotifyService
