--!strict
-- CelebrateController: fires the client Moments for three server-side payoffs, so Motion-FX and the sound cues can
-- hook onto them (issue 529; AudioController already plays buildDone, questDone and checkIn on them):
-- - BuildFinished(build) when the BuildFinished remote says a build is done (switch builds). The server sends it
--   just before it redraws the plot, so this waits up to BUILD_WAIT seconds for the built station or room in the
--   player's own plot (Stations/<id>, VipRoomArea, GardenArea) and passes the plot itself if it never shows.
-- - QuestDone() when a send of the Quests remote shows a quest that was open in the last send now done (switch
--   quests; QuestRules.newlyDone). The first send of a visit, a new day or a new week plays nothing.
-- - CheckInClaimed() when the days taken on the check in card (CheckinDays) go up (switch checkinCard), which only
--   a claim does; the first value of a visit plays nothing.
-- A moment only reports what happened: nothing here changes gameplay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local CheckinRules = require(Shared:WaitForChild("CheckinRules"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local Moments = require(Shared:WaitForChild("Moments"))
local QuestRules = require(Shared:WaitForChild("QuestRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local VipRules = require(Shared:WaitForChild("VipRules"))

local BUILD_WAIT = 3 -- seconds to wait for the built model after the BuildFinished remote
local BUILD_POLL = 0.1

local CelebrateController = {}

-- The name the finished build `id` has in the plot's stations folder.
local function builtName(id: string): string
	if id == SpaLayout.VIP_ID then
		return VipRules.AREA_NAME
	end
	if id == GardenRules.ID then
		return GardenRules.AREA_NAME
	end
	return id
end

local function onBuildFinished(rawId: unknown)
	if type(rawId) ~= "string" or BuildRules.ITEMS[rawId] == nil then
		return
	end
	local name = builtName(rawId)
	task.spawn(function()
		local started = os.clock()
		local plot: Model? = nil
		while os.clock() - started <= BUILD_WAIT do
			local slot = SpaLayout.slotOf(Players.LocalPlayer)
			plot = if slot then SpaLayout.plotModel(slot) else nil
			local folder = if plot then plot:FindFirstChild(SpaLayout.STATIONS_FOLDER) else nil
			local built = if folder then folder:FindFirstChild(name) else nil
			if built and built:IsA("Model") then
				Moments.BuildFinished:Fire(built :: Model)
				return
			end
			task.wait(BUILD_POLL)
		end
		if plot then
			Moments.BuildFinished:Fire(plot)
		end
	end)
end

type Entry = { id: string, done: boolean }

-- The id and done of each quest in a send of the Quests remote, skipping anything malformed.
local function questEntries(raw: unknown): { Entry }
	local out: { Entry } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, item in raw :: { any } do
		if type(item) == "table" and type(item.id) == "string" then
			table.insert(out, { id = item.id, done = item.done == true })
		end
	end
	return out
end

function CelebrateController.Init(_controllers: { [string]: any }) end

function CelebrateController.Start()
	local player = Players.LocalPlayer
	Remotes.event("BuildFinished").OnClientEvent:Connect(onBuildFinished)

	local lastQuests: { Entry } = {}
	Remotes.event("Quests").OnClientEvent:Connect(function(raw: unknown)
		local entries = questEntries(raw)
		if QuestRules.newlyDone(lastQuests, entries) > 0 then
			Moments.QuestDone:Fire()
		end
		lastQuests = entries
	end)

	local lastDays: unknown = player:GetAttribute(CheckinRules.DAYS_ATTRIBUTE)
	player:GetAttributeChangedSignal(CheckinRules.DAYS_ATTRIBUTE):Connect(function()
		local days: unknown = player:GetAttribute(CheckinRules.DAYS_ATTRIBUTE)
		if type(lastDays) == "number" and type(days) == "number" and days > lastDays then
			Moments.CheckInClaimed:Fire()
		end
		lastDays = days
	end)
end

return CelebrateController
