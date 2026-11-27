--!strict
-- SideButtons: the HUD's row of round buttons that open the game's windows (#232), from Design-Agent's hud.html:
-- top left, just under Roblox's menu buttons, each a 76 px button with a 52 px icon and a caption under it (66 px
-- on a phone held sideways). Settings sits last as a lilac button with the gear.
--
--   SideButtons.build(root, open)   makes the row once; open(windowName) runs when a button is pressed
--   SideButtons.any()               true while the HUD is on and at least one button shows
--   SideButtons.onChanged(fn)       fn() when a switch that shows or hides a button flips
--   SideButtons.find(window)        the button that opens `window`, or nil
--   SideButtons.setNote(window, t)  a small chip under that button's caption (nil hides it)
--   SideButtons.setAside(on)        hides the row while the wash's tick list has its place (HUD/StepList); the
--                                   windows are for between washes. SideButtons.isAside()
--
-- A button shows only while the game HUD (gameHud) and its own window's switch are on, so a switched-off window
-- never has a way in. While any button shows, the starter Menu hides (UI/init). With a gamepad the row is reached
-- with Roblox's UI navigation (the Select button); the buttons are linked left and right in order.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Arrive = require(script.Parent.Parent.Parent:WaitForChild("Effects"):WaitForChild("Arrive"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent.Parent:WaitForChild("Motion"))

local SideButtons = {}

local HUD_FLAG = "gameHud"
local ARRIVE_FLAG = "buttonArrive"
local TIDY_FLAG = "hudTidy" -- issue 738: a 2 by 2 grid with a More tray, and the starter pack as a side ad

type Spec = {
	window: string,
	flag: string,
	icon: string,
	caption: string,
	top: Color3,
	bottom: Color3,
	attribute: string?, -- also waits for this Player attribute to be set and not false (QuestsOpen, StarterEndsAt)
	also: string?, -- a second switch it needs (the starter pack gives passes, so it needs passes too)
	anyOf: { string }?, -- also waits for at least one of these Player attributes to be set (a helper hired)
	tidy: string?, -- with hudTidy on: "main" (the 2 by 2 grid), "more" (the More tray) or "ad" (HUD/StarterAd)
	tidyOrder: number?, -- its place in the grid or the tray
}

-- In order, left to right. Tools and Build join when their windows exist.
SideButtons.BUTTONS = {
	{
		window = "CatIndex",
		tidy = "more",
		tidyOrder = 4,
		flag = "catIndexWindow",
		icon = "Index",
		caption = "Index",
		top = Color3.fromHex("C9F5E5"),
		bottom = Color3.fromHex("A8E6CF"),
	},
	{
		window = "Pets",
		tidy = "more",
		tidyOrder = 3,
		flag = "petsWindow",
		icon = "Pets",
		caption = "Pets",
		top = Color3.fromHex("FFE3EE"),
		bottom = Color3.fromHex("FFC4D8"),
	},
	{
		-- once a helper is hired: their levels, modes and names (issue 526 item 3)
		window = "Helpers",
		tidy = "main",
		tidyOrder = 3,
		flag = "helpersWindow",
		also = "workers",
		-- HelperViewRules.LEVEL_PREFIX .. id, or with menuOnly MenuRules.OPEN_ATTRIBUTE: the coins for the first hire
		anyOf = { "WorkerLevel_Jo", "WorkerLevel_Sam", "WorkerLevel_Lou", "HelpersOpen" },
		icon = "Helpers",
		caption = "Helpers",
		top = Color3.fromHex("FFE4CC"),
		bottom = Color3.fromHex("FFC79E"),
	},
	{
		-- builds and upgrades in one window (issue 751): in the tidy grid only, so the old row never grows
		window = "Build",
		flag = "buildWindow",
		also = TIDY_FLAG,
		tidy = "main",
		tidyOrder = 2,
		icon = "Build",
		caption = "Build",
		top = Color3.fromHex("D7F0FF"),
		bottom = Color3.fromHex("A9DDFF"),
	},
	{
		window = "Checkin",
		tidy = "more",
		tidyOrder = 2,
		flag = "checkinCard",
		icon = "Gift",
		caption = "Gifts",
		top = Color3.fromHex("FFF1C2"),
		bottom = Color3.fromHex("FFD97A"),
	},
	{
		window = "Quests",
		tidy = "more",
		tidyOrder = 1,
		flag = "quests",
		attribute = "QuestsOpen", -- QuestViewRules.OPEN_ATTRIBUTE: QuestService sets it at 6:00 of play
		icon = "Quests",
		caption = "Quests",
		top = Color3.fromHex("D6F0FF"),
		bottom = Color3.fromHex("A9DCFB"),
	},
	{
		window = "Shop",
		tidy = "main",
		tidyOrder = 1,
		flag = "passes",
		icon = "Shop",
		caption = "Shop",
		top = Color3.fromHex("FFE9A8"),
		bottom = Color3.fromHex("FFC94D"),
	},
	{
		window = "Settings",
		tidy = "more",
		tidyOrder = 5,
		flag = "settingsCard",
		icon = "Settings",
		caption = "Settings",
		top = Color3.fromHex("ECE2FB"),
		bottom = Color3.fromHex("D9C7F5"),
	},
	{
		-- last in the row, so it never crowds the first minutes (starterpack.html "hud")
		window = "Starter",
		tidy = "ad",
		flag = "starterPack",
		also = "passes",
		attribute = "StarterEndsAt", -- StarterRules.ENDS_ATTRIBUTE: set only while the pack is offered
		icon = "Gift",
		caption = "Starter",
		top = Color3.fromHex("FFE98F"),
		bottom = Color3.fromHex("FFC94D"),
	},
} :: { Spec }

