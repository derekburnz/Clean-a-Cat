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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local GiftFlowRules = require(Shared:WaitForChild("GiftFlowRules"))
local GiftViewRules = require(Shared:WaitForChild("GiftViewRules"))
local LikeHowToRules = require(Shared:WaitForChild("LikeHowToRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Comfort = require(script.Parent:WaitForChild("Comfort"))
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
	-- the like how-to (switch likeHowTo, issue 869), in the picture side's place while it shows
	howTo: Frame,
	howArt: Frame,
	howThumb: Frame,
	howHand: Frame,
	howRing: Frame,
	howCaption: TextLabel,
	howNote: TextLabel,
	howButton: TextButton,
}

local parts: Parts? = nil
local state: GiftViewRules.State =
	{ lit = false, favourite = false, group = false, claimed = false }
local stepListeners: { (key: string) -> () } = {}
local howToListeners: { (answer: string?) -> () } = {}
local howToShowing = false
local howToDone = false -- once a visit (issue 869)
local howToLoop: RBXScriptConnection? = nil
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
	edge.Color = if step.done then TICK_FILL else Kit.line()
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

-- The state as drawn: the controller's state plus the stand's stage (switch giftFlow, issue 968), which the server
-- keeps on the Player attribute GiftStage (nil with the switch off).
local function shownState(): GiftViewRules.State
	local stage = Players.LocalPlayer:GetAttribute(GiftFlowRules.STAGE_ATTRIBUTE)
	if typeof(stage) ~= "number" then
		return state
	end
	local shown = table.clone(state)
	shown.stage = stage
	return shown
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local state = shownState()
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
	p.window.title.Text = GiftViewRules.title(state)
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad + 2), pad
	p.columns.Padding = UDim.new(0, s.gap)

	-- the pet
	p.pet.Size = UDim2.fromOffset(s.petW, 0)
	p.pic.Size = UDim2.fromOffset(s.pic, s.pic)
	-- (giftCrate, issue 859) the stand gives a crate to open, not Starcoat; (giftFlow, issue 968) the welcome gift adds
	-- the like's coins and the playtime stage shows its good crate
	local crate = LiveFlags.isOn(CrateRules.GIFT_FLAG)
	local prize = GiftViewRules.prize(state, crate)
	local rarity = CrateRules.rarityOf(GiftViewRules.PET) or "Uncommon"
	local stale = p.pic:FindFirstChild(if prize.crate then "Portrait" else "Icon") -- the other picture, if it changed
	if stale then
		stale:Destroy()
	end
	if prize.crate then
		Icons.draw("Crate", p.pic)
	else
		Portraits.draw(GiftViewRules.PET, rarity, p.pic)
	end
	p.petName.TextSize = s.petName
	p.petName.Size = UDim2.new(1, 0, 0, s.petName + 4)
	p.petName.Text = prize.name
	p.petRarity.TextSize = s.petLine
	p.petRarity.Size = UDim2.new(1, 0, 0, s.petLine + 4)
	p.petRarity.Text = rarity
	p.petRarity.Visible = not prize.crate
	p.petRarity.TextColor3 = (Kit.RARITY[rarity] or Kit.INK):Lerp(Kit.INK, 0.45)
	p.petLine.TextSize = s.petLine
	p.petLine.Size = UDim2.new(1, 0, 0, s.petLine * 2 + 4)
	p.petLine.Text = prize.line

	-- (likeHowTo, issue 869) the how-to takes the picture side's place while it shows
	for _, piece in { p.pic, p.petName, p.petLine } :: { GuiObject } do
		piece.Visible = not howToShowing
	end
	if howToShowing then
		p.petRarity.Visible = false
	end
	p.howTo.Visible = howToShowing
	p.howArt.Size = UDim2.fromOffset(s.pic, s.pic)
	p.howCaption.TextSize = s.petLine
	p.howNote.TextSize = s.petLine - 2
	p.howNote.Text = LikeHowToRules.note(state.stage == 1)
	p.howButton.TextSize = s.actionText
	p.howButton.Size = UDim2.new(1, 0, 0, math.max(s.claimH - 12, math.ceil(MIN_TAP / scale)))

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
	p.claim.Visible = GiftViewRules.hasClaim(state) -- the playtime stage's row has its own Claim
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
	p.wait.Visible = waitLine ~= nil and not (howToShowing and state.free ~= nil)
	-- with the free rewards rows (four of them) the steps left for Starcoat sit under the pet, so the card fits a phone
	p.wait.Parent = if state.free then p.pet else p.right
	p.wait.LayoutOrder = if state.free then 5 else 3
	p.wait.TextSize = s.wait
	p.wait.Size = UDim2.new(1, 0, 0, s.wait + 4)
	p.wait.Text = waitLine or ""
end

