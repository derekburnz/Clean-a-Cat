--!strict
-- ExpansionController: the prompt at the player's own back door while it is locked (ExpansionRules, issue 1041),
-- behind the switch expansionDoor. It shows "Unlock · 1500 coins" (50 on dev) until the server's Player attribute
-- ExpansionUnlocked is true; a tap asks the server (RequestUnlockExpansion), which checks the coins and the distance
-- and opens the door. Nothing opens by itself, and the prompt never says "hurry".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpansionRules = require(Shared:WaitForChild("ExpansionRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local ANCHOR_NAME = "CleanACat_BackDoorPrompt"
local ANCHOR_HEIGHT = 3 -- studs over the door's spot, about the middle of the doorway

local ExpansionController = {}

local anchor: BasePart? = nil

local function place(part: BasePart)
	part.CFrame = SpaLayout.spot(ExpansionRules.SPOT) * CFrame.new(0, ANCHOR_HEIGHT, 0)
end

local function refresh()
	local wanted = LiveFlags.isOn(ExpansionRules.FLAG)
		and Players.LocalPlayer:GetAttribute(ExpansionRules.ATTRIBUTE) == false
	if wanted and anchor == nil then
		local part = Instance.new("Part")
		part.Name = ANCHOR_NAME
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		place(part)
		local made = Instance.new("ProximityPrompt")
		made.ActionText = ExpansionRules.promptText(ExpansionRules.priceIn(game.GameId))
		made.ObjectText = "Back door"
		made.HoldDuration = 0.3
		made.MaxActivationDistance = ExpansionRules.PROMPT_REACH
		made.RequiresLineOfSight = false
		made.Parent = part
		made.Triggered:Connect(function()
			Remotes.event(ExpansionRules.REMOTE):FireServer()
		end)
		part.Parent = Workspace
		anchor = part
	elseif not wanted and anchor then
		(anchor :: BasePart):Destroy()
		anchor = nil
	end
end

function ExpansionController.Init(_controllers: { [string]: any }) end

function ExpansionController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. ExpansionRules.FLAG)
		:Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal(ExpansionRules.ATTRIBUTE):Connect(refresh)
	-- the plot placed or taken away: the prompt moves with the door
	SpaLayout.changed(function()
		local part = anchor
		if part then
			place(part)
		end
	end)
	refresh()
end

return ExpansionController
