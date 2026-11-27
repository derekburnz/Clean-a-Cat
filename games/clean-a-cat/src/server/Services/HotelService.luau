--!strict
-- HotelService: the Cat Hotel's guests and stays (HotelRules, issue 1049), behind the switch catHotel with
-- expansionDoor. Opening the hotel and rooms 3 and 4 are BuildService's timed builds; this runs what happens inside.
--
-- While the hotel is open and a room is free, a guest waits at the desk: rolled here (HotelRules.rollGuest at the
-- player's star tier), held for the visit, never saved. The client is told the hotel's state with the event Hotel
-- (HotelRules' view: open, rooms, stays, guest, the server's clock) after every change, and the guests stand in the
-- plot's hotel model: the waiting one at SpotHotelDesk with its suitcase, the sleeping ones on their beds
-- (CleanACat_Cat_<kind>_Loaf_Lite, attributes HotelGuest, HotelRoom and EndsAt), sitting up once their stay is over.
--
--   BookStay(room, hours)  1 a second; switches on, save loaded, hotel open, within HotelRules.SERVER_REACH of the
--                          back door, a guest waiting, `room` a whole number from 1 to the open rooms and free, `hours`
--                          1, 4 or 8. Saves the stay (server time, so it runs while the player is away).
--   CollectRoom(room?)     1 a second; the same checks of place; `room` 1 to 4, or nil for every ready room. Each ended
--                          stay is taken out of the save first, then pays HotelRules.pay plus its gift (bonus coins,
--                          the next bow tier with bowTiers on, or a normal crate with crates on; coins otherwise).
-- No Robux inside the hotel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BowRules = require(Shared:WaitForChild("BowRules"))
local CatRules = require(Shared:WaitForChild("CatRules"))
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local ExpansionRules = require(Shared:WaitForChild("ExpansionRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local HotelRules = require(Shared:WaitForChild("HotelRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local VipRules = require(Shared:WaitForChild("VipRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local ExpansionService = require(script.Parent:WaitForChild("ExpansionService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local StationService = require(script.Parent:WaitForChild("StationService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local HotelService = {}

local SLEEP_SUFFIX = "_Loaf_Lite" -- Model-Agent's sleeping twins (PR 1087)
local SUITCASE_OFFSET = CFrame.new(1.6, 0, 0.4) -- beside the waiting guest, from the desk spot
local GUEST_PREFIX = "HotelGuest" -- the guest models' names in the hotel: HotelGuestDesk, HotelGuest1 to 4
local READY_CHECK = 5 -- seconds between looks for stays that just ended, so the guest sits up

local random = Random.new()
local guests: { [Player]: HotelRules.Guest } = {}
local readyShown: { [Player]: { [string]: boolean } } = {}

local function on(): boolean
	return LiveFlags.isOn(HotelRules.FLAG) and LiveFlags.isOn(ExpansionRules.FLAG)
end

-- The save's stays, read through a check and kept on the save.
local function staysOf(save: any): { [string]: HotelRules.Stay }
	if type(save.hotel) ~= "table" then
		save.hotel = { stays = {} }
	end
	save.hotel.stays = HotelRules.cleanStays(save.hotel.stays)
	return save.hotel.stays
end

local function isOpen(save: any): boolean
	return HotelRules.open(save.stations, save.expansionUnlocked == true)
end

local function near(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or SpaLayout.slotOf(player) == nil then
		return false
	end
	local spot = SpaLayout.spot(ExpansionRules.SPOT, player)
	return ((root :: BasePart).Position - spot.Position).Magnitude <= HotelRules.SERVER_REACH
end

-- A cat model for the hotel with no scripts, anchored and out of the way, or nil when none of `names` is there.
local function catModel(assets: Instance, names: { string }): Model?
	for _, name in names do
		local base = assets:FindFirstChild(name)
		if base and base:IsA("Model") then
			local cat = (base :: Model):Clone() :: Model
			for _, piece in cat:GetDescendants() do
				if piece:IsA("Script") or piece:IsA("LocalScript") then
					piece:Destroy()
				elseif piece:IsA("BasePart") then
					local part = piece :: BasePart
					part.Anchored = true
					part.CanCollide = false
					part.CanTouch = false
				end
			end
			return cat
		end
	end
	return nil
end

local function sittingNames(kind: string): { string }
	local names = {}
	for _, suffix in VipRules.RESIDENT_SUFFIXES do
		table.insert(names, `CleanACat_Cat_{kind}{suffix}`)
	end
	return names
end

-- Puts the guests into `hotel` (the plot's hotel model), replacing any already there.
local function drawGuests(player: Player, hotel: Model)
	for _, child in hotel:GetChildren() do
		if
			string.sub(child.Name, 1, #GUEST_PREFIX) == GUEST_PREFIX
			or child.Name == "HotelSuitcase"
		then
			child:Destroy()
		end
	end
	local save = DataService.get(player)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if save == nil or assets == nil or not on() then
		return
	end
	local raw = hotel:GetAttribute(HotelRules.GUEST_SCALE_ATTRIBUTE)
	local scale = if type(raw) == "number" and raw > 0.2 and raw < 3 then raw else 1
	local now = os.time()
	for key, stay in staysOf(save) do
		local spot = hotel:FindFirstChild(HotelRules.ROOM_SPOT_PREFIX .. key, true)
		if spot == nil or not spot:IsA("Attachment") then
			continue
		end
		local ready = now >= stay.endsAt
		local names = sittingNames(stay.kind)
		if not ready then
			table.insert(names, 1, `CleanACat_Cat_{stay.kind}{SLEEP_SUFFIX}`)
		end
		local cat = catModel(assets :: Instance, names)
		if cat then
			cat.Name = GUEST_PREFIX .. key
			cat:SetAttribute(HotelRules.GUEST_ATTRIBUTE, stay.kind)
			cat:SetAttribute(HotelRules.ROOM_ATTRIBUTE, tonumber(key))
			cat:SetAttribute(HotelRules.ENDS_ATTRIBUTE, stay.endsAt)
			cat:SetAttribute("Ready", ready)
			cat:ScaleTo(scale)
			cat:PivotTo((spot :: Attachment).WorldCFrame)
			cat.Parent = hotel
		end
	end
	local guest = guests[player]
	local desk = hotel:FindFirstChild(HotelRules.DESK_SPOT, true)
	if guest and desk and desk:IsA("Attachment") then
		local at = (desk :: Attachment).WorldCFrame
		local cat = catModel(assets :: Instance, sittingNames(guest.kind))
		if cat then
			cat.Name = GUEST_PREFIX .. "Desk"
			cat:SetAttribute(HotelRules.GUEST_ATTRIBUTE, guest.kind)
			cat:ScaleTo(scale)
			cat:PivotTo(at)
			cat.Parent = hotel
		end
		local suitcase = assets:FindFirstChild(HotelRules.SUITCASE_ASSET)
		if suitcase and suitcase:IsA("Model") then
			local bag = (suitcase :: Model):Clone() :: Model
			bag.Name = "HotelSuitcase"
			for _, piece in bag:GetDescendants() do
				if piece:IsA("BasePart") then
					(piece :: BasePart).Anchored = true
					(piece :: BasePart).CanCollide = false
				end
			end
			bag:PivotTo(at * SUITCASE_OFFSET)
			bag.Parent = hotel
		end
	end
end

local function hotelModel(player: Player): Model?
	local slot = SpaLayout.slotOf(player)
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	local folder = if plot then plot:FindFirstChild(SpaLayout.STATIONS_FOLDER) else nil
	local hotel = if folder then folder:FindFirstChild(HotelRules.AREA_NAME) else nil
	return if hotel and hotel:IsA("Model") then hotel :: Model else nil
end

-- Tells the client the hotel as it is now.
local function send(player: Player)
	local save = DataService.get(player)
	if save == nil then
		return
	end
	local open = on() and isOpen(save)
	NetService.fire(player, HotelRules.STATE_EVENT, {
		open = open,
		rooms = if open then HotelRules.rooms(save.stations) else 0,
		stays = if open then staysOf(save) else {},
		guest = if open then guests[player] else nil,
		now = os.time(),
	})
end

-- Brings the save and the desk up to date: a save whose door was unlocked before catHotel has the hotel built, a built
-- hotel keeps the door open when the switch goes off, and a free room gets a guest. True when anything changed.
local function settle(player: Player): boolean
	local save = DataService.get(player)
	if save == nil or not on() then
		return false
	end
	local changed = false
	if save.expansionUnlocked == true and save.stations[HotelRules.ID] ~= true then
		save.stations[HotelRules.ID] = true
		changed = true
	elseif save.stations[HotelRules.ID] == true and save.expansionUnlocked ~= true then
		save.expansionUnlocked = true
		changed = true
	end
	if changed then
		ExpansionService.show(player)
	end
	if not isOpen(save) then
		return changed
	end
	local stays = staysOf(save)
	if guests[player] == nil and HotelRules.freeRoom(stays, HotelRules.rooms(save.stations)) then
		guests[player] = HotelRules.rollGuest(function()
			return random:NextNumber()
		end, player:GetAttribute(CatRules.TIER_ATTRIBUTE) :: number?)
		changed = true
	end
	return changed
end

local function redraw(player: Player)
	local hotel = hotelModel(player)
	if hotel then
		drawGuests(player, hotel)
	end
	send(player)
end

local function onBook(player: Player, rawRoom: unknown, rawHours: unknown)
	if not on() then
		return
	end
	local room = Guard.int(rawRoom, 1, HotelRules.MAX_ROOMS)
	local hours = Guard.int(rawHours, 1, 8)
	local save = DataService.get(player)
	if room == nil or hours == nil or save == nil or not isOpen(save) or not near(player) then
		return
	end
	local stays = staysOf(save)
	local guest = guests[player]
	local ok, reason =
		HotelRules.canBook(stays, HotelRules.rooms(save.stations), room, hours, guest)
	if not ok or guest == nil then
		NetService.notice(player, reason or "Can't book that room", "warning")
		return
	end
	HotelRules.book(stays, room, hours, guest, os.time())
	guests[player] = nil
	settle(player)
	redraw(player)
	NetService.notice(player, `{CatRules.displayName(guest.kind)} is asleep in room {room}`)
	Telemetry.event(player, "hotel_booked", hours, { guest.rarity })
end

-- The gift for a stay that paid `coins`: what it is, the words for the popup, and the extra coins (bonus or fallback).
local function giveGift(
	player: Player,
	save: any,
	stay: HotelRules.Stay,
	coins: number
): (string, string, number)
	local gift = HotelRules.gift(stay.hours, random:NextNumber())
	if gift == "bow" and LiveFlags.isOn(BowRules.FLAG) then
		local tier = HotelRules.nextBow(BowRules.TIERS, save.bows)
		if tier then
			save.bows[tier] = true
			save.bow = BowRules.best(save.bows) -- the tier in use is always the best one owned
			player:SetAttribute(BowRules.ATTRIBUTE, save.bow)
			return "bow", `a {BowRules.TIER[tier].name} bow`, 0
		end
	elseif gift == "crate" and LiveFlags.isOn(CrateRules.FLAG) then
		if PetService.give(player, HotelRules.GIFT_CRATE, 1) then
			return "crate", "a crate", 0
		end
	end
	local bonus = HotelRules.bonus(coins)
	return "coins", `{bonus} bonus coins`, bonus
end

local function onCollect(player: Player, rawRoom: unknown)
	if not on() then
		return
	end
	local room = if rawRoom == nil then nil else Guard.int(rawRoom, 1, HotelRules.MAX_ROOMS)
	local save = DataService.get(player)
	if (rawRoom ~= nil and room == nil) or save == nil or not isOpen(save) or not near(player) then
		return
	end
	-- every ended stay leaves the save before anything is paid, so a stay pays once
	local out = HotelRules.checkOut(staysOf(save), room, os.time())
	if #out == 0 then
		return
	end
	for _, entry in out do
		local stay = entry.stay
		local coins = HotelRules.pay(stay.hours, stay.rarity)
		local gift, giftText, extra = giveGift(player, save, stay, coins)
		save.coins += coins + extra
		NetService.fire(player, "HotelPaid", entry.room, coins + extra, gift, giftText, stay.kind)
		NetService.notice(
			player,
			`{CatRules.displayName(stay.kind)} checked out: {coins} coins and {giftText}`,
			"info",
			stay.kind
		)
		Telemetry.economy(
			player,
			"coins",
			"source",
			coins + extra,
			save.coins,
			"Gameplay",
			"hotel_stay"
		)
		Telemetry.event(player, "hotel_collected", stay.hours, { stay.rarity, gift })
	end
	WalletService.show(player)
	settle(player)
	redraw(player)
end

function HotelService.Init(_services: { [string]: any }) end

function HotelService.Start()
	NetService.on(HotelRules.BOOK_REMOTE, { perSecond = 1, burst = 2 }, onBook)
	NetService.on(HotelRules.COLLECT_REMOTE, { perSecond = 1, burst = 2 }, onCollect)
	-- the plot drawn again (a build started or ended, the switches, the street): its hotel gets its guests back
	StationService.onDrawn(function(player: Player, folder: Folder)
		settle(player)
		local hotel = folder:FindFirstChild(HotelRules.AREA_NAME)
		if hotel and hotel:IsA("Model") then
			drawGuests(player, hotel :: Model)
		end
		send(player)
	end)
	DataService.onLoaded:Connect(function(player: Player)
		if settle(player) then
			StationService.refresh(player)
		else
			send(player)
		end
	end)
	for _, flag in { HotelRules.FLAG, ExpansionRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				for _, player in Players:GetPlayers() do
					settle(player)
					send(player)
				end
			end)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		guests[player] = nil
		readyShown[player] = nil
	end)
	-- a stay that ended while the player is here: the guest sits up with its coin bubble
	task.spawn(function()
		while true do
			task.wait(READY_CHECK)
			if not on() then
				continue
			end
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local save = DataService.get(player)
				if save == nil or not isOpen(save) then
					continue
				end
				local shown = readyShown[player] or {}
				readyShown[player] = shown
				local fresh = false
				for key, stay in staysOf(save) do
					local mark = `{key}:{stay.endsAt}`
					if now >= stay.endsAt and not shown[mark] then
						shown[mark] = true
						fresh = true
					end
				end
				if fresh then
					redraw(player)
				end
			end
		end
	end)
end

return HotelService
