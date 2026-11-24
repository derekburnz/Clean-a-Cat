--!strict
-- HUD icons: the ONE place an icon image is set (#210). Derek picked Model-Agent's 3D renders "for now"
-- (CleanACat_Icon_Hud_*, 512 px), so a later swap must touch only IMAGES. Until the group uploads exist an id stays ""
-- and the icon draws its stand-in: a glyph on a coloured tile. Model icons are drawn at 48 real px or larger and are
-- never scaled by TextSize.
local Icons = {}

-- name -> "rbxassetid://<id>" once uploaded under the group (rule 18); "" draws the stand-in.
Icons.IMAGES = {
	Coins = "",
	Index = "",
	Settings = "",
	Sponge = "",
	Brush = "",
	Bow = "",
	Camera = "",
	Star = "",
	Paw = "",
	Heart = "",
	Station = "",
	Gear = "",
	Gift = "",
	Music = "",
	Speaker = "",
	Shake = "",
	Sparkle = "",
	Dice = "",
	Check = "",
	Crown = "",
	Lock = "",
	Mud = "",
	Tangles = "",
	Wet = "",
	Pointer = "",
} :: { [string]: string }

local INK = Color3.fromHex("45226B")

-- The stand-in for an icon with no image yet.
-- `bare` draws the glyph alone, with no tile (a star or a row's small icon).
type StandIn = { glyph: string, fill: Color3, round: boolean, bare: boolean? }
local STAND_INS: { [string]: StandIn } = {
	Coins = { glyph = "", fill = Color3.fromHex("FFC94D"), round = true }, -- a plain gold coin
	Sponge = { glyph = "🧽", fill = Color3.fromHex("FFE98F"), round = false },
	Brush = { glyph = "🖌", fill = Color3.fromHex("FFB3C7"), round = false },
	Bow = { glyph = "🎀", fill = Color3.fromHex("FFD6E7"), round = false },
	Camera = { glyph = "📷", fill = Color3.fromHex("8FD3FE"), round = false },
	Star = { glyph = "⭐", fill = Color3.fromHex("FFC94D"), round = true, bare = true },
	Paw = { glyph = "🐾", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Heart = { glyph = "💗", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Station = { glyph = "🛁", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Index = { glyph = "📖", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Settings = { glyph = "⚙️", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Gift = { glyph = "🎁", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Gear = { glyph = "⚙️", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Music = { glyph = "🎵", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Speaker = { glyph = "🔊", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Shake = { glyph = "📳", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Sparkle = { glyph = "✨", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Dice = { glyph = "🎲", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Check = { glyph = "✅", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Crown = { glyph = "👑", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Lock = { glyph = "🔒", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Mud = { glyph = "🟤", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Tangles = { glyph = "🧶", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Wet = { glyph = "💧", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Pointer = { glyph = "👈", fill = Color3.fromHex("FFFFFF"), round = true, bare = true }, -- the tutorial's arrow
}

-- Puts icon `name` inside `parent`, filling it, and returns it. `faded` dims it (a step already done).
function Icons.draw(name: string, parent: GuiObject, faded: boolean?): GuiObject
	local old = parent:FindFirstChild("Icon")
	if old then
		old:Destroy()
	end
	local fade = if faded then 0.55 else 0
	local image = Icons.IMAGES[name] or ""
	if image ~= "" then
		local label = Instance.new("ImageLabel")
		label.Name = "Icon"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Image = image
		label.ScaleType = Enum.ScaleType.Fit
		label.ImageTransparency = fade
		label.Parent = parent
		return label
	end
	local standIn: StandIn = STAND_INS[name]
		or { glyph = "?", fill = Color3.new(1, 1, 1), round = true, bare = false }
	if standIn.bare then
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Icon"
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.Text = standIn.glyph
		glyph.TextScaled = true -- an emoji stand-in, not words: it fills its box
		glyph.TextTransparency = fade
		glyph.Parent = parent
		return glyph
	end
	local tile = Instance.new("Frame")
	tile.Name = "Icon"
	tile.Size = UDim2.fromScale(1, 1)
	tile.BackgroundColor3 = standIn.fill
	tile.BackgroundTransparency = fade
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if standIn.round then UDim.new(0.5, 0) else UDim.new(0.25, 0)
	corner.Parent = tile
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Transparency = fade
	stroke.Parent = tile
	if standIn.glyph ~= "" then
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Glyph"
		glyph.BackgroundTransparency = 1
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.Size = UDim2.fromScale(0.72, 0.72)
		glyph.Text = standIn.glyph
		glyph.TextScaled = true -- an emoji stand-in, not words: it fills its tile
		glyph.TextTransparency = fade
		glyph.Parent = tile
	end
	tile.Parent = parent
	return tile
end

return Icons
