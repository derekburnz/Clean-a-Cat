--!strict
-- QuestController: the quest book (UI/QuestBook, issue 516), behind the switch quests. It draws the book from the
-- server's Quests remote (QuestService: the open quests, today's first, and whether this week's crate is taken),
-- sent on load, after each wash and on a new day or week. Quests pay themselves as they finish, so the book sends
-- nothing back. The weekly crate's chance button opens the crate window on the normal crate, and the book comes back
-- when that closes (not after Open crate there). The HUD's Quests button and Suds's tip wait for QuestsOpen (6:00 of play; UI/HUD/SideButtons,
-- BubbleController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local QuestRules = require(Shared:WaitForChild("QuestRules"))
local QuestViewRules = require(Shared:WaitForChild("QuestViewRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local QuestController = {}

local crates: any = nil
local entries: { QuestViewRules.Entry } = {}
local crateTaken = false

local function on(): boolean
	return LiveFlags.isOn(QuestRules.FLAG)
end

local function chancesOn(): boolean
	return crates ~= nil and LiveFlags.isOn(CrateViewRules.FLAG) and LiveFlags.isOn(CrateRules.FLAG)
end

local function refresh()
	UI.setQuests(entries, crateTaken, chancesOn())
end

function QuestController.Init(controllers: { [string]: any })
	crates = controllers.CrateWindowController
end

function QuestController.Start()
	UI.onQuestChances(function(kind: string)
		local attribute = CrateRules.CRATE_ATTRIBUTE_PREFIX .. kind
		local held = Players.LocalPlayer:GetAttribute(attribute)
		if crates and chancesOn() and crates.show(kind) then
			UI.onceClosed("Crate", function()
				-- back to the book after a look at the chances; not after Open crate, so the reveal plays clear
				local opened = Players.LocalPlayer:GetAttribute(attribute) ~= held
				if on() and not opened and not UI.busy() then
					UI.open(QuestViewRules.WINDOW)
				end
			end)
		end
	end)
	Remotes.event("Quests").OnClientEvent:Connect(function(raw: unknown, taken: unknown)
		entries = QuestViewRules.clean(raw)
		crateTaken = taken == true
		refresh()
	end)
	for _, name in { QuestRules.FLAG, CrateViewRules.FLAG, CrateRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name)
			:Connect(refresh)
	end
	refresh()
end

return QuestController
