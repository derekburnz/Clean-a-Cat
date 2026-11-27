--!strict
-- FeedbackService: "Send feedback" in Settings (FeedbackRules, issue 1081), behind the switch feedback.
-- SendFeedback(choice, note?): once in 30 seconds and FeedbackRules.PER_VISIT times a visit; the choice must be one
-- of FeedbackRules.CHOICES and the note, when given, text of at most NOTE_MAX characters (a bad note is dropped, the
-- choice still counts). The note goes through Roblox's text filter before it is kept; when the filter can't be asked
-- only the choice is kept. Then the analytics event "feedback" (fields: the choice, note or no_note) and one entry in
-- the day's key of the DataStore FeedbackRules.STORE, with no name or user id. A thank-you toast either way, and the
-- Player attribute FeedbackSent counts the sends of this visit for Settings.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedbackRules = require(Shared:WaitForChild("FeedbackRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local FeedbackService = {}

local TRIES = 3

local sent: { [Player]: number } = {}

-- Roblox's filter of `note` typed by `player`; nil when the filter could not be asked. Yields.
local function filter(player: Player, note: string): string?
	local ok, result = pcall(function()
		local filtered =
			TextService:FilterStringAsync(note, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(result) == "string" then result else nil
end

local function store(): DataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(
			if RunService:IsStudio() then FeedbackRules.STUDIO_STORE else FeedbackRules.STORE
		)
	end)
	return if ok then result else nil
end

-- Adds `entry` to its day's key, a few tries apart. Yields.
local function keep(entry: FeedbackRules.Entry)
	local data = store()
	if data == nil then
		warn("[FeedbackService] the feedback DataStore is not reachable")
		return
	end
	local key = FeedbackRules.dayKey(entry.at)
	for try = 1, TRIES do
		local ok, err = pcall(function()
			(data :: DataStore):UpdateAsync(key, function(old: unknown)
				local list = FeedbackRules.append(old, entry)
				return list
			end)
		end)
		if ok then
			return
		end
		if try == TRIES then
			warn(`[FeedbackService] could not keep feedback: {err}`)
		else
			task.wait(2 * try)
		end
	end
end

local function onSend(player: Player, rawChoice: unknown, rawNote: unknown)
	if not LiveFlags.isOn(FeedbackRules.FLAG) then
		return
	end
	local choice = Guard.oneOf(rawChoice, FeedbackRules.CHOICES)
	if choice == nil or (sent[player] or 0) >= FeedbackRules.PER_VISIT then
		return
	end
	sent[player] = (sent[player] or 0) + 1
	player:SetAttribute(FeedbackRules.SENT_ATTRIBUTE, sent[player])
	local typed = FeedbackRules.cleanNote(rawNote)
	local note = if typed then FeedbackRules.kept(filter(player, typed)) else nil
	if player.Parent ~= Players then
		return
	end
	Telemetry.event(player, "feedback", 1, { choice, if note then "note" else "no_note" })
	NetService.notice(player, FeedbackRules.THANKS)
	keep({ choice = choice, note = note, at = os.time(), placeVersion = game.PlaceVersion })
end

function FeedbackService.Init(_services: { [string]: any }) end

function FeedbackService.Start()
	NetService.on(FeedbackRules.REMOTE, { perSecond = 1 / 30, burst = 1 }, onSend)
	Players.PlayerRemoving:Connect(function(player: Player)
		sent[player] = nil
	end)
end

return FeedbackService
