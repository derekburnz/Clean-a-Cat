--!strict
-- QuestService: the quest book (QuestRules, issue 516). Each player's book (save.quests) is brought to their own day
-- and the week on load and every minute; each customer's cat they wash by hand (SpaService.washed) moves the open
-- quests on, and a quest done pays its coins at once with a notice. All three weekly quests done gives one normal
-- crate, once a week. The book goes to the client as Quests for Design's quest book.
-- Behind the LiveFlags switch quests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local QuestRules = require(Shared:WaitForChild("QuestRules"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local SpaService = require(script.Parent:WaitForChild("SpaService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local CHECK_SECONDS = 60 -- how often a new day or week is looked for

local QuestService = {}

local random = Random.new()
local function nextNumber(): number
	return random:NextNumber()
end

-- Sends the open quests: { id, text, goal, progress, coins, weekly, done } in book order, and the crate's state.
local function send(player: Player, save: SaveSchema.Save)
	local book = save.quests
	local list = {}
	for _, q in QuestRules.open(book, LiveFlags.isOn) do
		table.insert(list, {
			id = q.id,
			text = q.text,
			goal = q.goal,
			progress = book.progress[q.id] or 0,
			coins = q.coins,
			weekly = table.find(book.daily, q.id) == nil,
			done = book.claimed[q.id] == true,
		})
	end
	NetService.fire(player, "Quests", list, book.weeklyCrate)
end

local function refresh(player: Player, save: SaveSchema.Save, always: boolean)
	local now = os.time()
	local changed = QuestRules.refresh(
		save.quests,
		SaveSchema.day(save, now),
		QuestRules.week(now),
		LiveFlags.isOn,
		nextNumber
	)
	if changed or always then
		send(player, save)
	end
end

local function onWashed(player: Player, facts: QuestRules.Facts)
	if not LiveFlags.isOn(QuestRules.FLAG) then
		return
	end
	local save = DataService.get(player)
	if save == nil then
		return
	end
	refresh(player, save, false)
	local done, crate = QuestRules.count(save.quests, facts, LiveFlags.isOn)
	for _, q in done do
		save.coins += q.coins
		NetService.notice(player, `Quest done: {q.text}! +{q.coins} coins`)
		Telemetry.economy(
			player,
			"coins",
			"source",
			q.coins,
			save.coins,
			"Gameplay",
			"quest_reward"
		)
		Telemetry.event(
			player,
			"quest_done",
			1,
			{ if table.find(save.quests.daily, q.id) then "daily" else "weekly" }
		)
	end
	if #done > 0 then
		WalletService.show(player)
	end
	if crate and PetService.give(player, QuestRules.WEEK_CRATE, 1) then
		NetService.notice(player, "Every weekly quest done! A crate is yours")
		Telemetry.event(player, "crate_earned", 1, { "quest" })
	end
	send(player, save)
end

function QuestService.Init(_services: { [string]: any }) end

function QuestService.Start()
	SpaService.washed:Connect(onWashed)
	DataService.onLoaded:Connect(function(player: Player, save)
		if LiveFlags.isOn(QuestRules.FLAG) then
			refresh(player, save, true)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. QuestRules.FLAG)
		:Connect(function()
			if LiveFlags.isOn(QuestRules.FLAG) then
				for _, player in Players:GetPlayers() do
					local save = DataService.get(player)
					if save then
						refresh(player, save, true)
					end
				end
			end
		end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			if LiveFlags.isOn(QuestRules.FLAG) then
				for _, player in Players:GetPlayers() do
					local save = DataService.get(player)
					if save then
						refresh(player, save, false)
					end
				end
			end
		end
	end)
end

return QuestService
