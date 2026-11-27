--!strict
-- HotelController: the Cat Hotel on the player's own plot (issue 1051, switch catHotel; the server is HotelService,
-- issue 1049). It keeps the server's hotel state (the Hotel event) and shows it:
--   * a prompt on the front desk: "Book a stay" while a guest waits for a free room, "Collect all" while a stay is
--     over, else "Front desk"; a tap opens the hotel's card (UI/HotelWindow), never anything by itself;
--   * a bubble over each bed (UI/HotelBubble): the time left while a guest sleeps, gold with its coins once ready;
--   * a "Check out" prompt on each ready bed, which collects that room.
-- The card's stay buttons ask BookStay(room, hours) and its Collect buttons CollectRoom(room?). The server checks the
-- room, the hours, the guest, the distance and the time, and pays; nothing here decides anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HotelRules = require(Shared:WaitForChild("HotelRules"))
local HotelViewRules = require(Shared:WaitForChild("HotelViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local HotelBubble = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HotelBubble"))
local UI = require(script.Parent.Parent:WaitForChild("UI"))

local HotelController = {}

local PROMPT_REACH = 12 -- studs: the desk and the beds sit inside the hotel, well within HotelRules.SERVER_REACH
local TICK_SECONDS = 1 -- the bubbles' times change once a minute at most; read each second while the hotel is open

local player = Players.LocalPlayer
local state: HotelViewRules.State = HotelViewRules.EMPTY
local skew = 0 -- server time minus os.time()

type Bed = { spot: Instance, bubble: HotelBubble.Bubble, prompt: ProximityPrompt }
local desk: ProximityPrompt? = nil
local beds: { [number]: Bed } = {}

local function on(): boolean
	return LiveFlags.isOn(HotelRules.FLAG) and state.open
end

local function now(): number
	return os.time() + skew
end

-- The hotel model in the player's own plot, once the server has placed it.
local function hotelModel(): Instance?
	local slot = SpaLayout.slotOf(player)
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	local folder = if plot then plot:FindFirstChild(SpaLayout.STATIONS_FOLDER) else nil
	return if folder then folder:FindFirstChild(HotelRules.AREA_NAME) else nil
end

local function prompt(parent: Instance, action: string): ProximityPrompt
	local made = Instance.new("ProximityPrompt")
	made.Name = "CleanACat_HotelPrompt"
	made.ActionText = action
	made.ObjectText = HotelViewRules.TITLE
	made.HoldDuration = 0
	made.MaxActivationDistance = PROMPT_REACH
	made.RequiresLineOfSight = false
	made.Parent = parent
	return made
end

local function collect(room: number?)
	if not on() then
		return
	end
	Remotes.event(HotelRules.COLLECT_REMOTE):FireServer(room)
end

local function clear()
	if desk then
		desk:Destroy()
		desk = nil
	end
	for room, bed in beds do
		bed.bubble.gui:Destroy()
		bed.prompt:Destroy()
		beds[room] = nil
	end
end

local function refresh()
	if not on() then
		clear()
		return
	end
	local hotel = hotelModel()
	if hotel == nil then
		clear()
		return
	end

	-- the front desk
	local deskSpot = hotel:FindFirstChild(HotelRules.DESK_SPOT, true)
	local current = desk
	if current and (current.Parent == nil or current.Parent ~= deskSpot) then
		current:Destroy()
		desk = nil
	end
	if desk == nil and deskSpot then
		local made = prompt(deskSpot, HotelViewRules.PROMPT)
		made.Triggered:Connect(function()
			UI.open(HotelViewRules.WINDOW)
		end)
		desk = made
	end
	local at = now()
	local readyCount = HotelViewRules.ready(state, at)
	local made = desk
	if made then
		made.ActionText = if readyCount > 0
			then "Collect all"
			elseif HotelViewRules.bookRoom(state) then "Book a stay"
			else HotelViewRules.PROMPT
	end

	-- the beds
	for _, row in HotelViewRules.rooms(state, at) do
		local spot = hotel:FindFirstChild(HotelRules.ROOM_SPOT_PREFIX .. row.room, true)
		local bed: Bed? = beds[row.room]
		if bed and bed.spot ~= spot then
			bed.bubble.gui:Destroy()
			bed.prompt:Destroy()
			beds[row.room] = nil
			bed = nil
		end
		if bed == nil and spot then
			local room = row.room
			local checkOut = prompt(spot, "Check out")
			checkOut.Enabled = false
			checkOut.Triggered:Connect(function()
				collect(room)
			end)
			local made: Bed = { spot = spot, bubble = HotelBubble.make(spot), prompt = checkOut }
			beds[room] = made
			bed = made
		end
		if bed then
			local ready = row.status == "ready"
			HotelBubble.set(
				bed.bubble,
				if row.status == "asleep" or ready then row.bubble else nil,
				ready
			)
			bed.prompt.Enabled = ready
		end
	end
end

function HotelController.Init(_controllers: { [string]: any }) end

function HotelController.Start()
	Remotes.event(HotelRules.STATE_EVENT).OnClientEvent:Connect(function(raw: unknown)
		state = HotelViewRules.clean(raw)
		if state.now > 0 then
			skew = state.now - os.time()
		end
		UI.setHotel(state, skew)
		refresh()
	end)
	UI.onHotelBook(function(room: number, hours: number)
		if not on() then
			return
		end
		Remotes.event(HotelRules.BOOK_REMOTE):FireServer(room, hours)
	end)
	UI.onHotelCollect(collect)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. HotelRules.FLAG)
		:Connect(refresh)
	-- the times over the beds, and a hotel model that arrives after the state
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			if on() then
				refresh()
			end
		end
	end)
end

return HotelController
