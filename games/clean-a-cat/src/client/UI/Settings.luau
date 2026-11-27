--!strict
-- Settings: the Settings card (#230), from Design-Agent's draft (settings.html). Behind the live switch settingsCard,
-- off by default: while it is off the starter Menu opens the example window as before and nothing here shows.
--
--   Settings.build(root, onChange)   makes the window once and returns its layer (UI registers it as "Settings")
--   Settings.show(settings)          draws these values (a SettingsRules.Settings)
--
-- Rows: the Music and Sounds sliders (the whole slider is the touch area; a gamepad press steps it a quarter down
-- to 0 and back up), then
-- Less screen shake and Less sparkle as switches that say On or Off in words, then "Odds on boards", an info line
-- with no switch because the game never hides odds. A wide screen has one column; a phone held sideways has two, so
-- nothing scrolls. Nothing here is destructive. UI never fires remotes: onChange(settings) runs on every change and
-- SettingsController applies it.
--
-- "Visitors can come in" (issue 520, switch visiting) is a switch row like the others, but its value is the server's
-- (the Player attribute VisitorsAllowed, nil while visiting is off, and then the row is hidden): a press asks the
-- server (SettingsCard.onVisitors) and the switch moves only when the server's answer comes back (setVisitors).
--
-- "Tips on screen" from the draft waits until the game has tips to turn off: a switch that does nothing would mislead.
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SettingsRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local SettingsCard = {}

type Settings = SettingsRules.Settings
type RowKind = "slider" | "toggle" | "info"
type RowSpec = { key: string, kind: RowKind, icon: string, say: string, detail: string? }

local ROWS: { RowSpec } = {
	{ key = "music", kind = "slider", icon = "Music", say = "Music" },
	{ key = "sounds", kind = "slider", icon = "Speaker", say = "Sounds" },
	{
		key = "lessShake",
		kind = "toggle",
		icon = "Shake",
		say = "Less screen shake",
		detail = "Softer bumps",
	},
	{
		key = "lessSparkle",
		kind = "toggle",
		icon = "Sparkle",
		say = "Less sparkle",
		detail = "Fewer flashes",
	},
	{
		key = "visitors",
		kind = "toggle",
		icon = "Helper",
		say = "Visitors can come in",
		detail = "Others may visit your spa",
	},
	{
		key = "odds",
		kind = "info",
		icon = "Dice",
		say = "Odds on boards",
		detail = "Always shown, for every cat",
	},
}
local SHORT_FIRST_COLUMN = 3 -- rows in the left column on a short screen

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local OFF_TOP, OFF_BOTTOM = Color3.fromHex("E4DBD2"), Color3.fromHex("CFC2B4")
local TRACK = Color3.fromHex("F7E9DA")
local FILL_TOP, FILL_BOTTOM = Color3.fromHex("BFE9FF"), Color3.fromHex("4FB4F0")
local THUMB = 48 -- design px: the slider's bubble
local SLIDER_TOUCH = 60 -- design px tall: the slider's touch area, 45 real px at the smallest scale (44 needed)
local TRACK_HEIGHT = 18
local SCREEN_MARGIN = 64 -- design px kept clear beside the window

-- Sizes in design pixels: full, then compact for a short screen.
local SIZES = {
	full = {
		width = 760,
		band = 72,
		title = 38,
		badge = 96,
		padX = 26,
		padY = 12,
		gap = 26,
		row = 74,
		icon = 40,
		label = 24,
		detail = 19,
		sliderLabel = 150,
		switchW = 92,
		switchH = 46,
		knob = 34,
	},
	short = {
		width = 900,
		band = 56,
		title = 32,
		badge = 80,
		padX = 18,
		padY = 6,
		gap = 26,
		row = 74,
		icon = 34,
		label = 22,
		detail = 19,
		sliderLabel = 86,
		switchW = 86,
		switchH = 44,
		knob = 32,
	},
}
type Sizes = typeof(SIZES.full)

type Row = {
	spec: RowSpec,
	frame: GuiObject,
	line: Frame,
	iconBox: Frame,
	words: Frame,
	say: TextLabel,
	detail: TextLabel?,
	-- slider rows
	slider: TextButton?,
	fill: Frame?,
	thumb: Frame?,
	-- toggle rows
	switch: Frame?,
	switchGradient: UIGradient?,
	switchWord: TextLabel?,
	knob: Frame?,
	-- info rows
	check: Frame?,
}

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	columns: { Frame },
	rows: { Row },
	reset: TextButton,
	feedback: TextButton,
}

