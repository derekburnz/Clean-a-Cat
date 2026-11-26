--!strict
-- WashScreenController: the wash minigame on its own screen (switch washScreen, issue 856). Derek on dev, 2026-11-26:
-- "make the cat washing minigame a whole different screen that it changes to can do a quick bubbly across screen
-- animation when transitioning to it after placing cat in bath, don't make it still show stuff in background that way
-- they can focus and don't have any of the regular hud on the screen during washing minigame".
--
-- While the close-up wash view is up (Spa/WashView, for a customer's cat or Suds in the opening), this:
--   * has the view come up and go down under Motion-FX's bubbly wipe (Effects/BubbleWipe, when it is there; through
--     WashView.setTransition, so the camera cuts under the cover) and draws a clean room around the shot there:
--     Model-Agent's CleanACat_Area_WashRoom, or a plain pastel box until it exists;
--   * hides on this device every other part inside the room, keeping what sits near the cat (WashScreenRules.keeps:
--     the tub or station, the cat, its bubbles), and looks again every WashScreenRules.REFRESH seconds;
--   * hides Roblox's player list and asks the UI to hide the regular HUD (UI.setWashFocus, Design-Agent's) while the
--     minigame's own step counter, progress bar and tool tray stay.
-- PromptController hides every prompt pill and ScrubController the Walk button under the same switch. On the way
-- out the wipe plays again and everything comes back under its cover. A later step's station moves the room with
-- the shot. Client only, nothing is sent: the wash's server checks do not change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local WashScreenRules = require(Shared:WaitForChild("WashScreenRules"))

local Client = script.Parent.Parent :: Instance
local UI = require(Client:WaitForChild("UI"))
local WashView = require(Client:WaitForChild("Spa"):WaitForChild("WashView"))

local WashScreenController = {}

local player = Players.LocalPlayer
local up = false -- the wash screen is up (or its wipe in is under way)
local turn = 0 -- bumped on every change, so a stale wipe or look does nothing
local room: Model? = nil
local roomAt: Vector3? = nil -- the spot the room stands on
local hidden: { [Instance]: number } = {} -- each part, decal or texture hidden here, with its own fade to put back
local playerListWas: boolean? = nil
local WASH_FOLDER = "PH_SpaPrototype" -- ScrubController's folder: the cat in the tub, the bow buttons
local FX_PREFIX = "CleanACat_Fx" -- the effects' folders in Workspace

local function on(): boolean
	return WashScreenRules.on(LiveFlags.isOn)
end

-- Motion-FX's wipe: covers the screen, calls onCovered once while covered, then uncovers. With no wipe (not merged
-- yet, or it failed) onCovered runs at once, and if the wipe never calls back it runs after COVER_TIMEOUT anyway
-- (Review-QA on #860), so the screen never waits on it.
local COVER_TIMEOUT = 1
local function wipe(onCovered: () -> ())
	local called = false
	local function once()
		if not called then
			called = true
			onCovered()
		end
	end
	task.delay(COVER_TIMEOUT, once)
	local effects = Client:FindFirstChild("Effects")
	local module = if effects then effects:FindFirstChild("BubbleWipe") else nil
	if module and module:IsA("ModuleScript") then
		local ok = pcall(function()
			local wipeModule: any = require(module :: ModuleScript)
			wipeModule.play(once)
		end)
		if ok then
			return
		end
	end
	once()
end

local function setFocus(focused: boolean)
	-- Design-Agent's UI.setWashFocus hides the regular HUD; until it is merged there is nothing to call
	local set: any = (UI :: any).setWashFocus
	if type(set) == "function" then
		(set :: any)(focused)
	end
	pcall(function()
		if focused then
			if playerListWas == nil then
				playerListWas = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
			end
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		elseif playerListWas ~= nil then
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, playerListWas)
			playerListWas = nil
		end
	end)
end

local function hideOne(item: Instance)
	if hidden[item] == nil then
		hidden[item] = (item :: any).LocalTransparencyModifier
	end
	(item :: any).LocalTransparencyModifier = 1
end

local function showAll()
	for item, was in hidden do
		if item.Parent then
			(item :: any).LocalTransparencyModifier = was
		end
	end
	table.clear(hidden)
end

