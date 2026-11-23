--!strict
-- SpaService: one cat's visit per player, server authoritative. It hands out a cat, checks each step the client
-- reports (scrub, brush strokes, bow, photo) against SpaRules and pays the photo coins once, into the save.
-- The client only reports what the player did; it never says how many coins. Behind `scrubPrototype`.
-- Cats live in memory only: a rejoin starts a fresh cat. Coins are saved through DataService.
--
-- Customers (behind `customers` as well): each player has a queue of QUEUE_SIZE customers at the door, each
-- holding a cat rolled from CatRules. The next cat comes from the front of the queue and the queue refills at
-- once, so it is never empty. The photo hands the cat back: the customer pays CatRules.pay (coins plus tip)
-- and stars instead of PHOTO_COINS. The first customer of a save (no stars yet) always brings a common cat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local WindowRules = require(Shared:WaitForChild("WindowRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local IndexService = require(script.Parent:WaitForChild("IndexService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WindowService = require(script.Parent:WaitForChild("WindowService"))

local FLAG = "scrubPrototype"
local CUSTOMERS_FLAG = "customers"
local STRAYS_FLAG = "strays"
local QUEUE_SIZE = 3
local FUNNEL = "onboarding_v1"
local MAX_CAT_ID = 2 ^ 31

local SpaService = {}

local cats: { [Player]: SpaRules.Cat } = {}
local nextId: { [Player]: number } = {}
local lastSeq: { [Player]: number } = {} -- the newest report number each client sent
local queues: { [Player]: { string } } = {} -- customers waiting at the door, front first
local handedOut: { [Player]: number } = {} -- cats handed out this session, for the stray turns
local random = Random.new()

local function rollCustomer(player: Player): string
	local save = DataService.get(player)
	local queue = queues[player]
	-- The first customer of a save is common: no stars yet and nobody queued ahead of them.
	local first = (save == nil or save.stars <= 0) and (queue == nil or #queue == 0)
	return CatRules.roll(function()
		return random:NextNumber()
	end, first)
end

-- The player's door queue, filled to QUEUE_SIZE, so there is always a customer waiting.
local function queueFor(player: Player): { string }
	local queue = queues[player]
	if queue == nil then
		queue = {}
		queues[player] = queue
	end
	local q = queue :: { string }
	while #q < QUEUE_SIZE do
		table.insert(q, rollCustomer(player))
	end
	return q
end

local function newCat(player: Player): SpaRules.Cat
	local id = (nextId[player] or 0) + 1
	nextId[player] = id
	local cat = SpaRules.newCat(id, os.clock())
	local count = handedOut[player] or 0
	handedOut[player] = count + 1
	local save = DataService.get(player)
	if LiveFlags.isOn(STRAYS_FLAG) and save then
		local residents = #WindowService.residents(player)
		local brandNew = save.stars <= 0 and residents == 0
		if WindowRules.isStrayTurn(count, residents, brandNew) then
			-- A stray waits at the back door; a brand new player's first one is common.
			cat.kind = CatRules.roll(function()
				return random:NextNumber()
			end, brandNew)
			cat.stray = true
			cats[player] = cat
			return cat
		end
	end
	if LiveFlags.isOn(CUSTOMERS_FLAG) then
		-- The front customer hands over their cat; queueFor refills the line when it is next read.
		cat.kind = table.remove(queueFor(player), 1)
		Telemetry.funnelStep(player, FUNNEL, 6, "first_customer")
	end
	cats[player] = cat
	return cat
end

-- Tells the client a dirty cat is in the tub; for a customer's cat, which cat, its needs and the needs whose
-- station is not built yet.
local function sendCat(player: Player, cat: SpaRules.Cat)
	local kind = cat.kind
	if kind == nil then
		NetService.fire(player, "CatReady", cat.id)
		return
	end
	local save = DataService.get(player)
	local needs = CatRules.needs(kind)
	local locked = CatRules.lockedNeeds(needs, if save then save.stations else {})
	NetService.fire(player, "CatReady", cat.id, kind, needs, locked, cat.stray)
end

local function onRequestCat(player: Player)
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local cat = cats[player]
	-- A dirty cat is resent (the client may have missed it); any other cat is replaced by a fresh dirty one.
	-- Starting over never pays sooner: the photo still waits MIN_VISIT_SECONDS from the new cat's arrival.
	if cat == nil or cat.stage ~= "dirty" then
		cat = newCat(player)
	end
	sendCat(player, cat :: SpaRules.Cat)
	if LiveFlags.isOn(CUSTOMERS_FLAG) then
		NetService.fire(player, "CustomerQueue", table.clone(queueFor(player)))
	end
end

-- Tells the client where the server stands, so a refused step never leaves it stuck ahead of the server.
local function sendStage(player: Player, cat: SpaRules.Cat, seq: number)
	NetService.fire(player, "CatStage", cat.id, seq, cat.stage, cat.strokes, cat.photoTaken)
end

-- Runs `step` on the player's current cat when `rawId` names it and the switch is on, then answers with the
-- stage, echoing the client's report number `rawSeq`. A report for another cat (a stale client) is answered with
-- the current cat's id (0 for none) and changes nothing; the client then asks for a cat through RequestCat, which
-- has its own rate limit. Malformed reports get no answer.
local function withCat(player: Player, rawId: unknown, rawSeq: unknown, step: (SpaRules.Cat) -> ())
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local id = Guard.int(rawId, 1, MAX_CAT_ID)
	local seq = Guard.int(rawSeq, 0, MAX_CAT_ID)
	if id == nil or seq == nil then
		return
	end
	local cat = cats[player]
	if cat == nil or cat.id ~= id then
		NetService.fire(player, "CatStage", if cat then cat.id else 0, seq, "dirty", 0, false)
		return
	end
	lastSeq[player] = seq
	step(cat)
	sendStage(player, cat, seq)
end

local function payPhoto(player: Player, cat: SpaRules.Cat)
	if cats[player] ~= cat or not LiveFlags.isOn(FLAG) then
		return
	end
	local save = DataService.get(player)
	if save == nil then
		-- No save loaded yet: nothing is paid and the client gets the camera back to try again.
		cat.photoTaken = false
		sendStage(player, cat, lastSeq[player] or 0)
		return
	end
	local coins = SpaRules.photo(cat, os.clock())
	if coins <= 0 then
		return
	end
	local kind = cat.kind
	if kind ~= nil then
		IndexService.stamp(player, kind, "washed")
	end
	if kind ~= nil and cat.stray then
		-- A stray has nobody to pay: the photo coins, and it moves into the window when there is room.
		save.coins += coins
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
		local moved = WindowService.addResident(player, kind, cat.bow)
		NetService.notice(
			player,
			if moved then `+{coins} coins. {kind} moved into your window` else `+{coins} coins`
		)
		return
	end
	if kind == nil then
		save.coins += coins
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
		NetService.notice(player, `+{coins} coins`)
		return
	end
	-- A customer's cat goes home: the customer pays coins plus a tip, and the spa earns stars.
	local pay = CatRules.pay(kind)
	coins = pay.coins + pay.tip
	save.coins += coins
	save.stars += pay.stars
	NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
	NetService.notice(
		player,
		`+{coins} coins, +{pay.stars} {if pay.stars == 1 then "star" else "stars"}`
	)
	Telemetry.funnelStep(player, FUNNEL, 7, "first_return")
end

local function onScrubbed(player: Player, rawId: unknown, rawSeq: unknown)
	withCat(player, rawId, rawSeq, function(cat)
		SpaRules.scrubbed(cat)
	end)
end

local function onBrushStroke(player: Player, rawId: unknown, rawSeq: unknown)
	withCat(player, rawId, rawSeq, function(cat)
		SpaRules.brushStroke(cat, os.clock())
	end)
end

local function onPickBow(player: Player, rawId: unknown, rawSeq: unknown, rawBow: unknown)
	local bow = Guard.oneOf(rawBow, SpaRules.BOWS)
	withCat(player, rawId, rawSeq, function(cat)
		if bow then
			SpaRules.pickBow(cat, bow)
		end
	end)
end

local function onPhoto(player: Player, rawId: unknown, rawSeq: unknown)
	withCat(player, rawId, rawSeq, function(cat)
		local wait = SpaRules.askPhoto(cat, os.clock())
		if wait == nil then
			return
		end
		-- An early photo is held, not refused: it pays once the visit is long enough.
		if wait > 0 then
			task.delay(wait, payPhoto, player, cat)
		else
			payPhoto(player, cat)
		end
	end)
end

function SpaService.Init(_services: { [string]: any }) end

function SpaService.Start()
	NetService.on("RequestCat", { perSecond = 1, burst = 2 }, onRequestCat)
	NetService.on("ReportScrubbed", { perSecond = 2 }, onScrubbed)
	NetService.on("ReportBrushStroke", { perSecond = 8 }, onBrushStroke)
	NetService.on("RequestPickBow", { perSecond = 2 }, onPickBow)
	NetService.on("RequestPhoto", { perSecond = 2 }, onPhoto)

	-- Switch turned off: drop every cat, so turning it on again starts clean.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(function()
			if not LiveFlags.isOn(FLAG) then
				table.clear(cats)
			end
		end)
	-- Customers switched on or off: the next cat follows the switch; a queue left over is dropped.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CUSTOMERS_FLAG)
		:Connect(function()
			if not LiveFlags.isOn(CUSTOMERS_FLAG) then
				table.clear(queues)
			end
		end)
	Players.PlayerRemoving:Connect(function(player: Player)
		cats[player] = nil
		nextId[player] = nil
		lastSeq[player] = nil
		queues[player] = nil
		handedOut[player] = nil
	end)
end

return SpaService
