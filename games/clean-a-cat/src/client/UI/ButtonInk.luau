--!strict
-- ButtonInk: readable words on the bright menu buttons, behind the switch menuContrast3 (issue 1096, part 2 of
-- Derek's "contrast in menus is really bad", from Sync's iPhone check of menuContrast2). Window.new hands each
-- window's card here, and while the switch is on:
--   * a button's white words (Buy, Build, Level up, Claim, Save, Wash next, Favourite, Like, Reset my game, the X)
--     get a thick ink outline, the way the HUD pills and the shop prices already draw theirs (Kit.outlined). A
--     TextButton's own UIStroke draws its border, so the words are drawn again by a child label with the outline,
--     and the button's own words are hidden under it;
--   * the light tick green on the pale green "done" fill becomes a deeper green (2.7 to 4.8 to 1);
--   * the gold words (Kit.GOLD_INK, the Cat Index "+100", the recap's coins) become a deeper gold (3.2 to 4.7 to 1
--     on the Cat Index's pink band);
--   * the old cream to beige soft buttons (the Helpers "Takes:" chip, Rename's secondary button) turn white to a pale
--     lilac, the look of the white cards around them.
-- Settings puts each of its rows on a white card under the same switch (Settings.luau).
-- Each piece keeps its own values in attributes, so turning the switch off puts every piece back exactly. Nothing
-- else changes: fills, sizes and words stay as the window drew them.
--
--   ButtonInk.watch(card)   applies the above to the window card and everything in it, now and as it changes
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Kit = require(script.Parent:WaitForChild("Kit"))

local ButtonInk = {}

ButtonInk.FLAG = "menuContrast3"
ButtonInk.OUTLINE = 3 -- design px, as Kit.outlined
ButtonInk.TICK_GREEN = Color3.fromHex("3FA868")
ButtonInk.TICK_STRONG = Color3.fromHex("1E7A45")
ButtonInk.GOLD_STRONG = Color3.fromHex("6B4200")
ButtonInk.SOFT_TOP, ButtonInk.SOFT_BOTTOM = Color3.fromHex("FFF6EC"), Color3.fromHex("ECDCCA")
ButtonInk.CLEAN = ColorSequence.new(Color3.fromHex("FFFFFF"), Color3.fromHex("F1E9FB"))

local LABEL = "InkWords" -- the child label that draws a button's words with their outline
local OWN_TEXT = "Ink_TextTransparency" -- attribute: the button's own text transparency while the switch is on
local OWN_STROKE = "Ink_TextStrokeTransparency"
local OWN_COLOUR = "Ink_TextColor3" -- attribute: a label's own text colour while the switch is on
local OWN_SEQUENCE = "Ink_Color" -- attribute: a soft button gradient's own colours while the switch is on

-- Properties the outlined label copies from its button, so it always draws the same words in the same place.
local MIRROR = {
	"Text",
	"FontFace",
	"TextSize",
	"TextScaled",
	"TextWrapped",
	"TextXAlignment",
	"TextYAlignment",
	"RichText",
	"LineHeight",
	"TextTruncate",
	"ZIndex",
}

local cards: { Frame } = {}

local function same(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.004
		and math.abs(a.G - b.G) < 0.004
		and math.abs(a.B - b.B) < 0.004
end

-- A button whose words are white: the bright green, blue, coral and red buttons (Window.button).
local function whiteWords(button: TextButton): boolean
	return same(button.TextColor3, Kit.WHITE) and button.Text ~= ""
end

local function copy(button: TextButton, label: TextLabel)
	for _, property in MIRROR do
		(label :: any)[property] = (button :: any)[property]
	end
	local floor = button:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint?
	local mine = label:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint?
	if floor and mine then
		mine.MinTextSize, mine.MaxTextSize = floor.MinTextSize, floor.MaxTextSize
	elseif floor then
		floor:Clone().Parent = label
	elseif mine then
		mine:Destroy()
	end
end

-- Our own TextTransparency writes on each button that its listener has not seen yet.
local pending: { [TextButton]: number } = {}

-- Writes the button's text transparency, counted so its listener knows the write is ours. A write that changes
-- nothing fires no signal, so it is not counted.
local function setText(button: TextButton, value: number)
	if button.TextTransparency == value then
		return
	end
	pending[button] = (pending[button] or 0) + 1
	button.TextTransparency = value
end

-- The button's own text transparency: kept in an attribute while its words are drawn by the label.
local function ownTransparency(button: TextButton): number
	local kept = button:GetAttribute(OWN_TEXT)
	return if typeof(kept) == "number" then kept else button.TextTransparency
end

local function outline(button: TextButton, on: boolean)
	local found = button:FindFirstChild(LABEL)
	local label: TextLabel? = if found and found:IsA("TextLabel") then found :: TextLabel else nil
	-- words the window hides on purpose stay hidden
	if on and whiteWords(button) and ownTransparency(button) < 0.99 then
		if label == nil then
			local made = Instance.new("TextLabel")
			made.Name = LABEL
			made.BackgroundTransparency = 1
			made.Size = UDim2.fromScale(1, 1)
			made.TextColor3 = Kit.WHITE
			made.ZIndex = button.ZIndex
			made.Active = false
			local stroke = Instance.new("UIStroke")
			stroke.Color = Kit.INK
			stroke.Thickness = ButtonInk.OUTLINE
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Parent = made
			made.Parent = button
			label = made
		end
		local words: TextLabel = label :: TextLabel
		copy(button, words)
		words.TextTransparency = ownTransparency(button)
		if typeof(button:GetAttribute(OWN_TEXT)) ~= "number" then
			button:SetAttribute(OWN_TEXT, button.TextTransparency)
			button:SetAttribute(OWN_STROKE, button.TextStrokeTransparency)
		end
		setText(button, 1)
		button.TextStrokeTransparency = 1
	else
		if label then
			label:Destroy()
		end
		local text = button:GetAttribute(OWN_TEXT)
		local stroke = button:GetAttribute(OWN_STROKE)
		if typeof(text) == "number" then
			setText(button, text)
		end
		if typeof(stroke) == "number" then
			button.TextStrokeTransparency = stroke
		end
		button:SetAttribute(OWN_TEXT, nil)
		button:SetAttribute(OWN_STROKE, nil)
	end
end

-- The deeper colour for a label's own text colour, or nil to leave it.
local function deeper(own: Color3): Color3?
	if same(own, ButtonInk.TICK_GREEN) then
		return ButtonInk.TICK_STRONG
	elseif same(own, Kit.GOLD_INK) then
		return ButtonInk.GOLD_STRONG
	end
	return nil
end

local function recolour(label: TextLabel, on: boolean)
	local kept = label:GetAttribute(OWN_COLOUR)
	local own: Color3 = if typeof(kept) == "Color3" then kept else label.TextColor3
	local strong = deeper(own)
	if on and strong then
		if typeof(kept) ~= "Color3" then
			label:SetAttribute(OWN_COLOUR, own)
		end
		label.TextColor3 = strong
	elseif typeof(kept) == "Color3" then
		label:SetAttribute(OWN_COLOUR, nil)
		label.TextColor3 = kept
	end
end

-- Whether `sequence` is the old cream to beige soft button.
local function soft(sequence: ColorSequence): boolean
	local points: { ColorSequenceKeypoint }? = sequence.Keypoints
	return points ~= nil
		and #points == 2
		and same(points[1].Value, ButtonInk.SOFT_TOP)
		and same(points[2].Value, ButtonInk.SOFT_BOTTOM)
end

local function clean(gradient: UIGradient, on: boolean)
	local kept = gradient:GetAttribute(OWN_SEQUENCE)
	local own: ColorSequence = if typeof(kept) == "ColorSequence" then kept else gradient.Color
	if on and soft(own) and gradient.Parent and gradient.Parent:IsA("TextButton") then
		if typeof(kept) ~= "ColorSequence" then
			gradient:SetAttribute(OWN_SEQUENCE, own)
		end
		gradient.Color = ButtonInk.CLEAN
	elseif typeof(kept) == "ColorSequence" then
		gradient:SetAttribute(OWN_SEQUENCE, nil)
		gradient.Color = kept
	end
end

local function apply(piece: Instance, on: boolean)
	if piece:IsA("UIGradient") then
		clean(piece :: UIGradient, on)
	elseif piece:IsA("TextButton") then
		outline(piece :: TextButton, on)
	elseif piece:IsA("TextLabel") and piece.Name ~= LABEL then
		recolour(piece :: TextLabel, on)
	end
end

-- A window that redraws a button or a label: its new words or colour are its own, applied again while on.
local function follow(piece: Instance)
	if piece:IsA("TextButton") then
		local button = piece :: TextButton
		local function again()
			if LiveFlags.isOn(ButtonInk.FLAG) then
				outline(button, true)
			end
		end
		for _, property in MIRROR do
			button:GetPropertyChangedSignal(property):Connect(again)
		end
		button:GetPropertyChangedSignal("TextColor3"):Connect(again)
		button:GetPropertyChangedSignal("TextTransparency"):Connect(function()
			local mine = pending[button]
			if mine then
				-- one of our own writes: with deferred signals this runs after the write's turn ended, so a count of
				-- writes still to be seen tells them apart, not a flag cleared in that turn (Review-QA on 1116)
				pending[button] = if mine > 1 then mine - 1 else nil
				return
			end
			-- the window set its own transparency (1 included, to hide the words): it is the button's own, and the
			-- label follows it (gone while hidden, back when shown again)
			if button:FindFirstChild(LABEL) then
				button:SetAttribute(OWN_TEXT, button.TextTransparency)
				setText(button, 1)
			end
			again()
		end)
	elseif piece:IsA("TextLabel") and piece.Name ~= LABEL then
		local label = piece :: TextLabel
		label:GetPropertyChangedSignal("TextColor3"):Connect(function()
			if not LiveFlags.isOn(ButtonInk.FLAG) then
				return
			end
			local now = label.TextColor3
			local kept = label:GetAttribute(OWN_COLOUR)
			if typeof(kept) == "Color3" then
				local ours = deeper(kept)
				if ours and same(now, ours) then
					return -- our own write
				end
			end
			label:SetAttribute(OWN_COLOUR, nil)
			recolour(label, true)
		end)
	end
end

local function applyAll(card: Frame)
	local on = LiveFlags.isOn(ButtonInk.FLAG)
	for _, piece in card:GetDescendants() do
		apply(piece, on)
	end
end

function ButtonInk.watch(card: Frame)
	table.insert(cards, card)
	for _, piece in card:GetDescendants() do
		follow(piece)
	end
	card.DescendantAdded:Connect(function(piece: Instance)
		follow(piece)
		apply(piece, LiveFlags.isOn(ButtonInk.FLAG))
	end)
	applyAll(card)
end

ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. ButtonInk.FLAG)
	:Connect(function()
		for _, card in cards do
			applyAll(card)
		end
	end)

return ButtonInk