local parts: Parts? = nil
local current: Settings = SettingsRules.defaults()
local changed: ((Settings) -> ())? = nil
local visitors: boolean? = nil -- the server's VisitorsAllowed; nil hides the row
local visitorListeners: { (allowed: boolean) -> () } = {}
-- "Reset my game" (issue 1037, switch resetSave): shown only while the server says CanResetSave; the first tap arms it,
-- a second tap within ARM_SECONDS asks the server, so one stray tap never wipes a save
local canReset = false
local resetListeners: { () -> () } = {}
local armedAt: number? = nil
local ARM_SECONDS = 4
local RESET_TOP, RESET_BOTTOM = Color3.fromHex("FF7062"), Color3.fromHex("E83A3A")
local RESET_TEXT = "Reset my game"
local RESET_SURE = "Tap again to wipe it all"
-- "Send feedback" (issue 1081, switch feedback): opens the Feedback card; after a send it thanks, and after
-- FeedbackRules.PER_VISIT sends this visit it stops offering
local feedbackOn = false
local feedbackSent = 0
local feedbackMax = 3
local feedbackListeners: { () -> () } = {}
local FEEDBACK_TOP, FEEDBACK_BOTTOM = Color3.fromHex("C9A8FF"), Color3.fromHex("9A6BEA")
local FEEDBACK_TEXT = "Send feedback"
local FEEDBACK_MORE = "Sent, thank you! Send more"
local FEEDBACK_DONE = "Sent, thank you!"

-- A switch row's value: the visitors row reads the server's, the others the saved settings.
local function toggleOn(key: string): boolean
	if key == "visitors" then
		return visitors == true
	end
	return if key == "lessShake" then current.lessShake else current.lessSparkle
end

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function words(name: string, parent: Instance, font: Enum.Font, colour: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = colour
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AutomaticSize = Enum.AutomaticSize.X
	Kit.minText(label)
	label.Parent = parent
	return label
end

local function gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
	return g
end

local function level(key: string): number
	return if key == "music" then current.music else current.sounds
end

local function setValue(key: string, value: any)
	local copy = table.clone(current) :: { [string]: any }
	copy[key] = value
	current = copy :: any
	local fn = changed
	if fn then
		fn(table.clone(current) :: any)
	end
end

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last.Name:sub(1, 7) == "Gamepad"
end

local redraw: () -> ()

-- The whole slider takes the press: a touch or click jumps the bubble there and dragging moves it; a gamepad
-- press steps it a quarter, down to 0 and back up (SettingsRules.step).
local function wireSlider(row: Row, slider: TextButton, thumb: Frame)
	local dragging: InputObject? = nil
	local direction = -1 -- a gamepad press first turns a full slider down
	local function moveTo(x: number)
		local value = SettingsRules.fromPointer(
			x,
			slider.AbsolutePosition.X,
			slider.AbsoluteSize.X,
			thumb.AbsoluteSize.X
		)
		setValue(row.spec.key, value)
		redraw()
	end
	slider.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = input
			moveTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local active = dragging
		if active == nil then
			return
		end
		if input == active or input.UserInputType == Enum.UserInputType.MouseMovement then
			moveTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local active = dragging
		if
			active ~= nil
			and (input == active or input.UserInputType == Enum.UserInputType.MouseButton1)
		then
			dragging = nil
		end
	end)
	slider.Activated:Connect(function()
		if usingGamepad() then
			local nextLevel, nextDirection = SettingsRules.step(level(row.spec.key), direction)
			direction = nextDirection
			setValue(row.spec.key, nextLevel)
			redraw()
		end
	end)
end

