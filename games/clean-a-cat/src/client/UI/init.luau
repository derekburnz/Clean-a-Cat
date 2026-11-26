--!strict
-- UI: a starter HUD with one menu button, one example window and toasts, built in code. It is a small working
-- example for the UI gate (tools/cloudcheck/uigate.mjs) to check at every screen size; replace it with the game's
-- own screens (skills roblox-gui and ui-review). UI never fires remotes: controllers do, and call UI to show things.
--
--   UI.init()                 builds the HUD once, under the local player's PlayerGui
--   UI.open("Example")        opens a window by name; UI.closeAll() closes every window
--   UI.onOpened(fn)           fn(name) each time UI.open shows a window (the funnel's window_opened, FunnelController)
--   UI.toast(text, kind)      a short line at the top of the screen for a few seconds
--   UI.setCoins(n)            the HUD coin counter (UI/HUD, switch gameHud, #210)
--   UI.setWashStage(stage)    the HUD wash step bar and tool tray for a ScrubController stage; nil hides them
--   UI.setWashMeter(f, step) the bar that fills while the player works an area step (UI/HUD/WashMeter, switch
--                             washMeter); f from 0 to 1, nil hides it
--   UI.setWashPlan(later)     the later steps ("bath", "claws") this wash takes, which join the step bar (#267)
--   UI.onSettingsChanged(fn)  fn(settings) on every change on the Settings card (UI/Settings, switch settingsCard,
--                             #230); with the switch on, the Menu opens that card
--   UI.setIndex(entries, newCats, tier)  the Cat Index window (UI/CatIndex, switch catIndexWindow, #238)
--   UI.setQueue(cards, headline, pickable)  the "Who's next?" window and the HUD's waiting faces (UI/QueueWindow,
--                             HUD/Waiting, switch queueWindow, #246); UI.onQueuePick(fn) gets fn(place) on Wash next
--   UI.setTip(tip)            the tutorial's tip line, { step, total, say } or nil (UI/HUD/TipLine, switch
--                             tutorialTip)
--   UI.pointAt(window, say, done)  the tutorial's dim step on the HUD button that opens `window` (UI/Spotlight, switch
--                             tutorialDim); done() once the player presses it. UI.clearPointer() takes it away
--   UI.showBubble(bubble, fn, gone)  Suds's help bubble at the bottom (UI/SudsBubble, switch sudsBubble); fn runs
--                             when the player presses its button, gone(closed) once the card goes for any reason
--                             (closed: the player's X). UI.hideBubble() takes it away; UI.busy() is true while a
--                             window, the recap or the dim step is up, when no bubble should start
--   UI.showCrate(kind, count, rows)  opens the crate window (UI/CrateWindow, switch crateWindow, issue 526): every pet
--                             with its chance, then Open crate; UI.onCrateOpen(fn) gets fn(kind) on Open crate
--   UI.setPets(pets, hired)  the pets window (UI/PetsWindow, switch petsWindow, issue 526), opened by the HUD's Pets
--                             button; UI.onPetPlace(fn) gets fn(id, slot?) and UI.onPetFuse(fn) gets fn(ids)
--   UI.showRecap(recap, fn)   the recap card after a customer's cat (UI/Recap, switch recapCard, #224); fn runs once
--                             when the player closes it
--
-- Every screen honours the player's Roblox comfort settings through UI/Comfort (#181), behind the live switch
-- comfortSettings: see-through backgrounds go through Comfort.backdrop, and text leaves room to grow
-- (Comfort.autoHeight) when the player picks a larger text size.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))
local IndexRules = require(Shared:WaitForChild("IndexRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local QuestViewRules = require(Shared:WaitForChild("QuestViewRules"))
local QueueViewRules = require(Shared:WaitForChild("QueueViewRules"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))
local SettingsRules = require(Shared:WaitForChild("SettingsRules"))
local ShopViewRules = require(Shared:WaitForChild("ShopViewRules"))
local StarterViewRules = require(Shared:WaitForChild("StarterViewRules"))

local CatIndex = require(script:WaitForChild("CatIndex"))
local CheckinCard = require(script:WaitForChild("CheckinCard"))
local Comfort = require(script:WaitForChild("Comfort"))
local CrateWindow = require(script:WaitForChild("CrateWindow"))
local HUD = require(script:WaitForChild("HUD"))
local HeldTool = require(script:WaitForChild("HUD"):WaitForChild("HeldTool"))
local Motion = require(script:WaitForChild("Motion"))
local PetsWindow = require(script:WaitForChild("PetsWindow"))
local QuestBook = require(script:WaitForChild("QuestBook"))
local QueueWindow = require(script:WaitForChild("QueueWindow"))
local Recap = require(script:WaitForChild("Recap"))
local SettingsCard = require(script:WaitForChild("Settings"))
local ShopWindow = require(script:WaitForChild("ShopWindow"))
local SideButtons = require(script:WaitForChild("HUD"):WaitForChild("SideButtons"))
local Spotlight = require(script:WaitForChild("Spotlight"))
local StarterWindow = require(script:WaitForChild("StarterWindow"))
local SudsBubble = require(script:WaitForChild("SudsBubble"))
local Waiting = require(script:WaitForChild("HUD"):WaitForChild("Waiting"))
local WalkButton = require(script:WaitForChild("HUD"):WaitForChild("WalkButton"))

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
local CONTROLS_FLAG = "windowsHideControls"

local windows: { [string]: Frame } = {}
local settingsListeners: { (SettingsRules.Settings) -> () } = {}
local walkListeners: { () -> () } = {}
local toastLabel: TextLabel? = nil
local revealRecap: RBXScriptConnection? = nil -- shows the recap again when the window over it closes
local openedListeners: { (name: string) -> () } = {}
local toastToken = 0
local controlsHidden = false -- true while this module has Roblox's touch controls hidden

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

-- Roblox's thumbstick and jump button sit over a window's lower corners on a phone held sideways (Sync-Agent's
-- iPhone 14 check of the Cat Index). With the switch windowsHideControls on, they hide while any window is open and
-- come back when the last one closes. Off by default. A window is for tapping, not walking, so nothing is lost.
local windowListeners: { (open: boolean) -> () } = {}
local windowWasOpen = false

-- True while any window is open (not the recap card or strip, which sit beside play).
function UI.anyWindowOpen(): boolean
	for _, frame in windows do
		if frame.Visible then
			return true
		end
	end
	return false
end

-- fn(open) each time the first window opens or the last one closes.
function UI.onWindowsChanged(fn: (open: boolean) -> ())
	table.insert(windowListeners, fn)
end

local function syncWindows()
	local open = UI.anyWindowOpen()
	if open == windowWasOpen then
		return
	end
	windowWasOpen = open
	for _, listener in windowListeners do
		task.spawn(listener, open)
	end
end

local function syncControls()
	local anyOpen = false
	for _, frame in windows do
		if frame.Visible then
			anyOpen = true
			break
		end
	end
	-- The recap card at the side (switch recapSide) hides them too: its Next cat sits low on the left.
	local hide = (anyOpen and LiveFlags.isOn(CONTROLS_FLAG)) or Recap.sideShown()
	if hide == controlsHidden then
		return
	end
	controlsHidden = hide
	GuiService.TouchControlsEnabled = not hide
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
		-- the HUD's button row (#232) replaces the starter Menu while any of its buttons shows; both step aside for
		-- the wash's tick list (switch washChecklist), which takes their place at the left. The row also steps aside
		-- for the whole wash: with five or more buttons it reached the step line's title (issue 625, Sync's B5), and
		-- the windows are for between washes.
		local listShown = HUD.listShown()
		SideButtons.setAside(listShown or HUD.washing())
		menu.Visible = not SideButtons.any() and not listShown
	end
	fitScreen()
	Comfort.onTenFootChanged(fitScreen)
	HUD.onActiveChanged(fitScreen)
	SideButtons.onChanged(fitScreen)
	HUD.onListChanged(fitScreen)

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

	-- the way out of the close-up wash view (switch washView), in Roblox's top bar row; ScrubController.stepOut
	WalkButton.build(playerGui, function()
		for _, listener in walkListeners do
			listener()
		end
	end)
	HeldTool.build(playerGui) -- the step's tool under the finger (switch toolCursor), its own layer in GUI space
	Spotlight.build(root, HUD.tipShown) -- the tutorial's dim step (switch tutorialDim), over the HUD and under the
	-- windows; its words keep clear of the step pill
	HUD.onTipChanged(Spotlight.refit)
	SudsBubble.build(root) -- Suds's help bubble (switch sudsBubble), at the bottom while the tub is empty
	Recap.build(root) -- the recap card and strip (switch recapCard, off by default), above the HUD and toast
	windows.CatIndex = CatIndex.build(root) -- the Cat Index window (switch catIndexWindow, #238)
	windows.Queue = QueueWindow.build(root) -- "Who's next?" (switch queueWindow, #246)
	windows.Pets = PetsWindow.build(root) -- your pets, who has one, Fuse (switch petsWindow, issue 526)
	windows.Crate = CrateWindow.build(root) -- the crate's chance list and Open crate (switch crateWindow, issue 526)
	windows.Checkin = CheckinCard.build(root) -- the seven day check in card (switch checkinCard, issue 517)
	windows.Quests = QuestBook.build(root) -- the quest book (switch quests, issue 516)
	windows.Shop = ShopWindow.build(root) -- the shop's game passes (switch passes, issues 518 and 526)
	windows.Starter = StarterWindow.build(root) -- the Spa Starter Pack (switch starterPack with passes, issue 519)
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

	for _, frame in windows do
		frame:GetPropertyChangedSignal("Visible"):Connect(syncControls)
		frame:GetPropertyChangedSignal("Visible"):Connect(syncWindows)
	end
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CONTROLS_FLAG)
		:Connect(syncControls)
	Recap.onShownChanged(syncControls)

	hud.Parent = playerGui
end

-- Shows or hides the Walk button (ScrubController.walkChanged); UI.onWalk(fn) runs fn when it is pressed.
function UI.setWalk(shown: boolean)
	WalkButton.set(shown)
end

function UI.onWalk(fn: () -> ())
	table.insert(walkListeners, fn)
end

-- The wash step's tool under the finger (switch toolCursor): `at` is where the finger is (nil when it lifts), and
-- `centre` and `head` where the cat's middle and head are, so the tool keeps off the face (ScrubController.pointerMoved).
function UI.setToolPoint(at: Vector2?, centre: Vector2?, head: Vector2?)
	HeldTool.set(if at then HUD.toolIcon() else nil, at, centre, head)
end

function UI.setCoins(coins: unknown)
	HUD.setCoins(coins)
end

function UI.setWashStage(stage: string?)
	HUD.setStage(stage)
end

-- The bar that fills while the player works an area step: fraction 0 to 1 (nil hides it) and the step ("scrub",
-- "brush", "lather", "rinse", "claws"), from ScrubController.meterChanged.
function UI.setWashMeter(fraction: number?, step: string?)
	HUD.setMeter(fraction, step)
end

-- The later steps ("bath", "claws") this cat's wash takes, for the step bar (#267).
function UI.setWashPlan(later: { string })
	HUD.setPlan(later)
end

function UI.setTip(tip: { step: number, total: number, say: string }?)
	HUD.setTip(tip)
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
	if button == nil or not button.Visible or SideButtons.isAside() then
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

function UI.showBubble(
	bubble: BubbleRules.Bubble,
	onPress: (() -> ())?,
	onGone: ((closed: boolean) -> ())?
)
	SudsBubble.show(bubble, onPress, onGone)
end

function UI.hideBubble()
	SudsBubble.hide()
end

function UI.bubbleShown(): boolean
	return SudsBubble.isShown()
end

-- The bubble on screen now, or nil.
function UI.shownBubble(): BubbleRules.Bubble?
	return if SudsBubble.isShown() then SudsBubble.current() else nil
end

-- True while something the player is reading or choosing is up: a window, the recap card or strip, or the dim step.
function UI.busy(): boolean
	for _, frame in windows do
		if frame.Visible then
			return true
		end
	end
	return Recap.isOpen() or Spotlight.isOn()
end

-- Opens the crate window on crate `kind`, `count` of them held, with its chance list (CrateViewRules.rows).
function UI.showCrate(kind: string, count: number, rows: { CrateViewRules.Row })
	CrateWindow.set(kind, count, rows)
	if not windows.Crate.Visible then
		UI.open("Crate")
	end
end

-- Draws the crate window again (a crate came or went) without opening it.
function UI.setCrate(kind: string, count: number, rows: { CrateViewRules.Row })
	CrateWindow.set(kind, count, rows)
end

function UI.onCrateOpen(fn: (kind: string) -> ())
	CrateWindow.onOpen(fn)
end

-- The crate window's Robux rows (CrateViewRules.shopRows), {} for none.
function UI.setCrateShop(rows: { CrateViewRules.ShopRow })
	CrateWindow.setShop(rows)
end

-- fn(key) when a Robux row's price button is pressed.
function UI.onCrateBuy(fn: (key: string) -> ())
	CrateWindow.onBuy(fn)
end

-- The pets window's pets and which helpers are hired (PetsWindowController).
function UI.setPets(pets: { CrateRules.Pet }, hired: { [string]: boolean }, second: boolean?)
	PetsWindow.set(pets, hired, second)
end

function UI.onPetPlace(fn: (id: number, slot: string?) -> ())
	PetsWindow.onPlace(fn)
end

function UI.onPetFuse(fn: (ids: { number }) -> ())
	PetsWindow.onFuse(fn)
end

-- The check in card: the day waiting (1 to 7, or nil), the days taken, and whether the good crate's chance list can
-- open (CheckinController).
function UI.setCheckin(ready: number?, days: number, chances: boolean)
	CheckinCard.set(ready, days, chances)
end

function UI.onCheckinClaim(fn: () -> ())
	CheckinCard.onClaim(fn)
end

function UI.onCheckinChances(fn: (kind: string) -> ())
	CheckinCard.onChances(fn)
end

-- The quest book: the server's quests (QuestViewRules.clean), the weekly crate taken, and whether its chance list
-- can open (QuestController).
function UI.setQuests(entries: { QuestViewRules.Entry }, crateTaken: boolean, chances: boolean)
	QuestBook.set(entries, crateTaken, chances)
end

function UI.onQuestChances(fn: (kind: string) -> ())
	QuestBook.onChances(fn)
end

-- The shop's pass cards (ShopController, ShopViewRules.cards).
function UI.setShop(cards: { ShopViewRules.Card })
	ShopWindow.set(cards)
end

function UI.onShopBuy(fn: (key: string) -> ())
	ShopWindow.onBuy(fn)
end

-- The starter pack window (StarterController): its three cards, the pack's price or nil, and the offer's end time.
function UI.setStarter(items: { StarterViewRules.Item }, pack: number?, endsAt: number?)
	StarterWindow.set(items, pack, endsAt)
end

-- fn() when Get pack is pressed.
function UI.onStarterBuy(fn: () -> ())
	StarterWindow.onBuy(fn)
end

-- The HUD side button that opens `window`, or nil while it is not drawn.
function UI.sideButton(window: string): TextButton?
	return SideButtons.find(window)
end

-- A short chip under a HUD side button's caption, or nil to clear it.
function UI.setSideNote(window: string, text: string?)
	SideButtons.setNote(window, text)
end

-- True while window `name` shows.
function UI.isOpen(name: string): boolean
	local frame: Frame? = windows[name]
	return frame ~= nil and frame.Visible
end

-- fn() once, the next time window `name` closes.
function UI.onceClosed(name: string, fn: () -> ())
	local frame: Frame? = windows[name]
	if frame == nil then
		return
	end
	local shown: Frame = frame
	local connection: RBXScriptConnection
	connection = shown:GetPropertyChangedSignal("Visible"):Connect(function()
		if not shown.Visible then
			connection:Disconnect()
			fn()
		end
	end)
end

function UI.showRecap(recap: RecapRules.Recap, onClose: (() -> ())?)
	Recap.show(recap, onClose)
end

function UI.onOpened(fn: (name: string) -> ())
	table.insert(openedListeners, fn)
end

-- Opens one window and closes the others. A recap card or strip showing is hidden, not closed, so opening a window
-- never counts as Next cat; it shows again once this window closes.
function UI.open(name: string)
	local connection = revealRecap
	if connection then
		connection:Disconnect()
		revealRecap = nil
	end
	for _, other in windows do
		other.Visible = false
	end
	local frame: Frame? = windows[name]
	assert(frame ~= nil, `UI.open: no window {name}`)
	Recap.setHidden(true)
	frame.Visible = true
	for _, listener in openedListeners do
		task.spawn(listener, name)
	end
	-- A window the player opened wins over a tip. Hidden after the window shows, so a bubble waiting behind this one
	-- sees the window and never shows (and counts as seen) under it (Review-QA on #300).
	SudsBubble.hide()
	local opened: Frame = frame
	revealRecap = opened:GetPropertyChangedSignal("Visible"):Connect(function()
		if not opened.Visible then
			local own = revealRecap
			if own then
				own:Disconnect()
				revealRecap = nil
			end
			Recap.setHidden(false)
		end
	end)
	Motion.popIn(frame) -- trial springs, switch springUi (#183)
end

-- Closes one window if it is open; a recap card hidden behind it shows again.
function UI.close(name: string)
	local frame: Frame? = windows[name]
	if frame and frame.Visible then
		frame.Visible = false
	end
end

-- Closes every window and the recap card or strip (calling its onClose).
function UI.closeAll()
	local connection = revealRecap
	if connection then
		connection:Disconnect()
		revealRecap = nil
	end
	for _, frame in windows do
		frame.Visible = false
	end
	Recap.setHidden(false)
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

-- A toast at the top: shown 5 s. Toasts that come together (one cat finishing several quests) wait their turn
-- instead of replacing each other: while one waits, the one showing gives way after TOAST_SHORT seconds (issue 624,
-- Sync's B5). At most TOAST_QUEUE wait; past that the oldest waiting one is dropped.
local TOAST_SECONDS = 5
local TOAST_SHORT = 2.5
local TOAST_QUEUE = 4
type Toast = { text: string, kind: ("info" | "warning")? }
local toastQueue: { Toast } = {}
local toastShownAt = -math.huge
local toastBusy = false

local function showNextToast()
	local label = toastLabel
	local nextToast = table.remove(toastQueue, 1)
	if label == nil or nextToast == nil then
		toastBusy = false
		if label then
			label.Visible = false
		end
		return
	end
	toastBusy = true
	toastToken += 1
	local token = toastToken
	label.Text = nextToast.text
	label.BackgroundColor3 = if nextToast.kind == "warning"
		then Color3.fromRGB(150, 60, 20)
		else Color3.fromRGB(30, 30, 30)
	label.Visible = true
	toastShownAt = os.clock()
	task.spawn(function()
		while token == toastToken do
			local shownFor = os.clock() - toastShownAt
			if shownFor >= TOAST_SECONDS or (#toastQueue > 0 and shownFor >= TOAST_SHORT) then
				break
			end
			task.wait(0.1)
		end
		if token == toastToken then
			showNextToast()
		end
	end)
end

function UI.toast(text: string, kind: ("info" | "warning")?)
	if toastLabel == nil then
		return
	end
	table.insert(toastQueue, { text = text, kind = kind })
	while #toastQueue > TOAST_QUEUE do
		table.remove(toastQueue, 1)
	end
	if not toastBusy then
		showNextToast()
	end
end

return UI
