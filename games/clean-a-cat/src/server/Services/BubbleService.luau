--!strict
-- BubbleService: keeps which of Suds's help bubbles (BubbleRules, switch sudsBubble) a save already showed, so each
-- shows once per save. The client picks the bubble and tells us with ReportBubbleSeen as it shows; we mark it in
-- save.bubbles and mirror the list to the Player attribute BubbleRules.ATTRIBUTE. A lie only hides a tip from the
-- liar: nothing else reads the list, and nothing is paid or unlocked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))

local BubbleService = {}

local function mirror(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	player:SetAttribute(
		BubbleRules.ATTRIBUTE,
		BubbleRules.pack(BubbleRules.cleanSeen(save.bubbles))
	)
end

local function onReportSeen(player: Player, rawId: unknown)
	local id = Guard.oneOf(rawId, BubbleRules.IDS)
	local save = DataService.get(player)
	if id == nil or save == nil or not LiveFlags.isOn(BubbleRules.FLAG) then
		return
	end
	local seen = BubbleRules.cleanSeen(save.bubbles)
	if seen[id] then
		return
	end
	seen[id] = true
	save.bubbles = seen
	mirror(player)
end

function BubbleService.Init(_services: { [string]: any }) end

function BubbleService.Start()
	NetService.on("ReportBubbleSeen", { perSecond = 2, burst = 3 }, onReportSeen)
	DataService.onLoaded:Connect(function(player: Player)
		mirror(player)
	end)
	for _, player in Players:GetPlayers() do
		mirror(player)
	end
end

return BubbleService
