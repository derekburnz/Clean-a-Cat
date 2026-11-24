--!strict
-- UI: a starter HUD with one menu button, one example window and toasts, built in code. It is a small working
-- example for the UI gate (tools/cloudcheck/uigate.mjs) to check at every screen size; replace it with the game's
-- own screens (skills roblox-gui and ui-review). UI never fires remotes: controllers do, and call UI to show things.
--
--   UI.init()                 builds the HUD once, under the local player's PlayerGui
--   UI.open("Example")        opens a window by name; UI.closeAll() closes every window
--   UI.toast(text, kind)      a short line at the top of the screen for a few seconds
--   UI.setCoins(n)            the HUD coin counter (UI/HUD, switch gameHud, #210)
--   UI.setWashStage(stage)    the HUD wash step bar and tool tray for a ScrubController stage; nil hides them
--   UI.onSettingsChanged(fn)  fn(settings) on every change on the Settings card (UI/Settings, switch settingsCard,
--                             #230); with the switch on, the Menu opens that card
--   UI.setIndex(entries, newCats, tier)  the Cat Index window (UI/CatIndex, switch catIndexWindow, #238)
--   UI.setQueue(cards, headline, pickable)  the "Who's next?" window and the HUD's waiting faces (UI/QueueWindow,
--                             HUD/Waiting, switch queueWindow, #246); UI.onQueuePick(fn) gets fn(place) on Wash next
--   UI.pointAt(window, say, done)  the tutorial's dim step on the HUD button that opens `window` (UI/Spotlight, switch
--                             tutorialDim); done() once the player presses it. UI.clearPointer() takes it away
--   UI.showRecap(recap, fn)   the recap card after a customer's cat (UI/Recap, switch recapCard, #224); fn runs once
--                             when the player closes it
--
-- Every screen honours the player's Roblox comfort settings through UI/Comfort (#181), behind the live switch
-- comfortSettings: see-through backgrounds go through Comfort.backdrop, and text leaves room to grow
-- (Comfort.autoHeight) when the player picks a larger text size.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IndexRules = require(Shared:WaitForChild("IndexRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local QueueViewRules = require(Shared:WaitForChild("QueueViewRules"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))
local SettingsRules = require(Shared:WaitForChild("SettingsRules"))

local CatIndex = require(script:WaitForChild("CatIndex"))
local Comfort = require(script:WaitForChild("Comfort"))
local HUD = require(script:WaitForChild("HUD"))
local Motion = require(script:WaitForChild("Motion"))
local QueueWindow = require(script:WaitForChild("QueueWindow"))
local Recap = require(script:WaitForChild("Recap"))
local SettingsCard = require(script:WaitForChild("Settings"))
local SideButtons = require(script:WaitForChild("HUD"):WaitForChild("SideButtons"))
local Spotlight = require(script:WaitForChild("Spotlight"))
local Waiting = require(script:WaitForChild("HUD"):WaitForChild("Waiting"))

local UI = {}

local TAP = 52 -- px: comfortable on a phone (the UI gate fails anything pressable under 44 px on touch)
local FONT = Enum.Font.GothamMedium
local MENU_SIZE = Vector2.new(120, TAP)
local MENU_TEXT = 20
local MENU_SIZE_TV = Vector2.new(160, 68) -- a TV is read from the couch (#209)
local MENU_TEXT_TV = 30
local MENU_EDGE = 16 -- px from the left edge (inside the TV inset on a console)
local MENU_HEIGHT = 0.5 -- share of the root's height at the Menu's centre
local MENU_HEIGHT_HUD = 0.36 -- with the game HUD on: clear of the touch thumbstick on a small phone (#222)

local SETTINGS_FLAG = "settingsCard"

local windows: { [string]: Frame } = {}
local settingsListeners: { (SettingsRules.Settings) -> () } = {}
local toastLabel: TextLabel? = nil
local toastToken = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function button(text: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = text:gsub("%s", "")
	b.Size = UDim2.fromOffset(120, TAP)
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.TextColor3 = Color3.fromRGB(30, 30, 30)
	b.Font = FONT
	b.TextSize = 20
	b.Text = text
	b.AutoButtonColor = true
	corner(b, 12)
	b.Parent = parent
	return b
end

local function window(name: string, title: string, gui: ScreenGui): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.6, 0.6)
	frame.BackgroundColor3 = Color3.fromRGB(250, 246, 240)
	frame.Visible = false
	corner(frame, 16)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 400)
	limit.MinSize = Vector2.new(300, 220)
	limit.Parent = frame

	local heading = Instance.new("TextLabel")
	heading.Name = "Title"
	heading.BackgroundTransparency = 1
	heading.Position = UDim2.fromOffset(20, 12)
	heading.Size = UDim2.new(1, -40 - TAP, 0, 40)
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 26
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Color3.fromRGB(30, 30, 30)
	heading.Text = title
	heading.Parent = frame

	local close = button("X", frame)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(TAP, TAP)
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	frame.Parent = gui
	windows[name] = frame
	return frame
end

function UI.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = Instance.new("ScreenGui")
	hud.Name = "HUD"
	hud.ResetOnSpawn = false
	hud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = hud

	-- On a TV, everything stays Comfort.TV_INSET in from every edge (#209). The padding is on the root, so every HUD
	-- piece placed in it gets the inset without its own code.
	local tvPad = Instance.new("UIPadding")
	tvPad.Name = "TvInset"
	tvPad.Parent = root

	-- Left column, centred: clear of Roblox's top bar and of the phone thumbstick (bottom left). Anchored at its
	-- centre so Motion.press squashes it in place instead of toward the edge.
	local menu = button("Menu", root)
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Activated:Connect(function()
		UI.open(if LiveFlags.isOn(SETTINGS_FLAG) then "Settings" else "Example")
	end)
	Motion.press(menu) -- trial springs, switch springUi (#183)

	local function fitScreen()
		local tv = Comfort.tenFoot()
		local inset = UDim.new(if tv then Comfort.TV_INSET else 0, 0)
		tvPad.PaddingLeft, tvPad.PaddingRight, tvPad.PaddingTop, tvPad.PaddingBottom =
			inset, inset, inset, inset
		local size = if tv then MENU_SIZE_TV else MENU_SIZE
		menu.Size = UDim2.fromOffset(size.X, size.Y)
		menu.Position = UDim2.new(
			0,
			MENU_EDGE + size.X / 2,
			if HUD.active() then MENU_HEIGHT_HUD else MENU_HEIGHT,
			0
		)
		menu.TextSize = if tv then MENU_TEXT_TV else MENU_TEXT
		-- the HUD's button row (#232) replaces the starter Menu while any of its buttons shows
		menu.Visible = not SideButtons.any()
	end
	fitScreen()
	Comfort.onTenFootChanged(fitScreen)
	HUD.onActiveChanged(fitScreen)
	SideButtons.onChanged(fitScreen)

	HUD.build(root) -- coin counter, wash step bar and tool tray (switch gameHud, off by default)
	SideButtons.build(root, function(name: string)
		UI.open(name)
	end)
	Waiting.build(
		root,
		function() -- the waiting faces open "Who's next?" (switch queueWindow, #246)
			UI.open("Queue")
		end
	)

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 70)
	toast.Size = UDim2.new(0.8, 0, 0, 40)
	Comfort.autoHeight(toast) -- 40 px at least, taller when larger text wraps to more lines (switch comfortSettings)
	toast.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	Comfort.backdrop(toast, 0.2)
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.Font = FONT
	toast.TextSize = 18
	toast.TextWrapped = true
	toast.Visible = false
	corner(toast, 10)
	toast.Parent = root
	toastLabel = toast

	Spotlight.build(root) -- the tutorial's dim step (switch tutorialDim), over the HUD and under the windows
	Recap.build(root) -- the recap card and strip (switch recapCard, off by default), above the HUD and toast
	windows.CatIndex = CatIndex.build(root) -- the Cat Index window (switch catIndexWindow, #238)
	windows.Queue = QueueWindow.build(root) -- "Who's next?" (switch queueWindow, #246)
	windows.Settings = SettingsCard.build(root, function(settings: SettingsRules.Settings)
		for _, listener in settingsListeners do
			listener(settings)
		end
	end)

	local example = window("Example", "Example window", hud)
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(20, 64)
	body.Size = UDim2.new(1, -40, 1, -84)
	body.Font = FONT
	body.TextSize = 18
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(60, 60, 60)
	body.Text =
		"Replace this window with the game's own. The UI gate checks every window at phone, tablet and desktop sizes."
	body.Parent = example

	hud.Parent = playerGui
end

function UI.setCoins(coins: unknown)
	HUD.setCoins(coins)
end

function UI.setWashStage(stage: string?)
	HUD.setStage(stage)
end

-- The Cat Index window's stamps, New! marks and star tier (IndexWindowController).
function UI.setIndex(
	entries: { [string]: IndexRules.Entry },
	newCats: { [string]: boolean },
	tier: number
)
	CatIndex.set(entries, newCats, tier)
end

-- fn() each time the Cat Index window closes.
function UI.onIndexClosed(fn: () -> ())
	CatIndex.onClosed(fn)
end

-- For the UI gate: the Cat Index detail for `cat`, or the grid for nil.
function UI.showIndexDetail(cat: string?)
	CatIndex.showDetail(cat)
end

-- The customers at the door for "Who's next?" and the waiting faces (QueueWindowController).
function UI.setQueue(
	cards: { QueueViewRules.Card },
	headline: string,
	pickable: { [number]: boolean }
)
	QueueWindow.set(cards, headline, pickable)
	Waiting.set(cards)
end

-- fn(place) when the player presses Wash next on "Who's next?".
function UI.onQueuePick(fn: (place: number) -> ())
	QueueWindow.onPick(fn)
end

-- The tutorial's dim step on the HUD button that opens `window`; false when that button is not on screen.
function UI.pointAt(window: string, say: string, done: (() -> ())?): boolean
	local button = SideButtons.find(window)
	if button == nil or not button.Visible then
		return false
	end
	Spotlight.point(button, say, done)
	return Spotlight.isOn()
end

function UI.clearPointer()
	Spotlight.clear()
end

function UI.onSettingsChanged(fn: (SettingsRules.Settings) -> ())
	table.insert(settingsListeners, fn)
end

-- Draws these values on the Settings card (when the controller resets them).
function UI.showSettings(settings: SettingsRules.Settings)
	SettingsCard.show(settings)
end

function UI.showRecap(recap: RecapRules.Recap, onClose: (() -> ())?)
	Recap.show(recap, onClose)
end

function UI.open(name: string)
	UI.closeAll()
	local frame: Frame? = windows[name]
	assert(frame ~= nil, `UI.open: no window {name}`)
	frame.Visible = true
	Motion.popIn(frame) -- trial springs, switch springUi (#183)
end

function UI.closeAll()
	for _, frame in windows do
		frame.Visible = false
	end
	Recap.close()
end

function UI.windowNames(): { string }
	local names = {}
	for name in windows do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function UI.toast(text: string, kind: ("info" | "warning")?)
	local label = toastLabel
	if label == nil then
		return
	end
	toastToken += 1
	local token = toastToken
	label.Text = text
	label.BackgroundColor3 = if kind == "warning"
		then Color3.fromRGB(150, 60, 20)
		else Color3.fromRGB(30, 30, 30)
	label.Visible = true
	task.delay(5, function()
		if token == toastToken then
			label.Visible = false
		end
	end)
end

return UI
