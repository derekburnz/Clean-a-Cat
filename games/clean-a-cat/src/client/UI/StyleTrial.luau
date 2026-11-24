--!strict
-- StyleTrial: a small Settings card built two ways, for the owner to compare (#186). The plain way sets every look
-- property in code, as the game's screens do today. The styled way sets none of them: one Roblox StyleSheet holds
-- the Bubble Pastel tokens (cream window, ink outline, green, red and grey buttons) and rules that tag-select the
-- card's parts, with short hover and press transitions.
--
--   StyleTrial.build(gui, styled)   builds the card (closed) under a ScreenGui and returns it
--
-- In the game it is built only when the live switch styleSheetUi is on (off by default), so nothing changes while it
-- is off. The UI gate builds the plain card in its StyleTrial scene. It cannot build the styled one: its stand-in for
-- Roblox has no StyleSheet classes, so a sheet's colours, fonts and sizes go unchecked there (the known cost in #186).
local StyleTrial = {}

local INK = Color3.fromHex("45226b")
local CREAM = Color3.fromHex("fff6ec")
local GREEN = Color3.fromHex("3dbf3f")
local GREEN_HOVER = Color3.fromHex("5ad45a")
local GREEN_PRESS = Color3.fromHex("2a8a2e")
local RED = Color3.fromHex("e0453f")
local RED_HOVER = Color3.fromHex("ef6a64")
local GREY = Color3.fromHex("b7aec4")
local HEAD = Font.fromEnum(Enum.Font.FredokaOne)
local BODY = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)
local TAP = 52

-- the structure both ways share: names, sizes, positions and words, never colours, fonts or outlines
local function skeleton(gui: ScreenGui): (Frame, { TextButton }, { TextLabel })
	local card = Instance.new("Frame")
	card.Name = "StyleTrial"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(340, 256)
	card.Visible = false

	local buttons: { TextButton } = {}
	local labels: { TextLabel } = {}

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -40 - TAP, 0, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Settings"
	title.Parent = card
	table.insert(labels, title)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(TAP, TAP)
	close.Text = "X"
	close.Parent = card
	close.Activated:Connect(function()
		card.Visible = false
	end)
	table.insert(buttons, close)

	for i, row in { { "Music", "On" }, { "Sounds", "Off" } } do
		local y = 64 + (i - 1) * 58
		local label = Instance.new("TextLabel")
		label.Name = row[1] .. "Label"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(20, y)
		label.Size = UDim2.new(1, -150, 0, TAP)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = row[1]
		label.Parent = card
		table.insert(labels, label)

		local toggle = Instance.new("TextButton")
		toggle.Name = row[1] .. "Toggle"
		toggle.AnchorPoint = Vector2.new(1, 0)
		toggle.Position = UDim2.new(1, -20, 0, y)
		toggle.Size = UDim2.fromOffset(100, TAP)
		toggle.Text = row[2]
		toggle.Parent = card
		table.insert(buttons, toggle)
	end

	local done = Instance.new("TextButton")
	done.Name = "Done"
	done.AnchorPoint = Vector2.new(0.5, 1)
	done.Position = UDim2.new(0.5, 0, 1, -14)
	done.Size = UDim2.fromOffset(160, TAP)
	done.Text = "Done"
	done.Parent = card
	done.Activated:Connect(function()
		card.Visible = false
	end)
	table.insert(buttons, done)

	card.Parent = gui
	return card, buttons, labels
end

local function plainLook(card: Frame, buttons: { TextButton }, labels: { TextLabel })
	card.BackgroundColor3 = CREAM
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 4
	stroke.Parent = card
	for _, label in labels do
		label.FontFace = if label.Name == "Title" then HEAD else BODY
		label.TextSize = if label.Name == "Title" then 28 else 20
		label.TextColor3 = INK
	end
	for _, button in buttons do
		local colour = if button.Name == "Close"
			then RED
			elseif button.Text == "Off" then GREY
			else GREEN
		button.BackgroundColor3 = colour
		button.FontFace = HEAD
		button.TextSize = 22
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextStrokeColor3 = INK
		button.TextStrokeTransparency = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 16)
		c.Parent = button
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = INK
		s.Thickness = 3
		s.Parent = button
	end
end

local function rule(sheet: StyleSheet, selector: string, props: { [string]: any }): StyleRule
	local r = Instance.new("StyleRule")
	r.Selector = selector
	r:SetProperties(props)
	r.Parent = sheet
	return r
end

local function styledLook(
	gui: ScreenGui,
	card: Frame,
	buttons: { TextButton },
	labels: { TextLabel }
)
	local tokens = Instance.new("StyleSheet")
	tokens.Name = "CleanACatTokens"
	tokens:SetAttribute("Ink", INK)
	tokens:SetAttribute("Cream", CREAM)
	tokens:SetAttribute("Green", GREEN)
	tokens:SetAttribute("GreenHover", GREEN_HOVER)
	tokens:SetAttribute("GreenPress", GREEN_PRESS)
	tokens:SetAttribute("Red", RED)
	tokens:SetAttribute("RedHover", RED_HOVER)
	tokens:SetAttribute("Grey", GREY)

	local sheet = Instance.new("StyleSheet")
	sheet.Name = "CleanACatStyle"
	local derive = Instance.new("StyleDerive")
	derive.StyleSheet = tokens
	derive.Parent = sheet

	card:AddTag("Window")
	rule(sheet, ".Window", { BackgroundColor3 = "$Cream" })
	rule(sheet, ".Window::UICorner", { CornerRadius = UDim.new(0, 22) })
	rule(sheet, ".Window::UIStroke", { Color = "$Ink", Thickness = 4 })

	for _, label in labels do
		label:AddTag(if label.Name == "Title" then "Head" else "Body")
	end
	rule(sheet, ".Head", { FontFace = HEAD, TextSize = 28, TextColor3 = "$Ink" })
	rule(sheet, ".Body", { FontFace = BODY, TextSize = 20, TextColor3 = "$Ink" })

	for _, button in buttons do
		button:AddTag("Btn")
		button:AddTag(
			if button.Name == "Close" then "Red" elseif button.Text == "Off" then "Grey" else "Green"
		)
	end
	local btn = rule(sheet, ".Btn", {
		FontFace = HEAD,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = "$Ink",
		TextStrokeTransparency = 0,
	})
	btn:SetPropertyTransitions({
		BackgroundColor3 = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	})
	rule(sheet, ".Btn::UICorner", { CornerRadius = UDim.new(0, 16) })
	rule(
		sheet,
		".Btn::UIStroke",
		{ Color = "$Ink", Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
	rule(sheet, ".Green", { BackgroundColor3 = "$Green" })
	rule(sheet, ".Green:Hover", { BackgroundColor3 = "$GreenHover" })
	rule(sheet, ".Green:Press", { BackgroundColor3 = "$GreenPress" })
	rule(sheet, ".Red", { BackgroundColor3 = "$Red" })
	rule(sheet, ".Red:Hover", { BackgroundColor3 = "$RedHover" })
	rule(sheet, ".Grey", { BackgroundColor3 = "$Grey" })

	tokens.Parent = gui
	sheet.Parent = gui
	local link = Instance.new("StyleLink")
	link.StyleSheet = sheet
	link.Parent = gui
end

function StyleTrial.build(gui: ScreenGui, styled: boolean): Frame
	local card, buttons, labels = skeleton(gui)
	if styled then
		styledLook(gui, card, buttons, labels)
	else
		plainLook(card, buttons, labels)
	end
	return card
end

return StyleTrial
