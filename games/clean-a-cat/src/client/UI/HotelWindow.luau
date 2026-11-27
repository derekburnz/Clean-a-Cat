--!strict
-- HotelWindow: the Cat Hotel's front desk card (issue 1051, switch catHotel; Design-Agent's spec for issue 1042, Derek's
-- pick of 2026-11-27: "go with cat Hotel and draft it"). It opens from the desk's prompt, never by itself.
--
--   HotelWindow.build(root)        makes the window once and returns its layer ("Hotel")
--   HotelWindow.set(state, skew)   the server's hotel state (HotelViewRules.clean) and server time minus os.time()
--   HotelWindow.onBook(fn)         fn(room, hours) when a stay is picked
--   HotelWindow.onCollect(fn)      fn(room) for one ready room, fn(nil) for Collect all
--
-- Top: the guest waiting at the desk, its portrait framed in its rarity and "Misty Blue would like a room". Then the
-- three stays as big buttons, each with its true pay for this guest and its gift chances (always shown, since the gift
-- is random). Then the four rooms: free, asleep with the time left (never seconds), ready with its coins (tap to
-- collect) or not built yet (the Build board builds rooms 3 and 4). Then Collect all when any room is ready. No Robux
-- anywhere in the hotel, and nothing counts down in red. UI never fires remotes: HotelController asks the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local HotelRules = require(Shared:WaitForChild("HotelRules"))
local HotelViewRules = require(Shared:WaitForChild("HotelViewRules"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Portraits = require(script.Parent:WaitForChild("Portraits"))
local Window = require(script.Parent:WaitForChild("Window"))

local HotelWindow = {}

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local STAY_TOP, STAY_BOTTOM = Color3.fromHex("FFFFFF"), Color3.fromHex("F1E6FF")
local OFF = Color3.fromHex("E4DDEC") -- a stay that cannot be booked now, and a room not built yet
local READY = Color3.fromHex("FFE98F") -- a room whose guest is ready to check out
local ASLEEP = Color3.fromHex("DDEBFF")
local PAY_INK = Color3.fromHex("2E7D32") -- coins on white: 5.1 to 1
local SCREEN_MARGIN = 64
local MIN_TAP = 44 -- real px
local TICK_SECONDS = 1 -- the rooms' times change once a minute at most; read each second while open

local SIZES = {
	full = {
		width = 820,
		band = 72,
		title = 34,
		badge = 96,
		pad = 18,
		gap = 12,
		face = 64,
		guest = 26,
		stayH = 112,
		stayLabel = 26,
		stayPay = 22,
		stayOdds = 15,
		roomH = 78,
		roomName = 20,
		roomLine = 16,
		button = 60,
		text = 24,
		fine = 16,
	},
	short = {
		width = 760,
		band = 56,
		title = 28,
		badge = 80,
		pad = 10,
		gap = 8,
		face = 44,
		guest = 22,
		stayH = 92,
		stayLabel = 22,
		stayPay = 19,
		stayOdds = 14,
		roomH = 60,
		roomName = 18,
		roomLine = 14,
		button = 50,
		text = 21,
		fine = 0, -- no small print on a short screen
	},
}
type Sizes = typeof(SIZES.full)

type Stay = { button: TextButton, label: TextLabel, pay: TextLabel, odds: TextLabel }
type RoomTile = { button: TextButton, name: TextLabel, line: TextLabel }
type Parts = {
	window: Window.Window,
	pad: UIPadding,
	stack: UIListLayout,
	guestRow: Frame,
	face: Frame,
	guest: TextLabel,
	stayRow: Frame,
	stays: { Stay },
	roomRow: Frame,
	rooms: { RoomTile },
	collect: TextButton,
	fine: TextLabel,
}

local parts: Parts? = nil
local state: HotelViewRules.State = HotelViewRules.EMPTY
local skew = 0 -- server time minus os.time()
local drawnGuest = "" -- the guest whose portrait shows
local bookListeners: { (room: number, hours: number) -> () } = {}
local collectListeners: { (room: number?) -> () } = {}

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

local function card(name: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = true
	b.BackgroundColor3 = Kit.WHITE
	Kit.corner(b, UDim.new(0, 16))
	local edge = Kit.stroke(b, 3)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Kit.INK
	b.Parent = parent
	return b
end

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

local function now(): number
	return os.time() + skew
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	local width = math.min(s.width, screenWidth(scale) - SCREEN_MARGIN)
	Window.fit(p.window, width, s.band, s.title, s.badge, nil)
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad + 4), pad
	p.stack.Padding = UDim.new(0, s.gap)
	local inner = width - 2 * s.pad
	local tap = math.ceil(MIN_TAP / scale)

	-- the guest at the desk
	local guest = state.guest
	local bookRoom = HotelViewRules.bookRoom(state)
	p.guestRow.Size = UDim2.new(1, 0, 0, s.face)
	p.face.Size = UDim2.fromOffset(s.face, s.face)
	p.face.Visible = guest ~= nil and bookRoom ~= nil
	local key = if guest then `{guest.kind}/{guest.rarity}` else ""
	if guest and key ~= drawnGuest then
		drawnGuest = key
		Portraits.draw(guest.kind, guest.rarity, p.face)
	end
	p.guest.TextSize = s.guest
	p.guest.Size = UDim2.new(1, -(s.face + 12), 1, 0)
	p.guest.Text = HotelViewRules.guestLine(state)

	-- the three stays
	local options = HotelViewRules.options(guest)
	local stayW = math.floor((inner - 2 * 10) / 3)
	p.stayRow.Size = UDim2.new(1, 0, 0, math.max(s.stayH, tap))
	for index, stay in p.stays do
		local option = options[index]
		stay.button.Visible = option ~= nil
		if option then
			local can = bookRoom ~= nil
			stay.button.Size = UDim2.fromOffset(stayW, math.max(s.stayH, tap))
			stay.button.BackgroundColor3 = if can then Kit.WHITE else OFF
			stay.button.AutoButtonColor = can
			stay.button.Active = can
			local fill = stay.button:FindFirstChildOfClass("UIGradient") :: UIGradient?
			if fill then
				fill.Enabled = can
			end
			stay.label.TextSize = s.stayLabel
			stay.label.Size = UDim2.new(1, 0, 0, s.stayLabel + 4)
			stay.label.Text = option.label
			stay.pay.TextSize = s.stayPay
			stay.pay.Size = UDim2.new(1, 0, 0, s.stayPay + 4)
			stay.pay.Text = `{option.pay} coins`
			stay.odds.TextSize = s.stayOdds
			stay.odds.Size = UDim2.new(1, 0, 0, s.stayOdds * 2 + 4)
			stay.odds.Text = option.chances
		end
	end

	-- the four rooms
	local rooms = HotelViewRules.rooms(state, now())
	local roomW = math.floor((inner - 3 * 10) / 4)
	p.roomRow.Size = UDim2.new(1, 0, 0, math.max(s.roomH, tap))
	for index, tile in p.rooms do
		local room = rooms[index]
		tile.button.Size = UDim2.fromOffset(roomW, math.max(s.roomH, tap))
		tile.button.BackgroundColor3 = if room.status == "ready"
			then READY
			elseif room.status == "asleep" then ASLEEP
			elseif room.status == "locked" then OFF
			else Kit.WHITE
		local ready = room.status == "ready"
		tile.button.AutoButtonColor = ready
		tile.button.Active = ready
		tile.name.TextSize = s.roomName
		tile.name.Size = UDim2.new(1, 0, 0, s.roomName + 4)
		tile.name.Text = if room.kind then CatRules.displayName(room.kind) else `Room {room.room}`
		tile.line.TextSize = s.roomLine
		tile.line.Size = UDim2.new(1, 0, 0, s.roomLine * 2 + 4)
		tile.line.Text = room.line
	end

	-- Collect all
	local collect = HotelViewRules.collectText(state, now())
	p.collect.Visible = collect ~= nil
	p.collect.Text = collect or ""
	p.collect.TextSize = s.text
	p.collect.Size = UDim2.new(1, 0, 0, math.max(s.button, tap))

	p.fine.Visible = s.fine > 0
	p.fine.TextSize = math.max(s.fine, 14)
	p.fine.Size = UDim2.new(1, 0, 0, s.fine + 6)
end

function HotelWindow.set(newState: HotelViewRules.State, newSkew: number)
	state, skew = newState, newSkew
	local p = parts
	if p and p.window.layer.Visible then
		if not state.open then
			p.window.layer.Visible = false
			return
		end
		redraw()
	end
end

function HotelWindow.onBook(fn: (room: number, hours: number) -> ())
	table.insert(bookListeners, fn)
end

function HotelWindow.onCollect(fn: (room: number?) -> ())
	table.insert(collectListeners, fn)
end

local function collect(room: number?)
	for _, listener in collectListeners do
		task.spawn(listener, room)
	end
end

function HotelWindow.build(root: Instance): Frame
	local window = Window.new(HotelViewRules.WINDOW, HotelViewRules.TITLE, "Hotel", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local stack = list(window.body, false, 12)
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- the guest at the desk
	local guestRow = frame("Guest", window.body)
	guestRow.LayoutOrder = 1
	local guestList = list(guestRow, true, 12)
	guestList.VerticalAlignment = Enum.VerticalAlignment.Center
	local face = frame("Face", guestRow)
	face.LayoutOrder = 1
	local guest = words("Line", guestRow, 26)
	guest.LayoutOrder = 2
	guest.TextXAlignment = Enum.TextXAlignment.Left
	guest.TextWrapped = true

	-- the three stays
	local stayRow = frame("Stays", window.body)
	stayRow.LayoutOrder = 2
	list(stayRow, true, 10)
	local stays: { Stay } = {}
	for index, hours in HotelRules.HOURS do
		local button = card(`Stay{hours}`, stayRow)
		button.LayoutOrder = index
		local fill = Instance.new("UIGradient")
		fill.Rotation = 90
		fill.Color = ColorSequence.new(STAY_TOP, STAY_BOTTOM)
		fill.Parent = button
		local inside = Instance.new("UIPadding")
		inside.PaddingLeft, inside.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		inside.PaddingTop, inside.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
		inside.Parent = button
		local column = list(button, false, 2)
		column.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local label = words("Hours", button, 26)
		label.LayoutOrder = 1
		local pay = words("Pay", button, 22)
		pay.LayoutOrder = 2
		pay.TextColor3 = PAY_INK
		local odds = words("Odds", button, 15)
		odds.LayoutOrder = 3
		odds.FontFace = Kit.BODY_FACE
		odds.TextWrapped = true
		button.Activated:Connect(function()
			local room = HotelViewRules.bookRoom(state)
			if room == nil then
				return
			end
			window.layer.Visible = false
			for _, listener in bookListeners do
				task.spawn(listener, room, hours)
			end
		end)
		table.insert(stays, { button = button, label = label, pay = pay, odds = odds })
	end

	-- the four rooms
	local roomRow = frame("Rooms", window.body)
	roomRow.LayoutOrder = 3
	list(roomRow, true, 10)
	local rooms: { RoomTile } = {}
	for room = 1, HotelRules.MAX_ROOMS do
		local button = card(`Room{room}`, roomRow)
		button.LayoutOrder = room
		local inside = Instance.new("UIPadding")
		inside.PaddingLeft, inside.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
		inside.PaddingTop = UDim.new(0, 4)
		inside.Parent = button
		local column = list(button, false, 0)
		column.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local name = words("Name", button, 20)
		name.LayoutOrder = 1
		Kit.shrinkToFit(name, 20)
		local line = words("Line", button, 16)
		line.LayoutOrder = 2
		line.FontFace = Kit.BODY_FACE
		line.TextWrapped = true
		button.Activated:Connect(function()
			local rows = HotelViewRules.rooms(state, now())
			if rows[room] and rows[room].status == "ready" then
				collect(room)
			end
		end)
		table.insert(rooms, { button = button, name = name, line = line })
	end

	local collectAll = Window.button("Collect", "", window.body, GREEN_TOP, GREEN_BOTTOM)
	collectAll.LayoutOrder = 4
	collectAll.Visible = false
	collectAll.Activated:Connect(function()
		collect(nil)
	end)

	local fine = words("Fine", window.body, 16)
	fine.LayoutOrder = 5
	fine.FontFace = Kit.BODY_FACE
	fine.TextColor3 = Kit.INK_SOFT
	fine.Text = HotelViewRules.FINE

	parts = {
		window = window,
		pad = pad,
		stack = stack,
		guestRow = guestRow,
		face = face,
		guest = guest,
		stayRow = stayRow,
		stays = stays,
		roomRow = roomRow,
		rooms = rooms,
		collect = collectAll,
		fine = fine,
	}
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
			task.spawn(function()
				while window.layer.Visible do
					task.wait(TICK_SECONDS)
					if window.layer.Visible then
						redraw()
					end
				end
			end)
		end
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

return HotelWindow
