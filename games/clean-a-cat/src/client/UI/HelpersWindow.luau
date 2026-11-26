--!strict
-- HelpersWindow: the spa's helpers in one place (issue 526 item 3), behind the live switch helpersWindow with
-- workers, both off by default. Opened only from its HUD button (shown once a helper is hired), never by itself.
--
--   HelpersWindow.build(root)          makes the window once and returns its layer (UI registers "Helpers")
--   HelpersWindow.set(rows, rename, shop)  draws the rows (HelperViewRules.rows); `rename` adds each hired helper's
--                                      Rename button (switch staffRename), `shop` Lou's pass button (switch passes)
--   HelpersWindow.onMode(fn)           fn(id) when a helper's Takes button is pressed
--   HelpersWindow.onLevel(fn)          fn(id) when Level up is pressed
--   HelpersWindow.onRename(fn)         fn(id) when Rename is pressed
--   HelpersWindow.onPass(fn)           fn() when Lou's See the pass is pressed
--
-- One row per helper: their round picture, name and level, then Takes: <which waiting cat first> (tap to change),
-- and Level up with its coins; a pencil on the picture renames them. A helper not hired yet shows their price, paid at their pad by
-- the tubs (hiring stays there, so the player sees where they will work); Lou says he comes with his pass. The
-- buttons ask; the row changes only when the server's WorkerLevel_<id> and WorkerMode_<id> come back. UI never
-- fires remotes: HelpersController asks the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HelperViewRules = require(Shared:WaitForChild("HelperViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local HelpersWindow = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local SOFT_TOP, SOFT_BOTTOM = Color3.fromHex("FFF6EC"), Color3.fromHex("ECDCCA")
local GOLD_TOP, GOLD_BOTTOM = Color3.fromHex("FFE9A8"), Color3.fromHex("FFC94D")
local WHO_FILL = Color3.fromHex("E8F7FF")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 8 -- design px below the middle on a short screen
local MIN_TAP = 44 -- real px
local BUTTON_PAD = 28 -- design px of face beside a button's words

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 900,
		band = 72,
		title = 38,
		badge = 96,
		pad = 18,
		gap = 10,
		rowH = 96,
		who = 68,
		pencil = 26,
		name = 24,
		say = 18,
		button = 56,
		buttonText = 20,
	},
	short = {
		width = 860,
		band = 56,
		title = 32,
		badge = 80,
		pad = 12,
		gap = 6,
		rowH = 80,
		who = 64, -- 48 real px at the smallest scale: the Rename tap
		pencil = 24,
		name = 21,
		say = 16,
		button = 52,
		buttonText = 19,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	stack: UIListLayout,
	rowsFrame: Frame,
}

local parts: Parts? = nil
local rows: { HelperViewRules.Row } = {}
local canRename = false
local canShop = false
local modeListeners: { (id: string) -> () } = {}
local levelListeners: { (id: string) -> () } = {}
local renameListeners: { (id: string) -> () } = {}
local passListeners: { () -> () } = {}

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function words(name: string, parent: Instance, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Kit.FONT
	label.TextColor3 = Kit.INK
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	Kit.minText(label)
	label.Parent = parent
	return label
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

-- Design px the words take at `size`.
local function measure(text: string, size: number): number
	return TextService:GetTextSize(text, size, Kit.FONT, Vector2.new(2000, 200)).X
end

local function tell(listeners: { (id: string) -> () }, id: string)
	for _, listener in listeners do
		task.spawn(listener, id)
	end
end

-- The Takes button is as wide as its longest words, so it never jumps as the mode changes.
local function modeWidth(s: Sizes): number
	local widest = 0
	for _, mode in WorkerRules.MODES do
		widest = math.max(widest, measure(`Takes: {WorkerRules.MODE_NAMES[mode]}`, s.buttonText))
	end
	return math.ceil(widest) + BUTTON_PAD
end

local function levelWidth(s: Sizes): number
	local widest = 0
	for _, cost in WorkerRules.LEVEL_COST do
		widest = math.max(widest, measure(`Level up · {cost}`, s.buttonText))
	end
	return math.ceil(widest) + BUTTON_PAD
end

local function drawRow(row: HelperViewRules.Row, order: number, s: Sizes, parent: Frame)
	local scale = Kit.screenScale()
	local tap = math.ceil(MIN_TAP / scale)
	local buttonH = math.max(s.button, tap)

	local card = frame(row.id, parent)
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, math.max(s.rowH, buttonH + 12))
	card.BackgroundTransparency = if row.hired then 0 else 0.35
	card.BackgroundColor3 = Kit.WHITE
	Kit.corner(card, UDim.new(0, 18))
	local edge = Kit.stroke(card, 3)
	edge.Color = Kit.LINE
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = card

	local who = frame("Who", card)
	who.AnchorPoint = Vector2.new(0, 0.5)
	who.Position = UDim2.fromScale(0, 0.5)
	who.Size = UDim2.fromOffset(s.who, s.who)
	who.BackgroundTransparency = 0
	who.BackgroundColor3 = WHO_FILL
	Kit.corner(who, UDim.new(0.5, 0))
	Kit.stroke(who, 3)
	local whoIcon = frame("Icon", who)
	whoIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	whoIcon.Position = UDim2.fromScale(0.5, 0.5)
	whoIcon.Size = UDim2.fromScale(0.7, 0.7)
	Icons.draw(if row.hired then "Helpers" elseif row.pass then "Star" else "Coins", whoIcon)
	local id = row.id
	if row.hired and canRename then
		-- the round picture is the Rename button, with a pencil on it, as in the Pets window (issue 487)
		local rename = Instance.new("TextButton")
		rename.Name = "Rename"
		rename.BackgroundTransparency = 1
		rename.Text = ""
		rename.Size = UDim2.fromScale(1, 1)
		rename.ZIndex = 4
		rename:SetAttribute("Says", `Rename {row.name}`)
		rename.Parent = who
		rename.Activated:Connect(function()
			tell(renameListeners, id)
		end)
		local pencil = frame("Pencil", who)
		pencil.AnchorPoint = Vector2.new(0.5, 0.5)
		pencil.Position = UDim2.fromScale(0.86, 0.86)
		pencil.Size = UDim2.fromOffset(s.pencil, s.pencil)
		pencil.BackgroundTransparency = 0
		pencil.BackgroundColor3 = Kit.WHITE
		pencil.ZIndex = 3
		Kit.corner(pencil, UDim.new(0.5, 0))
		Kit.stroke(pencil, 2)
		Icons.draw("Pencil", pencil)
	end

	-- the buttons, right to left: Level up, Takes (or Lou's pass)
	local right = frame("Buttons", card)
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.fromScale(1, 0.5)
	right.AutomaticSize = Enum.AutomaticSize.X
	right.Size = UDim2.fromOffset(0, buttonH)
	local rightList = Instance.new("UIListLayout")
	rightList.FillDirection = Enum.FillDirection.Horizontal
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, 8)
	rightList.Parent = right
	local used = 0
	if row.hired then
		local mode =
			Window.button("Mode", HelperViewRules.modeText(row), right, SOFT_TOP, SOFT_BOTTOM)
		mode.LayoutOrder = 1
		mode.TextColor3 = Kit.INK
		mode.TextStrokeTransparency = 1
		mode.TextSize = s.buttonText
		local modeW = modeWidth(s)
		mode.Size = UDim2.fromOffset(modeW, buttonH)
		mode:SetAttribute("Says", `{row.name} takes {row.modeName}. Tap to change`)
		mode.Activated:Connect(function()
			tell(modeListeners, id)
		end)
		used += modeW + 8
		local levelText = HelperViewRules.levelText(row)
		if levelText then
			local level = Window.button("Level", levelText, right, GREEN_TOP, GREEN_BOTTOM)
			level.LayoutOrder = 2
			level.TextSize = s.buttonText
			local levelW = levelWidth(s)
			level.Size = UDim2.fromOffset(levelW, buttonH)
			level:SetAttribute("Says", `Level up {row.name} for {row.nextCost} coins`)
			level.Activated:Connect(function()
				tell(levelListeners, id)
			end)
			used += levelW + 8
		end
	elseif row.pass and canShop then
		local text = "See the pass"
		local pass = Window.button("Pass", text, right, GOLD_TOP, GOLD_BOTTOM)
		pass.LayoutOrder = 1
		pass.TextColor3 = Kit.INK
		pass.TextStrokeTransparency = 1
		pass.TextSize = s.buttonText
		local passW = math.ceil(measure(text, s.buttonText)) + BUTTON_PAD
		pass.Size = UDim2.fromOffset(passW, buttonH)
		pass:SetAttribute("Says", "See the Lou pass in the Shop")
		pass.Activated:Connect(function()
			for _, listener in passListeners do
				task.spawn(listener)
			end
		end)
		used += passW + 8
	end

	local text = frame("Text", card)
	text.Position = UDim2.fromOffset(s.who + 12, 0)
	text.Size = UDim2.new(1, -(s.who + 12 + used + 4), 1, 0)
	local textList = Instance.new("UIListLayout")
	textList.SortOrder = Enum.SortOrder.LayoutOrder
	textList.VerticalAlignment = Enum.VerticalAlignment.Center
	textList.Parent = text
	local name = words("Name", text, s.name)
	name.LayoutOrder = 1
	name.Size = UDim2.new(1, 0, 0, s.name + 6)
	Kit.shrinkToFit(name, s.name)
	name.Text = row.name
	local say = words("Says", text, s.say)
	say.LayoutOrder = 2
	say.FontFace = Kit.BODY_FACE
	say.TextColor3 = Kit.INK_SOFT
	say.Size = UDim2.new(1, 0, 0, s.say + 6)
	Kit.shrinkToFit(say, s.say)
	say.Text = HelperViewRules.say(row)
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	local width = math.min(s.width, screenWidth(scale) - SCREEN_MARGIN)
	Window.fit(p.window, width, s.band, s.title, s.badge, if short then SHORT_SHIFT else nil)
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad - 4), pad
	p.stack.Padding = UDim.new(0, s.gap)
	for _, child in p.rowsFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, row in rows do
		drawRow(row, index, s, p.rowsFrame)
	end