local function buildRow(spec: RowSpec, parent: Instance, order: number): Row
	local holder: GuiObject
	if spec.kind == "toggle" then
		-- A switch row is pressable anywhere along its length.
		local button = Instance.new("TextButton")
		button.Name = spec.key
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.Parent = parent
		holder = button
	else
		holder = frame(spec.key, parent)
	end
	holder.LayoutOrder = order

	local line = frame("Line", holder)
	line.BackgroundTransparency = 0
	line.BackgroundColor3 = Kit.line()
	line.Size = UDim2.new(1, 0, 0, 3)

	local iconBox = frame("IconBox", holder)
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	Icons.draw(spec.icon, iconBox)

	local block = frame("Words", holder)
	block.AnchorPoint = Vector2.new(0, 0.5)
	block.AutomaticSize = Enum.AutomaticSize.X -- its height is set in redraw, so the words sit centred in the row
	local blockList = Instance.new("UIListLayout")
	blockList.SortOrder = Enum.SortOrder.LayoutOrder
	blockList.Padding = UDim.new(0, 4)
	blockList.Parent = block
	local say = words("Say", block, Kit.FONT, Kit.INK)
	say.LayoutOrder = 1
	say.Text = spec.say
	local detail: TextLabel? = nil
	if spec.detail then
		local d = words("Detail", block, Kit.FONT, Kit.INK_SOFT)
		d.FontFace = Kit.BODY_FACE
		d.LayoutOrder = 2
		d.Text = spec.detail
		detail = d
	end

	local row: Row = {
		spec = spec,
		frame = holder,
		line = line,
		iconBox = iconBox,
		words = block,
		say = say,
		detail = detail,
	}

	if spec.kind == "slider" then
		local slider = Instance.new("TextButton")
		slider.Name = "Slider"
		slider.Text = ""
		slider.AutoButtonColor = false
		slider.BackgroundTransparency = 1
		slider.AnchorPoint = Vector2.new(1, 0.5)
		slider.Parent = holder
		local track = frame("Track", slider)
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.fromScale(0, 0.5)
		track.Size = UDim2.new(1, 0, 0, TRACK_HEIGHT)
		track.BackgroundTransparency = 0
		track.BackgroundColor3 = TRACK
		track.ClipsDescendants = true
		Kit.corner(track, UDim.new(0.5, 0))
		Kit.stroke(track, 3)
		local fill = frame("Fill", track)
		fill.BackgroundTransparency = 0
		fill.BackgroundColor3 = Kit.WHITE
		gradient(fill, FILL_TOP, FILL_BOTTOM)
		Kit.corner(fill, UDim.new(0.5, 0)) -- round like its track: a corner never clips a child (issue 1062)
		local thumb = frame("Thumb", slider)
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)
		thumb.Size = UDim2.fromOffset(THUMB, THUMB)
		thumb.BackgroundTransparency = 0
		thumb.BackgroundColor3 = Color3.fromHex("E8F7FF")
		Kit.corner(thumb, UDim.new(0.5, 0))
		Kit.stroke(thumb, 4)
		row.slider, row.fill, row.thumb = slider, fill, thumb
		wireSlider(row, slider, thumb)
	elseif spec.kind == "toggle" then
		local switch = frame("Switch", holder)
		switch.AnchorPoint = Vector2.new(1, 0.5)
		switch.BackgroundTransparency = 0
		switch.BackgroundColor3 = Kit.WHITE
		Kit.corner(switch, UDim.new(0.5, 0))
		Kit.stroke(switch, 4)
		local switchGradient = gradient(switch, OFF_TOP, OFF_BOTTOM)
		local word = words("Word", switch, Kit.FONT, Kit.INK)
		word.AnchorPoint = Vector2.new(0.5, 0.5)
		word.AutomaticSize = Enum.AutomaticSize.None
		word.TextXAlignment = Enum.TextXAlignment.Center
		word.Size = UDim2.fromScale(0.55, 1)
		local knob = frame("Knob", switch)
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.BackgroundTransparency = 0
		knob.BackgroundColor3 = Kit.WHITE
		Kit.corner(knob, UDim.new(0.5, 0))
		Kit.stroke(knob, 3)
		row.switch, row.switchGradient, row.switchWord, row.knob =
			switch, switchGradient, word, knob
		local button = holder :: TextButton
		button.Activated:Connect(function()
			local key = spec.key
			if key == "visitors" then
				local now = visitors
				if now == nil then
					return
				end
				for _, listener in visitorListeners do
					task.spawn(listener, not now)
				end
				return
			end
			setValue(key, not toggleOn(key))
			redraw()
		end)
	else
		local check = frame("Check", holder)
		check.AnchorPoint = Vector2.new(1, 0.5)
		Icons.draw("Check", check)
		row.check = check
	end
	return row
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

