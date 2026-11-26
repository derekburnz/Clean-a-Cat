--!strict
-- Portraits: the ONE place a cat's portrait image is set, for the recap card now and the Cat Index later. Model-Agent
-- renders them (the screens' img/portrait_<Name>_ink.png). Until a group upload exists (rule 18) a name maps to "" and
-- the portrait draws its stand-in: a cat glyph on a tile in the rarity's colour. Portraits are drawn at 48 real px or
-- larger.
local Kit = require(script.Parent:WaitForChild("Kit"))

local Portraits = {}

-- cat name -> "rbxassetid://<id>" once uploaded under the group; a missing or "" entry draws the stand-in. Suds, the
-- mascot (#285), has his own key here though he is not in the Cat Index.
Portraits.IMAGES = {
	Suds = "rbxassetid://134546291029280", -- CleanACat_UI_Portrait_Suds, round cheeks, group upload (#784)
} :: { [string]: string }

-- The stand-in glyph for a cat with no image yet; the cat glyph when not listed. One code point each: a joined emoji
-- such as the black cat (cat + zero width joiner + black square) splits into two glyphs on some phones (Sync-Agent).
Portraits.GLYPHS = {
	Suds = "🐈",
} :: { [string]: string }

local TILE_TINT = 0.55 -- how far the stand-in tile's rarity colour is lightened toward white

-- The picture for `cat`, at dirt level `dirt` (1 to 4, DirtRules) when given and uploaded as "<Cat>_Dirty<n>"; else
-- the clean picture; "" when there is none yet (the stand-in draws). Issue 794.
function Portraits.imageFor(cat: string, dirt: number?): string
	if dirt then
		local dirty: string? = Portraits.IMAGES[`{cat}_Dirty{dirt}`]
		if dirty ~= nil and dirty ~= "" then
			return dirty
		end
	end
	return Portraits.IMAGES[cat] or ""
end

-- Puts `cat`'s portrait inside `parent` on a tile framed in the rarity's colour, filling it, and returns the tile.
-- `round` draws a round face with no frame of its own (the HUD's waiting faces, whose button has the outline).
-- `dirt` shows the cat at that dirt level when its picture exists (the bench card, switch dirtLevels).
function Portraits.draw(
	cat: string,
	rarity: string,
	parent: GuiObject,
	round: boolean?,
	dirt: number?
): Frame
	local old = parent:FindFirstChild("Portrait")
	if old then
		old:Destroy()
	end
	local colour = Kit.RARITY[rarity] or Kit.RARITY.Common
	local tile = Instance.new("Frame")
	tile.Name = "Portrait"
	tile.Size = UDim2.fromScale(1, 1)
	tile.BackgroundColor3 = colour:Lerp(Kit.WHITE, TILE_TINT)
	Kit.corner(tile, UDim.new(if round then 0.5 else 0.14, 0))
	if not round then
		local frame = Kit.stroke(tile, 4)
		frame.Color = Kit.INK
	end
	local image = Portraits.imageFor(cat, dirt)
	if image ~= "" then
		local label = Instance.new("ImageLabel")
		label.Name = "Image"
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.92, 0.92)
		label.Image = image
		label.ScaleType = Enum.ScaleType.Fit
		label.Parent = tile
	else
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Glyph"
		glyph.BackgroundTransparency = 1
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.Size = UDim2.fromScale(0.7, 0.7)
		glyph.Text = Portraits.GLYPHS[cat] or "🐱"
		glyph.TextScaled = true -- an emoji stand-in, not words: it fills its tile
		glyph.Parent = tile
	end
	tile.Parent = parent
	return tile
end

return Portraits
