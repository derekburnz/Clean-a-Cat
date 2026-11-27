--!strict
-- HelpersWindow: the spa's helpers in one place (issue 526 item 3), behind the live switch helpersWindow with
-- workers, both off by default. Opened only from its HUD button (shown once a helper is hired), never by itself.
--
--   HelpersWindow.build(root)          makes the window once and returns its layer (UI registers "Helpers")
--   HelpersWindow.set(rows, rename, shop)  draws the rows (HelperViewRules.rows); `rename` adds each hired helper's
--                                      Rename button (switch staffRename), `shop` Lou's pass button (switch passes)
--   HelpersWindow.onMode(fn)           fn(id) when a helper's Takes button is pressed
--   HelpersWindow.onLevel(fn)          fn(id) when Level up is pressed
--   HelpersWindow.onRename(fn)         fn(id) when Rename is pressed
--   HelpersWindow.onPass(fn)           fn() when Lou's See the pass is pressed
--   HelpersWindow.setPets(pets)        the player's pets (CrateRules.Pet list), for the pet box on each hired row
--   HelpersWindow.onPet(fn)            fn(id) when a helper's pet box is pressed (UI opens Pets with their slot picked)
--
-- One row per helper: their round picture, name and level, then Takes: <which waiting cat first> (tap to change),
-- and Level up with its coins; a pencil on the picture renames them. With the switch helperPets (issue 929) a hired
-- row starts its buttons with a pet box: their pet's portrait, or a paw when they have none; pets are given there, not
-- at a prompt in the world. A helper not hired yet shows their price, paid at their pad by
-- the tubs (hiring stays there, so the player sees where they will work); Lou says he comes with his pass. The
-- buttons ask; the row changes only when the server's WorkerLevel_<id> and WorkerMode_<id> come back. UI never
-- fires remotes: HelpersController asks the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local HelperViewRules = require(Shared:WaitForChild("HelperViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))
local Window = require(script.Parent:WaitForChild("Window"))

local HelpersWindow = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local SOFT_TOP, SOFT_BOTTOM = Color3.fromHex("FFF6EC"), Color3.fromHex("ECDCCA")
local GOLD_TOP, GOLD_BOTTOM = Color3.fromHex("FFE9A8"), Color3.fromHex("FFC94D")
local WHO_FILL = Color3.fromHex("E8F7FF")
local SCREEN_MARGIN = 64 -- design px kept clear beside the window
local SHORT_SHIFT = 8 -- design px below the middle on a short screen (Window keeps the X clear of the coin pill)
local MIN_TAP = 44 -- real px
local BUTTON_PAD = 28 -- design px of face beside a button's words
local BUTTON_GAP = 14 -- design px between a row's buttons, so Takes and Level up never read as one (issue 929)
local NAME_ROOM = 150 -- design px a name keeps at most before the buttons take two lines each

-- Sizes in design pixels: full, then compact for a short screen (a phone held sideways).
local SIZES = {
	full = {
		width = 900,
		band = 72,
		title = 38,
		badge = 96,
		pad = 18,
		gap = 10,
		rowH = 96,
		who = 68,
		pencil = 26,
		name = 24,
		say = 18,
		button = 56,
		buttonText = 20,
	},
	short = {
		width = 860,
		band = 50, -- a little slimmer than the other windows, so three rows fit under the coin pill (issue 873)
		title = 32,
		badge = 76,
		pad = 8,
		gap = 4,
		rowH = 80,
		who = 64, -- 48 real px at the smallest scale: the Rename tap
		pencil = 24,
		name = 21,
		say = 16,
		button = 52,
		buttonText = 19,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	stack: UIListLayout,
	rowsFrame: Frame,
}

local parts: Parts? = nil
local rows: { HelperViewRules.Row } = {}
local canRename = false
local canShop = false
local modeListeners: { (id: string) -> () } = {}
local levelListeners: { (id: string) -> () } = {}
local renameListeners: { (id: string) -> () } = {}
local passListeners: { () -> () } = {}
local petListeners: { (id: string) -> () } = {}
local hireListeners: { (id: string) -> () } = {}
local pets: { CrateRules.Pet } = {}

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
	label.TextXAlignment = Enum.TextXAlignment.Left
	Kit.minText(label)
	label.Parent = parent
	return label
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

-- Design px the words take at `size`.
local TEXT_FLOOR = 19 -- Kit's MIN_TEXT: no text is drawn smaller
local MEASURE_SLACK = 1.08 -- the real font draws a little wider than TextService's guess (issue 698)

-- Design px the words take at `size` (never under the text floor), with room to spare.
local function measure(text: string, size: number): number
	local drawn = math.max(size, TEXT_FLOOR)
	return TextService:GetTextSize(text, drawn, Kit.FONT, Vector2.new(2000, 200)).X * MEASURE_SLACK
end

local function tell(listeners: { (id: string) -> () }, id: string)
	for _, listener in listeners do
		task.spawn(listener, id)
	end
end

-- The Takes button is as wide as its longest words, so it never jumps as the mode changes.
local function modeWidth(s: Sizes): number
	local widest = 0
	for _, mode in WorkerRules.MODES do
		widest = math.max(widest, measure(`Takes: {WorkerRules.MODE_NAMES[mode]}`, s.buttonText))
	end
	return math.ceil(widest) + BUTTON_PAD
end

local function levelWidth(s: Sizes): number
	local widest = 0
	for _, cost in WorkerRules.LEVEL_COST do
		widest = math.max(widest, measure(`Level up · {cost}`, s.buttonText))
	end
	return math.ceil(widest) + BUTTON_PAD
end

-- The Takes and Level up widths on two lines ("Takes:" over the mode, "Level up" over the coins).
local function narrowModeWidth(s: Sizes): number
	local widest = measure("Takes:", s.buttonText)
	for _, mode in WorkerRules.MODES do
		widest = math.max(widest, measure(WorkerRules.MODE_NAMES[mode], s.buttonText))
	end
	return math.ceil(widest) + BUTTON_PAD
end

local function narrowLevelWidth(s: Sizes): number
	local widest = measure("Level up", s.buttonText)
	for _, cost in WorkerRules.LEVEL_COST do
		widest = math.max(widest, measure(tostring(cost), s.buttonText))
	end
	return math.ceil(widest) + BUTTON_PAD
end

local function drawRow(
	row: HelperViewRules.Row,
	order: number,
	s: Sizes,
	parent: Frame,
	rowW: number
)
	local scale = Kit.screenScale()
	local tap = math.ceil(MIN_TAP / scale)
	local buttonH = math.max(s.button, tap)

	local card = frame(row.id, parent)
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, math.max(s.rowH, buttonH + 12))
	card.BackgroundTransparency = if row.hired then 0 else 0.35
	card.BackgroundColor3 = Kit.WHITE
	Kit.corner(card, UDim.new(0, 18))
	local edge = Kit.stroke(card, 3)
	edge.Color = Kit.line()
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = card

	local who = frame("Who", card)
	who.AnchorPoint = Vector2.new(0, 0.5)
	who.Position = UDim2.fromScale(0, 0.5)
	who.Size = UDim2.fromOffset(s.who, s.who)
	who.BackgroundTransparency = 0
	who.BackgroundColor3 = WHO_FILL
	Kit.corner(who, UDim.new(0.5, 0))
	Kit.stroke(who, 3)
	local whoIcon = frame("Icon", who)
	whoIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	whoIcon.Position = UDim2.fromScale(0.5, 0.5)
	whoIcon.Size = UDim2.fromScale(0.7, 0.7)
	-- each helper's own picture (issue 1036), faded until hired; Icons.draw falls back if an id has none
	local own = `Staff{row.id}`
	if Icons.IMAGES[own] then
		whoIcon.Size = UDim2.fromScale(0.92, 0.92)
		Icons.draw(own, whoIcon, not row.hired)
	else
		Icons.draw(if row.hired then "Helper" elseif row.pass then "Star" else "Coins", whoIcon)
	end
	local id = row.id
	if row.hired and canRename then
		-- the round picture is the Rename button, with a pencil on it, as in the Pets window (issue 487)
		local rename = Instance.new("TextButton")
		rename.Name = "Rename"
		rename.BackgroundTransparency = 1
		rename.Text = ""
		rename.Size = UDim2.fromScale(1, 1)
		rename.ZIndex = 4
		rename:SetAttribute("Says", `Rename {row.name}`)
		rename.Parent = who
		rename.Activated:Connect(function()
			tell(renameListeners, id)
		end)
		local pencil = frame("Pencil", who)
		pencil.AnchorPoint = Vector2.new(0.5, 0.5)
		pencil.Position = UDim2.fromScale(0.86, 0.86)
		pencil.Size = UDim2.fromOffset(s.pencil, s.pencil)
		pencil.BackgroundTransparency = 0
		pencil.BackgroundColor3 = Kit.WHITE
		pencil.ZIndex = 3
		Kit.corner(pencil, UDim.new(0.5, 0))
		Kit.stroke(pencil, 2)
		Icons.draw("Pencil", pencil)
	end

	-- the buttons, right to left: Level up, Takes (or Lou's pass)
	local right = frame("Buttons", card)
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.fromScale(1, 0.5)
	right.AutomaticSize = Enum.AutomaticSize.X
	right.Size = UDim2.fromOffset(0, buttonH)
	local rightList = Instance.new("UIListLayout")
	rightList.FillDirection = Enum.FillDirection.Horizontal
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, BUTTON_GAP)
	rightList.Parent = right
	local used = 0
	-- on a narrow window (a phone with bigger text) the pet box, Takes and Level up leave the name too little room, so
	-- Takes and Level up go on two lines each: the name is never cut with "..." (issue 838)
	local petShown = row.hired
		and LiveFlags.isOn(HelperViewRules.PETS_FLAG)
		and LiveFlags.isOn(CrateRules.FLAG)
	local wide = (if petShown then buttonH + BUTTON_GAP else 0)
		+ modeWidth(s)
		+ levelWidth(s)
		+ 2 * BUTTON_GAP
	local nameW = math.min(
		math.max(measure(row.name, s.name), measure(HelperViewRules.say(row), s.say)),
		NAME_ROOM
	)
	local twoLines = row.hired and rowW - (s.who + 12 + 4) - wide < nameW
	if petShown then
		-- the pet box: their pet, or a paw; a tap opens Pets with this helper's slot picked
		local pet = HelperViewRules.petOf(id, pets)
		local box = frame("Pet", right)
		box.LayoutOrder = 0
		box.Size = UDim2.fromOffset(buttonH, buttonH)
		box.BackgroundTransparency = 0
		box.BackgroundColor3 = Kit.WHITE
		Kit.corner(box, UDim.new(0, 14))
		local boxEdge = Kit.stroke(box, 3)
		boxEdge.Color = if pet then Kit.INK else Kit.INK_SOFT
		if pet then
			Portraits.draw(pet.kind, CrateRules.rarityOf(pet.kind) or "Common", box, true)
		else
			local paw = frame("Icon", box)
			paw.AnchorPoint = Vector2.new(0.5, 0.5)
			paw.Position = UDim2.fromScale(0.5, 0.5)
			paw.Size = UDim2.fromScale(0.6, 0.6)
			Icons.draw("Paw", paw, true)
			Kit.plusBadge(box)
		end
		local petTap = Instance.new("TextButton")
		petTap.Name = "Tap"
		petTap.Text = ""
		petTap.BackgroundTransparency = 1
		petTap.Size = UDim2.fromScale(1, 1)
		petTap.ZIndex = 4
		petTap:SetAttribute(
			"Says",
			if pet then `{row.name}'s pet {pet.kind}. Tap to change` else `Give {row.name} a pet`
		)
		petTap.Parent = box
		petTap.Activated:Connect(function()
			tell(petListeners, id)
		end)
		used += buttonH + BUTTON_GAP
	end
	if row.hired then
		local modeText = HelperViewRules.modeText(row)
		local mode = Window.button(
			"Mode",
			if twoLines then (string.gsub(modeText, ": ", ":\n", 1)) else modeText,
			right,
			SOFT_TOP,
			SOFT_BOTTOM
		)
		mode.LayoutOrder = 1
		mode.TextColor3 = Kit.INK
		mode.TextStrokeTransparency = 1
		mode.TextSize = s.buttonText
		mode.TextWrapped = true -- if the font still runs wide, two lines rather than a cut word (issue 698)
		local modeW = if twoLines then narrowModeWidth(s) else modeWidth(s)
		mode.Size = UDim2.fromOffset(modeW, buttonH)
		mode:SetAttribute("Says", `{row.name} takes {row.modeName}. Tap to change`)
		mode.Activated:Connect(function()
			tell(modeListeners, id)
		end)
		used += modeW + BUTTON_GAP
		local levelText = HelperViewRules.levelText(row)
		if levelText then
			local level = Window.button(
				"Level",
				if twoLines then (string.gsub(levelText, " · ", "\n", 1)) else levelText,
				right,
				GREEN_TOP,
				GREEN_BOTTOM
			)
			level.LayoutOrder = 2
			level.TextSize = s.buttonText
			level.TextWrapped = twoLines
			local levelW = if twoLines then narrowLevelWidth(s) else levelWidth(s)
			level.Size = UDim2.fromOffset(levelW, buttonH)
			level:SetAttribute("Says", `Level up {row.name} for {row.nextCost} coins`)
			level.Activated:Connect(function()
				tell(levelListeners, id)
			end)
			used += levelW + BUTTON_GAP
		end
	elseif HelperViewRules.hireText(row) ~= nil then
		-- menuOnly (issue 1033, Derek: "it should just be hire new worker through menu"): hire right here
		local hireText = HelperViewRules.hireText(row) :: string
		local hire = Window.button("Hire", hireText, right, GREEN_TOP, GREEN_BOTTOM)
		hire.LayoutOrder = 1
		hire.TextSize = s.buttonText
		local hireW =
			math.max(math.ceil(measure(hireText, s.buttonText)) + BUTTON_PAD, levelWidth(s))
		hire.Size = UDim2.fromOffset(hireW, buttonH)
		hire:SetAttribute("Says", `Hire {row.name} for {row.price or 0} coins`)
		hire.Activated:Connect(function()
			tell(hireListeners, id)
		end)
		used += hireW + BUTTON_GAP
	elseif row.pass and canShop then
		local text = "See the pass"
		local pass = Window.button("Pass", text, right, GOLD_TOP, GOLD_BOTTOM)
		pass.LayoutOrder = 1
		pass.TextColor3 = Kit.INK
		pass.TextStrokeTransparency = 1
		pass.TextSize = s.buttonText
		local passW = math.ceil(measure(text, s.buttonText)) + BUTTON_PAD
		pass.Size = UDim2.fromOffset(passW, buttonH)
		pass:SetAttribute("Says", "See the Extra Worker pass in the Shop")
		pass.Activated:Connect(function()
			for _, listener in passListeners do
				task.spawn(listener)
			end
		end)
		used += passW + BUTTON_GAP
	end

	local text = frame("Text", card)
	text.Position = UDim2.fromOffset(s.who + 12, 0)
	text.Size = UDim2.new(1, -(s.who + 12 + used + 4), 1, 0)
	local textList = Instance.new("UIListLayout")
	textList.SortOrder = Enum.SortOrder.LayoutOrder
	textList.VerticalAlignment = Enum.VerticalAlignment.Center
	textList.Parent = text
	local name = words("Name", text, s.name)
	name.LayoutOrder = 1
	name.Size = UDim2.new(1, 0, 0, s.name + 6)
	Kit.shrinkToFit(name, s.name)
	name.Text = row.name
	local say = words("Says", text, s.say)
	say.LayoutOrder = 2
	say.FontFace = Kit.BODY_FACE
	say.TextColor3 = Kit.INK_SOFT
	say.Size = UDim2.new(1, 0, 0, s.say + 6)
	Kit.shrinkToFit(say, s.say)
	say.Text = HelperViewRules.say(row)
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	local width = math.min(s.width, screenWidth(scale) - SCREEN_MARGIN)
	Window.fit(p.window, width, s.band, s.title, s.badge, if short then SHORT_SHIFT else nil)
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad - 4), pad
	p.stack.Padding = UDim.new(0, s.gap)
	for _, child in p.rowsFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, row in rows do
		drawRow(row, index, s, p.rowsFrame, width - 2 * s.pad - 20)
	end
end

function HelpersWindow.set(newRows: { HelperViewRules.Row }, rename: boolean, shop: boolean)
	rows, canRename, canShop = newRows, rename, shop
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function HelpersWindow.onMode(fn: (id: string) -> ())
	table.insert(modeListeners, fn)
end

function HelpersWindow.onHire(fn: (id: string) -> ())
	table.insert(hireListeners, fn)
end

function HelpersWindow.onLevel(fn: (id: string) -> ())
	table.insert(levelListeners, fn)
end

function HelpersWindow.onRename(fn: (id: string) -> ())
	table.insert(renameListeners, fn)
end

function HelpersWindow.onPass(fn: () -> ())
	table.insert(passListeners, fn)
end

function HelpersWindow.setPets(newPets: { CrateRules.Pet })
	pets = newPets
	local p = parts
	if p and p.window.layer.Visible then
		redraw()
	end
end

function HelpersWindow.onPet(fn: (id: string) -> ())
	table.insert(petListeners, fn)
end

function HelpersWindow.build(root: Instance): Frame
	local window = Window.new(HelperViewRules.WINDOW, "Helpers", "Helpers", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
		end
	end)

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local rowsFrame = frame("Rows", window.body)
	rowsFrame.AutomaticSize = Enum.AutomaticSize.Y
	rowsFrame.Size = UDim2.fromScale(1, 0)
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 10)
	stack.Parent = rowsFrame

	parts = { window = window, pad = pad, stack = stack, rowsFrame = rowsFrame }
	for _, flag in { HelperViewRules.FLAG, WorkerRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				if
					not (LiveFlags.isOn(HelperViewRules.FLAG) and LiveFlags.isOn(WorkerRules.FLAG))
				then
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

return HelpersWindow
