--!strict
-- ToastCard: the look of the short notices (UI.toast, the server's Notice). With the switch toastCards (issue 877;
-- the owner on 2026-11-26: "the long bars across screen suck ... figure out a better ui design for popups and make it
-- look clean") a notice is a small card, not a bar across the screen:
--   * as wide as its words (at most MAX_W design px), at the top right under Roblox's top bar, so it never covers the
--     wash's meter and step line in the middle or the prompts in the world;
--   * cream with the ink outline and ink words, and a coloured tab at its left by type: mint for a reward (a notice
--     that starts with "+" or says "is yours" or "is ready"), peach for a "not yet" (warning), lilac for news;
--   * the cat's round portrait in the tab when the notice is about a cat (a special visitor).
-- Off, it is the old dark bar. Design-Agent, 2026-11-26.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local ToastRules = require(Shared:WaitForChild("ToastRules"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))

local ToastCard = {}

local DARK = Color3.fromRGB(30, 30, 30)
local DARK_WARNING = Color3.fromRGB(150, 60, 20)
local TAB: { [string]: Color3 } = {
	reward = Color3.fromHex("6FD8A8"),
	warning = Color3.fromHex("FFB38F"),
	news = Color3.fromHex("CDB8FF"),
}
local TEXT_SIZE = 17
local MAX_W = 340 -- design px: the card's widest
local TAB_W = 40 -- px: the coloured tab at the left, the portrait in it
local ICON = 30
local SIDE = 14 -- px of room right of the words
local EDGE = 16 -- px from the screen's right edge
local TOP = 64 -- px from the top: under Roblox's top bar row

-- The card's type for a notice (ToastRules, pure and covered by its spec).
ToastCard.lookOf = ToastRules.lookOf

local function child<T>(parent: Instance, name: string, class: string): T
	local found = parent:FindFirstChild(name)
	if found then
		return (found :: any) :: T
	end
	local made = Instance.new(class)
	made.Name = name
	made.Parent = parent
	return (made :: any) :: T
end

-- Sets `label` (the toast) for one notice of `kind`, about the cat named `icon` when given.
function ToastCard.style(label: TextLabel, text: string, kind: ("info" | "warning")?, icon: string?)
	local on = LiveFlags.isOn(ToastRules.FLAG)
	local stroke = child(label, "Outline", "UIStroke") :: UIStroke
	local pad = child(label, "Room", "UIPadding") :: UIPadding
	local tab = child(label, "Tab", "Frame") :: Frame
	local face = child(tab, "Icon", "ImageLabel") :: ImageLabel
	if not on then
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 70)
		label.Size = UDim2.new(0.8, 0, 0, label.Size.Y.Offset)
		label.BackgroundColor3 = if kind == "warning" then DARK_WARNING else DARK
		label.TextColor3 = Kit.WHITE
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Center
		stroke.Enabled = false
		tab.Visible = false
		pad.PaddingLeft = UDim.new(0, 0)
		pad.PaddingRight = UDim.new(0, 0)
		return
	end
	local look: string = ToastCard.lookOf(text, kind)
	local image = if icon then Portraits.imageFor(icon) else ""
	label.Font = Kit.FONT
	label.TextSize = TEXT_SIZE
	label.TextColor3 = Kit.INK
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundColor3 = Kit.CREAM
	label.BackgroundTransparency = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Kit.INK
	stroke.Thickness = 2.5
	stroke.Enabled = true
	-- as wide as the words on one line, wrapping past MAX_W
	local words = TextService:GetTextSize(text, TEXT_SIZE, Kit.FONT, Vector2.new(MAX_W, 1000))
	local width = math.min(words.X + TAB_W + SIDE + 12, MAX_W)
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -EDGE, 0, TOP)
	label.Size = UDim2.new(0, width, 0, label.Size.Y.Offset)
	pad.PaddingLeft = UDim.new(0, TAB_W + 10)
	pad.PaddingRight = UDim.new(0, SIDE)
	tab.Visible = true
	tab.BackgroundColor3 = TAB[look]
	tab.BorderSizePixel = 0
	tab.Position = UDim2.new(0, -(TAB_W + 10), 0, 0)
	tab.Size = UDim2.new(0, TAB_W, 1, 0)
	local corner = label:FindFirstChildOfClass("UICorner")
	local round = child(tab, "Round", "UICorner") :: UICorner
	round.CornerRadius = if corner then corner.CornerRadius else UDim.new(0, 10)
	face.Visible = image ~= ""
	face.Image = image
	face.BackgroundColor3 = Kit.WHITE
	face.BorderSizePixel = 0
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromOffset(ICON, ICON)
	local faceRound = child(face, "Round", "UICorner") :: UICorner
	faceRound.CornerRadius = UDim.new(0.5, 0)
end

return ToastCard