local SIZE_FULL, SIZE_SHORT = 76, 66 -- design px
local ICON = 52 -- design px: model icons are never drawn under 48
local GAP = 16
local CAPTION_ROOM = 22 -- design px under the buttons for their captions
local NOTE_ROOM = 46 -- and with a note chip under a caption
local EDGE = Vector2.new(16, 14) -- real px from the root's top left (the root starts under Roblox's top bar)
local TRAY_PAD = 10 -- design px inside the More tray's panel
local MORE_TOP, MORE_BOTTOM = Color3.fromHex("ECE2FB"), Color3.fromHex("D9C7F5")

-- The More button (switch hudTidy): it opens the tray with the "more" buttons.
local MORE_SPEC: Spec = {
	window = "More",
	flag = HUD_FLAG,
	icon = "",
	caption = "More",
	top = MORE_TOP,
	bottom = MORE_BOTTOM,
}

type Button = { spec: Spec, button: TextButton, iconBox: Frame, note: TextLabel }

local row: Frame? = nil
local rowScale: UIScale? = nil
local captionRoom: UIPadding? = nil
local lines: { Frame } = {} -- the row's two lines: with hudTidy the grid's top and bottom, else all in the first
local tray: Frame? = nil -- the More tray's panel
local trayScale: UIScale? = nil
local more: Button? = nil
local moreDot: Frame? = nil
local trayOpen = false
local buttons: { Button } = {}
local aside = false
-- Motion-FX's arrive motion (issue 528) for a button that unlocks while the player is here: buttons already there
-- when the row first shows arrive quietly; a later one plays once, as soon as the row is on screen.
local seen: { [string]: boolean } = {}
local settled = false
local pending: { [string]: TextButton } = {}
local starterAd: any = nil -- HUD/StarterAd, set by SideButtons.useAd

local function tidy(): boolean
	return LiveFlags.isOn(TIDY_FLAG)
end

local function shown(spec: Spec): boolean
	local attribute = spec.attribute
	if attribute then
		local value = Players.LocalPlayer:GetAttribute(attribute)
		if value == nil or value == false then
			return false
		end
	end
	local also = spec.also
	if also and not LiveFlags.isOn(also) then
		return false
	end
	local anyOf = spec.anyOf
	if anyOf then
		local found = false
		for _, name in anyOf do
			found = found or Players.LocalPlayer:GetAttribute(name) ~= nil
		end
		if not found then
			return false
		end
	end
	return LiveFlags.isOn(HUD_FLAG) and LiveFlags.isOn(spec.flag)
end

-- Where a button goes now: "row" (the old single row), "main", "more" or "ad".
local function place(spec: Spec): string
	if not tidy() then
		return "row"
	end
	return spec.tidy or "main"
end

