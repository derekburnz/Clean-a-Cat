--!strict
-- WalkButton: the way out of the close-up wash view (switch washView, #368 follow-up), placed and drawn from
-- Design-Agent's note: in Roblox's top bar row, 12 real px right of its menu buttons and centred on them; a ghost
-- button (white to cream, ink edge and ink text) with an arrow pointing left and the label "Walk", which says what
-- the player gets ("Back" or "Exit" could read as quitting the cat). 52 design px tall, never under 44 real px. With
-- under 360 design px free in the top bar it shows the arrow only. Gamepad ButtonB and the Backspace key press it
-- too (not Esc, which is Roblox's menu).
--
--   WalkButton.build(playerGui, press)   makes it once, hidden; press() runs when it is pressed
--   WalkButton.set(shown)                shows or hides it (ScrubController.walkChanged, via HudController)
--
-- Pressing it gives the player their camera and walking back while the cat waits in the tub; it never cancels the
-- job or costs anything. UI never fires remotes: press() is ScrubController.stepOut.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent.Parent:WaitForChild("Motion"))

local WalkButton = {}

WalkButton.LABEL = "Walk"

local GAP = 12 -- real px right of Roblox's menu buttons
local HEIGHT = 52 -- design px
local MIN_HEIGHT = 44 -- real px: a thumb's reach
local LABEL_BELOW = 360 -- design px of free top bar width under which the label goes
local TEXT = 26 -- design px
local CREAM_TOP = Kit.WHITE
local CREAM_BOTTOM = Kit.CREAM

local button: TextButton? = nil
local label: TextLabel? = nil
local shown = false
local onPress: (() -> ())? = nil

-- A chevron pointing left, from two short bars, so the arrow needs no image upload.
local function arrow(parent: Instance): Frame
	local box = Instance.new("Frame")
	box.Name = "Arrow"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1) -- square: both sides follow the button's height
	box.SizeConstraint = Enum.SizeConstraint.RelativeYY
	box.LayoutOrder = 1
	box.Parent = parent
	for _, turn in { -40, 40 } do
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BackgroundColor3 = Kit.INK
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Size = UDim2.fromScale(0.42, 0.11)
		-- each bar's left end sits on the point of the chevron
		bar.Position = UDim2.fromScale(0.3, 0.5 + (if turn < 0 then -0.13 else 0.13))
		bar.Rotation = turn
		Kit.corner(bar, UDim.new(1, 0))
		bar.Parent = box
	end
	return box
end

local function redraw()
	local b, l = button, label
	if b == nil or l == nil then
		return
	end
	b.Visible = shown
	if not shown then
		return
	end
	local scale = Kit.screenScale()
	local inset = GuiService.TopbarInset
	local height = math.max(MIN_HEIGHT, math.floor(HEIGHT * scale + 0.5))
	local barHeight = if inset.Height > 0 then inset.Height else height
	b.Size = UDim2.fromOffset(0, height)
	b.Position = UDim2.fromOffset(inset.Min.X + GAP, inset.Min.Y + barHeight / 2)
	local free = (inset.Max.X - inset.Min.X) / scale
	l.Visible = free >= LABEL_BELOW
	l.TextSize = math.floor(TEXT * scale + 0.5)
end

local function press()
	local fn = onPress
	if shown and fn then
		fn()
	end
end

function WalkButton.set(on: boolean)
	if shown ~= on then
		shown = on
		redraw()
	end
end

function WalkButton.build(playerGui: Instance, pressed: () -> ())
	onPress = pressed
	local gui = Instance.new("ScreenGui")
	gui.Name = "WalkBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- placed in the top bar row, by GuiService.TopbarInset
	gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local b = Instance.new("TextButton")
	b.Name = "Walk"
	b.Text = ""
	b.AutoButtonColor = true
	b.BackgroundColor3 = Kit.WHITE
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Selectable = true
	b.Visible = false
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(CREAM_TOP, CREAM_BOTTOM)
	g.Parent = b
	Kit.corner(b, UDim.new(0, 22))
	local edge = Kit.stroke(b, 3)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = b
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = b
	arrow(b)
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.LayoutOrder = 2
	l.BackgroundTransparency = 1
	l.Font = Kit.FONT
	l.Text = WalkButton.LABEL
	l.TextColor3 = Kit.INK
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromScale(0, 1)
	l.Parent = b
	b.Parent = gui
	Motion.press(b) -- trial springs, switch springUi (#183)
	b.Activated:Connect(press)
	gui.Parent = playerGui
	button, label = b, l

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Backspace then
			press()
		end
	end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(redraw)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

return WalkButton
