--!strict
-- Window: the game's window look from Design-Agent's kit (cream body, ink outline, a lilac-to-pink title band, a round
-- badge at the top left and a red X at the top right), built once per window. Only the X (or the window's own action)
-- closes a window, and the player opens every window: nothing here opens one by itself.
--
--   local w = Window.new(name, title, badgeIcon, root)
--   w.layer      the whole window with its dim backdrop; register it with UI so UI.open and UI.closeAll work
--   w.card       the window itself (set its width with Window.fit), w.body the space under the band
--   w.close      the X button; the caller connects it
--   Window.fit(w, width, band, title, badge)   sizes in design pixels for the current screen, then w.scale.Scale
--
-- The screen scale sits on a see-through holder the size of the layer, so Motion.popIn can use its own UIScale on
-- the layer (one UIScale per object).
local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent:WaitForChild("Motion"))

local Window = {}

local BACKDROP = Color3.fromRGB(36, 16, 56)
local RED_TOP, RED_BOTTOM = Color3.fromHex("FF7062"), Color3.fromHex("E83A3A")
local TOPBAR_SHIFT = 33 -- real px: the window sits a little below the middle, clear of Roblox's top bar
local CLOSE = 64 -- design px

export type Window = {
	layer: Frame,
	scale: UIScale,
	card: Frame,
	band: Frame,
	title: TextLabel,
	badge: Frame,
	close: TextButton,
	body: Frame,
}

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

-- A chunky button: ink outline, a two-tone face and outlined words (the screens' .btn).
function Window.button(
	name: string,
	text: string,
	parent: Instance,
	top: Color3,
	bottom: Color3
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.BackgroundColor3 = Kit.WHITE
	b.Font = Kit.FONT
	b.Text = text
	b.TextColor3 = Kit.WHITE
	b.TextStrokeColor3 = Kit.INK
	b.TextStrokeTransparency = 0.4
	Kit.minText(b)
	gradient(b, top, bottom)
	Kit.corner(b, UDim.new(0, 16))
	local s = Kit.stroke(b, 4)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Parent = parent
	Motion.press(b) -- trial springs, switch springUi (#183)
	return b
end

function Window.new(name: string, title: string, badgeIcon: string, root: Instance): Window
	local layer = frame(name, root)
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.Position = UDim2.fromScale(0.5, 0.5)
	layer.Size = UDim2.fromScale(1, 1)
	layer.Visible = false
	layer.ZIndex = 10

	-- The dim behind the window; large enough to cover the TV inset around the root. It takes presses so a tap
	-- beside the window does not reach the world, but it does not close the window.
	local backdrop = frame("Backdrop", layer)
	backdrop.AnchorPoint = Vector2.new(0.5, 0.5)
	backdrop.Position = UDim2.fromScale(0.5, 0.5)
	backdrop.Size = UDim2.fromScale(1.5, 1.5)
	backdrop.BackgroundTransparency = 0.58
	backdrop.BackgroundColor3 = BACKDROP
	backdrop.Active = true

	local holder = frame("Holder", layer)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	local scale = Instance.new("UIScale")
	scale.Name = "WindowScale"
	scale.Parent = holder

	local card = frame("Card", holder)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, TOPBAR_SHIFT)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundTransparency = 0
	card.BackgroundColor3 = Kit.CREAM
	Kit.corner(card, UDim.new(0, 26))
	Kit.stroke(card, 4)

	local stack = frame("Stack", card)
	stack.Size = UDim2.fromScale(1, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	local stackList = Instance.new("UIListLayout")
	stackList.SortOrder = Enum.SortOrder.LayoutOrder
	stackList.Parent = stack

	local band = frame("Band", stack)
	band.LayoutOrder = 1
	band.BackgroundTransparency = 0
	band.BackgroundColor3 = Kit.WHITE
	gradient(band, Color3.fromHex("E7DBFF"), Color3.fromHex("F6A9C9"))
	Kit.corner(band, UDim.new(0, 22))
	local heading = Kit.outlined("Title", band)
	heading.AnchorPoint = Vector2.new(0, 0.5)
	heading.Text = title

	local body = frame("Body", stack)
	body.LayoutOrder = 2
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y

	local badge = frame("Badge", card)
	badge.Position = UDim2.fromOffset(-6, -14)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Kit.CREAM
	badge.ZIndex = 2
	Kit.corner(badge, UDim.new(0.5, 0))
	Kit.stroke(badge, 4)
	local badgeIconBox = frame("IconBox", badge)
	badgeIconBox.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeIconBox.Position = UDim2.fromScale(0.5, 0.5)
	badgeIconBox.Size = UDim2.fromScale(0.6, 0.6)
	Icons.draw(badgeIcon, badgeIconBox)

	local close = Window.button("Close", "X", card, RED_TOP, RED_BOTTOM)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 20, 0, -20)
	close.Size = UDim2.fromOffset(CLOSE, CLOSE)
	close.TextSize = 34
	close.ZIndex = 3

	return {
		layer = layer,
		scale = scale,
		card = card,
		band = band,
		title = heading,
		badge = badge,
		close = close,
		body = body,
	}
end

-- Sizes in design pixels for the current screen.
function Window.fit(w: Window, width: number, band: number, title: number, badge: number)
	local scale = Kit.screenScale()
	w.scale.Scale = scale
	w.card.Size = UDim2.fromOffset(width, 0)
	w.band.Size = UDim2.new(1, 0, 0, band)
	w.title.TextSize = title
	w.title.Position = UDim2.new(0, badge + 4, 0.5, 0)
	w.badge.Size = UDim2.fromOffset(badge, badge)
end

return Window