local function anyMore(): boolean
	for _, spec in SideButtons.BUTTONS do
		if place(spec) == "more" and shown(spec) then
			return true
		end
	end
	return false
end

function SideButtons.any(): boolean
	for _, spec in SideButtons.BUTTONS do
		local at = place(spec)
		if (at == "row" or at == "main") and shown(spec) then
			return true
		end
	end
	return tidy() and anyMore()
end

function SideButtons.find(window: string): TextButton?
	if window == "Starter" and starterAd and starterAd.isOn() then
		return starterAd.button()
	end
	for _, entry in buttons do
		if entry.spec.window == window then
			return entry.button
		end
	end
	return nil
end

function SideButtons.onChanged(fn: () -> ())
	local names = { HUD_FLAG, TIDY_FLAG }
	for _, spec in SideButtons.BUTTONS do
		table.insert(names, spec.flag)
		local also = spec.also
		if also and not table.find(names, also) then
			table.insert(names, also)
		end
	end
	for _, name in names do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name):Connect(fn)
	end
	for _, spec in SideButtons.BUTTONS do
		local attribute = spec.attribute
		if attribute then
			Players.LocalPlayer:GetAttributeChangedSignal(attribute):Connect(fn)
		end
		local anyOf: { string } = spec.anyOf or {}
		for _, name in anyOf do
			Players.LocalPlayer:GetAttributeChangedSignal(name):Connect(fn)
		end
	end
end

local function order(entry: Button): number
	return entry.spec.tidyOrder or 0
end

local function redraw()
	local r, scale = row, rowScale
	if r == nil or scale == nil or #lines < 2 then
		return
	end
	local screenScale, short = Kit.screenScale()
	scale.Scale = screenScale
	local size = if short then SIZE_SHORT else SIZE_FULL
	local isTidy = tidy()
	if not isTidy or aside then
		trayOpen = false
	end
	local hasMore = isTidy and anyMore()
	if not hasMore then
		trayOpen = false
	end

	-- the grid's buttons in order (tidy), or the whole row in the list's order
	local mains: { Button } = {}
	local extras: { Button } = {}
	for _, entry in buttons do
		local at = place(entry.spec)
		local on = shown(entry.spec) and (at ~= "more" or trayOpen) and at ~= "ad"
		entry.button.Visible = on
		entry.button.Size = UDim2.fromOffset(size, size)
		entry.iconBox.Size = UDim2.fromOffset(math.min(ICON, size - 10), math.min(ICON, size - 10))
		if at == "more" then
			table.insert(extras, entry)
		elseif at ~= "ad" then
			table.insert(mains, entry)
		end
		if on then
			local window = entry.spec.window
			if not seen[window] then
				seen[window] = true
				if settled then
					pending[window] = entry.button
				end
			end
		end
	end
	local m = more
	if m then
		m.button.Visible = hasMore
		m.button.Size = UDim2.fromOffset(size, size)
		m.iconBox.Size = UDim2.fromOffset(math.min(ICON, size - 10), math.min(ICON, size - 10))
	end
	if isTidy then
		table.sort(mains, function(a, b)
			return order(a) < order(b)
		end)
		table.sort(extras, function(a, b)
			return order(a) < order(b)
		end)
		if m and hasMore then
			table.insert(mains, m)
		end
	end

	-- lay them out: two to a line with hudTidy, else one line
	local visible: { TextButton } = {}
	local count = 0
	for _, entry in mains do
		if entry.button.Visible then
			count += 1
			local line = if isTidy and count > 2 then lines[2] else lines[1]
			if entry.button.Parent ~= line then
				entry.button.Parent = line
			end
			entry.button.LayoutOrder = count
			table.insert(visible, entry.button)
		end
	end
	lines[2].Visible = isTidy and count > 2
	local t, tScale = tray, trayScale
	if t and tScale then
		tScale.Scale = screenScale
		local trayCount = 0
		for _, entry in extras do
			if entry.button.Parent ~= t then
				entry.button.Parent = t
			end
			if entry.button.Visible then
				trayCount += 1
				entry.button.LayoutOrder = trayCount
				table.insert(visible, entry.button)
			end
		end
		t.Visible = trayOpen and trayCount > 0 and not aside
		-- beside the grid, level with its top line
		local across = math.min(count, 2)
		t.Position = UDim2.fromOffset(
			EDGE.X + (across * (size + GAP) + GAP - TRAY_PAD) * screenScale,
			EDGE.Y - TRAY_PAD * screenScale
		)
	end
	settled = settled or #visible > 0
	for index, button in visible do
		button.NextSelectionLeft = visible[index - 1]
		button.NextSelectionRight = visible[index + 1]
	end
	local noted = false
	local moreNoted = false
	for _, entry in buttons do
		local at = place(entry.spec)
		if at == "more" then
			moreNoted = moreNoted or (shown(entry.spec) and entry.note.Visible)
		else
			noted = noted or (entry.button.Visible and entry.note.Visible)
		end
	end
	local dot = moreDot
	if dot then
		dot.Visible = moreNoted and not trayOpen
	end
	local room = captionRoom
	if room then
		room.PaddingBottom = UDim.new(0, if noted then NOTE_ROOM else CAPTION_ROOM)
	end
	local stack = r:FindFirstChildOfClass("UIListLayout") :: UIListLayout?
	if stack then
		stack.Padding = UDim.new(0, (if noted then NOTE_ROOM else CAPTION_ROOM) + 6)
	end
	r.Visible = #visible > 0 and not aside
	if r.Visible then
		for window, button in pending do
			pending[window] = nil
			if button.Visible and LiveFlags.isOn(ARRIVE_FLAG) then
				Arrive.play(button)
			end
		end
	end