end

function HelpersWindow.set(newRows: { HelperViewRules.Row }, rename: boolean, shop: boolean)
	rows, canRename, canShop = newRows, rename, shop
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function HelpersWindow.onMode(fn: (id: string) -> ())
	table.insert(modeListeners, fn)
end

function HelpersWindow.onLevel(fn: (id: string) -> ())
	table.insert(levelListeners, fn)
end

function HelpersWindow.onRename(fn: (id: string) -> ())
	table.insert(renameListeners, fn)
end

function HelpersWindow.onPass(fn: () -> ())
	table.insert(passListeners, fn)
end

function HelpersWindow.build(root: Instance): Frame
	local window = Window.new(HelperViewRules.WINDOW, "Helpers", "Helpers", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
		end
	end)

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local rowsFrame = frame("Rows", window.body)
	rowsFrame.AutomaticSize = Enum.AutomaticSize.Y
	rowsFrame.Size = UDim2.fromScale(1, 0)
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 10)
	stack.Parent = rowsFrame

	parts = { window = window, pad = pad, stack = stack, rowsFrame = rowsFrame }
	for _, flag in { HelperViewRules.FLAG, WorkerRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				if
					not (LiveFlags.isOn(HelperViewRules.FLAG) and LiveFlags.isOn(WorkerRules.FLAG))
				then
					window.layer.Visible = false
				end
			end)
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

return HelpersWindow