-- Hides every part in the room around `spot` but the room itself, the player's own character (WashView hides it)
-- and what sits near the cat; parts already hidden get their fade again, since a walk or effect may have reset it.
local function hideClutter(spot: Vector3)
	for item in hidden do
		if item.Parent then
			(item :: any).LocalTransparencyModifier = 1
		else
			hidden[item] = nil
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	if room then
		table.insert(skip, room :: Model)
	end
	if player.Character then
		table.insert(skip, player.Character :: Model)
	end
	-- the wash's own pieces: ScrubController's folder (the cat, the bow buttons) and the effects' folders (suds, foam)
	for _, child in Workspace:GetChildren() do
		if child.Name == WASH_FOLDER or string.sub(child.Name, 1, #FX_PREFIX) == FX_PREFIX then
			table.insert(skip, child)
		end
	end
	params.FilterDescendantsInstances = skip
	local h = WashScreenRules.HALF
	local centre = CFrame.new(spot + Vector3.new(0, WashScreenRules.HEIGHT / 2, 0))
	local size = Vector3.new(h * 2, WashScreenRules.HEIGHT + 2, h * 2)
	for _, part in Workspace:GetPartBoundsInBox(centre, size, params) do
		if
			hidden[part] ~= nil
			or part:IsA("Terrain")
			or WashScreenRules.keeps(part.Position, spot)
		then
			continue
		end
		hideOne(part)
		for _, child in part:GetChildren() do
			if child:IsA("Decal") or child:IsA("Texture") then
				hideOne(child)
			end
		end
	end
end

-- The placeholder room: a floor, a ceiling and four walls of WashScreenRules' size, in Bubble Pastel colours.
local function placeholder(pivot: CFrame): Model
	local model = Instance.new("Model")
	local h, height, wall = WashScreenRules.HALF, WashScreenRules.HEIGHT, WashScreenRules.WALL
	local lift = WashScreenRules.FLOOR_LIFT
	local function slab(name: string, size: Vector3, offset: Vector3, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = pivot * CFrame.new(offset)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end
	local span = h * 2 + wall * 2
	slab(
		"Floor",
		Vector3.new(span, wall, span),
		Vector3.new(0, lift - wall / 2, 0),
		WashScreenRules.FLOOR_COLOR
	)
	slab(
		"Ceiling",
		Vector3.new(span, wall, span),
		Vector3.new(0, height + wall / 2, 0),
		WashScreenRules.WALL_COLOR
	)
	slab(
		"Back",
		Vector3.new(span, height, wall),
		Vector3.new(0, height / 2, -h - wall / 2),
		WashScreenRules.WALL_COLOR
	)
	slab(
		"Front",
		Vector3.new(span, height, wall),
		Vector3.new(0, height / 2, h + wall / 2),
		WashScreenRules.WALL_COLOR
	)
	slab(
		"Left",
		Vector3.new(wall, height, span),
		Vector3.new(-h - wall / 2, height / 2, 0),
		WashScreenRules.WALL_COLOR
	)
	slab(
		"Right",
		Vector3.new(wall, height, span),
		Vector3.new(h + wall / 2, height / 2, 0),
		WashScreenRules.WALL_COLOR
	)
	return model
end

local function dropRoom()
	local old = room
	room = nil
	roomAt = nil
	if old then
		old:Destroy()
	end
end

-- Draws the room on `spot` (flat, its front toward the camera's side) and hides what else stands in it.
local function placeRoom(spot: CFrame)
	dropRoom()
	local flat = Vector3.new(spot.LookVector.X, 0, spot.LookVector.Z)
	local ahead = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local pivot = CFrame.lookAt(spot.Position, spot.Position + ahead)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(WashScreenRules.ROOM_ASSET) else nil
	local model: Model
	if asset and asset:IsA("Model") then
		model = (asset :: Model):Clone() :: Model
		model:PivotTo(pivot)
	else
		model = placeholder(pivot)
	end
	model.Name = WashScreenRules.ROOM_NAME
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local p = part :: BasePart
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false -- the room never darkens the tub: the sun still reaches it
		end
	end
	model.Parent = Workspace
	room = model
	roomAt = spot.Position
	hideClutter(spot.Position)
end

local function enter(my: number)
	if turn ~= my then
		return
	end
	setFocus(true)
	local spot = WashView.framing()
	placeRoom(spot)
	-- a passer by or a new prop in the room is hidden too, while this screen is up
	task.spawn(function()
		while turn == my and up do
			task.wait(WashScreenRules.REFRESH)
			local at = roomAt
			if turn == my and up and at then
				hideClutter(at)
			end
		end
	end)
end

local function leave()
	dropRoom()
	showAll()
	setFocus(false)
end

-- WashView calls this as the view comes up or goes down: everything swaps under the wipe's cover, where WashView
-- also cuts the camera, so the reveal is the finished shot (Motion-FX on #860).
local function cover(swap: () -> ())
	wipe(swap)
end

-- Runs on every change of the view (already under the cover when the view came up or went down).
local function update()
	WashView.setTransition(if on() then cover else nil)
	local want = on() and WashView.active()
	if want and not up then
		up = true
		turn += 1
		enter(turn)
	elseif want and up then
		-- framed on a later step's station: the room follows the shot, with no wipe
		local spot = WashView.framing()
		local at = roomAt
		if at and (at - spot.Position).Magnitude > 0.5 then
			placeRoom(spot)
		end
	elseif not want and up then
		up = false
		turn += 1
		leave()
	end
end

function WashScreenController.Init(_controllers: { [string]: any }) end

function WashScreenController.Start()
	WashView.onChanged(update)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. WashScreenRules.FLAG)
		:Connect(update)
	update()
end

return WashScreenController