end

-- A small chip under button `window`'s caption, or none with nil (the starter pack's time left; no seconds).
function SideButtons.setNote(window: string, text: string?)
	if window == "Starter" and starterAd then
		starterAd.setNote(text)
	end
	for _, entry in buttons do
		if entry.spec.window == window then
			entry.note.Visible = text ~= nil
			entry.note.Text = text or ""
		end
	end
	redraw()
end

function SideButtons.setAside(on: boolean)
	if starterAd then
		starterAd.setAside(on)
	end
	if aside ~= on then
		aside = on
		redraw()
	end
end

function SideButtons.isAside(): boolean
	return aside
end

-- True while the More tray is open (switch hudTidy).
function SideButtons.trayOpen(): boolean
	return trayOpen
end

-- Closes the More tray (a window opened, or a tap elsewhere).
function SideButtons.closeTray()
	if trayOpen then
		trayOpen = false
		redraw()
	end
end

-- Opens the More tray as the More button does (the UI gate's scene).
function SideButtons.openTray()
	if not trayOpen then
		trayOpen = true
		redraw()
	end
end

-- The starter pack's side ad takes the Starter button's place while hudTidy is on (HUD/StarterAd).
function SideButtons.useAd(ad: any)
	starterAd = ad
end

local function tile(spec: Spec, parent: Instance, index: number): Button
	local button = Instance.new("TextButton")
	button.Name = spec.window
	button.LayoutOrder = index
	button.Text = ""
	button.AutoButtonColor = true
	button.BackgroundColor3 = Kit.WHITE
	button.Selectable = true
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(spec.top, spec.bottom)
	g.Parent = button
	Kit.corner(button, UDim.new(0, 22))
	local edge = Kit.stroke(button, 4)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundTransparency = 1
	iconBox.AnchorPoint = Vector2.new(0.5, 0.5)
	iconBox.Position = UDim2.fromScale(0.5, 0.5)
	iconBox.Parent = button
	if spec.icon ~= "" then
		Icons.draw(spec.icon, iconBox)
	end
	local caption = Kit.outlined("Caption", button)
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 1, -6)
	caption.TextSize = 19
	caption.Text = spec.caption
	-- a small chip under the caption (SideButtons.setNote): the starter pack's time left
	local note = Instance.new("TextLabel")
	note.Name = "Note"
	note.AnchorPoint = Vector2.new(0.5, 0)
	note.Position = UDim2.new(0.5, 0, 1, 18)
	note.AutomaticSize = Enum.AutomaticSize.X
	note.Size = UDim2.fromOffset(0, 22)
	note.BackgroundColor3 = Kit.WHITE
	note.Font = Kit.FONT
	note.TextColor3 = Kit.INK
	note.TextSize = 17
	note.Visible = false
	Kit.minText(note)
	Kit.corner(note, UDim.new(0, 10))
	local noteEdge = Kit.stroke(note, 2)
	noteEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local notePad = Instance.new("UIPadding")
	notePad.PaddingLeft, notePad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	notePad.Parent = note
	note.Parent = button
	button.Parent = parent
	Motion.press(button) -- trial springs, switch springUi (#183)
	return { spec = spec, button = button, iconBox = iconBox, note = note }
end

-- Three round dots: the More button's picture (a drawn mark, not a model icon).
local function dots(box: Frame)
	local holder = Instance.new("Frame")
	holder.Name = "Dots"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 0.3)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.08, 0)
	list.Parent = holder
	for index = 1, 3 do
		local dot = Instance.new("Frame")
		dot.Name = `Dot{index}`
		dot.LayoutOrder = index
		dot.BackgroundColor3 = Kit.WHITE
		dot.Size = UDim2.fromScale(0.22, 0.22 / 0.3)
		Kit.corner(dot, UDim.new(0.5, 0))
		Kit.stroke(dot, 3)
		dot.Parent = holder
	end
	holder.Parent = box
