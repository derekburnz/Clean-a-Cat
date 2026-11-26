--!strict
-- WashView: one place that holds the close-up wash view (Effects/WashCamera, framed on the tub) with the player's
-- own avatar hidden and walking paused, so two parts of the game that each want it cannot end it for the other. Each
-- caller holds it under its own reason, like ControlHold: the opening while Suds is set down and washed
-- (OpeningController, "opening"), and every cat in the tub with the switch washView on (ScrubController, "scrub").
-- The view eases in when the first reason holds and back out when none does, RELEASE_GRACE seconds later.
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
-- Seconds the view waits after its last reason lets go before it eases out. A reason that takes it again in that time
-- keeps the view up with no cut: Suds's "Open the spa!" lets go and the first customer's cat sits in the tub a moment
-- later (Sync-Agent's run on 507cdce: the avatar showed for one frame and the next cat's view cut in 20 ms later).
local RELEASE_GRACE = 0.4

local WashView = {}

WashView.RELEASE_GRACE = RELEASE_GRACE

local player = Players.LocalPlayer
local held: { [string]: boolean } = {}
local wash: WashCamera.Handle? = nil
local spot: CFrame? = nil -- what the shot frames (WashView.frame): nil is the tub
local framed: Model? = nil -- the cat the shot fits (WashView.frame); nil frames the spot alone
local hiddenParts: { BasePart } = {}
local hiddenDecals: { Decal } = {}
local hideConnection: RBXScriptConnection? = nil
local releaseTurn = 0 -- bumped whenever a waiting release is called off or replaced
local listeners: { () -> () } = {} -- WashView.onChanged: the view came up, went down or was framed elsewhere

-- WashView.setTransition: while set (the wash screen, switch washScreen), the view comes up and goes down under a
-- cover that this function plays; it calls swap once, while the screen is covered, and the camera cuts there.
local transition: ((swap: () -> ()) -> ())? = nil
local entering = false -- a way in is waiting for its cover

local function changed()
	for _, listener in listeners do
		task.spawn(listener)
	end
end

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

local function release(onDone: (() -> ())?)
	local view = wash
	wash = nil
	local cover = transition
	if view and cover then
		-- the wash screen: everything comes back at once under the cover, the camera cut back with it
		cover(function()
			view.destroy()
			hideCharacter(false)
			if wash == nil and not entering then
				ControlHold.set(HOLD_REASON, false)
			end
			changed()
			if onDone then
				task.defer(onDone)
			end
		end)
		return
	end
	if view then
		view.exit(onDone)
	elseif onDone then
		task.defer(onDone)
	end
	hideCharacter(false)
	ControlHold.set(HOLD_REASON, false)
	if view then
		changed()
	end
end

local function apply()
	local want = next(held) ~= nil
	releaseTurn += 1 -- any release still waiting is called off; it is set again below if it is still wanted
	if want == (wash ~= nil) then
		return
	end
	if want then
		if entering then
			return -- its cover is already on the way
		end
		ControlHold.set(HOLD_REASON, true)
		local cover = transition
		local function swapIn()
			entering = false
			if wash ~= nil or next(held) == nil then
				if wash == nil then
					ControlHold.set(HOLD_REASON, false)
				end
				return
			end
			wash = WashCamera.enter(
				WashCamera.shot(spot or SpaLayout.tubSpot(), framed),
				nil,
				cover ~= nil
			)
			hideCharacter(true)
			changed()
		end
		if cover then
			entering = true
			cover(swapIn)
		else
			swapIn()
		end
	else
		local turn = releaseTurn
		task.delay(RELEASE_GRACE, function()
			if turn == releaseTurn and next(held) == nil then
				release()
			end
		end)
	end
end

-- Holds (true) or lets go of (false) the close-up wash view for `reason`. Letting go with `onDone` eases out at once,
-- with no grace, when no other reason holds the view, and runs onDone once the camera is back with the player: what
-- comes next waits for the ease (Suds's "Open the spa!", then the first customer). onDone always runs once, deferred,
-- also when the view stays up for another reason or was not up.
function WashView.set(reason: string, on: boolean, onDone: (() -> ())?)
	if on then
		held[reason] = true
	else
		held[reason] = nil
	end
	if onDone ~= nil and not on and next(held) == nil and wash ~= nil then
		releaseTurn += 1
		release(onDone)
		return
	end
	apply()
	if onDone then
		task.defer(onDone)
	end
end

-- Frames the view on `where` (a spot on the floor that faces the player, like SpaLayout.tubSpot), or back on the
-- tub with nil: a cat at a later step's station is washed there in the same close-up (Sync-Agent's run on
-- f01718c: with the view dropped, the Pawdicure's paws were 10 px behind the avatar). An open view eases over.
-- `cat` is the cat on that spot: with the wash scene (switch washScene) the shot fits his own size, so a station's
-- seat height never pushes him up under the step dots (Motion-FX, #416).
function WashView.frame(where: CFrame?, cat: Model?)
	spot = where
	framed = cat
	local view = wash
	if view then
		view.moveTo(WashCamera.shot(where or SpaLayout.tubSpot(), cat))
		changed()
	end
end

-- Sets (or clears, with nil) the cover the view comes up and goes down under: cover(swap) plays it and calls swap
-- exactly once while the screen is covered (WashScreenController, switch washScreen: Motion-FX's bubble wipe).
function WashView.setTransition(cover: ((swap: () -> ()) -> ())?)
	transition = cover
end

-- The spot the shot frames now (a later step's station, else the tub) and the cat it fits, if any.
function WashView.framing(): (CFrame, Model?)
	return spot or SpaLayout.tubSpot(), framed
end

-- fn() runs (spawned) each time the view comes up, goes down, or is framed on another spot while up. Read
-- WashView.active() and WashView.framing() in it. WashScreenController (switch washScreen) builds its room from it.
function WashView.onChanged(fn: () -> ())
	table.insert(listeners, fn)
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
	releaseTurn += 1
	entering = false
	table.clear(held)
	local view = wash
	wash = nil
	if view then
		view.destroy()
	end
	hideCharacter(false)
	ControlHold.set(HOLD_REASON, false)
	if view then
		changed()
	end
end)

return WashView
