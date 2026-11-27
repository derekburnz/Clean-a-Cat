--!strict
-- Contrast: stronger menu colours behind the switch menuContrast2 (issue 1029, Derek's playtest of 2026-11-27:
-- "contrast in menus is really bad it has light on light on light"). Window.new hands each window's card here, and
-- while the switch is on every piece in it is recoloured as it is drawn or redrawn:
--   * the window's own cream card becomes a deeper lilac PANEL, so the white and cream cards on it stand apart;
--   * a cream card or row inside it becomes white;
--   * the pale card edges (Kit.LINE, and menuContrast's LINE_STRONG) become ink;
--   * the soft lilac body text (Kit.INK_SOFT) becomes ink.
-- Contrast (WCAG): ink on white 12.4 to 1, ink on PANEL 7.6 to 1, ink on cream 11.8 to 1; a white card on PANEL is
-- set apart by its ink edge (12.4 to 1 against white, 7.6 against PANEL). Each piece keeps its own colour in an
-- attribute, so turning the switch off puts every piece back exactly. Nothing else changes: rarity, gold, green and
-- red colours are left alone.
--
--   Contrast.watch(card)   recolours the window card and everything in it, now and as it changes
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local Kit = require(script.Parent:WaitForChild("Kit"))

local Contrast = {}

Contrast.FLAG = "menuContrast2"
Contrast.PANEL = Color3.fromHex("DCC8F2")

local OWN = "Contrast2_" -- attribute prefix holding a piece's own colour while the switch is on

local cards: { Frame } = {}

local function same(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.004
		and math.abs(a.G - b.G) < 0.004
		and math.abs(a.B - b.B) < 0.004
end

local function isLine(c: Color3): boolean
	return same(c, Kit.LINE) or same(c, Kit.LINE_STRONG)
end

-- The colour `property` of `piece` should show: `strong` while on, else its own colour back.
local function set(piece: Instance, property: string, strong: Color3?, on: boolean)
	local key = OWN .. property
	local kept = piece:GetAttribute(key)
	if on and strong then
		if typeof(kept) ~= "Color3" then
			piece:SetAttribute(key, (piece :: any)[property])
		end
		(piece :: any)[property] = strong
	elseif typeof(kept) == "Color3" then
		piece:SetAttribute(key, nil);
		(piece :: any)[property] = kept
	end
end

-- What `property` of `piece` becomes with the switch on, from its own colour, or nil to leave it.
local function strongFor(piece: Instance, property: string, own: Color3, card: Frame): Color3?
	if property == "TextColor3" then
		return if same(own, Kit.INK_SOFT) then Kit.INK else nil
	elseif property == "Color" then
		return if isLine(own) then Kit.INK else nil
	elseif property == "BackgroundColor3" then
		if not same(own, Kit.CREAM) then
			return nil
		end
		return if piece == (card :: Instance) then Contrast.PANEL else Kit.WHITE
	end
	return nil
end

local function ownColour(piece: Instance, property: string): Color3
	local kept = piece:GetAttribute(OWN .. property)
	if typeof(kept) == "Color3" then
		return kept
	end
	return (piece :: any)[property]
end

local function apply(piece: Instance, card: Frame, on: boolean)
	local properties: { string } = {}
	if piece:IsA("TextLabel") or piece:IsA("TextButton") or piece:IsA("TextBox") then
		table.insert(properties, "TextColor3")
	end
	if piece:IsA("GuiObject") then
		table.insert(properties, "BackgroundColor3")
	elseif piece:IsA("UIStroke") then
		table.insert(properties, "Color")
	end
	for _, property in properties do
		set(piece, property, strongFor(piece, property, ownColour(piece, property), card), on)
	end
end

-- A later change to a piece's colour by its window: the new colour is its own, recoloured again while on.
local function follow(piece: Instance, card: Frame)
	local properties: { string } = {}
	if piece:IsA("TextLabel") or piece:IsA("TextButton") or piece:IsA("TextBox") then
		table.insert(properties, "TextColor3")
	end
	if piece:IsA("GuiObject") then
		table.insert(properties, "BackgroundColor3")
	elseif piece:IsA("UIStroke") then
		table.insert(properties, "Color")
	else
		return
	end
	for _, property in properties do
		piece:GetPropertyChangedSignal(property):Connect(function()
			if not LiveFlags.isOn(Contrast.FLAG) then
				return
			end
			local now: Color3 = (piece :: any)[property]
			local key = OWN .. property
			local kept = piece:GetAttribute(key)
			if typeof(kept) == "Color3" then
				local ours = strongFor(piece, property, kept, card)
				if ours and same(now, ours) then
					return -- our own write
				end
			end
			local strong = strongFor(piece, property, now, card)
			if strong then
				piece:SetAttribute(key, now);
				(piece :: any)[property] = strong
			else
				piece:SetAttribute(key, nil) -- the window set a colour of its own: it stays as it is
			end
		end)
	end
end

local function applyAll(card: Frame)
	local on = LiveFlags.isOn(Contrast.FLAG)
	apply(card, card, on)
	for _, piece in card:GetDescendants() do
		apply(piece, card, on)
	end
end

function Contrast.watch(card: Frame)
	table.insert(cards, card)
	follow(card, card)
	for _, piece in card:GetDescendants() do
		follow(piece, card)
	end
	card.DescendantAdded:Connect(function(piece: Instance)
		follow(piece, card)
		apply(piece, card, LiveFlags.isOn(Contrast.FLAG))
	end)
	applyAll(card)
end

ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Contrast.FLAG)
	:Connect(function()
		for _, card in cards do
			applyAll(card)
		end
	end)

return Contrast
