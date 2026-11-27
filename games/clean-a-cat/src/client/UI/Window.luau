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
-- A window never runs off a short screen (bug hunt B8: the crate window with its Robux rows was 360 px tall on a
-- 332 px phone screen under Roblox's top bar): whenever the card's height changes, a card taller than the room under
-- the top bar is scaled down to fit (to at most MIN_FIT of its size, never under Kit.SCALE_MIN) and moved up to sit
-- just under the bar.
--
-- The screen scale sits on a see-through holder the size of the layer, so Motion.popIn can use its own UIScale on
-- the layer (one UIScale per object).
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local ButtonInk = require(script.Parent:WaitForChild("ButtonInk"))
local Contrast = require(script.Parent:WaitForChild("Contrast"))
local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local ShortText = require(script.Parent:WaitForChild("ShortText"))

local Window = {}

-- issue 1038 (Derek: "some ui is overlapping still like the first helper and the top left image circle"): the round
-- badge sits inside the title band instead of hanging over its corner, and the HUD's buttons step aside while a window
-- is open (UI init's fitScreen)
Window.CLEAR_FLAG = "windowClear"
local BADGE_INSET = 6 -- design px between the badge and the band's top and bottom

local BACKDROP = Color3.fromRGB(36, 16, 56)
local RED_TOP, RED_BOTTOM = Color3.fromHex("FF7062"), Color3.fromHex("E83A3A")
-- Design px (the holder's UIScale scales it): the window sits a little below the middle, clear of Roblox's top bar.
local TOPBAR_SHIFT = 33
local CLOSE = 64 -- design px
local OVERHANG = 20 -- design px the X stands above the card
local EDGE = 2 -- real px kept clear above and below a window that had to shrink
local MIN_FIT = 0.8 -- a tall window shrinks to at most this share of its size
local TINY_BAND, TINY_TITLE, TINY_BADGE = 46, 28, 68 -- design px: the band on a very short screen (Kit.screenScale)

-- What Window.fit last asked for, per card: the screen scale and the shift below the middle.
local asked: { [Frame]: { scale: number, shift: number, width: number } } = {}

-- The HUD pieces a window's X must stay below (the coin pill and the friend tag, set by UI from HUD.topRight): on a
-- short phone the X stood on the coin number (issue 873). Nil, nothing is avoided.
Window.avoid = nil :: (() -> { GuiObject })?

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
	b.TextStrokeTransparency = 0 -- a solid ink edge: white on bright green or red needs it to read on a phone
	Kit.minText(b)
	gradient(b, top, bottom)
	Kit.corner(b, UDim.new(0, 16))
	local s = Kit.stroke(b, 4)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Parent = parent
	Motion.press(b) -- trial springs, switch springUi (#183)
	return b
end

-- Shrinks and lifts `w` when its card is taller than the room under the top bar; otherwise as Window.fit asked.
local function keepOnScreen(w: Window)
	local want = asked[w.card]
	local camera = Workspace.CurrentCamera
	if want == nil or camera == nil or w.scale.Scale <= 0 then
		return
	end
	-- in screen px: AbsolutePosition counts from under the top bar, as GuiService's inset says
	local inset = GuiService:GetGuiInset().Y
	local layerTop = w.layer.AbsolutePosition.Y + inset
	local layerH = w.layer.AbsoluteSize.Y
	local top = math.max(inset, layerTop) + EDGE
	local bottom = math.min(camera.ViewportSize.Y, layerTop + layerH) - EDGE
	local designH = w.card.AbsoluteSize.Y / w.scale.Scale + OVERHANG
	-- the lowest edge of an avoided HUD piece (the coin pill) in the X's column: the X stays below it (issue 873)
	local clearTop = top
	local avoid = Window.avoid
	if avoid then
		local closeRight = w.layer.AbsolutePosition.X
			+ w.layer.AbsoluteSize.X / 2
			+ (want.width / 2 + 20) * want.scale
		local closeLeft = closeRight - CLOSE * want.scale
		for _, piece in avoid() do
			local x0 = piece.AbsolutePosition.X
			local x1 = x0 + piece.AbsoluteSize.X
			if piece.Visible and x0 < closeRight and x1 > closeLeft then
				clearTop = math.max(
					clearTop,
					piece.AbsolutePosition.Y + inset + piece.AbsoluteSize.Y + EDGE
				)
			end
		end
	end
	local scale, shift = want.scale, want.shift
	local room = bottom - clearTop
	local tucked = false
	if designH * scale > room and designH > 0 and room > 0 then
		-- never under Kit.SCALE_MIN: the text floor (Kit.minText) holds in real pixels, so a smaller scale shrinks a
		-- pill around words that stay the same size (Sync on 2a34a8e: "Uncommon" past its pill, prices at 12.7 px)
		scale = math.max(room / designH, want.scale * MIN_FIT, Kit.SCALE_MIN)
		local over = OVERHANG
		if clearTop > top and designH * scale > room then
			-- still too tall under the coin pill (a short phone): the X tucks into the card's corner, so the card
			-- can rise by the X's overhang and its X still clears the coins (issue 873)
			tucked = true
			over = 0
			scale = math.max(room / (designH - OVERHANG), want.scale * MIN_FIT, Kit.SCALE_MIN)
		end
		-- the card's middle, so its X sits EDGE under the top bar (or under the coin pill)
		local middle = clearTop + (over + (designH - OVERHANG) / 2) * scale
		-- never past the bottom: if even that is too tall, the bottom wins over the coin pill
		middle = math.min(middle, bottom - (designH - OVERHANG) / 2 * scale)
		-- and never above the top bar's edge, as before
		middle = math.max(middle, top + (over + (designH - OVERHANG) / 2) * scale)
		shift = (middle - (layerTop + layerH / 2)) / scale
	else
		-- it fits: moved down only as far as its X needs to clear the coin pill
		local cardH = (designH - OVERHANG) * scale
		local middle = layerTop + layerH / 2 + shift * scale
		local closeTop = middle - cardH / 2 - OVERHANG * scale
		local spare = bottom - (middle + cardH / 2)
		local down = math.min(clearTop - closeTop, math.max(spare, 0))
		if down > 0 then
			shift += down / scale
		end
	end
	local closeAt = if tucked then UDim2.new(1, -6, 0, 0) else UDim2.new(1, 20, 0, -OVERHANG)
	if w.close.Position ~= closeAt then
		w.close.Position = closeAt
	end
	if math.abs(w.scale.Scale - scale) > 0.001 then
		w.scale.Scale = scale
	end
	local position = UDim2.new(0.5, 0, 0.5, shift)
	if w.card.Position ~= position then
		w.card.Position = position
	end
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

	local w: Window = {
		layer = layer,
		scale = scale,
		card = card,
		band = band,
		title = heading,
		badge = badge,
		close = close,
		body = body,
	}
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		keepOnScreen(w)
	end)
	Contrast.watch(card) -- switch menuContrast2 (issue 1029)
	ShortText.watch(card) -- switch shortText (issue 1027)
	ButtonInk.watch(card) -- switch menuContrast3 (issue 1096)
	return w
end

-- Sizes in design pixels for the current screen. `shift` moves the card below the middle (TOPBAR_SHIFT by default);
-- a window that is tall for a short screen passes less, so its bottom stays on screen.
function Window.fit(
	w: Window,
	width: number,
	band: number,
	title: number,
	badge: number,
	shift: number?
)
	local scale, _, tiny = Kit.screenScale()
	if tiny then
		-- a very short screen: a slimmer title band, so the tallest windows keep their bottom on screen (issue 988)
		band, title, badge =
			math.min(band, TINY_BAND), math.min(title, TINY_TITLE), math.min(badge, TINY_BADGE)
	end
	w.scale.Scale = scale
	w.card.Size = UDim2.fromOffset(width, 0)
	w.card.Position = UDim2.new(0.5, 0, 0.5, shift or TOPBAR_SHIFT)
	asked[w.card] = { scale = scale, shift = shift or TOPBAR_SHIFT, width = width }
	w.band.Size = UDim2.new(1, 0, 0, band)
	w.title.TextSize = title
	if LiveFlags.isOn(Window.CLEAR_FLAG) then
		-- the badge inside the band, never over the first row or the HUD
		local side = math.max(band - 2 * BADGE_INSET, 24)
		w.badge.Position = UDim2.fromOffset(BADGE_INSET * 2, (band - side) / 2)
		w.badge.Size = UDim2.fromOffset(side, side)
		w.title.Position = UDim2.new(0, BADGE_INSET * 2 + side + 10, 0.5, 0)
	else
		w.badge.Position = UDim2.fromOffset(-6, -14)
		w.title.Position = UDim2.new(0, badge + 4, 0.5, 0)
		w.badge.Size = UDim2.fromOffset(badge, badge)
	end
	keepOnScreen(w)
end

return Window