-- Draws one frame of the how-to's loop (LikeHowToRules.frame).
local function drawHowTo(t: number)
	local p = parts
	if p == nil then
		return
	end
	local f = LikeHowToRules.frame(t, Comfort.reducedMotion())
	local thumb = p.howThumb:FindFirstChild("Icon")
	local shown = if f.filled then "HeartFilled" else "HeartOutline"
	if p.howThumb:GetAttribute("Shown") ~= shown then
		p.howThumb:SetAttribute("Shown", shown)
		Icons.draw(shown, p.howThumb)
	elseif thumb == nil then
		Icons.draw(shown, p.howThumb)
	end
	-- the tap dot comes from the lower right onto the heart, a little smaller while it presses
	local away = 1 - f.hand
	local size = if f.press > 0 then 0.42 else 0.48
	p.howHand.Size = UDim2.fromScale(size, size)
	p.howHand.Position = UDim2.fromScale(0.62 + 0.3 * away, 0.62 + 0.3 * away)
	p.howRing.Visible = f.ring > 0
	p.howRing.Size = UDim2.fromScale(0.4 + 0.6 * f.ring, 0.4 + 0.6 * f.ring)
	for _, child in p.howRing:GetDescendants() do
		if child:IsA("ImageLabel") then
			(child :: ImageLabel).ImageTransparency = f.ring
		elseif child:IsA("TextLabel") then
			(child :: TextLabel).TextTransparency = f.ring
		end
	end
end

local function tellHowTo(answer: string?)
	for _, listener in howToListeners do
		task.spawn(listener, answer)
	end
end

local function hideHowTo(answer: string?)
	if not howToShowing then
		return
	end
	howToShowing = false
	if howToLoop then
		howToLoop:Disconnect()
		howToLoop = nil
	end
	tellHowTo(answer)
	redraw()
end

local function showHowTo()
	local p = parts
	if p == nil or howToShowing or howToDone then
		return
	end
	howToShowing = true
	howToDone = true
	Icons.draw("TapDot", p.howHand)
	Icons.draw("RingPuff", p.howRing)
	local started = os.clock()
	drawHowTo(0)
	howToLoop = RunService.Heartbeat:Connect(function()
		drawHowTo(os.clock() - started)
	end)
	tellHowTo(nil)
	redraw()
end

function GiftCard.set(newState: GiftViewRules.State)
	-- (likeHowTo, issue 869) Like was just tapped on the open card: show how to like the game, once a visit
	local before = state.free
	local now = newState.free
	local tapped = before ~= nil and now ~= nil and not before.likeAsked and now.likeAsked
	state = newState
	local open = parts ~= nil and (parts :: Parts).window.layer.Visible
	if tapped and open and LiveFlags.isOn(LikeHowToRules.FLAG) then
		showHowTo()
		return
	end
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function GiftCard.onStep(fn: (key: string) -> ())
	table.insert(stepListeners, fn)
end

-- fn(answer) for the like how-to's ask events: nil when it shows, "yes" on Got it, "closed" when the card closes.
function GiftCard.onHowTo(fn: (answer: string?) -> ())
	table.insert(howToListeners, fn)
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
	petEdge.Color = Kit.line()
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
	-- the like how-to (switch likeHowTo, issue 869): its loop, its two lines and Got it
	local howTo = frame("HowTo", pet)
	howTo.LayoutOrder = 6
	howTo.Size = UDim2.fromScale(1, 0)
	howTo.AutomaticSize = Enum.AutomaticSize.Y
	howTo.Visible = false
	list(howTo, false, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local howArt = frame("Art", howTo)
	howArt.LayoutOrder = 1
	local howThumb = frame("Thumb", howArt)
	howThumb.AnchorPoint = Vector2.new(0.5, 0.5)
	howThumb.Position = UDim2.fromScale(0.45, 0.45)
	howThumb.Size = UDim2.fromScale(0.62, 0.62)
	local howRing = frame("Ring", howArt)
	howRing.AnchorPoint = Vector2.new(0.5, 0.5)
	howRing.Position = UDim2.fromScale(0.55, 0.55)
	howRing.ZIndex = 2
	local howHand = frame("Hand", howArt)
	howHand.AnchorPoint = Vector2.new(0.5, 0.5)
	howHand.ZIndex = 3
	local howCaption = words("Caption", howTo, 17)
	howCaption.LayoutOrder = 2
	howCaption.Text = LikeHowToRules.CAPTION
	howCaption.TextWrapped = true
	howCaption.Size = UDim2.fromScale(1, 0)
	howCaption.AutomaticSize = Enum.AutomaticSize.Y
	local howNote = words("Note", howTo, 15)
	howNote.LayoutOrder = 3
	howNote.FontFace = Kit.BODY_FACE
	howNote.TextColor3 = Kit.INK_SOFT
	howNote.TextWrapped = true
	howNote.Size = UDim2.fromScale(1, 0)
	howNote.AutomaticSize = Enum.AutomaticSize.Y
	local howButton = Window.button("GotIt", LikeHowToRules.BUTTON, howTo, GREEN_TOP, GREEN_BOTTOM)
	howButton.LayoutOrder = 4
	howButton.Activated:Connect(function()
		hideHowTo("yes")
	end)

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
		howTo = howTo,
		howArt = howArt,
		howThumb = howThumb,
		howHand = howHand,
		howRing = howRing,
		howCaption = howCaption,
		howNote = howNote,
		howButton = howButton,
	}
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
		else
			hideHowTo("closed") -- the card closed over the how-to (the like gift is unaffected)
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
	-- the stand moves to its next stage (giftFlow): the open card follows
	Players.LocalPlayer:GetAttributeChangedSignal(GiftFlowRules.STAGE_ATTRIBUTE):Connect(function()
		if window.layer.Visible then
			redraw()
		end
	end)
	redraw()
	return window.layer
end

return GiftCard
