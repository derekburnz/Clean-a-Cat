--!strict
-- Waiting: the HUD's waiting faces (#246), from Design-Agent's hud.html: one round face per customer at the door,
-- on the right. On a tall screen they stand in a column at mid height under the word "Waiting"; on a phone held
-- sideways they sit in a row under the coins. A Rare or rarer customer wears its rarity tag. Pressing any face opens
-- "Who's next?" (UI/QueueWindow). The patience ring around each face waits for the design to set patience.
--
--   Waiting.build(root, open)   makes the faces once; open() runs when a face is pressed
--   Waiting.set(cards)          the line (QueueViewRules cards, front first)
--
-- Shows only while the game HUD (gameHud) and queueWindow are on and someone is waiting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local QueueViewRules = require(Shared:WaitForChild("QueueViewRules"))

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Motion = require(script.Parent.Parent:WaitForChild("Motion"))
local Portraits = require(script.Parent.Parent:WaitForChild("Portraits"))

local Waiting = {}

local FLAGS = { "gameHud", "queueWindow" }
local FACE_FULL, FACE_SHORT = 74, 60 -- design px
local EDGE = 26 -- real px from the root's right edge
local SHORT_TOP = 122 -- design px from the root's top on a short screen: under the coin counter
local FACE_BACK = Color3.fromHex("FFF4E6")

type Parts = { holder: Frame, scale: UIScale, list: UIListLayout, head: TextLabel, faces: Frame }

local parts: Parts? = nil
local cards: { QueueViewRules.Card } = {}
local openWindow: () -> () = function() end

local function allOn(): boolean
	for _, name in FLAGS do
		if not LiveFlags.isOn(name) then
			return false
		end
	end
	return true
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	p.scale.Scale = scale
	p.holder.Visible = allOn() and #cards > 0
	if short then
		p.holder.AnchorPoint = Vector2.new(1, 0)
		p.holder.Position = UDim2.new(1, -EDGE, 0, SHORT_TOP * scale)
	else
		p.holder.AnchorPoint = Vector2.new(1, 0.5)
		p.holder.Position = UDim2.new(1, -EDGE, 0.54, 0)
	end
	p.head.Visible = not short
	p.list.FillDirection = if short
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	p.list.Padding = UDim.new(0, if short then 22 else 24)

	for _, child in p.faces:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local size = if short then FACE_SHORT else FACE_FULL
	local faces: { TextButton } = {}
	for _, card in cards do
		local face = Instance.new("TextButton")
		face.Name = `Face{card.place}`
		-- front first: top to bottom in the column, right to left in the row
		face.LayoutOrder = if short then -card.place else card.place
		face.Size = UDim2.fromOffset(size, size)
		face.Text = ""
		face.AutoButtonColor = true
		face.BackgroundColor3 = FACE_BACK
		face.Selectable = true
		Kit.corner(face, UDim.new(0.5, 0))
		local edge = Kit.stroke(face, 4)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Portraits.draw(card.cat, card.rarity, face, true)
		if card.vip then
			local tag = Instance.new("Frame")
			tag.Name = "Rarity"
			tag.AnchorPoint = Vector2.new(0.5, 0.5)
			tag.Position = UDim2.fromScale(0.5, 1)
			tag.AutomaticSize = Enum.AutomaticSize.X
			tag.Size = UDim2.fromOffset(0, 24)
			tag.BackgroundColor3 = Kit.RARITY[card.rarity] or Kit.RARITY.Common
			tag.ZIndex = 2
			Kit.corner(tag, UDim.new(0.5, 0))
			Kit.stroke(tag, 2)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 9), UDim.new(0, 9)
			pad.Parent = tag
			local word = Kit.outlined("Text", tag)
			word.AnchorPoint = Vector2.new(0, 0.5)
			word.Position = UDim2.fromScale(0, 0.5)
			word.TextSize = 19
			word.Text = card.rarity
			word.ZIndex = 2
			tag.Parent = face
		end
		face.Parent = p.faces
		Motion.press(face) -- trial springs, switch springUi (#183)
		face.Activated:Connect(function()
			openWindow()
		end)
		table.insert(faces, face)
	end
	for index, face in faces do
		face.NextSelectionUp = faces[index - 1]
		face.NextSelectionDown = faces[index + 1]
	end
end

function Waiting.set(newCards: { QueueViewRules.Card })
	cards = newCards
	redraw()
end

function Waiting.build(root: Instance, open: () -> ())
	openWindow = open
	local holder = Instance.new("Frame")
	holder.Name = "Waiting"
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Visible = false
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = holder
	local column = Instance.new("UIListLayout")
	column.SortOrder = Enum.SortOrder.LayoutOrder
	column.HorizontalAlignment = Enum.HorizontalAlignment.Center
	column.Padding = UDim.new(0, 10)
	column.Parent = holder
	local head = Kit.outlined("Head", holder)
	head.LayoutOrder = 1
	head.TextSize = 20
	head.Text = "Waiting"
	local faces = Instance.new("Frame")
	faces.Name = "Faces"
	faces.LayoutOrder = 2
	faces.BackgroundTransparency = 1
	faces.AutomaticSize = Enum.AutomaticSize.XY
	faces.Size = UDim2.fromOffset(0, 0)
	faces.Parent = holder
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = faces
	-- room under the last face for its rarity tag
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = faces
	holder.Parent = root

	parts = { holder = holder, scale = scale, list = list, head = head, faces = faces }
	for _, name in FLAGS do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name)
			:Connect(redraw)
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
end

return Waiting
