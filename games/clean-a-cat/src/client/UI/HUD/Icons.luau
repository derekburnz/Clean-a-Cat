--!strict
-- HUD icons: the ONE place an icon image is set (#210). Derek picked Model-Agent's 3D renders "for now"
-- (CleanACat_Icon_Hud_*, 512 px), so a later swap must touch only IMAGES. The ids are group-owned uploads (Creampuff
-- Games, 2026-11-24, Model-Agent); one without an upload yet stays "" and draws its stand-in: a glyph on a coloured
-- tile. A picture still in moderation draws blank until Roblox approves it. Model icons are drawn at 48 real px or
-- larger and are never scaled by TextSize.
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local Icons = {}

-- name -> "rbxassetid://<id>" once uploaded under the group (rule 18); "" draws the stand-in.
Icons.IMAGES = {
	Coins = "rbxassetid://116447888023490",
	Index = "rbxassetid://121227338658862",
	Settings = "rbxassetid://118282050361608",
	Sponge = "",
	Brush = "",
	Bow = "rbxassetid://134446077497785", -- a pink bow (2026-11-26, PR 706)
	Camera = "rbxassetid://81858835488207",
	Star = "rbxassetid://79608175953496",
	Paw = "rbxassetid://107223055953057",
	Heart = "rbxassetid://76458853696811",
	-- the like how-to's loop (issue 869): no hands (Model-Agent's PR 976); the filled heart is the approved Heart, the
	-- grey heart and the tap dot passed Review-QA's image gate (upload-asset run 45940088945)
	HeartFilled = "rbxassetid://76458853696811",
	RingPuff = "rbxassetid://113448726935917",
	HeartOutline = "rbxassetid://98146759736466", -- the like how-to's empty heart, no hands (issue 869)
	TapDot = "rbxassetid://112847264343092", -- the like how-to's tap dot (issue 869)
	Station = "rbxassetid://123888181775346",
	Gear = "rbxassetid://118282050361608", -- the Settings render
	Gift = "rbxassetid://111988171087116",
	Music = "rbxassetid://121194068527540",
	Speaker = "rbxassetid://86682357409787",
	Shake = "rbxassetid://85720072168320",
	Sparkle = "rbxassetid://109429421000897",
	Dice = "rbxassetid://129990093520857",
	Check = "rbxassetid://74659087291165",
	Crown = "rbxassetid://104854723012308",
	Lock = "rbxassetid://113173528545537",
	Mud = "rbxassetid://137792046843119",
	Tangles = "rbxassetid://115237769890322",
	Wet = "rbxassetid://94261429421876",
	Smell = "", -- the Bubble Bath's need (#267)
	Claws = "", -- the Pawdicure's need (#267)
	Pointer = "rbxassetid://86511050552339",
	Helper = "rbxassetid://73988627805858", -- CleanACat_Icon_Hud_Helper, round cheeks (#784)
	Tools = "rbxassetid://100929090324662",
	Build = "rbxassetid://84861881998122",
	-- the HUD buttons' own pictures (Model-Agent, PR 706, group uploads 2026-11-26)
	Quests = "rbxassetid://80864490324180", -- a clipboard with a tick
	Shop = "rbxassetid://75206569453389", -- a shopfront with a striped awning; soft below 48 px, so keep it 48+
	Pets = "rbxassetid://112809586144557", -- a lilac cat's head in a collar with a bell
	Crate = "rbxassetid://79856687835511", -- the pet crate with cat ears and a paw latch
	-- two helpers side by side (CleanACat_Icon_Hud_HelpersTeam, Model-Agent, issue 1110, Derek 2026-11-27 on the apron:
	-- "this icon sucks remake it"; image gate passed). Was the staff apron 75869829179271, before that Jo's head
	Helpers = "rbxassetid://97491083681037",
	-- each helper's own smooth bust (issue 1036, Derek: "redo the picture for helpers it looks blocky and mid and it
	-- shouldn't be the same as the first worker"; Model-Agent's uploads to the group, 2026-11-27)
	StaffJo = "rbxassetid://85051325996520",
	StaffSam = "rbxassetid://73703341255691",
	StaffLou = "rbxassetid://114806114354624",
	-- the shop's big card pictures (issues 1030 and 1031, Model-Agent): their x2, x3 or +1 is drawn in the picture
	ShopExtraWorker = "rbxassetid://95165289753902",
	ShopCoins2x = "rbxassetid://113360699781391",
	ShopCoins3x = "rbxassetid://114423850933764",
	ShopBuilder2 = "rbxassetid://79901743380915",
	ShopGoldenSponge = "rbxassetid://89559848537020",
	ShopPetSlot2 = "rbxassetid://114149856510592",
	-- Midas, the starter pack's golden pet, whole with sparkles (issue 1090, Model-Agent's PR 1093, group upload run
	-- 46012351823 after Review-QA's image gate)
	ShopStarterPet = "rbxassetid://75389504028903",
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
	-- the like how-to's loop (issue 869) until Model-Agent's icons are uploaded
	HeartOutline = { glyph = "🤍", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	HeartFilled = { glyph = "💗", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	TapDot = { glyph = "", fill = Color3.fromHex("FFF6EC"), round = true },
	RingPuff = { glyph = "✨", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
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
	Smell = { glyph = "🧼", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Claws = { glyph = "💅", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Pencil = { glyph = "✏️", fill = Color3.fromHex("FFFFFF"), round = true, bare = true }, -- rename a helper
	Quests = { glyph = "📋", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Shop = { glyph = "🏪", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Pets = { glyph = "🐱", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Crate = { glyph = "📦", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Helpers = { glyph = "🧑", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Pointer = { glyph = "👈", fill = Color3.fromHex("FFFFFF"), round = true, bare = true }, -- the tutorial's arrow
	Helper = { glyph = "🧑", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	StaffJo = { glyph = "👩", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	StaffSam = { glyph = "👨", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	StaffLou = { glyph = "🧑", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	ShopExtraWorker = { glyph = "🧑", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	ShopCoins2x = { glyph = "🪙", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	ShopCoins3x = { glyph = "💰", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	ShopBuilder2 = { glyph = "🔨", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	ShopGoldenSponge = {
		glyph = "🧽",
		fill = Color3.fromHex("FFFFFF"),
		round = true,
		bare = true,
	},
	ShopPetSlot2 = { glyph = "🐾", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	ShopStarterPet = { glyph = "🐱", fill = Color3.fromHex("FFE98F"), round = true, bare = true },
	Tools = { glyph = "🧴", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Build = { glyph = "🔨", fill = Color3.fromHex("FFFFFF"), round = true, bare = true },
	Hotel = { glyph = "🛏️", fill = Color3.fromHex("FFFFFF"), round = true, bare = true }, -- the Cat Hotel's card (1051)
}
Icons.STAND_INS = STAND_INS

-- Ids that would not load on this device (issue 1034, Derek: "tons of missing hud and ui images"): a rejected,
-- deleted or not group-owned picture fails its fetch and drew a blank square. Once one fails it draws its stand-in, here
-- and on every later draw, so a button is never empty.
local failed: { [string]: boolean } = {}

local drawStandIn: (name: string, parent: GuiObject, fade: number) -> GuiObject

-- Calls `fallback` once if `image` on `label` fails to load (Roblox reports its fetch as Failure), and remembers the id
-- as failed. Only in a running game. Portraits uses it too.
function Icons.onFail(label: ImageLabel, image: string, fallback: () -> ())
	if not RunService:IsRunning() then
		return
	end
	local done = false
	local function fail()
		if done then
			return
		end
		done = true
		failed[image] = true
		if label.Parent then
			fallback()
		end
	end
	task.spawn(function()
		if Icons.check(label, image, ContentProvider :: any) then
			fail()
		end
	end)
end

-- The part of the provider Icons.check uses (ContentProvider, or a stand-in in tests).
export type Provider = {
	PreloadAsync: (self: any, items: { Instance }) -> (),
	GetAssetFetchStatus: (self: any, id: string) -> Enum.AssetFetchStatus,
}

-- Whether `image` on `label` failed to load. Preloads the LABEL, never the bare "rbxassetid://" string: for image ids
-- the string form always reports Failure, which swapped every picture for its stand-in (Sync on #1054). Then only a
-- fetch Roblox reports as Failure for this id counts; a slow or timed out fetch, or a hidden label not drawn yet, never
-- does. Yields while it preloads.
function Icons.check(label: ImageLabel, image: string, provider: Provider): boolean
	local ok = pcall(function()
		provider:PreloadAsync({ label })
	end)
	if not ok or label.Parent == nil then
		return false
	end
	local read, status = pcall(function(): Enum.AssetFetchStatus
		return provider:GetAssetFetchStatus(image)
	end)
	return read and status == Enum.AssetFetchStatus.Failure
end

function Icons.hasFailed(image: string): boolean
	return failed[image] == true
end

-- Swaps `label` for its stand-in when its picture fails to load, keeping the ZIndex a caller gave it.
local function watch(label: ImageLabel, name: string, image: string, fade: number)
	Icons.onFail(label, image, function()
		local parent = label.Parent
		if parent == nil or not parent:IsA("GuiObject") then
			return
		end
		local z = label.ZIndex
		label:Destroy()
		local drawn = drawStandIn(name, parent :: GuiObject, fade)
		drawn.ZIndex = z
		for _, d in drawn:GetDescendants() do
			if d:IsA("GuiObject") then
				(d :: GuiObject).ZIndex = z
			end
		end
	end)
end

-- Puts icon `name` inside `parent`, filling it, and returns it. `faded` dims it (a step already done).
function Icons.draw(name: string, parent: GuiObject, faded: boolean?): GuiObject
	local old = parent:FindFirstChild("Icon")
	if old then
		old:Destroy()
	end
	local fade = if faded then 0.55 else 0
	local image = Icons.IMAGES[name] or ""
	if image ~= "" and not failed[image] then
		local label = Instance.new("ImageLabel")
		label.Name = "Icon"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Image = image
		label.ScaleType = Enum.ScaleType.Fit
		label.ImageTransparency = fade
		label.Parent = parent
		watch(label, name, image, fade)
		return label
	end
	return drawStandIn(name, parent, fade)
end

function drawStandIn(name: string, parent: GuiObject, fade: number): GuiObject
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
