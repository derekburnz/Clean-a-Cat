--!strict
-- WashView: one place that holds the close-up wash view (Effects/WashCamera, framed on the tub) with the player's
-- own avatar hidden and walking paused, so two parts of the game that each want it cannot end it for the other. Each
-- caller holds it under its own reason, like ControlHold: the opening while Suds is set down and washed
-- (OpeningController, "opening"), and every cat in the tub with the switch washView on (ScrubController, "scrub").
-- The view eases in when the first reason holds and back out when none does.
-- Why: Derek's dev test ("cleaning doesn't enter the minigame screen yet and your character gets in way"), and
-- Sync-Agent's run on 1a38eeb, where the second cat had no close-up view: the avatar stood behind the tub and the tool
-- tray covered the cat's lower half, so the wash could not be finished.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpaLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpaLayout"))

local Client = script.Parent.Parent
local ControlHold = require(script.Parent:WaitForChild("ControlHold"))
local WashCamera = require(Client:WaitForChild("Effects"):WaitForChild("WashCamera"))

local HIDE_BIND = "CleanACat_WashHide"
local HOLD_REASON = "washView"

local WashView = {}

local player = Players.LocalPlayer
local held: { [string]: boolean } = {}
local wash: WashCamera.Handle? = nil
local hiddenParts: { BasePart } = {}
local hiddenDecals: { Decal } = {}
local hideConnection: RBXScriptConnection? = nil

-- The player's own avatar is hidden on their screen while the view is up: it stands by the tub, so it would sit
-- between the camera and the cat. Only on this device; everyone else still sees it. Set every frame after the camera,
-- because Roblox's camera scripts set the same fade themselves.
local function hideCharacter(hide: boolean)
	if hideConnection then
		hideConnection:Disconnect()
		hideConnection = nil
	end
	pcall(function()
		RunService:UnbindFromRenderStep(HIDE_BIND)
	end)
	for _, part in hiddenParts do
		part.LocalTransparencyModifier = 0
	end
	for _, decal in hiddenDecals do
		decal.LocalTransparencyModifier = 0
	end
	table.clear(hiddenParts)
	table.clear(hiddenDecals)
	local character = player.Character
	if not hide or character == nil then
		return
	end
	local function add(item: Instance)
		if item:IsA("BasePart") then
			table.insert(hiddenParts, item :: BasePart)
		elseif item:IsA("Decal") then
			table.insert(hiddenDecals, item :: Decal)
		end
	end
	for _, item in character:GetDescendants() do
		add(item)
	end
	hideConnection = character.DescendantAdded:Connect(add)
	RunService:BindToRenderStep(HIDE_BIND, Enum.RenderPriority.Camera.Value + 2, function()
		for _, part in hiddenParts do
			part.LocalTransparencyModifier = 1
		end
		for _, decal in hiddenDecals do
			decal.LocalTransparencyModifier = 1
		end
	end)
end

local function apply()
	local want = next(held) ~= nil
	if want == (wash ~= nil) then
		return
	end
	if want then
		ControlHold.set(HOLD_REASON, true)
		wash = WashCamera.enter(WashCamera.shot(SpaLayout.tubSpot()))
		hideCharacter(true)
	else
		local view = wash
		wash = nil
		if view then
			view.exit()
		end
		hideCharacter(false)
		ControlHold.set(HOLD_REASON, false)
	end
end

-- Holds (true) or lets go of (false) the close-up wash view for `reason`.
function WashView.set(reason: string, on: boolean)
	if on then
		held[reason] = true
	else
		held[reason] = nil
	end
	apply()
end

-- Is the view held for `reason`?
function WashView.holds(reason: string): boolean
	return held[reason] == true
end

-- Is the view up for any reason?
function WashView.active(): boolean
	return wash ~= nil
end

-- A new character (a reset) starts with no view: the camera goes back at once and nothing holds it.
player.CharacterAdded:Connect(function()
	table.clear(held)
	local view = wash
	wash = nil
	if view then
		view.destroy()
	end
	hideCharacter(false)
	ControlHold.set(HOLD_REASON, false)
end)

return WashView
