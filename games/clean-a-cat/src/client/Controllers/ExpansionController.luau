--!strict
-- ExpansionController: the prompt at the player's own back door while it is locked (ExpansionRules, issue 1041),
-- behind the switch expansionDoor. It shows "Unlock · 1500 coins" (50 on dev) until the server's Player attribute
-- ExpansionUnlocked is true; a tap asks the server (RequestUnlockExpansion), which checks the coins and the distance
-- and opens the door. Nothing opens by itself, and the prompt never says "hurry".
-- With catHotel on (HotelRules, issue 1049) the door opens through the Cat Hotel's timed build instead: the prompt
-- reads "Build the Cat Hotel · 1500 coins" and asks RequestBuild("CatHotel"); while it builds (the Player attribute
-- HotelBuilding) it offers Finish now (RequestFinish, with finishNow on), and it goes once the hotel is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local ExpansionRules = require(Shared:WaitForChild("ExpansionRules"))
local FinishRules = require(Shared:WaitForChild("FinishRules"))
local HotelRules = require(Shared:WaitForChild("HotelRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local ANCHOR_NAME = "CleanACat_BackDoorPrompt"
local ANCHOR_HEIGHT = 3 -- studs over the door's spot, about the middle of the doorway

local ExpansionController = {}

local anchor: BasePart? = nil
local shown: string? = nil -- the mode the prompt was made for

local function place(part: BasePart)
	part.CFrame = SpaLayout.spot(ExpansionRules.SPOT) * CFrame.new(0, ANCHOR_HEIGHT, 0)
end

-- What the door's prompt does now: nil (no prompt), "unlock" (expansionDoor's coin unlock), "hotel" (catHotel: start
-- the Cat Hotel's build) or "finish" (catHotel: Finish now while it builds, with finishNow on).
local function mode(): string?
	local player = Players.LocalPlayer
	if
		not LiveFlags.isOn(ExpansionRules.FLAG)
		or player:GetAttribute(ExpansionRules.ATTRIBUTE) ~= false
	then
		return nil
	end
	if not LiveFlags.isOn(HotelRules.FLAG) then
		return "unlock"
	end
	if player:GetAttribute(HotelRules.BUILDING_ATTRIBUTE) == true then
		return if LiveFlags.isOn(FinishRules.FLAG) then "finish" else nil
	end
	return "hotel"
end

local function refresh()
	local wanted = mode()
	if anchor and wanted ~= shown then
		(anchor :: BasePart):Destroy()
		anchor = nil
	end
	shown = wanted
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
		local hotel = BuildRules.ITEMS[HotelRules.ID]
		local made = Instance.new("ProximityPrompt")
		made.ActionText = if wanted == "hotel"
			then `Build the Cat Hotel · {hotel.price} coins`
			elseif wanted == "finish" then "Finish now"
			else ExpansionRules.promptText(ExpansionRules.priceIn(game.GameId))
		made.ObjectText = if wanted == "unlock" then "Back door" else hotel.name
		made.HoldDuration = 0.3
		made.MaxActivationDistance = ExpansionRules.PROMPT_REACH
		made.RequiresLineOfSight = false
		made.Parent = part
		made.Triggered:Connect(function()
			if wanted == "hotel" then
				Remotes.event("RequestBuild"):FireServer(HotelRules.ID)
			elseif wanted == "finish" then
				Remotes.event("RequestFinish"):FireServer(hotel.slot)
			else
				Remotes.event(ExpansionRules.REMOTE):FireServer()
			end
		end)
		part.Parent = Workspace
		anchor = part
	end
end

function ExpansionController.Init(_controllers: { [string]: any }) end

function ExpansionController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. ExpansionRules.FLAG)
		:Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal(ExpansionRules.ATTRIBUTE):Connect(refresh)
	-- (catHotel) the hotel's build starts or ends, or a switch the door's prompt reads changes
	Players.LocalPlayer:GetAttributeChangedSignal(HotelRules.BUILDING_ATTRIBUTE):Connect(refresh)
	for _, flag in { HotelRules.FLAG, FinishRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(refresh)
	end
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
