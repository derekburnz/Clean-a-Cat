--!strict
-- SideButtons: the HUD's row of round buttons that open the game's windows (#232), from Design-Agent's hud.html:
-- top left, just under Roblox's menu buttons, each a 76 px button with a 52 px icon and a caption under it (66 px
-- on a phone held sideways). Settings sits last as a lilac button with the gear.
--
--   SideButtons.build(root, open)   makes the row once; open(windowName) runs when a button is pressed
--   SideButtons.any()               true while the HUD is on and at least one button shows
--   SideButtons.onChanged(fn)       fn() when a switch that shows or hides a button flips
--   SideButtons.find(window)        the button that opens `window`, or nil
--   SideButtons.setAside(on)        hides the row while the wash's tick list has its place (HUD/StepList); the
--                                   windows are for between washes. SideButtons.isAside()
--
-- A button shows only while the game HUD (gameHud) and its own window's switch are on, so a switched-off window
-- never has a way in. While any button shows, the starter Menu hides (UI/init). With a gamepad the row is reached
-- with Roblox's UI navigation (the Select button); the buttons are linked left and right in order.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("Icons"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent.Parent:WaitForChild("Motion"))

local SideButtons = {}

local HUD_FLAG = "gameHud"

type Spec = {
	window: string,
	flag: string,
	icon: string,
	caption: string,
	top: Color3,
	bottom: Color3,
}

-- In order, left to right. Tools, Helpers and Build join when their windows exist.
SideButtons.BUTTONS = {
	{
		window = "CatIndex",
		flag = "catIndexWindow",
		icon = "Index",
		caption = "Index",
		top = Color3.fromHex("C9F5E5"),
		bottom = Color3.fromHex("A8E6CF"),
	},
	{
		window = "Settings",
		flag = "settingsCard",
		icon = "Settings",
		caption = "Settings",
		top = Color3.fromHex("ECE2FB"),
		bottom = Color3.fromHex("D9C7F5"),
	},
} :: { Spec }

local SIZE_FULL, SIZE_SHORT = 76, 66 -- design px
local ICON = 52 -- design px: model icons are never drawn under 48
local GAP = 16
local EDGE = Vector2.new(16, 14) -- real px from the root's top left (the root starts under Roblox's top bar)

type Button = { spec: Spec, button: TextButton, iconBox: Frame }

local row: Frame? = nil
local rowScale: UIScale? = nil
local buttons: { Button } = {}
local aside = false

local function shown(spec: Spec): boolean
	return LiveFlags.isOn(HUD_FLAG) and LiveFlags.isOn(spec.flag)
end

function SideButtons.any(): boolean
	for _, spec in SideButtons.BUTTONS do
		if shown(spec) then
			return true
		end
	end
	return false
end

function SideButtons.find(window: string): TextButton?
	for _, entry in buttons do
		if entry.spec.window == window then
			return entry.button
		end
	end
	return nil
end

function SideButtons.onChanged(fn: () -> ())
	local names = { HUD_FLAG }
	for _, spec in SideButtons.BUTTONS do
		table.insert(names, spec.flag)
	end
	for _, name in names do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name):Connect(fn)
	end
end

local function redraw()
	local r, scale = row, rowScale
	if r == nil or scale == nil then
		return
	end
	local screenScale, short = Kit.screenScale()
	scale.Scale = screenScale
	local size = if short then SIZE_SHORT else SIZE_FULL
	local visible: { TextButton } = {}
	for _, entry in buttons do
		local on = shown(entry.spec)
		entry.button.Visible = on
		entry.button.Size = UDim2.fromOffset(size, size)
		entry.iconBox.Size = UDim2.fromOffset(math.min(ICON, size - 10), math.min(ICON, size - 10))
		if on then
			table.insert(visible, entry.button)
		end
	end
	for index, button in visible do
		button.NextSelectionLeft = visible[index - 1]
		button.NextSelectionRight = visible[index + 1]
	end
	r.Visible = #visible > 0 and not aside
end

function SideButtons.setAside(on: boolean)
	if aside ~= on then
		aside = on
		redraw()
	end
end

function SideButtons.isAside(): boolean
	return aside
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
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = frame
	-- room under the buttons for their captions
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 22)
	pad.Parent = frame
	frame.Parent = root

	for index, spec in SideButtons.BUTTONS do
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
		Icons.draw(spec.icon, iconBox)
		local caption = Kit.outlined("Caption", button)
		caption.AnchorPoint = Vector2.new(0.5, 0)
		caption.Position = UDim2.new(0.5, 0, 1, -6)
		caption.TextSize = 19
		caption.Text = spec.caption
		button.Parent = frame
		Motion.press(button) -- trial springs, switch springUi (#183)
		button.Activated:Connect(function()
			open(spec.window)
		end)
		table.insert(buttons, { spec = spec, button = button, iconBox = iconBox })
	end

	row, rowScale = frame, scale
	SideButtons.onChanged(redraw)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

return SideButtons
