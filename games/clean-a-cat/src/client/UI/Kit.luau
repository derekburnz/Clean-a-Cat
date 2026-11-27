--!strict
-- Kit: the shared look of the game's screens (Design-Agent's ui-screens kit.css), so every screen draws the same
-- outline, corner and outlined words, and scales the same way.
--
--   Kit.INK, Kit.WHITE, Kit.CREAM, Kit.FONT   the palette and the one display font (Fredoka One)
--   Kit.RARITY[rarity]                          a rarity's colour (Common grey to Legendary gold, Special lilac)
--   Kit.screenScale()                           (scale, short): design pixels on a 1280 x 720 canvas scale like the
--                                               asset library's Scale.luau, clamp(min(w / 1280, h / 720), 0.75, 1.3);
--                                               short is a screen under 560 design pixels tall (a phone held sideways)
--   Kit.corner(parent, radius)                  a UICorner
--   Kit.stroke(parent, thickness)               an ink UIStroke
--   Kit.outlined(name, parent)                  white words with an ink outline and no box (the screens' .outlined)
--   Kit.minText(label)                          the 14 real px floor at the smallest scale
--   Kit.line()                                  the edge of a card or row inside a window: the pale LINE, or with the
--                                               switch menuContrast a lilac that stands 3 to 1 against the window
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

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
-- The card edge with menuContrast (issue 928, the owner on 2026-11-26: "fix the contrast with the background for a lot
-- of the menus so its easier to differentiate"): 3.4 to 1 on white, 3.2 to 1 on cream (WCAG's 3 to 1 for a shape's
-- edge); LINE was 1.3 to 1, so white rows melted into the cream window.
Kit.LINE_STRONG = Color3.fromHex("9A7FBA")
Kit.CONTRAST_FLAG = "menuContrast"

function Kit.line(): Color3
	return if LiveFlags.isOn(Kit.CONTRAST_FLAG) then Kit.LINE_STRONG else Kit.LINE
end
Kit.GOLD = Color3.fromHex("FFC94D")
Kit.GOLD_INK = Color3.fromHex("8F5A00")
Kit.GOLD_TEXT = Color3.fromHex("FFE98F")

Kit.RARITY = {
	Common = Color3.fromHex("8E97B2"),
	Uncommon = Color3.fromHex("5FC98B"),
	Rare = Color3.fromHex("5FA8FF"),
	Epic = Color3.fromHex("C07CFF"),
	Legendary = Color3.fromHex("FFC94D"),
	Special = Color3.fromHex("8F62F0"), -- special visitors' cats: a deeper lilac than Epic, so the best cat never reads as Common grey
} :: { [string]: Color3 }

-- A rarity's outline where it should read by more than hue: Special is lilac with a gold rim (style guide), so it never
-- looks like Epic. Other rarities keep the caller's own outline.
Kit.RARITY_RIM = {
	Special = Kit.GOLD,
} :: { [string]: Color3 }

-- Sets the chip's or card's UIStroke to the rarity's rim, or back to `default`.
function Kit.rim(holder: Instance, rarity: string?, default: Color3)
	local edge = holder:FindFirstChildOfClass("UIStroke") :: UIStroke?
	if edge then
		edge.Color = (if rarity then Kit.RARITY_RIM[rarity] else nil) or default
	end
end

local DESIGN = Vector2.new(1280, 720)
local SCALE_MIN, SCALE_MAX = 0.75, 1.3
Kit.SCALE_MIN = SCALE_MIN -- below it the 14 px text floor no longer holds
local SHORT_BELOW = 560 -- design pixels of height
-- design pixels of height: below it the screen is very short (a small Android phone such as a Galaxy A06 in
-- landscape, 338 real px under the top bar at the 0.75 floor), and the tallest windows drop a line (issue 988)
local TINY_BELOW = 470
local MIN_TEXT = 19 -- design pixels: 14 real px at the smallest scale (0.75), the screens' floor

-- The screen scale, whether the screen is short, and whether it is very short (TINY_BELOW).
function Kit.screenScale(): (number, boolean, boolean)
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else DESIGN
	local scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), SCALE_MIN, SCALE_MAX)
	return scale, size.Y / scale < SHORT_BELOW, size.Y / scale < TINY_BELOW
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

local CHIP_TEXT = 19 -- design px: the floor, so the words never shrink
local CHIP_PAD = 9 -- design px each side inside the pill
local CHIP_PAD_TIGHT = 3 -- when the room is short
local CHIP_OUTLINE = 3 -- the words' own ink outline (Kit.outlined), each side
local CHIP_SLACK = 4 -- design px for the font's own side bearings

-- The rarity pill's width in design px: its words as drawn, their outline and the padding. Issue 609: an automatic
-- width left out the outline, so "Uncommon" ran 7 px past its pill on a phone.
function Kit.chipWidth(rarity: string, room: number?): number
	local words =
		math.ceil(TextService:GetTextSize(rarity, CHIP_TEXT, Kit.FONT, Vector2.new(10000, 1000)).X)
	local full = words + 2 * (CHIP_PAD + CHIP_OUTLINE) + CHIP_SLACK
	if room and full > room then
		return math.max(room, words + 2 * (CHIP_PAD_TIGHT + CHIP_OUTLINE) + CHIP_SLACK)
	end
	return full
end

-- A rarity pill ("Uncommon" on green), sized by Kit.chipWidth to fit `room` design px when given.
function Kit.rarityChip(
	parent: Instance,
	rarity: string,
	height: number,
	order: number,
	room: number?
): Frame
	local c = Instance.new("Frame")
	c.Name = "Rarity"
	c.BorderSizePixel = 0
	c.LayoutOrder = order
	c.BackgroundColor3 = Kit.RARITY[rarity] or Kit.RARITY.Common
	c.Size = UDim2.fromOffset(Kit.chipWidth(rarity, room), height)
	Kit.corner(c, UDim.new(0.5, 0))
	Kit.stroke(c, 2)
	Kit.rim(c, rarity, Kit.INK)
	local label = Kit.outlined("Text", c)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.TextSize = CHIP_TEXT
	label.Text = rarity
	c.Parent = parent
	return c
end

-- An empty pet slot's "+" (issue 1034, Derek saw empty slots as plain grey circles): a small green round badge at the
-- box's bottom right, so the box reads as "put a pet here".
function Kit.plusBadge(box: GuiObject): Frame
	local badge = Instance.new("Frame")
	badge.Name = "Plus"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.86, 0.86)
	badge.Size = UDim2.fromScale(0.42, 0.42)
	badge.BackgroundColor3 = Color3.fromHex("5BCB8A")
	badge.ZIndex = box.ZIndex + 2
	Kit.corner(badge, UDim.new(0.5, 0))
	Kit.stroke(badge, 2)
	local plus = Instance.new("TextLabel")
	plus.Name = "Glyph"
	plus.BackgroundTransparency = 1
	plus.Size = UDim2.fromScale(1, 1)
	plus.Text = "+"
	plus.TextScaled = true -- one glyph that fills its badge
	plus.TextColor3 = Kit.WHITE
	plus.Font = Kit.FONT
	plus.ZIndex = badge.ZIndex
	plus.Parent = badge
	badge.Parent = box
	return badge
end

return Kit
