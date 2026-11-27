--!strict
-- GiftCard: the gift stand's card (issue 521), behind the switch giftStand (with pets). It opens when the player taps
-- the prompt on their own lit stand (GiftCardController), never by itself.
--
--   GiftCard.build(root)          makes the window once and returns its layer ("Gift")
--   GiftCard.set(state)           draws GiftViewRules' steps for GiftController.state()
--   GiftCard.onStep(fn)           fn(key) when a step's button is pressed ("favourite" or "group"; with the free
--                                 rewards rows, issue 730: "like", "likeClaim" and "playClaim")
--   GiftCard.onClaim(fn)          fn() when Get Starcoat is pressed
--
-- The free pet on the left (its portrait, name, rarity and "A free pet, yours to keep"); on the right the steps:
-- Favourite and Join, each with a button that opens Roblox's own prompt and a tick once the server has it, and the
-- like, asked for in words with no button and no tick. Get Starcoat under them is green once both are ticked and a
-- soft cream with "One step to go" before. Nothing costs Robux and nothing is random. UI never fires remotes:
-- GiftCardController calls GiftController, which asks the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local GiftViewRules = require(Shared:WaitForChild("GiftViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))
local Window = require(script.Parent:WaitForChild("Window"))

local GiftCard = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local BLUE_TOP, BLUE_BOTTOM = Color3.fromHex("8FD8FF"), Color3.fromHex("4FB3F0")
local WAIT_TOP, WAIT_BOTTOM = Color3.fromHex("EDE3F5"), Color3.fromHex("D9CBE6")
local TICK_FILL = Color3.fromHex("3FB071")
local PET_TOP = Color3.fromHex("E9F9F1")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 8
local FREE_TRIM = 4 -- design px off each free rewards row on a short screen
local MIN_TAP = 44 -- real px

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 860,
		band = 72,
		title = 34,
		badge = 96,
		pad = 18,
		gap = 16,
		petW = 250,
		pic = 150,
		petName = 26,
		petLine = 17,
		rowH = 76,
		rowGap = 10,
		icon = 44,
		rowTitle = 22,
		rowLine = 16,
		actionW = 150,
		actionText = 21,
		claimH = 64,
		claimText = 26,
		wait = 17,
	},
	short = {
		width = 760,
		band = 56,
		title = 28,
		badge = 80,
		pad = 10,
		gap = 10,
		petW = 190,
		pic = 96,
		petName = 22,
		petLine = 15,
		rowH = 62,
		rowGap = 6,
		icon = 38,
		rowTitle = 19,
		rowLine = 15,
		actionW = 130,
		actionText = 19,
		claimH = 56,
		claimText = 22,
		wait = 15,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	columns: UIListLayout,
	pet: Frame,
	pic: Frame,
	petName: TextLabel,
	petRarity: TextLabel,
	petLine: TextLabel,
	right: Frame,
	rows: Frame,
	rowList: UIListLayout,
	claim: TextButton,
	claimGradient: UIGradient,
	wait: TextLabel,
}

local parts: Parts? = nil
local state: GiftViewRules.State =
	{ lit = false, favourite = false, group = false, claimed = false }
local stepListeners: { (key: string) -> () } = {}
local claimListeners: { () -> () } = {}

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function words(name: string, parent: Instance, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Kit.FONT
	label.TextColor3 = Kit.INK
	label.TextSize = size
	Kit.minText(label)
	label.Parent = parent
	return label
end

local function list(parent: Instance, horizontal: boolean, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

local function drawStep(
	step: GiftViewRules.Step,
	order: number,
	s: Sizes,
	scale: number,
	parent: Frame
)
	local row = frame(step.key, parent)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, s.rowH)
	row.BackgroundTransparency = 0
	row.BackgroundColor3 = Kit.WHITE
	Kit.corner(row, UDim.new(0, 16))
	local edge = Kit.stroke(row, 3)
	edge.Color = if step.done then TICK_FILL else Kit.LINE
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = row

	local icon = frame("Icon", row)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Size = UDim2.fromOffset(s.icon, s.icon)
	Icons.draw(step.icon, icon)

	local rightRoom = if step.action then s.actionW + 10 elseif step.done then s.icon + 6 else 0
	local textX = s.icon + 12
	local title = words("Title", row, s.rowTitle)
	title.Position = UDim2.new(0, textX, 0.5, -(s.rowTitle + 2))
	title.Size = UDim2.new(1, -(textX + rightRoom), 0, s.rowTitle + 2)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Kit.shrinkToFit(title, s.rowTitle)
	title.Text = step.title
	local line = words("Line", row, s.rowLine)
	line.FontFace = Kit.BODY_FACE
	line.TextColor3 = Kit.INK_SOFT
	line.Position = UDim2.new(0, textX, 0.5, 2)
	line.Size = UDim2.new(1, -(textX + rightRoom), 0, s.rowLine + 4)
	line.TextXAlignment = Enum.TextXAlignment.Left
	Kit.shrinkToFit(line, s.rowLine)
	line.Text = step.line

	local action = step.action
	if action then
		local key = step.key
		local style = step.style or "ask"
		local top, bottom = BLUE_TOP, BLUE_BOTTOM
		if style == "claim" then
			top, bottom = GREEN_TOP, GREEN_BOTTOM
		elseif style == "wait" then
			top, bottom = WAIT_TOP, WAIT_BOTTOM
		end
		local button = Window.button("Action", action, row, top, bottom)
		if style == "wait" then
			-- a countdown, not a button: nothing to press until the gift is ready
			button.AutoButtonColor = false
			button.Active = false
			button.TextColor3 = Kit.INK_SOFT
			button.TextStrokeTransparency = 1
		end
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		button.Size = UDim2.fromOffset(s.actionW, math.max(s.rowH - 16, math.ceil(MIN_TAP / scale)))
		button.TextSize = s.actionText
		button.Activated:Connect(function()
			if style == "wait" then
				return
			end
			for _, listener in stepListeners do
				task.spawn(listener, key)
			end
		end)
	elseif step.done then
		local tick = frame("Tick", row)
		tick.AnchorPoint = Vector2.new(1, 0.5)
		tick.Position = UDim2.fromScale(1, 0.5)
		tick.Size = UDim2.fromOffset(s.icon, s.icon)
		Icons.draw("Check", tick)
	end
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	if short and state.free then
		-- four free rewards rows put Get Starcoat a few px under a small phone's bottom edge (issue 837): the rows
		-- sit a little closer, the same rows at the same text sizes
		s = table.clone(s)
		s.rowH -= FREE_TRIM
		s.rowGap -= 2
	end
	local width = math.min(s.width, screenWidth(scale) - SCREEN_MARGIN)
	Window.fit(p.window, width, s.band, s.title, s.badge, if short then SHORT_SHIFT else nil)
	p.window.title.Text = if state.free then GiftViewRules.FREE_TITLE else GiftViewRules.TITLE
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad + 2), pad
	p.columns.Padding = UDim.new(0, s.gap)

	-- the pet
	p.pet.Size = UDim2.fromOffset(s.petW, 0)
	p.pic.Size = UDim2.fromOffset(s.pic, s.pic)
	-- (giftCrate, issue 859) the stand gives a crate to open, not Starcoat: the crate's picture, its name and what is in it
	local crate = LiveFlags.isOn(CrateRules.GIFT_FLAG)
	local rarity = CrateRules.rarityOf(GiftViewRules.PET) or "Uncommon"
	local stale = p.pic:FindFirstChild(if crate then "Portrait" else "Icon") -- the other picture, if the switch moved
	if stale then
		stale:Destroy()
	end
	if crate then
		Icons.draw("Crate", p.pic)
	else
		Portraits.draw(GiftViewRules.PET, rarity, p.pic)
	end
	p.petName.TextSize = s.petName
	p.petName.Size = UDim2.new(1, 0, 0, s.petName + 4)
	p.petName.Text = if crate then GiftViewRules.CRATE else GiftViewRules.PET
	p.petRarity.TextSize = s.petLine
	p.petRarity.Size = UDim2.new(1, 0, 0, s.petLine + 4)
	p.petRarity.Text = rarity
	p.petRarity.Visible = not crate
	p.petRarity.TextColor3 = (Kit.RARITY[rarity] or Kit.INK):Lerp(Kit.INK, 0.45)
	p.petLine.TextSize = s.petLine
	p.petLine.Size = UDim2.new(1, 0, 0, s.petLine * 2 + 4)
	p.petLine.Text = if crate then GiftViewRules.CRATE_LINE else GiftViewRules.PET_LINE

	-- the steps, then Get Starcoat
	p.right.Size = UDim2.fromOffset(width - 2 * s.pad - s.petW - s.gap, 0)
	for _, child in p.rows:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	p.rowList.Padding = UDim.new(0, s.rowGap)
	for index, step in GiftViewRules.steps(state) do
		drawStep(step, index, s, scale, p.rows)
	end
	local ready = GiftViewRules.ready(state)
	p.claim.Text = GiftViewRules.claimText(state, crate)
	p.claim.TextSize = s.claimText
	p.claim.Size = UDim2.new(1, 0, 0, math.max(s.claimH, math.ceil(MIN_TAP / scale)))
	p.claim.AutoButtonColor = ready
	p.claim.TextColor3 = if ready then Kit.WHITE else Kit.INK_SOFT
	p.claim.TextStrokeTransparency = if ready then 0 else 1
	p.claimGradient.Color = if ready
		then ColorSequence.new(GREEN_TOP, GREEN_BOTTOM)
		else ColorSequence.new(WAIT_TOP, WAIT_BOTTOM)
	local waitLine = GiftViewRules.waitLine(state)
	p.wait.Visible = waitLine ~= nil
	-- with the free rewards rows (four of them) the steps left for Starcoat sit under the pet, so the card fits a phone
	p.wait.Parent = if state.free then p.pet else p.right
	p.wait.LayoutOrder = if state.free then 5 else 3
	p.wait.TextSize = s.wait
	p.wait.Size = UDim2.new(1, 0, 0, s.wait + 4)
	p.wait.Text = waitLine or ""
end

function GiftCard.set(newState: GiftViewRules.State)
	state = newState
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function GiftCard.onStep(fn: (key: string) -> ())
	table.insert(stepListeners, fn)
end

function GiftCard.onClaim(fn: () -> ())
	table.insert(claimListeners, fn)
end

function GiftCard.build(root: Instance): Frame
	local window = Window.new(GiftViewRules.WINDOW, GiftViewRules.TITLE, "Gift", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local columnsFrame = frame("Columns", window.body)
	columnsFrame.Size = UDim2.fromScale(1, 0)
	columnsFrame.AutomaticSize = Enum.AutomaticSize.Y
	local columns = list(columnsFrame, true, 16)

	local pet = frame("Pet", columnsFrame)
	pet.LayoutOrder = 1
	pet.AutomaticSize = Enum.AutomaticSize.Y
	pet.BackgroundTransparency = 0
	pet.BackgroundColor3 = Kit.WHITE
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new(PET_TOP, Kit.WHITE)
	tint.Parent = pet
	Kit.corner(pet, UDim.new(0, 18))
	local petEdge = Kit.stroke(pet, 3)
	petEdge.Color = Kit.LINE
	local petPad = Instance.new("UIPadding")
	petPad.PaddingLeft, petPad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	petPad.PaddingTop, petPad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
	petPad.Parent = pet
	local petList = list(pet, false, 4)
	petList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local pic = frame("Pic", pet)
	pic.LayoutOrder = 1
	local petName = words("Name", pet, 26)
	petName.LayoutOrder = 2
	local petRarity = words("Rarity", pet, 17)
	petRarity.LayoutOrder = 3
	local petLine = words("Line", pet, 17)
	petLine.LayoutOrder = 4
	petLine.FontFace = Kit.BODY_FACE
	petLine.TextColor3 = Kit.INK_SOFT
	petLine.TextWrapped = true
	petLine.AutomaticSize = Enum.AutomaticSize.Y

	local right = frame("Steps", columnsFrame)
	right.LayoutOrder = 2
	right.AutomaticSize = Enum.AutomaticSize.Y
	list(right, false, 10)
	local rows = frame("Rows", right)
	rows.LayoutOrder = 1
	rows.Size = UDim2.fromScale(1, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	local rowList = list(rows, false, 10)
	local claim = Window.button("Claim", "", right, GREEN_TOP, GREEN_BOTTOM)
	claim.LayoutOrder = 2
	local claimGradient = claim:FindFirstChildOfClass("UIGradient") :: UIGradient
	claim.Activated:Connect(function()
		if not GiftViewRules.ready(state) then
			return
		end
		for _, listener in claimListeners do
			task.spawn(listener)
		end
	end)
	local wait = words("Wait", right, 17)
	wait.LayoutOrder = 3
	wait.FontFace = Kit.BODY_FACE
	wait.TextColor3 = Kit.INK_SOFT

	parts = {
		window = window,
		pad = pad,
		columns = columns,
		pet = pet,
		pic = pic,
		petName = petName,
		petRarity = petRarity,
		petLine = petLine,
		right = right,
		rows = rows,
		rowList = rowList,
		claim = claim,
		claimGradient = claimGradient,
		wait = wait,
	}
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
		end
	end)
	for _, flag in { GiftViewRules.FLAG, "pets" } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				if not LiveFlags.isOn(flag) then
					window.layer.Visible = false
				end
			end)
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

return GiftCard
