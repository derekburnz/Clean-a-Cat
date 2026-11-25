--!strict
-- QueuePickController: "pick who is next" (#201, a prototype of the bench in Planning-Agent's proposed design,
-- which is not decided yet). Each customer waiting behind the front of the door line gets a "Wash next" prompt
-- (tap, or E). The server moves that customer to the front (RequestPickCustomer, SpaRules.pickNext) and resends
-- the line, so the next cat out of the line is the one picked. It only asks; the server owns the line.
-- The prompt shows no name, coat or pay: the coat stays hidden under the mud until the wash.
-- Behind the LiveFlags switch `queuePick`, with `scrubPrototype` and `customers`; all off by default.
-- The prompts appear only once a customer has been served (Player attribute ChanceBoardLit, set by SpaService), so a
-- new save's first cat stays the guaranteed common one. The server refuses a pick before that too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryRules = require(Shared:WaitForChild("CarryRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local Trove = require(Shared:WaitForChild("Vendor"):WaitForChild("Trove"))

local FLAGS = { "queuePick", "scrubPrototype", "customers" }
local PROMPT_HEIGHT = 3 -- studs above the queue spot, about a customer's chest
local PROMPT_REACH = 10
local SERVED = "ChanceBoardLit" -- Player attribute SpaService sets once a customer has been served

local QueuePickController = {}

local trove = Trove.new() -- the prompts and their connections; one Clean takes them all away

local function allOn(): boolean
	for _, flag in FLAGS do
		if not LiveFlags.isOn(flag) then
			return false
		end
	end
	return true
end

local function refresh()
	trove:Clean()
	-- No picks while a customer's cat is being carried in (switch customerCarry): the server refuses them while the
	-- front customer still holds it, and with it in the arms they crowd the tub's "Put in tub" (Sync-Agent, 542efbc).
	local player = Players.LocalPlayer
	if
		not allOn()
		or player:GetAttribute(SERVED) ~= true
		or player:GetAttribute(CarryRules.ATTRIBUTE) ~= nil
	then
		return
	end
	local folder: Folder = trove:Add(Instance.new("Folder"))
	folder.Name = "QueuePick"
	-- The front customer (place 1) is already next, so only places 2 and up get a prompt.
	for index = 2, SpaRules.QUEUE_SIZE do
		local anchor = Instance.new("Part")
		anchor.Name = `Pick{index}`
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = SpaLayout.lineSpot("SpotQueue", index) * CFrame.new(0, PROMPT_HEIGHT, 0)
		anchor.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Wash next"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = PROMPT_REACH
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		trove:Connect(prompt.Triggered, function()
			Remotes.event("RequestPickCustomer"):FireServer(index)
		end)
	end
	folder.Parent = Workspace
end

function QueuePickController.Init(_controllers: { [string]: any }) end

function QueuePickController.Start()
	for _, flag in FLAGS do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(refresh)
	end
	Players.LocalPlayer:GetAttributeChangedSignal(SERVED):Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal(CarryRules.ATTRIBUTE):Connect(refresh)
	-- The plot came or went: the line's spots moved.
	SpaLayout.changed(function()
		task.delay(1, refresh)
	end)
	refresh()
end

return QueuePickController
