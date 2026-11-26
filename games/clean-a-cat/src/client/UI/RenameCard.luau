--!strict
-- RenameCard: name a hired helper (issue 487, switch staffRename). Opened from the helper's row in the Pets window,
-- never by itself.
--
--   RenameCard.build(root)              makes the window once and returns its layer ("Rename")
--   RenameCard.show(id, shown, default) fills it for helper `id`: the name shown now and the default name
--   RenameCard.onSave(fn)               fn(id, text) when Save is pressed ("" from Use <default>)
--
-- One text box (at most StaffNameRules.MAX_LENGTH letters, numbers and spaces, the default name as its placeholder),
-- Save, and "Use Jo" to go back to the default. The card closes on Save: the new name shows only once the server has
-- run it through Roblox's text filter and sent it back (StaffName_<id>), never the typed text. UI never fires
-- remotes: StaffNameController asks the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local StaffNameRules = require(Shared:WaitForChild("StaffNameRules"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local RenameCard = {}

RenameCard.WINDOW = "Rename"

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local SOFT_TOP, SOFT_BOTTOM = Color3.fromHex("FFF6EC"), Color3.fromHex("ECDCCA")
local SCREEN_MARGIN = 64
local SHORT_SHIFT = -40 -- design px above the middle on a short screen: the phone's keyboard comes up from below
local MIN_TAP = 44 -- real px

local SIZES = {
	full = {
		width = 560,
		band = 72,
		title = 34,
		badge = 96,
		pad = 20,
		box = 64,
		boxText = 28,
		button = 60,
		text = 24,
		note = 16,
	},
	short = {
		width = 520,
		band = 56,
		title = 28,
		badge = 80,
		pad = 12,
		box = 56,
		boxText = 24,
		button = 54,
		text = 21,
		note = 15,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	stack: UIListLayout,
	box: TextBox,
	buttons: Frame,
	save: TextButton,
	reset: TextButton,
	note: TextLabel,
}

local parts: Parts? = nil
local workerId: string? = nil
local defaultName = ""
local saveListeners: { (id: string, text: string) -> () } = {}

local function words(name: string, parent: Instance, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Kit.FONT
	label.TextColor3 = Kit.INK
	label.TextSize = size
	Kit.minText(label)
	label.Parent = parent
	return label
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
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
		pad, pad, UDim.new(0, s.pad + 2), pad
	p.window.title.Text = if defaultName ~= "" then `Name {defaultName}` else "Name your helper"
	local tap = math.ceil(MIN_TAP / scale)
	p.box.Size = UDim2.new(1, 0, 0, math.max(s.box, tap))
	p.box.TextSize = s.boxText
	p.box.PlaceholderText = defaultName
	p.buttons.Size = UDim2.new(1, 0, 0, math.max(s.button, tap))
	p.save.TextSize = s.text
	p.reset.TextSize = s.text
	p.reset.Text = `Use {defaultName}`
	p.note.TextSize = s.note
	p.note.Size = UDim2.fromScale(1, 0) -- as tall as its wrapped lines: the floor draws 16 as 19 (issue 669)
end

-- Keeps what is typed to the letters, numbers and spaces a name may have, at most MAX_LENGTH of them.
local function tidy(box: TextBox)
	local kept = string.sub(string.gsub(box.Text, "[^%w ]", ""), 1, StaffNameRules.MAX_LENGTH)
	if kept ~= box.Text then
		box.Text = kept
	end
end

function RenameCard.show(id: string, shown: string, default: string)
	workerId, defaultName = id, default
	local p = parts
	if p then
		p.box.Text = if shown ~= default then shown else ""
		redraw()
	end
end

function RenameCard.onSave(fn: (id: string, text: string) -> ())
	table.insert(saveListeners, fn)
end

local function send(text: string)
	local p = parts
	local id = workerId
	if p == nil or id == nil then
		return
	end
	p.window.layer.Visible = false
	for _, listener in saveListeners do
		task.spawn(listener, id, text)
	end
end

function RenameCard.build(root: Instance): Frame
	local window = Window.new(RenameCard.WINDOW, "Name your helper", "Helpers", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 12)
	stack.Parent = window.body

	local box = Instance.new("TextBox")
	box.Name = "Name"
	box.LayoutOrder = 1
	box.ClearTextOnFocus = false
	box.Font = Kit.FONT
	box.TextColor3 = Kit.INK
	box.PlaceholderColor3 = Kit.INK_SOFT
	box.BackgroundColor3 = Kit.WHITE
	box.Text = ""
	Kit.corner(box, UDim.new(0, 14))
	local edge = Kit.stroke(box, 3)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	box.Parent = window.body
	box:GetPropertyChangedSignal("Text"):Connect(function()
		tidy(box)
	end)
	box.FocusLost:Connect(function(enter: boolean)
		if enter then
			send(StaffNameRules.clean(box.Text) or "")
		end
	end)

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.LayoutOrder = 2
	buttons.BackgroundTransparency = 1
	buttons.Parent = window.body
	local reset = Window.button("Reset", "", buttons, SOFT_TOP, SOFT_BOTTOM)
	reset.TextColor3 = Kit.INK
	reset.TextStrokeTransparency = 1
	reset.Size = UDim2.fromScale(0.48, 1)
	reset.Activated:Connect(function()
		send("")
	end)
	local save = Window.button("Save", "Save", buttons, GREEN_TOP, GREEN_BOTTOM)
	save.AnchorPoint = Vector2.new(1, 0)
	save.Position = UDim2.fromScale(1, 0)
	save.Size = UDim2.fromScale(0.48, 1)
	save.Activated:Connect(function()
		send(StaffNameRules.clean(box.Text) or "")
	end)

	local note = words("Note", window.body, 16)
	note.LayoutOrder = 3
	note.FontFace = Kit.BODY_FACE
	note.TextColor3 = Kit.INK_SOFT
	note.TextWrapped = true
	note.AutomaticSize = Enum.AutomaticSize.Y
	note.Text =
		`Up to {StaffNameRules.MAX_LENGTH} letters, numbers and spaces. Names are checked before anyone sees them.`

	parts = {
		window = window,
		pad = pad,
		stack = stack,
		box = box,
		buttons = buttons,
		save = save,
		reset = reset,
		note = note,
	}
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. StaffNameRules.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(StaffNameRules.FLAG) then
				window.layer.Visible = false
			end
		end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

return RenameCard