end

local function line(name: string, parent: Instance, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = frame
	frame.Parent = parent
	return frame
end

function SideButtons.build(root: Instance, open: (window: string) -> ())
	local frame = Instance.new("Frame")
	frame.Name = "SideButtons"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(EDGE.X, EDGE.Y)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	frame.Visible = false
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = frame
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, CAPTION_ROOM + 6)
	stack.Parent = frame
	-- room under the buttons for their captions
	local pad = Instance.new("UIPadding")
	pad.Name = "CaptionRoom"
	pad.PaddingBottom = UDim.new(0, CAPTION_ROOM)
	pad.Parent = frame
	captionRoom = pad
	frame.Parent = root
	lines = { line("Top", frame, 1), line("Bottom", frame, 2) }

	-- the More tray (switch hudTidy): a cream panel beside the grid with the "more" buttons
	local panel = Instance.new("Frame")
	panel.Name = "MoreTray"
	panel.BackgroundColor3 = Kit.CREAM
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.Size = UDim2.fromOffset(0, 0)
	panel.Visible = false
	Kit.corner(panel, UDim.new(0, 24))
	local panelEdge = Kit.stroke(panel, 4)
	panelEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local panelScale = Instance.new("UIScale")
	panelScale.Name = "HudScale"
	panelScale.Parent = panel
	local panelList = Instance.new("UIListLayout")
	panelList.FillDirection = Enum.FillDirection.Horizontal
	panelList.SortOrder = Enum.SortOrder.LayoutOrder
	panelList.Padding = UDim.new(0, GAP)
	panelList.Parent = panel
	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingLeft, panelPad.PaddingRight = UDim.new(0, TRAY_PAD), UDim.new(0, TRAY_PAD)
	panelPad.PaddingTop, panelPad.PaddingBottom =
		UDim.new(0, TRAY_PAD), UDim.new(0, TRAY_PAD + CAPTION_ROOM)
	panelPad.Parent = panel
	panel.Parent = root
	tray, trayScale = panel, panelScale

	for index, spec in SideButtons.BUTTONS do
		local entry = tile(spec, lines[1], index)
		entry.button.Activated:Connect(function()
			if trayOpen then
				trayOpen = false
				redraw()
			end
			open(spec.window)
		end)
		table.insert(buttons, entry)
	end
	local moreEntry = tile(MORE_SPEC, lines[1], #SideButtons.BUTTONS + 1)
	dots(moreEntry.iconBox)
	moreEntry.button.Visible = false
	moreEntry.button:SetAttribute("Says", "More buttons")
	moreEntry.button.Activated:Connect(function()
		trayOpen = not trayOpen
		redraw()
	end)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -6, 0, 6)
	dot.Size = UDim2.fromOffset(18, 18)
	dot.BackgroundColor3 = Color3.fromHex("FF5A7A")
	dot.Visible = false
	Kit.corner(dot, UDim.new(0.5, 0))
	Kit.stroke(dot, 3)
	dot.Parent = moreEntry.button
	more, moreDot = moreEntry, dot

	row, rowScale = frame, scale
	SideButtons.onChanged(redraw)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

return SideButtons
