--!strict
-- HotelBubble: the small bubble over a hotel bed (issue 1051, switch catHotel). While a guest sleeps it shows a clock
-- and the time left ("1h 6m", never seconds); once the stay is over it turns gold with the coins ("+300") so the
-- player can see from the doorway which rooms are ready. HotelController makes one per bed and sets its words.
--
--   local bubble = HotelBubble.make(spot)   a bubble over `spot` (the bed's Attachment), hidden
--   HotelBubble.set(bubble, text, ready)    shows `text`, gold when `ready`; nil text hides it
local Kit = require(script.Parent:WaitForChild("Kit"))

local HotelBubble = {}

local HEIGHT = 2.4 -- studs over the bed top
local READY_FILL = Color3.fromHex("FFE98F")
local ASLEEP_FILL = Color3.fromHex("FFFFFF")
local MAX_DISTANCE = 70 -- studs: from the hotel's doorway, not from across the map

export type Bubble = { gui: BillboardGui, pill: Frame, label: TextLabel }

function HotelBubble.make(spot: Instance): Bubble
	local gui = Instance.new("BillboardGui")
	gui.Name = "CleanACat_HotelBubble"
	gui.Size = UDim2.fromOffset(120, 44)
	gui.StudsOffset = Vector3.new(0, HEIGHT, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 36)
	pill.BackgroundColor3 = ASLEEP_FILL
	Kit.corner(pill, UDim.new(0.5, 0))
	local edge = Kit.stroke(pill, 3)
	edge.Color = Kit.INK
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.Parent = pill
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.Font = Kit.FONT
	label.TextSize = 22
	label.TextColor3 = Kit.INK
	label.Parent = pill
	pill.Parent = gui
	gui.Adornee = spot
	gui.Parent = spot
	return { gui = gui, pill = pill, label = label }
end

function HotelBubble.set(bubble: Bubble, text: string?, ready: boolean)
	bubble.gui.Enabled = text ~= nil
	if text == nil then
		return
	end
	bubble.label.Text = if ready then `🪙 {text}` else `🕒 {text}`
	bubble.pill.BackgroundColor3 = if ready then READY_FILL else ASLEEP_FILL
end

return HotelBubble