redraw = function()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	local width = math.min(s.width, screenWidth(scale) - SCREEN_MARGIN)
	-- with the reset button on a short screen the card is taller: it sits a little higher, as the Helpers window does
	local extra = canReset or feedbackOn
	Window.fit(p.window, width, s.band, s.title, s.badge, if short and extra then 8 else nil)

	local padding = p.pad
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, s.padX), UDim.new(0, s.padX)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, s.padY), UDim.new(0, s.padY + 6)
	local inner = width - 2 * s.padX
	local columnWidth = if short then (inner - s.gap) / 2 else inner
	p.columns[2].Visible = short
	for index, column in p.columns do
		column.Size = UDim2.fromOffset(columnWidth, 0)
		column.LayoutOrder = index
	end

	local inColumn = { 0, 0 }
	local shown = 0
	for _, row in p.rows do
		local visible = row.spec.key ~= "visitors" or visitors ~= nil
		row.frame.Visible = visible
		if not visible then
			continue
		end
		shown += 1
		local columnIndex = if short and shown > SHORT_FIRST_COLUMN then 2 else 1
		row.frame.Parent = p.columns[columnIndex]
		inColumn[columnIndex] += 1
		row.line.Visible = inColumn[columnIndex] > 1
		row.frame.Size = UDim2.new(1, 0, 0, s.row)
		row.iconBox.Size = UDim2.fromOffset(s.icon, s.icon)
		row.iconBox.Position = UDim2.new(0, 2, 0.5, 0)
		row.words.Position = UDim2.new(0, s.icon + 14, 0.5, 0)
		row.say.TextSize = s.label
		row.say.Size = UDim2.fromOffset(0, s.label + 2)
		local detail = row.detail
		local blockHeight = s.label + 2
		if detail then
			detail.TextSize = s.detail
			detail.Size = UDim2.fromOffset(0, s.detail + 2)
			blockHeight += 4 + s.detail + 2
		end
		row.words.Size = UDim2.fromOffset(0, blockHeight)
		local slider, fill, thumb = row.slider, row.fill, row.thumb
		if slider and fill and thumb then
			local left = s.icon + 14 + s.sliderLabel
			slider.Position = UDim2.new(1, -4, 0.5, 0)
			slider.Size = UDim2.new(1, -left - 4, 0, SLIDER_TOUCH)
			local value = level(row.spec.key)
			-- the bubble's middle travels from THUMB / 2 to the width less THUMB / 2 (SettingsRules.thumbCentre)
			thumb.Position = UDim2.new(value, THUMB / 2 - THUMB * value, 0.5, 0)
			fill.Size = UDim2.new(value, THUMB / 2 - THUMB * value, 1, 0)
		end
		local switch, switchGradient, word, knob =
			row.switch, row.switchGradient, row.switchWord, row.knob
		if switch and switchGradient and word and knob then
			local on = toggleOn(row.spec.key)
			switch.Size = UDim2.fromOffset(s.switchW, s.switchH)
			switch.Position = UDim2.new(1, -4, 0.5, 0)
			switchGradient.Color = if on
				then ColorSequence.new(GREEN_TOP, GREEN_BOTTOM)
				else ColorSequence.new(OFF_TOP, OFF_BOTTOM)
			word.Text = if on then "On" else "Off"
			word.TextSize = 19
			word.Position = UDim2.fromScale(if on then 0.32 else 0.68, 0.5)
			knob.Size = UDim2.fromOffset(s.knob, s.knob)
			knob.Position = if on
				then UDim2.new(1, -s.knob - 3, 0.5, 0)
				else UDim2.new(0, 3, 0.5, 0)
		end
		local check = row.check
		if check then
			check.Size = UDim2.fromOffset(s.icon, s.icon)
			check.Position = UDim2.new(1, -14, 0.5, 0)
		end
	end
	-- the reset button goes under the shorter column, so it never pushes the window off a short screen
	p.reset.Parent = p.columns[if short then 2 else 1]
	p.reset.Size = UDim2.new(1, 0, 0, if short then 60 else 64) -- 44 real px at the smallest scale
	p.reset.Visible = canReset
	-- with both buttons on a short screen, feedback goes under the first column and reset under the second, so
	-- neither column runs off a small phone (Visitors, Send feedback and Reset all shown on a dev server)
	p.feedback.Parent = p.columns[if short and not canReset then 2 else 1]
	p.feedback.Size = UDim2.new(1, 0, 0, if short then 60 else 64)
	p.feedback.Visible = feedbackOn
	local done = feedbackSent >= feedbackMax
	p.feedback.Text = if done
		then FEEDBACK_DONE
		elseif feedbackSent > 0 then FEEDBACK_MORE
		else FEEDBACK_TEXT
	p.feedback.Active = not done
	p.feedback.AutoButtonColor = not done
