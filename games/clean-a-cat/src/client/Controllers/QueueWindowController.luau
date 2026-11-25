--!strict
-- QueueWindowController: feeds "Who's next?" and the HUD's waiting faces (UI/QueueWindow, HUD/Waiting, switch
-- queueWindow, #246) from the line the server sends (CustomerQueue), the Cat Index stamps (IndexController), the
-- built stations and the star tier, and sends a Wash next press to the server as RequestPickCustomer(place). The
-- server checks the pick and owns the line (SpaService, SpaRules.pickNext); it then resends the line, which redraws.
-- A Wash next button shows only while the server would take the pick: the queue pick switches on and a customer
-- already served (the Player attribute ChanceBoardLit), the same rule as the door prompts (QueuePickController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local IndexRules = require(Shared:WaitForChild("IndexRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local QueueViewRules = require(Shared:WaitForChild("QueueViewRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local QueueWindowController = {}

local FLAG = "queueWindow"
local PICK_FLAGS = { "queuePick", "scrubPrototype", "customers" } -- what the server needs to take a pick
local SERVED = "ChanceBoardLit" -- Player attribute SpaService sets once a customer has been served

local index: any = nil
local line: { string } = {}
local lineNeeds: { [number]: { CatRules.Need } } = {} -- each place's needs as the server rolled them (#267)
local lineDirt: { [number]: number }? = nil -- each place's dirt level while dirtLevels is on (DirtRules)

local function allOn(names: { string }): boolean
	for _, name in names do
		if not LiveFlags.isOn(name) then
			return false
		end
	end
	return true
end

-- The stations the player has built, for the needs' locks.
local function built(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, station in CatRules.NEED_STATION do
		if SpaLayout.station(station) ~= nil then
			out[station] = true
		end
	end
	return out
end

local function show()
	if not LiveFlags.isOn(FLAG) then
		UI.setQueue({}, "", {})
		return
	end
	local player = Players.LocalPlayer
	local entries: { [string]: IndexRules.Entry } = if index then index.entries else {}
	local cards = QueueViewRules.cards(line, entries, built(), lineNeeds, lineDirt)
	local pickOn = allOn(PICK_FLAGS)
	local served = player:GetAttribute(SERVED) == true
	local pickable: { [number]: boolean } = {}
	for place = 1, SpaRules.QUEUE_SIZE do
		pickable[place] = QueueViewRules.canPick(place, pickOn, served)
	end
	local tier = CatRules.cleanTier(player:GetAttribute(CatRules.TIER_ATTRIBUTE))
	UI.setQueue(cards, QueueViewRules.headline(cards, tier), pickable)
end

function QueueWindowController.Init(controllers: { [string]: any })
	index = controllers.IndexController
end

function QueueWindowController.Start()
	Remotes.event("CustomerQueue").OnClientEvent
		:Connect(function(raw: unknown, rawNeeds: unknown, rawDirt: unknown)
			line = QueueViewRules.clean(raw)
			lineNeeds = QueueViewRules.cleanNeeds(rawNeeds)
			-- the server sends the levels only while dirtLevels is on
			lineDirt = if rawDirt == nil then nil else QueueViewRules.cleanDirt(rawDirt)
			show()
		end)
	UI.onQueuePick(function(place: number)
		if LiveFlags.isOn(FLAG) and allOn(PICK_FLAGS) then
			Remotes.event("RequestPickCustomer"):FireServer(place)
		end
	end)
	if index then
		index.changed:Connect(show)
	end
	for _, name in { FLAG, table.unpack(PICK_FLAGS) } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name)
			:Connect(show)
	end
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(SERVED):Connect(show)
	player:GetAttributeChangedSignal(CatRules.TIER_ATTRIBUTE):Connect(show)
	SpaLayout.changed(show) -- the plot came or went: which stations stand changed
	show()
end

return QueueWindowController
