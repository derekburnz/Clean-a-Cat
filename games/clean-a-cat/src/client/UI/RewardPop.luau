--!strict
-- RewardPop: the big "You got it!" popup (issue 1024, switch rewardPop). Derek, 2026-11-27: "lots of pop ups like got
-- this from crate or found this in crate are missing images and also make it easier to see the popups check how other
-- popular games do it". Popular Roblox games show a reward in the middle of the screen: the item large on a turning
-- sunburst, its name big and outlined, its rarity under it, the screen dimmed behind. This is ours in that shape:
--   * the picture (ToastRules.pictureOf): the pet's or cat's portrait framed in its rarity's colour, else the HUD icon
--     of what it gives on a white round tile, on gold rays that turn slowly (still with Reduced Motion);
--   * the title in big white words with the ink outline ("You got Clover!"), the rest of the notice under it;
--   * "Tap to close": a tap anywhere closes it, and it closes by itself (UI holds it RewardPop.SECONDS).
-- It pops in with the shared pop curve and fades out. Coins, builds and news stay small cards (ToastRules.popOf).
-- Nothing on it buys or asks for anything.
--
--   local close = RewardPop.show(root, pop, picture, onClosed)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ToastRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ToastRules"))

local Comfort = require(script.Parent:WaitForChild("Comfort"))
local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Pop = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Pop"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))

local RewardPop = {}

RewardPop.SECONDS = 3.5 -- how long it stays when nothing else waits
RewardPop.SHORT = 1.6 -- at least this long when more notices wait
RewardPop.FADE = 0.18

local PICTURE = 132 -- design px: the picture's side
local PICTURE_SHORT = 104 -- on a short screen
local RAYS = 12
local RAY_W = 0.09 -- of the rays' circle
local RAYS_OF_PICTURE = 2.3 -- the sunburst's size against the picture
local TURN = 18 -- degrees a second
local TITLE = 34
local SUB = 20
local HINT = 19 -- the 14 real px floor at the smallest scale
local DIM = 0.5 -- the backdrop's transparency
local WIDE = 560 -- design px: the words' widest

-- The rarity a notice names at the start of its second line ("Common, +5% on your tips"), if any.
local function rarityOf(sub: string): string?
	local word = string.match(sub, "^(%a+)")
	local colour: Color3? = if word then Kit.RARITY[word] else nil
	return if colour ~= nil then word else nil
end

local function drawPicture(holder: Frame, picture: ToastRules.Picture?, rarity: string?)
	if picture and picture.kind == "portrait" then
		local tile = Portraits.draw(picture.name, rarity or "Common", holder)
		tile.ZIndex = 3
		for _, d in tile:GetDescendants() do
			if d:IsA("GuiObject") then
				(d :: GuiObject).ZIndex = 3
			end
		end
		return
	end
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.Size = UDim2.fromScale(1, 1)
	tile.BackgroundColor3 = Kit.WHITE
	tile.ZIndex = 3
	Kit.corner(tile, UDim.new(0.5, 0))
	Kit.stroke(tile, 4).Color = Kit.INK
	tile.Parent = holder
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.68, 0.68)
	inner.ZIndex = 3
	inner.Parent = tile
	local drawn = Icons.draw(if picture then picture.name else "Gift", inner)
	drawn.ZIndex = 3
	for _, d in drawn:GetDescendants() do
		if d:IsA("GuiObject") then
			(d :: GuiObject).ZIndex = 3
		end
	end
end

