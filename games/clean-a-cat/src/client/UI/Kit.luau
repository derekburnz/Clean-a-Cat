--!strict
-- Kit: the shared look of the game's screens (Design-Agent's ui-screens kit.css), so every screen draws the same
-- outline, corner and outlined words, and scales the same way.
--
--   Kit.INK, Kit.WHITE, Kit.CREAM, Kit.FONT   the palette and the one display font (Fredoka One)
--   Kit.RARITY[rarity]                          a rarity's colour (Common grey to Legendary gold)
--   Kit.screenScale()                           (scale, short): design pixels on a 1280 x 720 canvas scale like the
--                                               asset library's Scale.luau, clamp(min(w / 1280, h / 720), 0.75, 1.3);
--                                               short is a screen under 560 design pixels tall (a phone held sideways)
--   Kit.corner(parent, radius)                  a UICorner
--   Kit.stroke(parent, thickness)               an ink UIStroke
--   Kit.outlined(name, parent)                  white words with an ink outline and no box (the screens' .outlined)
--   Kit.minText(label)                          the 14 real px floor at the smallest scale
local Workspace = game:GetService("Workspace")

local Kit = {}

Kit.FONT = Enum.Font.FredokaOne
-- The body font of Design-Agent's drafts (--font-body): Nunito, bold. Headings, names and numbers use Kit.FONT. Set
-- it as a label's FontFace (Nunito's bold weight has no Enum.Font of its own).
Kit.BODY_FACE = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)
Kit.INK = Color3.fromHex("45226B")
Kit.INK_SOFT = Color3.fromHex("6C4F86")
Kit.WHITE = Color3.new(1, 1, 1)
Kit.CREAM = Color3.fromHex("FFF6EC")
Kit.LINE = Color3.fromHex("ECDCCA")
Kit.GOLD = Color3.fromHex("FFC94D")
Kit.GOLD_INK = Color3.fromHex("8F5A00")
Kit.GOLD_TEXT = Color3.fromHex("FFE98F")

Kit.RARITY = {
	Common = Color3.fromHex("8E97B2"),
	Uncommon = Color3.fromHex("5FC98B"),
	Rare = Color3.fromHex("5FA8FF"),
	Epic = Color3.fromHex("C07CFF"),
	Legendary = Color3.fromHex("FFC94D"),
} :: { [string]: Color3 }

local DESIGN = Vector2.new(1280, 720)
local SCALE_MIN, SCALE_MAX = 0.75, 1.3
local SHORT_BELOW = 560 -- design pixels of height
local MIN_TEXT = 19 -- design pixels: 14 real px at the smallest scale (0.75), the screens' floor

function Kit.screenScale(): (number, boolean)
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else DESIGN
	local scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), SCALE_MIN, SCALE_MAX)
	return scale, size.Y / scale < SHORT_BELOW
end

function Kit.corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

function Kit.stroke(parent: Instance, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = Kit.INK
	s.Thickness = thickness
	s.Parent = parent
	return s
end

function Kit.minText(label: TextLabel | TextButton)
	local floor = Instance.new("UITextSizeConstraint")
	floor.MinTextSize = MIN_TEXT
	floor.MaxTextSize = 100
	floor.Parent = label
end

-- A one-line name in a box of fixed width: it draws at `size` when it fits, shrinks as far as the text floor when it
-- does not, and only past that ends with "..." (#262). Call it on every redraw, as the screen's scale can change.
-- TextScaled text keeps to its box when the player picks a larger text size, so a long name never spills its card.
-- TextScaled works in screen pixels: a UIScale does not scale a UITextSizeConstraint, so its sizes take the screen
-- scale here (a floor of 19 under a 0.75 scale would draw 19 px text, too big for the box, on an iPhone 14).
function Kit.shrinkToFit(label: TextLabel, size: number)
	local scale = Kit.screenScale()
	local found = label:FindFirstChildOfClass("UITextSizeConstraint")
	local limit: UITextSizeConstraint = if found
		then found :: UITextSizeConstraint
		else Instance.new("UITextSizeConstraint")
	limit.Parent = label
	limit.MinTextSize = MIN_TEXT * scale
	limit.MaxTextSize = math.max(size, MIN_TEXT) * scale
	label.TextSize = size
	label.TextScaled = true
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
end

function Kit.outlined(name: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Kit.FONT
	label.TextColor3 = Kit.WHITE
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	Kit.stroke(label, 3)
	Kit.minText(label)
	label.Parent = parent
	return label
end

return Kit
