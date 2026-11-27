--!strict
-- ShortText: fewer words in the menus behind the switch shortText (issue 1027, Derek's playtest of 2026-11-27: "lots of
-- bloat text that doesn't need to be there"). Window.new hands each window's card here, and while the switch is on
-- every line in it is checked against ShortTextRules as it is drawn or redrawn:
--   * a line the picture and title already say is emptied, keeping its room so the cards' buttons stay in a row (the
--     shop cards' long descriptions, the gift steps' second lines, the Settings row note);
--   * a long line is cut to the fewest words that still say it ("Hire at their pad · 1200 coins" -> "1200 coins").
-- Numbers, prices, odds and every button keep their words: only these known lines change, so nothing that matters to
-- a purchase is ever hidden (the crate still says its chances add up to 100%). Each line keeps its own words in an
-- attribute, so turning the switch off puts every line back exactly.
--
--   ShortText.watch(card)    shortens the window card's lines, now and as they change
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local ShortTextRules = require(Shared:WaitForChild("ShortTextRules"))

local ShortText = {}

ShortText.FLAG = ShortTextRules.FLAG

local OWN_TEXT = "Short_Text" -- attribute: the line's own words while the switch is on

local function isText(piece: Instance): boolean
	return piece:IsA("TextLabel") or piece:IsA("TextButton")
end

-- Shows `piece` its short words while on, else puts its own words back.
local function set(piece: Instance, on: boolean)
	local label = piece :: TextLabel
	local kept = piece:GetAttribute(OWN_TEXT)
	if on then
		local own: string = if type(kept) == "string" then kept else label.Text
		local short = ShortTextRules.apply(own)
		if short == nil then
			if type(kept) == "string" then
				piece:SetAttribute(OWN_TEXT, nil)
			end
			return
		end
		if type(kept) ~= "string" then
			piece:SetAttribute(OWN_TEXT, own)
		end
		label.Text = short
	elseif type(kept) == "string" then
		piece:SetAttribute(OWN_TEXT, nil)
		label.Text = kept
	end
end

-- A window that writes a line again: its new words are its own, shortened again while on.
local function follow(piece: Instance)
	if not isText(piece) then
		return
	end
	(piece :: TextLabel):GetPropertyChangedSignal("Text"):Connect(function()
		if not LiveFlags.isOn(ShortText.FLAG) then
			return
		end
		local text = (piece :: TextLabel).Text
		local kept = piece:GetAttribute(OWN_TEXT)
		if type(kept) == "string" and ShortTextRules.apply(kept) == text then
			return -- our own write
		end
		piece:SetAttribute(OWN_TEXT, nil)
		set(piece, true)
	end)
end

local cards: { Frame } = {}

local function applyAll(card: Frame)
	local on = LiveFlags.isOn(ShortText.FLAG)
	for _, piece in card:GetDescendants() do
		if isText(piece) then
			set(piece, on)
		end
	end
end

function ShortText.watch(card: Frame)
	table.insert(cards, card)
	for _, piece in card:GetDescendants() do
		follow(piece)
	end
	card.DescendantAdded:Connect(function(piece: Instance)
		follow(piece)
		if isText(piece) then
			set(piece, LiveFlags.isOn(ShortText.FLAG))
		end
	end)
	applyAll(card)
end

ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. ShortText.FLAG)
	:Connect(function()
		for _, card in cards do
			applyAll(card)
		end
	end)

return ShortText