-- Shows the popup over `root` and returns a function that closes it. `onClosed` runs once, when it has gone (by the
-- tap or the close function).
function RewardPop.show(
	root: GuiObject,
	pop: ToastRules.Pop,
	picture: ToastRules.Picture?,
	onClosed: (() -> ())?
): () -> ()
	local old = root:FindFirstChild("RewardPop")
	if old then
		old:Destroy()
	end
	local scale, short = Kit.screenScale()
	local reduced = Comfort.reducedMotion()
	local rarity = rarityOf(pop.sub)
	local rim = if rarity then Kit.RARITY[rarity] else Kit.GOLD

	-- the dimmed screen: a tap anywhere closes
	local back = Instance.new("TextButton")
	back.Name = "RewardPop"
	back.Text = ""
	back.AutoButtonColor = false
	back.BackgroundColor3 = Kit.INK
	back.BackgroundTransparency = 1
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 50
	back.Selectable = false

	local stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0.5, 0.5)
	stack.Position = UDim2.fromScale(0.5, 0.5)
	stack.AutomaticSize = Enum.AutomaticSize.XY
	stack.Size = UDim2.fromOffset(0, 0)
	stack.ZIndex = 51
	stack.Parent = back
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, math.floor(6 * scale))
	list.Parent = stack
	local grow = Instance.new("UIScale")
	grow.Scale = if reduced then 1 else Pop.FROM
	grow.Parent = stack

	local side = math.floor((if short then PICTURE_SHORT else PICTURE) * scale)
	local holder = Instance.new("Frame")
	holder.Name = "Picture"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(side, side)
	holder.LayoutOrder = 1
	holder.ZIndex = 52
	holder.Parent = stack

	-- the sunburst behind the picture: gold rays turning slowly, a soft glow in the rarity's colour
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(RAYS_OF_PICTURE, RAYS_OF_PICTURE)
	rays.ZIndex = 1
	rays.Parent = holder
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.45, 1.45)
	glow.BackgroundColor3 = rim
	glow.BackgroundTransparency = 0.45
	glow.ZIndex = 2
	Kit.corner(glow, UDim.new(0.5, 0))
	glow.Parent = holder
	for i = 1, RAYS do
		local ray = Instance.new("Frame")
		ray.Name = `Ray{i}`
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(RAY_W, 1)
		ray.Rotation = (i - 1) * 180 / RAYS
		ray.BackgroundColor3 = if i % 2 == 0 then Kit.GOLD_TEXT else Kit.GOLD
		ray.BackgroundTransparency = 0.25
		ray.BorderSizePixel = 0
		ray.ZIndex = 1
		Kit.corner(ray, UDim.new(0.5, 0))
		ray.Parent = rays
	end
	drawPicture(holder, picture, rarity)

	local wide = math.floor(WIDE * scale)
	local function words(name: string, text: string, size: number, order: number): TextLabel
		local label = Kit.outlined(name, stack)
		label.Text = text
		label.TextSize = math.floor(math.max(size, HINT) * scale)
		label.TextWrapped = true
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.fromOffset(wide, 0)
		label.LayoutOrder = order
		label.ZIndex = 53
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
		if limit then
			limit:Destroy() -- sized here already, with its floor
		end
		return label
	end
	local title = words("Title", pop.title, TITLE, 2)
	title.TextColor3 = Kit.WHITE
	if pop.sub ~= "" then
		local sub = words("Sub", pop.sub, SUB, 3)
		sub.TextColor3 = if rarity then rim:Lerp(Kit.WHITE, 0.35) else Kit.GOLD_TEXT
	end
	local hint = words("Hint", "Tap to close", HINT, 4)
	hint.TextColor3 = Kit.CREAM
	hint.TextTransparency = 0.15

	back.Parent = root

	local spin: RBXScriptConnection? = nil
	local began = os.clock()
	spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if not reduced then
			rays.Rotation = (t * TURN) % 360
			grow.Scale = if Pop.done(t) then 1 else Pop.scale(t)
		end
		back.BackgroundTransparency = 1 - (1 - DIM) * math.min(t / RewardPop.FADE, 1)
	end)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local turning = spin
		if turning then
			turning:Disconnect()
			spin = nil
		end
		back.Active = false
		local info = TweenInfo.new(RewardPop.FADE)
		TweenService:Create(back, info, { BackgroundTransparency = 1 }):Play()
		if not reduced then
			TweenService:Create(grow, info, { Scale = 0.85 }):Play()
		end
		for _, d in back:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
			if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(RewardPop.FADE, function()
			back:Destroy()
			if onClosed then
				onClosed()
			end
		end)
	end
	back.Activated:Connect(close)
	return close
end

return RewardPop