end

-- The server's CanResetSave: whether the "Reset my game" button shows (issue 1037).
function SettingsCard.setCanReset(allowed: boolean)
	canReset = allowed
	redraw()
	local p = parts
	if p then
		if not allowed then
			armedAt = nil
			p.reset.Text = RESET_TEXT
		end
	end
end

-- Whether "Send feedback" shows (switch feedback), how many were sent this visit, and the most a visit allows.
function SettingsCard.setFeedback(on: boolean, sent: number, most: number)
	feedbackOn, feedbackSent, feedbackMax = on, sent, most
	redraw()
end

-- fn() when "Send feedback" is pressed (the UI opens the Feedback card).
function SettingsCard.onFeedback(fn: () -> ())
	table.insert(feedbackListeners, fn)
end

-- fn() when "Reset my game" is pressed twice.
function SettingsCard.onReset(fn: () -> ())
	table.insert(resetListeners, fn)
end

-- The server's VisitorsAllowed (nil hides the row).
function SettingsCard.setVisitors(allowed: boolean?)
	visitors = allowed
	redraw()
end

-- fn(allowed) when the visitors switch is pressed; the switch waits for setVisitors.
function SettingsCard.onVisitors(fn: (allowed: boolean) -> ())
	table.insert(visitorListeners, fn)
end

function SettingsCard.show(settings: Settings)
	current = table.clone(settings) :: any
	redraw()
end

function SettingsCard.build(root: Instance, onChange: (Settings) -> ()): Frame
	changed = onChange
	local window = Window.new("Settings", "Settings", "Gear", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local columnsList = Instance.new("UIListLayout")
	columnsList.FillDirection = Enum.FillDirection.Horizontal
	columnsList.SortOrder = Enum.SortOrder.LayoutOrder
	columnsList.Padding = UDim.new(0, SIZES.full.gap)
	columnsList.Parent = window.body

	local columns: { Frame } = {}
	for index = 1, 2 do
		local column = frame(`Column{index}`, window.body)
		column.AutomaticSize = Enum.AutomaticSize.Y
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = column
		columns[index] = column
	end

	local rows: { Row } = {}
	for index, spec in ROWS do
		rows[index] = buildRow(spec, columns[1], index)
	end

	local reset = Window.button("Reset", RESET_TEXT, columns[1], RESET_TOP, RESET_BOTTOM)
	reset.LayoutOrder = 999
	reset.TextSize = 22
	reset.Visible = false
	reset:SetAttribute("Says", "Reset my game: wipes the save and starts again from the beginning")
	reset.Activated:Connect(function()
		local at = armedAt
		if at and os.clock() - at <= ARM_SECONDS then
			armedAt = nil
			reset.Text = "Resetting..."
			for _, listener in resetListeners do
				task.spawn(listener)
			end
			-- the server kicks to rejoin; if it refused, the button reads as before (Review-QA on #1056)
			task.delay(ARM_SECONDS * 2, function()
				if reset.Parent and armedAt == nil then
					reset.Text = RESET_TEXT
				end
			end)
			return
		end
		local mine = os.clock()
		armedAt = mine
		reset.Text = RESET_SURE
		task.delay(ARM_SECONDS, function()
			if armedAt == mine then
				armedAt = nil
				reset.Text = RESET_TEXT
			end
		end)
	end)

	local feedback =
		Window.button("Feedback", FEEDBACK_TEXT, columns[1], FEEDBACK_TOP, FEEDBACK_BOTTOM)
	feedback.LayoutOrder = 998
	feedback.TextSize = 22
	feedback.Visible = false
	feedback:SetAttribute("Says", "Send feedback: tell us what you think")
	feedback.Activated:Connect(function()
		if feedbackSent >= feedbackMax then
			return
		end
		for _, listener in feedbackListeners do
			task.spawn(listener)
		end
	end)

	parts = {
		window = window,
		pad = pad,
		columns = columns,
		rows = rows,
		reset = reset,
		feedback = feedback,
	}
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

return SettingsCard
