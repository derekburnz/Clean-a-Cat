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
	-- the 20 cats, clean and at dirt level 1 (#794, upload run 45894254332); 2 to 4 after #791
	Bathtile = "rbxassetid://104371157404490",
	Bathtile_Dirty1 = "rbxassetid://94991187930912",
	Cotton = "rbxassetid://80096910425422",
	Cotton_Dirty1 = "rbxassetid://117451508772949",
	Djinn = "rbxassetid://109186971661634",
	Djinn_Dirty1 = "rbxassetid://85993286845676",
	Inky = "rbxassetid://122077934082838",
	Inky_Dirty1 = "rbxassetid://92789474698464",
	Jade = "rbxassetid://92101460375197",
	Jade_Dirty1 = "rbxassetid://125472089712055",
	LilacCloud = "rbxassetid://75943441954449",
	LilacCloud_Dirty1 = "rbxassetid://136675601469155",
	Marble = "rbxassetid://114874094825509",
	Marble_Dirty1 = "rbxassetid://138698246376272",
	Moonstag = "rbxassetid://79993946472684",
	Moonstag_Dirty1 = "rbxassetid://102082047842998",
	Muffin = "rbxassetid://97606052567188",
	Muffin_Dirty1 = "rbxassetid://93154177368279",
	Patches = "rbxassetid://91917604628792",
	Patches_Dirty1 = "rbxassetid://87621820192421",
	Phoenix = "rbxassetid://118082407857643",
	Phoenix_Dirty1 = "rbxassetid://117909308712404",
	Prism = "rbxassetid://74332001223114",
	Prism_Dirty1 = "rbxassetid://111447330527563",
	Rosette = "rbxassetid://123002968671356",
	Rosette_Dirty1 = "rbxassetid://83850186176603",
	Sherbet = "rbxassetid://124924090636385",
	Sherbet_Dirty1 = "rbxassetid://101381812378730",
	Smudge = "rbxassetid://71528379538305",
	Smudge_Dirty1 = "rbxassetid://113592255437124",
	Starcoat = "rbxassetid://73756232054918",
	Starcoat_Dirty1 = "rbxassetid://129469414193652",
	Stardust = "rbxassetid://116822669982867",
	Stardust_Dirty1 = "rbxassetid://104586769842876",
	Toffee = "rbxassetid://130371035242121",
	Toffee_Dirty1 = "rbxassetid://134685108707242",
	Tux = "rbxassetid://109271146277726",
	Tux_Dirty1 = "rbxassetid://108386771191031",
	WhiteTiger = "rbxassetid://85918010213265",
	WhiteTiger_Dirty1 = "rbxassetid://79069001924692",
} :: { [string]: string }

-- The stand-in glyph for a cat with no image yet; the cat glyph when not listed. One code point each: a joined emoji
-- such as the black cat (cat + zero width joiner + black square) splits into two glyphs on some phones (Sync-Agent).
Portraits.GLYPHS = {
	Suds = "🐈",
} :: { [string]: string }

local TILE_TINT = 0.55 -- how far the stand-in tile's rarity colour is lightened toward white

-- The picture for `cat` at dirt level `dirt` (1 to 4, DirtRules): "<Cat>_Dirty<n>" when uploaded, else the nearest
-- lower level that is, else the clean picture; "" when there is none yet (the stand-in draws). Issue 794: levels 2 to
-- 4 wait for the re-render after issue 791, so they show level 1 until then.
function Portraits.imageFor(cat: string, dirt: number?): string
	local level = dirt or 0
	while level >= 1 do
		local dirty: string? = Portraits.IMAGES[`{cat}_Dirty{level}`]
		if dirty ~= nil and dirty ~= "" then
			return dirty
		end
		level -= 1
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
