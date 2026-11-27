--!strict
-- Portraits: the ONE place a cat's portrait image is set, for the recap card now and the Cat Index later. Model-Agent
-- renders them (the screens' img/portrait_<Name>_ink.png). Until a group upload exists (rule 18) a name maps to "" and
-- the portrait draws its stand-in: a cat glyph on a tile in the rarity's colour. Portraits are drawn at 48 real px or
-- larger.
local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Portraits = {}

-- cat name -> "rbxassetid://<id>" once uploaded under the group; a missing or "" entry draws the stand-in. Suds, the
-- mascot (#285), has his own key here though he is not in the Cat Index.
Portraits.IMAGES = {
	Suds = "rbxassetid://134546291029280", -- CleanACat_UI_Portrait_Suds, round cheeks, group upload (#784)
	-- the 20 cats, clean (#794, upload run 45894254332) and at dirt levels 1 to 4 (the tangle and fluff renders after
	-- #791, upload run 45902777416)
	Bathtile = "rbxassetid://104371157404490",
	Bathtile_Dirty1 = "rbxassetid://139156526949599",
	Bathtile_Dirty2 = "rbxassetid://70663362429604",
	Bathtile_Dirty3 = "rbxassetid://131072418820327",
	Bathtile_Dirty4 = "rbxassetid://116865478696581",
	Cotton = "rbxassetid://80096910425422",
	Cotton_Dirty1 = "rbxassetid://114859924239800",
	Cotton_Dirty2 = "rbxassetid://130521564766189",
	Cotton_Dirty3 = "rbxassetid://94565195519463",
	Cotton_Dirty4 = "rbxassetid://111878139570591",
	Djinn = "rbxassetid://109186971661634",
	Djinn_Dirty1 = "rbxassetid://104938201513784",
	Djinn_Dirty2 = "rbxassetid://71136825395038",
	Djinn_Dirty3 = "rbxassetid://105010225463490",
	Djinn_Dirty4 = "rbxassetid://124587678339342",
	Inky = "rbxassetid://122077934082838",
	Inky_Dirty1 = "rbxassetid://96548148587417",
	Inky_Dirty2 = "rbxassetid://139877835119095",
	Inky_Dirty3 = "rbxassetid://98572961391993",
	Inky_Dirty4 = "rbxassetid://114507032994250",
	Jade = "rbxassetid://92101460375197",
	Jade_Dirty1 = "rbxassetid://109529679809623",
	Jade_Dirty2 = "rbxassetid://110110321934140",
	Jade_Dirty3 = "rbxassetid://91205509807847",
	Jade_Dirty4 = "rbxassetid://77203951376625",
	LilacCloud = "rbxassetid://75943441954449",
	LilacCloud_Dirty1 = "rbxassetid://123601403519347",
	LilacCloud_Dirty2 = "rbxassetid://93761717910944",
	LilacCloud_Dirty3 = "rbxassetid://86047873180553",
	LilacCloud_Dirty4 = "rbxassetid://101825651814740",
	Marble = "rbxassetid://114874094825509",
	Marble_Dirty1 = "rbxassetid://110351669539559",
	Marble_Dirty2 = "rbxassetid://110365581073102",
	Marble_Dirty3 = "rbxassetid://121563404782426",
	Marble_Dirty4 = "rbxassetid://116591089955294",
	Moonstag = "rbxassetid://79993946472684",
	Moonstag_Dirty1 = "rbxassetid://87364487016387",
	Moonstag_Dirty2 = "rbxassetid://73340789586983",
	Moonstag_Dirty3 = "rbxassetid://131770902912993",
	Moonstag_Dirty4 = "rbxassetid://105315092131314",
	Muffin = "rbxassetid://97606052567188",
	Muffin_Dirty1 = "rbxassetid://103732360664273",
	Muffin_Dirty2 = "rbxassetid://135173358834258",
	Muffin_Dirty3 = "rbxassetid://95151893323177",
	Muffin_Dirty4 = "rbxassetid://126041857156058",
	Patches = "rbxassetid://91917604628792",
	Patches_Dirty1 = "rbxassetid://120213831556695",
	Patches_Dirty2 = "rbxassetid://87305528515138",
	Patches_Dirty3 = "rbxassetid://75709165640705",
	Patches_Dirty4 = "rbxassetid://76106038693945",
	Phoenix = "rbxassetid://118082407857643",
	Phoenix_Dirty1 = "rbxassetid://132833230431582",
	Phoenix_Dirty2 = "rbxassetid://126788086927816",
	Phoenix_Dirty3 = "rbxassetid://109785083182074",
	Phoenix_Dirty4 = "rbxassetid://109761525322539",
	Prism = "rbxassetid://74332001223114",
	Prism_Dirty1 = "rbxassetid://77142244148141",
	Prism_Dirty2 = "rbxassetid://100818351454303",
	Prism_Dirty3 = "rbxassetid://122558099778552",
	Prism_Dirty4 = "rbxassetid://84651845088842",
	Rosette = "rbxassetid://123002968671356",
	Rosette_Dirty1 = "rbxassetid://103391589010434",
	Rosette_Dirty2 = "rbxassetid://82402858139633",
	Rosette_Dirty3 = "rbxassetid://138974850982583",
	Rosette_Dirty4 = "rbxassetid://92332868749907",
	Sherbet = "rbxassetid://124924090636385",
	Sherbet_Dirty1 = "rbxassetid://102861276283434",
	Sherbet_Dirty2 = "rbxassetid://80910111657134",
	Sherbet_Dirty3 = "rbxassetid://99309578237973",
	Sherbet_Dirty4 = "rbxassetid://89391291978262",
	Smudge = "rbxassetid://71528379538305",
	Smudge_Dirty1 = "rbxassetid://139293158007169",
	Smudge_Dirty2 = "rbxassetid://102294176625024",
	Smudge_Dirty3 = "rbxassetid://70646736832447",
	Smudge_Dirty4 = "rbxassetid://81708011101647",
	Starcoat = "rbxassetid://73756232054918",
	Starcoat_Dirty1 = "rbxassetid://132431920637167",
	Starcoat_Dirty2 = "rbxassetid://75087967863053",
	Starcoat_Dirty3 = "rbxassetid://117207608160037",
	Starcoat_Dirty4 = "rbxassetid://84400608270214",
	Stardust = "rbxassetid://116822669982867",
	Stardust_Dirty1 = "rbxassetid://72063351520159",
	Stardust_Dirty2 = "rbxassetid://91254485760597",
	Stardust_Dirty3 = "rbxassetid://138588632614896",
	Stardust_Dirty4 = "rbxassetid://135021406840570",
	Toffee = "rbxassetid://130371035242121",
	Toffee_Dirty1 = "rbxassetid://119739945379078",
	Toffee_Dirty2 = "rbxassetid://85593504689652",
	Toffee_Dirty3 = "rbxassetid://127159878345036",
	Toffee_Dirty4 = "rbxassetid://78826708044535",
	Tux = "rbxassetid://109271146277726",
	Tux_Dirty1 = "rbxassetid://118450788350304",
	Tux_Dirty2 = "rbxassetid://118286051415343",
	Tux_Dirty3 = "rbxassetid://81178407753904",
	Tux_Dirty4 = "rbxassetid://80784584092912",
	WhiteTiger = "rbxassetid://85918010213265",
	WhiteTiger_Dirty1 = "rbxassetid://118681560108494",
	WhiteTiger_Dirty2 = "rbxassetid://111573284250160",
	WhiteTiger_Dirty3 = "rbxassetid://105265029405232",
	WhiteTiger_Dirty4 = "rbxassetid://123255647273640",
	-- the eight crate pets under their new names (issue 883, Model-Agent's PR 962), group owned
	Clover = "rbxassetid://77963078642728", -- redrawn 2026-11-27 (Model-Agent PR 997)
	Ghost = "rbxassetid://85397860599687",
	Ooze = "rbxassetid://129987399664489",
	Glitch = "rbxassetid://80341127367421", -- redrawn 2026-11-27 (Model-Agent PR 997)
	Angler = "rbxassetid://107617453014958",
	Nebula = "rbxassetid://118688157626872",
	Dragon = "rbxassetid://119730475255717",
	Blaze = "rbxassetid://133643213662061",
} :: { [string]: string }

-- The stand-in glyph for a cat with no image yet; the cat glyph when not listed. One code point each: a joined emoji
-- such as the black cat (cat + zero width joiner + black square) splits into two glyphs on some phones (Sync-Agent).
Portraits.GLYPHS = {
	Suds = "🐈",
} :: { [string]: string }

local TILE_TINT = 0.55 -- how far the stand-in tile's rarity colour is lightened toward white

-- The picture for `cat` at dirt level `dirt` (1 to 4, DirtRules): "<Cat>_Dirty<n>" when uploaded, else the nearest
-- lower level that is, else the clean picture; "" when there is none yet (the stand-in draws).
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
	local function glyphIn()
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Glyph"
		glyph.BackgroundTransparency = 1
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.Size = UDim2.fromScale(0.7, 0.7)
		glyph.Text = Portraits.GLYPHS[cat] or "🐱"
		glyph.TextScaled = true -- an emoji stand-in, not words: it fills its tile
		glyph.ZIndex = tile.ZIndex
		glyph.Parent = tile
	end
	if image ~= "" and not Icons.hasFailed(image) then
		local label = Instance.new("ImageLabel")
		label.Name = "Image"
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.92, 0.92)
		label.Image = image
		label.ScaleType = Enum.ScaleType.Fit
		label.Parent = tile
		-- a portrait that will not load shows its emoji, never a bare tinted circle (issue 1034)
		Icons.onFail(label, image, function()
			label:Destroy()
			glyphIn()
		end)
	else
		glyphIn()
	end
	tile.Parent = parent
	return tile
end

return Portraits
