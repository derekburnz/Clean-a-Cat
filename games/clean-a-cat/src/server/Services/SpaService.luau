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
-- With `queuePick` on as well, the player may pick which waiting customer is next (RequestPickCustomer, #201): it
-- only reorders the line, so it can never reroll or skip paying for a cat.
-- With `sudsWash` on, a brand new save's first cat is the opening's kitten (SudsRules, #285): ahead of strays and
-- customers, no bows, a 3 star score that is never added to the save, and nothing paid. His photo names him Suds.
-- With `openingBox` on too, he waits in the box from the opening scene: no cat comes until the player taps the box
-- (RequestOpenBox), which the save remembers, so the scene never plays again once he is out.
-- With `customerCarry` on too (claim #406), a customer's cat stays in its carrier with the front customer until the
-- player takes it (RequestTakeCat) and goes into the tub only when the player puts it there (RequestPlaceCat); the
-- Player attribute CarryRules.ATTRIBUTE says where it is. Until then the client gets no CatReady, so no wash starts.
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BenchSave = require(Shared:WaitForChild("BenchSave"))
local BowRules = require(Shared:WaitForChild("BowRules"))
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local CarryRules = require(Shared:WaitForChild("CarryRules"))
local CatRules = require(Shared:WaitForChild("CatRules"))
local CounterRules = require(Shared:WaitForChild("CounterRules"))
local DirtRules = require(Shared:WaitForChild("DirtRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local HeartRules = require(Shared:WaitForChild("HeartRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local SpecialRules = require(Shared:WaitForChild("SpecialRules"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))
local VisitRules = require(Shared:WaitForChild("VisitRules"))
local WashDraft = require(Shared:WaitForChild("WashDraft"))
local WindowRules = require(Shared:WaitForChild("WindowRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local FigureService = require(script.Parent:WaitForChild("FigureService"))
local IndexService = require(script.Parent:WaitForChild("IndexService"))
local MascotService = require(script.Parent:WaitForChild("MascotService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PassService = require(script.Parent:WaitForChild("PassService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local StationService = require(script.Parent:WaitForChild("StationService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local VisitService = require(script.Parent:WaitForChild("VisitService"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))
local WindowService = require(script.Parent:WaitForChild("WindowService"))

local FLAG = "scrubPrototype"
local CUSTOMERS_FLAG = "customers"
local STRAYS_FLAG = "strays"
local PICK_FLAG = "queuePick"
local RECAP_FLAG = "recapCard"
-- Per cat toasts that repeat what the screen shows (the coin counter, the recap card, the line) are left out (issue 743)
local QUIET_FLAG = "helperPopups"
local QUEUE_SIZE = SpaRules.QUEUE_SIZE
local BOARD_LIT = "ChanceBoardLit" -- Player attribute: true once a customer has been served, so the board shows
local MAX_CAT_ID = 2 ^ 31
local OWNER_WAIT_SECONDS = 3 -- the opening replay's owner check, at most this long after the save loads

local SpaService = {}

-- Fired once for each customer's cat the player washed by hand and was paid for: (player, facts), the facts by quest
-- kind (QuestRules.Facts) for the quest book (QuestService, issue 516).
SpaService.washed = (require(Shared:WaitForChild("Signal")) :: any).new()

local cats: { [Player]: SpaRules.Cat } = {}
local nextId: { [Player]: number } = {}
local lastSeq: { [Player]: number } = {} -- the newest report number each client sent
local queues: { [Player]: { string } } = {} -- customers waiting at the door, front first
-- What each waiting customer brings, in the same order as queues: rolled when the customer joins the line, so the
-- card shows it before the pick, and moved with the customer on a pick.
type Order = {
	needs: { CatRules.Need }, -- what the cat needs (#267)
	dirt: number, -- its dirt level (DirtRules, switch dirtLevels)
	since: number, -- server time the customer's heart bar started full (HeartRules, switch heartBar)
	lasts: number, -- seconds from full to empty, fixed when they join
	early: boolean?, -- picked to go next while their bar was still nearly full (switch queuePick)
	reservedUntil: number?, -- os.clock() until which the player's pick is kept from the workers (worker.reserve)
	special: boolean?, -- a special visitor (SpecialRules, switch specialVisitors): only the player washes their cat
	tutorial: boolean, -- one of a new spa's first customers (HeartRules.TUTORIAL_STARS_CUSTOMERS)
}
local queueOrders: { [Player]: { Order } } = {}
-- (switch benchGrow) os.clock() when the next customer may join a line that is short of its bench size
local refillAt: { [Player]: number } = {}
-- The save's play time when it loaded and the os.clock() then, for the heart bars' first minutes.
local playBase: { [Player]: { play: number, at: number } } = {}
-- Whether the last heart tick was still in the first minutes (no cat leaves), to see the moment they end.
local noLeaveWas: { [Player]: boolean } = {}
local handedOut: { [Player]: number } = {} -- cats handed out this session, for the stray turns
-- Asked for a cat before the save loaded while sudsWash is on: answered once it loads, so a slow load can never hand
-- a brand new player a customer's cat in place of the kitten.
local waiting: { [Player]: boolean } = {}
-- The save-loaded step below has finished for this player (the owner replay is applied), so a parked ask may run.
local loadDone: { [Player]: boolean } = {}
local random = Random.new()
-- Where each player's customer cat is while it is carried in (switch customerCarry): "door" with the front customer,
-- "arms" while carried; nil once it is in the tub, or for a cat that is never carried.
local carrying: { [Player]: CarryRules.Where } = {}
-- Special visitors (switch specialVisitors): when the next is due, in seconds of play, and the cat of one who is due
-- and joins the line at its next free place (the back, as any new customer), so the line never grows past its size.
local visitorDue: { [Player]: number } = {}
local visitorPending: { [Player]: string } = {}
local visitedThisSession: { [Player]: boolean } = {}

local function rollCustomer(player: Player): string
	local save = DataService.get(player)
	local queue = queues[player]
	-- The first customer of a save is common: no stars yet and nobody queued ahead of them.
	local first = (save == nil or save.stars <= 0) and (queue == nil or #queue == 0)
	return CatRules.roll(function()
		return random:NextNumber()
	end, first, if save then CatRules.tierFor(save.stars) else 1)
end

local function nextNumber(): number
	return random:NextNumber()
end

-- A cat's dirt level (DirtRules): rolled by rarity. In a new spa's first line (no serve yet), `place` is the
-- customer's place in it, so the tutorial's first two customers get DirtRules.TUTORIAL's easy levels.
local function rollDirt(player: Player, kind: string, place: number): number
	local save = DataService.get(player)
	local fresh = save == nil or save.stars <= 0
	return DirtRules.roll(kind, nextNumber, if fresh then place else nil)
end

-- A cat's needs: with dirt levels on, its rarity's plus its level's; otherwise its rarity's plus the later needs whose
-- switches are on, by chance (WashDraft, #267).
local function rollNeeds(kind: string, dirt: number): { CatRules.Need }
	if LiveFlags.isOn(DirtRules.FLAG) then
		return DirtRules.needs(kind, dirt)
	end
	return CatRules.rollNeeds(kind, nextNumber, LiveFlags.isOn)
end

-- The orders beside the player's door queue, kept as long as the queue.
local function ordersFor(player: Player): { Order }
	local list = queueOrders[player]
	if list == nil then
		list = {}
		queueOrders[player] = list
	end
	return list :: { Order }
end

-- Seconds this save has been played, this session included (0 before it loads).
local function played(player: Player): number
	local base = playBase[player]
	if base == nil then
		return 0
	end
	return base.play + math.max(0, os.clock() - base.at)
end

-- A new customer's order for a cat of `kind`, joining the line now at `place`.
-- Where the bar of the order last in `orders` ends (server time), or nil for an empty line.
local function lastEnds(orders: { Order }): number?
	local last = orders[#orders]
	return if last and LiveFlags.isOn(HeartRules.SPACING_FLAG) then last.since + last.lasts else nil
end

-- A new customer's order for a cat of `kind`, joining the line now at `place`, behind `orders`. Its bar ends a
-- stagger after the one ahead (HeartRules.spacedSince), so customers who join together do not leave together.
local function newOrder(player: Player, kind: string, place: number, orders: { Order }): Order
	local dirt = rollDirt(player, kind, place)
	local save = DataService.get(player)
	local fresh = save == nil or save.stars <= 0
	local lasts = HeartRules.lasts(kind, played(player))
	return {
		needs = rollNeeds(kind, dirt),
		dirt = dirt,
		since = HeartRules.spacedSince(Workspace:GetServerTimeNow(), lasts, lastEnds(orders)),
		lasts = lasts,
		tutorial = fresh and place <= HeartRules.TUTORIAL_STARS_CUSTOMERS,
	}
end

-- How many customers wait on the player's bench now: QUEUE_SIZE, or with benchGrow once the spa has served its first
-- customer, 3 plus one per built tub (BuildRules.benchSize, issue 515). Until the tutorial ends (2:45 of play), with
-- tutorialBench, 1 and then 2 (SpaRules.tutorialBench), whether or not a customer was served.
local function benchSize(player: Player): number
	local save = DataService.get(player)
	local tutorial = if LiveFlags.isOn(SpaRules.TUTORIAL_BENCH_FLAG) and save
		then SpaRules.tutorialBench(played(player))
		else nil
	if tutorial then
		return tutorial -- bench.tutorialSize: 1, then 2 at 2:00, until the tutorial ends at 2:45
	end
	if not LiveFlags.isOn(SpaRules.BENCH_FLAG) or save == nil or save.stars <= 0 then
		return QUEUE_SIZE
	end
	return BuildRules.benchSize(save.stations, LiveFlags.isOn)
end

-- How many customers may wait now: benchSize less the customer still at the door holding their cat (switch
-- customerCarry), who stands on the first mat. So every waiting customer has a place of their own and is drawn: one
-- past the last mat would wait unseen with their heart bar running down (bug hunt B3, issue 595). The bench's size
-- the player sees (BenchSize) stays benchSize.
local function waitingSize(player: Player): number
	local size = benchSize(player)
	return if carrying[player] == "door" then math.max(size - 1, 0) else size
end

-- (switch benchGrow) Whether a customer may join now: always when the line is empty, else one each
-- bench.refillSeconds (6 less one per built tub) after the line came up short.
local function mayJoin(player: Player, length: number): boolean
	local save = DataService.get(player)
	if not LiveFlags.isOn(SpaRules.BENCH_FLAG) or length == 0 or save == nil or save.stars <= 0 then
		return true
	end
	local at = refillAt[player]
	if at == nil then
		refillAt[player] = os.clock() + BuildRules.refillSeconds(save.stations, LiveFlags.isOn)
		return false
	end
	if os.clock() < at then
		return false
	end
	refillAt[player] = nil
	return true
end

-- The player's door queue, filled to its bench size (benchSize), so there is always a customer waiting. With
-- `keepOnly` it only keeps the orders in step and lets nobody join: a newcomer must always go out with sendQueue, so
-- a caller that does not send (the heart bars, the workers' look at the line) never fills the line unseen (bug hunt
-- B4, issue 595: the line filled in tickHearts, then the bench loop saw it full and never sent it).
local function queueFor(player: Player, keepOnly: boolean?): { string }
	local queue = queues[player]
	if queue == nil then
		queue = {}
		queues[player] = queue
	end
	local q = queue :: { string }
	local o = ordersFor(player)
	-- out of step: roll what is missing, drop what is extra
	while #o < #q do
		table.insert(o, newOrder(player, q[#o + 1], #o + 1, o))
	end
	while #o > #q do
		table.remove(o)
	end
	local size = if keepOnly then 0 else waitingSize(player)
	while #q < size and mayJoin(player, #q) do
		local visitor = visitorPending[player]
		if visitor then
			-- a special visitor walks in: always the dirtiest, with the first one's long bar (SpecialRules)
			visitorPending[player] = nil
			local save = DataService.get(player)
			local first = save ~= nil and save.asks[SpecialRules.FIRST_DONE] ~= true
			local lasts = if first
				then HeartRules.FIRST_SPECIAL_SECONDS
				else HeartRules.SECONDS.Special
			table.insert(q, visitor)
			table.insert(o, {
				needs = rollNeeds(visitor, DirtRules.SPECIAL_LEVEL),
				dirt = DirtRules.SPECIAL_LEVEL,
				since = HeartRules.spacedSince(Workspace:GetServerTimeNow(), lasts, lastEnds(o)),
				lasts = lasts,
				tutorial = false,
				special = true,
			})
			NetService.notice(player, "A special visitor is here! Only you can wash their cat")
			continue
		end
		local kind = rollCustomer(player)
		table.insert(q, kind)
		table.insert(o, newOrder(player, kind, #q, o))
	end
	return q
end

-- The opening replay for timing on a real phone (switch openingReplay): the game's owner only. Their kitten's stage
-- is set back to none as their save loads, and the stars and residents that would make it an old save are ignored,
-- so the box and the kitten come again on every join. Checked as the player joins, while the save loads.
local isOwner: { [Player]: boolean } = {}

local function checkOwner(player: Player)
	LiveFlags.waitForRead()
	if not LiveFlags.isOn(SudsRules.REPLAY_FLAG) then
		return
	end
	if RunService:IsStudio() then
		isOwner[player] = true
		return
	end
	local ok, owner = pcall(function(): boolean
		if game.CreatorType == Enum.CreatorType.Group then
			local info = GroupService:GetGroupInfoAsync(game.CreatorId)
			local owner = if type(info) == "table" then info.Owner else nil
			return type(owner) == "table" and owner.Id == player.UserId
		end
		return player.UserId == game.CreatorId
	end)
	isOwner[player] = ok and owner == true
end

local function replaying(player: Player): boolean
	return isOwner[player] == true
		and LiveFlags.isOn(SudsRules.REPLAY_FLAG)
		and LiveFlags.isOn(SudsRules.FLAG)
end

-- Whether this player's next cat is the opening's kitten (switch sudsWash).
local function sudsNext(player: Player): boolean
	local save = DataService.get(player)
	if save == nil then
		return false
	end
	if replaying(player) and SudsRules.cleanStage(save.suds) < SudsRules.DONE then
		return true
	end
	return SudsRules.isNext(save.suds, save.stars, #WindowService.residents(player), LiveFlags.isOn)
end

-- Whether the kitten is still in the box (switch openingBox): the server hands out no cat until it is opened.
local function inBox(player: Player): boolean
	local save = DataService.get(player)
	if save == nil then
		return false
	end
	if
		replaying(player)
		and LiveFlags.isOn(SudsRules.BOX_FLAG)
		and SudsRules.cleanStage(save.suds) == SudsRules.NONE
	then
		return true
	end
	return SudsRules.waitsForBox(
		save.suds,
		save.stars,
		#WindowService.residents(player),
		LiveFlags.isOn
	)
end

-- Shows the player's client where the carried cat is (nil: not carried, or in the tub).
local function hasAsset(name: string): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets ~= nil and assets:FindFirstChild(name) ~= nil
end

-- Marks what is in the player's arms on their character, so every other player's game can draw it (switch
-- carryShared, Motion-FX): a customer's cat once taken, or Suds from the box opening until he is in the tub.
local function showHeld(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local model: string?, held: string? = nil, nil
	local cat = cats[player]
	if carrying[player] == "arms" and cat and cat.kind then
		model, held = CarryRules.modelName(cat.kind :: string, hasAsset), "sit"
	elseif player:GetAttribute(SudsRules.BOX_ATTRIBUTE) == false then
		local loaf = SudsRules.asset("_Dirty_Loaf", hasAsset)
		if hasAsset(loaf) then
			model, held = loaf, "loaf"
		else
			model, held = SudsRules.asset("_Dirty_Sit", hasAsset), "sit"
		end
	end
	character:SetAttribute(CarryRules.CHARACTER_CAT, model)
	character:SetAttribute(CarryRules.CHARACTER_HELD, held)
end

local function sayCarry(player: Player, kind: string?)
	local where = carrying[player]
	player:SetAttribute(CarryRules.ATTRIBUTE, where)
	player:SetAttribute(CarryRules.KIND_ATTRIBUTE, if where then kind else nil)
	showHeld(player)
end

local function newCat(player: Player): SpaRules.Cat
	local where = carrying[player]
	if where then
		-- a customer still holding a cat that is being replaced hands it over and leaves (Review-QA's nit on #408)
		local old = cats[player]
		if where == "door" and old and old.kind then
			FigureService.served(player, old.kind :: string)
		end
		carrying[player] = nil
		sayCarry(player, nil)
	end
	local id = (nextId[player] or 0) + 1
	nextId[player] = id
	local cat = SpaRules.newCat(id, os.clock())
	if sudsNext(player) then
		-- The kitten comes first and is nobody's: he takes no customer from the line and no stray turn.
		cat.kind = SudsRules.NAME
		cat.mascot = true
		cat.needs = table.clone(SudsRules.NEEDS)
		cats[player] = cat
		return cat
	end
	local count = handedOut[player] or 0
	handedOut[player] = count + 1
	local save = DataService.get(player)
	-- The Pro Brush (switch proBrush, #267) brushes the tangles out in fewer strokes; the save says who owns it.
	local tools: { [string]: boolean } = if save then save.tools else {}
	cat.brushStrokes = ToolRules.brushStrokes(
		SpaRules.BRUSH_STROKES,
		function(toolId: string): boolean
			return tools[toolId] == true
		end,
		LiveFlags.isOn
	)
	if LiveFlags.isOn(STRAYS_FLAG) and save then
		local residents = #WindowService.residents(player)
		local brandNew = save.stars <= 0 and residents == 0
		if WindowRules.isStrayTurn(count, residents, brandNew) then
			-- A stray waits at the back door; a brand new player's first one is common.
			cat.kind = CatRules.roll(function()
				return random:NextNumber()
			end, brandNew, CatRules.tierFor(save.stars))
			cat.stray = true
			cat.dirt = DirtRules.roll(cat.kind :: string, nextNumber, if brandNew then 1 else nil)
			cat.needs = rollNeeds(cat.kind :: string, cat.dirt :: number)
			cats[player] = cat
			return cat
		end
	end
	if LiveFlags.isOn(CUSTOMERS_FLAG) then
		-- The front customer hands over their cat; queueFor refills the line when it is next read.
		local line = queueFor(player)
		cat.kind = table.remove(line, 1)
		local order = table.remove(ordersFor(player), 1)
		if order then
			cat.needs = order.needs
			cat.dirt = order.dirt
			cat.tutorial = order.tutorial
			cat.special = order.special
			-- picked or taken while the heart bar was still nearly full: the early bonus (switch heartBar)
			cat.early = order.early == true
				or HeartRules.early(order.since, order.lasts, Workspace:GetServerTimeNow())
		end
		if CarryRules.carried(cat.kind, cat.stray, cat.mascot, LiveFlags.isOn) then
			-- (switch customerCarry) the customer stays at the front holding their cat until the player takes it
			carrying[player] = "door" -- CarryRules.DOOR
		else
			FigureService.served(player, cat.kind :: string) -- that customer's figure leaves the line
		end
		Telemetry.onboarding(player, "first_customer")
	end
	cats[player] = cat
	return cat
end

-- Tells the client a dirty cat is in the tub; for a customer's cat, which cat, its needs and the needs whose
-- station is not built yet. Last, the brush strokes this cat takes (fewer with the Pro Brush), so the client
-- counts the same strokes as the server.
local function sendCat(player: Player, cat: SpaRules.Cat)
	local kind = cat.kind
	if kind == nil then
		NetService.fire(player, "CatReady", cat.id, nil, nil, nil, nil, cat.brushStrokes)
		return
	end
	if cat.washFrom == nil then
		cat.washFrom = os.clock() -- in the tub: the wash grade's clock starts (HeartRules)
	end
	local save = DataService.get(player)
	local needs = CatRules.liveNeeds(cat.needs or CatRules.needs(kind), LiveFlags.isOn)
	local locked = CatRules.lockedNeeds(needs, if save then save.stations else {}, LiveFlags.isOn)
	-- the dirt level only while its switch is on, so switching it off gives every new cat its full mud again
	local dirt = if LiveFlags.isOn(DirtRules.FLAG) and not cat.mascot then cat.dirt else nil
	NetService.fire(
		player,
		"CatReady",
		cat.id,
		kind,
		needs,
		locked,
		cat.stray,
		cat.brushStrokes,
		dirt
	)
end

-- Sends the door line to the client and the figures (switch customers).
local function sendQueue(player: Player)
	local line = queueFor(player)
	local orders = ordersFor(player)
	local needs: { { CatRules.Need } } = {}
	for place, order in orders do
		needs[place] = CatRules.liveNeeds(order.needs, LiveFlags.isOn)
	end
	local dirtOn = LiveFlags.isOn(DirtRules.FLAG)
	-- a cat still with its customer at the door (switch customerCarry): that customer stays at the front of the line
	local cat = cats[player]
	local kinds, shownNeeds = CarryRules.shownLine(
		line,
		needs,
		carrying[player],
		if cat then cat.kind else nil,
		if cat and cat.kind
			then CatRules.liveNeeds(cat.needs or CatRules.needs(cat.kind), LiveFlags.isOn)
			else nil
	)
	-- each card's dirt level (switch dirtLevels), with the customer still at the door in front as in kinds
	local shownDirt: { number }? = nil
	if dirtOn then
		local list: { number } = {}
		for place, order in orders do
			list[place] = order.dirt
		end
		if #kinds > #line then
			table.insert(list, 1, if cat and cat.dirt then cat.dirt else 1)
		end
		shownDirt = list
	end
	-- each card's heart bar (switch heartBar): { since, lasts, stops, paused } with since the server time it started
	-- full, lasts its seconds, stops 1 while it never empties (the first minutes of play) and paused 1 while it does
	-- not drain at all (before the first serve); the customer still at the door, whose cat is taken, shows full
	local shownHearts: { { number } }? = nil
	if LiveFlags.isOn(HeartRules.FLAG) then
		local list: { { number } } = {}
		local stops = if played(player) < HeartRules.NO_LEAVE_BEFORE then 1 else 0
		local save = DataService.get(player)
		local paused = if save == nil or save.stars <= 0 then 1 else 0
		for place, order in orders do
			list[place] = { order.since, order.lasts, stops, paused }
		end
		if #kinds > #line then
			table.insert(list, 1, { 0, 0, 1, 1 })
		end
		shownHearts = list
	end
	NetService.fire(player, "CustomerQueue", kinds, shownNeeds, shownDirt, shownHearts)
	FigureService.showQueue(player, table.clone(kinds))
	-- (switch benchSave, issue 523) who waits goes into the save each time the line is sent, for the next join
	local save = DataService.get(player)
	if save and LiveFlags.isOn(BenchSave.FLAG) then
		save.bench = BenchSave.snapshot(line, orders :: any) :: any
	end
end

-- (switch benchSave, issue 523) A spa that has served before gets its saved line back on join, each customer with a
-- full heart bar, at most as many as its bench holds now. Before the line is first read, so nobody is rolled first.
local function restoreBench(player: Player, save: SaveSchema.Save)
	if not LiveFlags.isOn(BenchSave.FLAG) or save.stars <= 0 or queues[player] ~= nil then
		return
	end
	local saved = BenchSave.restore(save.bench)
	local size = benchSize(player)
	local line: { string } = {}
	local orders: { Order } = {}
	local now = Workspace:GetServerTimeNow()
	for _, entry in saved do
		if #line >= size then
			break
		end
		local lasts = HeartRules.lasts(entry.kind, played(player))
		table.insert(line, entry.kind)
		table.insert(orders, {
			needs = entry.needs,
			dirt = entry.dirt,
			since = HeartRules.spacedSince(now, lasts, lastEnds(orders)),
			lasts = lasts,
			tutorial = false,
		})
	end
	if #line > 0 then
		queues[player] = line
		queueOrders[player] = orders
	end
end

-- A brand new save's kitten waits in the box (switch openingBox): the client plays the scene while SudsBox is true.
-- The first time, the player stands at their entrance facing the street, where the box lands (Model-Agent). True
-- when the kitten is held for the box.
local function holdForBox(player: Player): boolean
	if not LiveFlags.isOn(FLAG) or cats[player] ~= nil or not inBox(player) then
		return false
	end
	if player:GetAttribute(SudsRules.BOX_ATTRIBUTE) ~= true then
		PlotService.standOn(player, SudsRules.OPENING_SPOT)
	end
	player:SetAttribute(SudsRules.BOX_ATTRIBUTE, true)
	return true
end

local function onRequestCat(player: Player)
	-- A new server's first player can ask before the switches are read, when every switch still reads off; the ask
	-- waits for the read, so the opening is never skipped for them (2026-11-24).
	if not LiveFlags.read() then
		waiting[player] = true
		return
	end
	if not LiveFlags.isOn(FLAG) then
		return
	end
	if LiveFlags.isOn(SudsRules.FLAG) and DataService.get(player) == nil then
		waiting[player] = true
		return
	end
	local cat = cats[player]
	if cat == nil and holdForBox(player) then
		return -- the opening: the kitten is in the box in front of the player
	end
	-- A dirty cat is resent (the client may have missed it). A done cat is replaced by a fresh dirty one. An
	-- unfinished cat is replaced only after a whole visit's time; sooner, it goes back to dirty and is resent,
	-- so asking again never rerolls a cheap cat into a rare one (issue #164).
	if cat == nil then
		cat = newCat(player)
	elseif cat.stage ~= "dirty" then
		if not SpaRules.canReplace(cat, os.clock()) then
			SpaRules.restart(cat)
		else
			local named = cat.mascot and cat.stage == "done"
			cat = newCat(player)
			if named then
				-- His wash is over and the tub has the next cat: Suds goes home to his bed (switch sudsMascot).
				MascotService.refresh(player)
				if LiveFlags.isOn("onboardingFunnel") and LiveFlags.isOn(SudsRules.MASCOT_FLAG) then
					Telemetry.event(player, "suds_home")
				end
			end
		end
	end
	if carrying[player] then
		sayCarry(player, cat.kind) -- still at the door or in the player's arms: no wash until it is in the tub
	else
		sendCat(player, cat :: SpaRules.Cat)
	end
	if LiveFlags.isOn(CUSTOMERS_FLAG) then
		sendQueue(player)
	end
end

-- The kitten's first cat for a player whose box just opened or whose wait ended: sent unless a cat is already out.
local function handOut(player: Player)
	player:SetAttribute(SudsRules.BOX_ATTRIBUTE, nil)
	PlotService.release(player)
	if player.Parent ~= Players or cats[player] ~= nil or not LiveFlags.isOn(FLAG) then
		return
	end
	sendCat(player, newCat(player))
	if LiveFlags.isOn(CUSTOMERS_FLAG) then
		sendQueue(player)
	end
end

-- The player tapped the box (switch openingBox): the save remembers it. The kitten peeks out, the player picks him
-- up and carries him to the tub (RequestPlaceKitten); he goes there by himself after CARRY_SECONDS if that never
-- comes.
local function onOpenBox(player: Player)
	if not LiveFlags.isOn(FLAG) or cats[player] ~= nil or not inBox(player) then
		return
	end
	local save = DataService.get(player)
	if save == nil then
		return
	end
	save.suds = SudsRules.BOX
	player:SetAttribute(SudsRules.ATTRIBUTE, save.suds)
	player:SetAttribute(SudsRules.BOX_ATTRIBUTE, false)
	PlotService.release(player)
	if LiveFlags.isOn("onboardingFunnel") then
		Telemetry.event(player, "box_opened")
	end
	task.delay(SudsRules.CARRY_SECONDS, function()
		if player:GetAttribute(SudsRules.BOX_ATTRIBUTE) == false then
			handOut(player)
		end
	end)
end

-- The player set the kitten down in the tub: he is handed out there. Only while this session's box is open and not
-- yet handed out (SudsBox false), with no cat out, and with the player standing by their own tub.
local function onPlaceKitten(player: Player)
	if
		not LiveFlags.isOn(FLAG)
		or cats[player] ~= nil
		or player:GetAttribute(SudsRules.BOX_ATTRIBUTE) ~= false
	then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local offset = (root :: BasePart).Position - SpaLayout.tubSpot(player).Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > SudsRules.PLACE_REACH then
		return
	end
	handOut(player)
end

-- Whether the player's character stands within `reach` studs (along the ground) of `spot`.
local function standsNear(player: Player, spot: Vector3, reach: number): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil
		and root:IsA("BasePart")
		and CarryRules.within((root :: BasePart).Position, spot, reach)
end

-- (switch counterLine, issue 746) The player takes the cat at counter place `place` (2 or more) while the front
-- customer holds `cat` at the door: that customer's cat goes back on the counter at the front of the line, with a
-- full heart bar, and the cat at `place` is the one handed over, with its order, as a pick would (#201). True when
-- it was taken.
local function takeFromCounter(player: Player, cat: SpaRules.Cat, place: number): boolean
	local save = DataService.get(player)
	-- a new spa's first customer is the guaranteed common cat: as with picks, the counter opens once one is served
	if save == nil or save.stars <= 0 or cat.kind == nil then
		return false
	end
	local line = queueFor(player, true)
	local orders = ordersFor(player)
	local entry = CounterRules.entryFor(place, true, #line)
	if entry == nil or entry < 1 then
		return false
	end
	local kind = cat.kind :: string
	local now = Workspace:GetServerTimeNow()
	local back: Order = {
		needs = (cat.needs or CatRules.needs(kind)) :: any,
		dirt = cat.dirt or 1,
		since = now, -- their bar was held full at the door
		lasts = HeartRules.lasts(kind, played(player)),
		tutorial = cat.tutorial == true,
		special = cat.special,
		-- the player put them back: workers leave them for a moment, as for a pick (tuning worker.reserve)
		reservedUntil = os.clock() + WorkerRules.RESERVE_SECONDS,
	}
	local taken, order = CounterRules.swapIn(line, orders, entry, { kind = kind, order = back })
	if taken == nil or order == nil then
		return false
	end
	cat.kind = taken
	cat.needs = order.needs :: any
	cat.dirt = order.dirt
	cat.tutorial = order.tutorial
	cat.special = order.special
	cat.early = order.early == true or HeartRules.early(order.since, order.lasts, now)
	-- the figures follow: the one taken goes first (with their look), so served takes them and not the one put back
	FigureService.picked(player, place)
	return true
end

-- The player takes a cat (switch customerCarry): it is in their arms, and that customer leaves the line. Only while
-- the next cat is at the door and the player stands by it: the front of the line, or with counterLine on the cat at
-- counter place `rawPlace` (1, the front, when nil), which may be any place in the line as shown (issue 746).
local function onTakeCat(player: Player, rawPlace: unknown)
	local cat = cats[player]
	if
		not (LiveFlags.isOn(FLAG) and LiveFlags.isOn(CarryRules.FLAG))
		or carrying[player] ~= CarryRules.DOOR
		or cat == nil
		or cat.kind == nil
	then
		return
	end
	local counter = LiveFlags.isOn(CounterRules.FLAG)
	local place = if rawPlace == nil then 1 else Guard.int(rawPlace, 1, SpaRules.MAX_QUEUE + 1)
	if place == nil or (place > 1 and not counter) then
		return
	end
	local slot = SpaLayout.slotOf(player)
	local spot = if counter
			and slot
			and SpaLayout.onPlot(player)
		then FigureService.counterCatSpot(place, slot).Position
		else SpaLayout.lineSpot("SpotQueue", place, player).Position
	if not standsNear(player, spot, CarryRules.TAKE_REACH) then
		return
	end
	if place > 1 and not takeFromCounter(player, cat, place) then
		return
	end
	carrying[player] = "arms" -- CarryRules.ARMS
	FigureService.served(player, cat.kind :: string)
	sayCarry(player, cat.kind)
	sendQueue(player)
end

-- The player puts the carried cat in the tub (switch customerCarry): the wash starts (CatReady). Only while it is in
-- their arms and they stand by their own tub.
local function onPlaceCat(player: Player)
	local cat = cats[player]
	if
		not (LiveFlags.isOn(FLAG) and LiveFlags.isOn(CarryRules.FLAG))
		or carrying[player] ~= CarryRules.ARMS
		or cat == nil
		or not standsNear(player, SpaLayout.tubSpot(player).Position, CarryRules.PLACE_REACH)
	then
		return
	end
	carrying[player] = nil
	sayCarry(player, nil)
	sendCat(player, cat)
end

-- The carry switched off while a cat is out of the tub: it goes straight into the tub, as before the switch, and a
-- customer still holding it leaves the line.
local function dropCarry(player: Player)
	local where = carrying[player]
	local cat = cats[player]
	if where == nil then
		return
	end
	carrying[player] = nil
	sayCarry(player, nil)
	if cat == nil then
		return
	end
	if where == CarryRules.DOOR and cat.kind then
		FigureService.served(player, cat.kind :: string)
	end
	sendCat(player, cat)
	if LiveFlags.isOn(CUSTOMERS_FLAG) then
		sendQueue(player)
	end
end

-- The player picks a waiting customer to be washed next: it moves to the front of the line (#201).
local function onPickCustomer(player: Player, rawIndex: unknown)
	if
		not (LiveFlags.isOn(FLAG) and LiveFlags.isOn(CUSTOMERS_FLAG) and LiveFlags.isOn(PICK_FLAG))
	then
		return
	end
	local index = Guard.int(rawIndex, 2, SpaRules.MAX_QUEUE) -- SpaRules.pickNext refuses a place past the line
	-- No pick while a customer still holds the cat at the door (switch customerCarry): the line the player sees then
	-- has that customer in front of the server's line, so the places would not match.
	if index == nil or queues[player] == nil or carrying[player] == CarryRules.DOOR then
		return
	end
	-- A new save's first customer is the guaranteed common cat; picking past it would skip that. Picks open once a
	-- customer has been served (stars > 0), the same moment the chance board lights.
	local save = DataService.get(player)
	if save == nil or save.stars <= 0 then
		return
	end
	local line = queueFor(player)
	local picked = ordersFor(player)[index]
	if picked and HeartRules.early(picked.since, picked.lasts, Workspace:GetServerTimeNow()) then
		picked.early = true -- the pick is what counts, not when the wash before it ends
	end
	if picked then
		-- the player's pick is theirs: workers leave it for WorkerRules.RESERVE_SECONDS (tuning worker.reserve)
		picked.reservedUntil = os.clock() + WorkerRules.RESERVE_SECONDS
	end
	if SpaRules.pickNext(line, index) then
		SpaRules.pickNext(ordersFor(player), index) -- the cat's order moves with it
		FigureService.picked(player, index) -- the customer's look goes to the front with their cat (#206)
		sendQueue(player)
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
	Telemetry.onboarding(player, "first_photo")
	if cat.mascot then
		-- The kitten's naming: he is Suds from now on. Nothing is paid, stamped or added to the spa's stars.
		save.suds = SudsRules.DONE
		player:SetAttribute(SudsRules.ATTRIBUTE, save.suds)
		if LiveFlags.isOn(RECAP_FLAG) then
			local recap = RecapRules.mascot(SudsRules.NAME, SudsRules.STARS)
			NetService.fire(player, "PhotoPaid", cat.id, 0, save.coins, recap)
		else
			NetService.fire(player, "PhotoPaid", cat.id, 0, save.coins)
			NetService.notice(player, `You washed {SudsRules.NAME}!`)
		end
		return
	end
	local kind = cat.kind
	local isNew = false
	if kind ~= nil then
		isNew = IndexService.stamp(player, kind, "washed")
		if isNew and cat.special and save.stations[SpaLayout.VIP_ID] then
			StationService.refresh(player) -- a new resident for the VIP Room (issue 515)
		end
	end
	if kind ~= nil and cat.stray then
		-- A stray has nobody to pay: the photo coins, and it moves into the window when there is room.
		save.coins += coins
		WalletService.show(player)
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
		local moved = WindowService.addResident(player, kind, cat.bow)
		if not LiveFlags.isOn(QUIET_FLAG) then
			NetService.notice(
				player,
				if moved then `+{coins} coins. {kind} moved into your window` else `+{coins} coins`
			)
		elseif moved then
			NetService.notice(player, `{kind} moved into your window`) -- a one-off: the window has a new cat
		end
		return
	end
	if kind == nil then
		save.coins += coins
		WalletService.show(player)
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
		if not LiveFlags.isOn(QUIET_FLAG) then
			NetService.notice(player, `+{coins} coins`)
		end
		return
	end
	-- A customer's cat goes home: the customer pays coins plus a tip, and the spa earns stars.
	local pay = CatRules.pay(kind)
	local extra: RecapRules.Extra? = nil
	local dirtOn = LiveFlags.isOn(DirtRules.FLAG)
	if LiveFlags.isOn(HeartRules.FLAG) then
		-- The pay formula (issue 507): base x wash grade x early pick x dirt, one recap line for each.
		local needs = CatRules.liveNeeds(cat.needs or CatRules.needs(kind), LiveFlags.isOn)
		local seconds = cat.washSeconds or (os.clock() - (cat.washFrom or os.clock()))
		local handSteps = DirtRules.steps(needs) - 1 -- the bow is not timed
		local formula = HeartRules.pay(kind, {
			grade = if cat.tutorial then 3 else HeartRules.grade(seconds, handSteps),
			early = cat.early == true,
			dirt = if dirtOn then cat.dirt else nil,
		})
		-- a slow wash pays less, but the card never shows a minus line: that part comes off the wash's own line
		local base = formula.base + math.min(formula.speed, 0)
		pay = { coins = base, tip = formula.tip, stars = formula.stars }
		local lines: RecapRules.Extra = {
			speed = math.max(formula.speed, 0),
			early = formula.early,
			dirt = formula.dirt,
			grade = formula.grade,
		}
		extra = lines
	elseif dirtOn then
		pay = DirtRules.pay(pay, cat.dirt) -- a dirtier cat pays more
	end
	-- Built stations (a Brush Table, a dryer) make every customer pay a little more; only while builds are on.
	-- Each built tub adds TUB_HAND_BONUS to a cat washed by hand (switch tubBuilds); this is the hand path only.
	local bonus = if LiveFlags.isOn("builds")
		then BuildRules.payBonus(save.stations, LiveFlags.isOn) + BuildRules.handBonus(
			save.stations,
			LiveFlags.isOn
		)
		else 0
	-- The bow tied by hand pays on top (switch bowTiers, tuning "then + bow + tip"); a worker's cat never comes here.
	if LiveFlags.isOn(BowRules.FLAG) and cat.bow ~= nil then
		local lines: RecapRules.Extra = extra or {}
		local tier = BowRules.best(save.bows)
		lines.bow = BowRules.bonus(tier)
		lines.bowTier = tier
		extra = lines
	end
	-- A special visitor's cat may leave a crate (switch specialVisitors): always the first of a save, then rarely.
	if cat.special and LiveFlags.isOn(SpecialRules.FLAG) then
		local firstDone = save.asks[SpecialRules.FIRST_DONE] == true
		save.asks[SpecialRules.FIRST_DONE] = true
		if SpecialRules.dropsCrate(firstDone, nextNumber) then
			local kind = SpecialRules.CRATE_KIND
			save.crates[kind] = (save.crates[kind] or 0) + 1
			player:SetAttribute(SpecialRules.CRATES_ATTRIBUTE, save.crates[kind])
			PetService.show(player)
			NetService.notice(player, `{cat.kind} left you a crate!`)
		end
	end
	-- The player's own pet adds to their tips (switch pets, tuning pet.boost)
	local tipBoost = PetService.playerBoost(player)
	if tipBoost > 0 then
		pay = {
			coins = pay.coins,
			tip = math.floor(pay.tip * (1 + tipBoost) + 0.5),
			stars = pay.stars,
		}
	end
	local more: RecapRules.Extra = extra or {}
	coins = pay.coins
		+ (more.speed or 0)
		+ (more.early or 0)
		+ (more.dirt or 0)
		+ (more.bow or 0)
		+ pay.tip
		+ bonus
	-- Friends in the server (switch friendBonus, issue 520; tuning pay.friend): on the hand wash's total, its own line
	local friendExtra = VisitRules.friendExtra(coins, VisitService.friends(player))
	if friendExtra > 0 then
		more.friends = friendExtra
		extra = more
		coins += friendExtra
	end
	-- 2x Coins and the Golden Sponge (switch passes, issue 518): on top of this hand wash's whole pay, its own line
	local function owns(key: string): boolean
		return PassService.owns(player, key)
	end
	local passExtra = Passes.handExtra(coins, owns)
	if passExtra > 0 then
		more.pass = passExtra
		more.passLine = Passes.handLine(owns)
		extra = more
		coins += passExtra
	end
	save.coins += coins
	WalletService.show(player)
	local dirt = if dirtOn then cat.dirt else nil
	SpaService.washed:Fire(player, {
		wash = 1,
		bow = if LiveFlags.isOn(BowRules.FLAG) and cat.bow ~= nil then 1 else 0,
		dirty = if dirt and dirt >= 3 then 1 else 0,
		dirt4 = if dirt == 4 then 1 else 0,
		threeStars = if more.grade == 3 then 1 else 0,
		early = if cat.early == true then 1 else 0,
		special = if cat.special then 1 else 0,
	})
	local starsBefore = save.stars
	save.stars += pay.stars
	player:SetAttribute(BOARD_LIT, true)
	player:SetAttribute(CatRules.TIER_ATTRIBUTE, CatRules.tierFor(save.stars))
	if LiveFlags.isOn(RECAP_FLAG) then
		-- The recap card shows the payment line by line (#224), so it replaces the toast.
		local recap = RecapRules.make(kind, pay, bonus, starsBefore, isNew, extra)
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins, recap)
	else
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
		if not LiveFlags.isOn(QUIET_FLAG) then
			NetService.notice(
				player,
				`+{coins} coins, +{pay.stars} {if pay.stars == 1 then "star" else "stars"}`
			)
		end
	end
end

local function onScrubbed(player: Player, rawId: unknown, rawSeq: unknown)
	withCat(player, rawId, rawSeq, function(cat)
		if SpaRules.scrubbed(cat) then
			Telemetry.onboarding(player, "first_reveal")
		end
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
		if bow and SpaRules.pickBow(cat, bow) and cat.washFrom then
			-- the bow ends the hand steps: the wash grade counts from the tub to here (tuning pay.starTimes)
			cat.washSeconds = os.clock() - (cat.washFrom :: number)
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

-- The customer at `place` of the server's line leaves with their cat (switch heartBar): their bar ran out. That job is
-- lost and nothing else is taken; the line refills at once. The client hears it first (CustomerLeft, at the place as
-- shown, before the figures are redrawn) so the leaving customer can still be found for the moment and sound.
local function customerLeaves(player: Player, place: number)
	local line = queues[player]
	local kind = if line then line[place] else nil
	if line == nil or kind == nil then
		return
	end
	local shownPlace = place + (if carrying[player] == CarryRules.DOOR then 1 else 0)
	-- In place (lineReuse), the device hears it after the redraw, so it gets the newcomer and the leave in the same
	-- frame and the line never counts one short (issue 571); the leaver's figure lingers to be found. Otherwise first.
	local after = FigureService.inPlace()
	if not after then
		NetService.fire(player, "CustomerLeft", shownPlace, kind)
	end
	table.remove(line, place)
	table.remove(ordersFor(player), place)
	FigureService.left(player, shownPlace, after)
	sendQueue(player)
	if after then
		NetService.fire(player, "CustomerLeft", shownPlace, kind)
	end
	if not LiveFlags.isOn(QUIET_FLAG) then
		NetService.notice(player, `{kind} went home`)
	end
end

-- Once a second (switch heartBar): bars drain, a customer whose bar is empty leaves (one a second at most), and each
-- figure gets its bar as HeartFill. Nothing drains before the spa's first serve, which is the tutorial.
local function tickHearts()
	local now = Workspace:GetServerTimeNow()
	for player in queues do
		local save = DataService.get(player)
		if save == nil or player.Parent ~= Players then
			continue
		end
		queueFor(player, true) -- keeps the orders in step with the line
		local orders = ordersFor(player)
		local playTime = played(player)
		local paused = save.stars <= 0
		local noLeave = playTime < HeartRules.NO_LEAVE_BEFORE
		local minutesEnded = noLeaveWas[player] == true and not noLeave
		noLeaveWas[player] = noLeave
		if minutesEnded then
			-- the cats on the sliver get a grumpy bar's worth back, and the cards learn their bars empty now
			for place, order in orders do
				order.since = HeartRules.graceSince(order.since, order.lasts, now, place)
			end
			sendQueue(player)
		end
		local leaving: number? = nil
		local aheadEnds: number? = nil
		for place, order in orders do
			if paused then
				-- held full until the first serve, each a stagger after the one ahead for when they start
				order.since = HeartRules.spacedSince(now, order.lasts, aheadEnds)
				aheadEnds = if LiveFlags.isOn(HeartRules.SPACING_FLAG)
					then order.since + order.lasts
					else nil
			elseif leaving == nil and HeartRules.gone(order.since, order.lasts, now, playTime) then
				leaving = place
			end
		end
		if leaving then
			customerLeaves(player, leaving)
		end
		local offset = if carrying[player] == CarryRules.DOOR then 1 else 0
		local fills: { number } = {}
		if offset == 1 then
			fills[1] = 1
		end
		for place, order in ordersFor(player) do
			local fill = HeartRules.shown(order.since, order.lasts, now, playTime)
			fills[place + offset] = math.floor(fill * 50 + 0.5) / 50 -- steps of 2 percent, so not every tick replicates
		end
		FigureService.setHearts(player, fills)
	end
end

-- Whether the player's spa has a special visitor now: waiting, due to walk in, or their cat with the player.
local function hasVisitor(player: Player): boolean
	if visitorPending[player] ~= nil then
		return true
	end
	local cat = cats[player]
	if cat and cat.special and not cat.photoTaken then
		return true
	end
	for _, order in ordersFor(player) do
		if order.special then
			return true
		end
	end
	return false
end

-- Once a second (switch specialVisitors): a visitor is due after a while of play, one per spa at a time. The first of
-- a save comes at about 4:00; the rest 8 to 15 minutes of play after the last one left or was washed.
local function tickVisitors()
	for player in queues do
		local save = DataService.get(player)
		local base = playBase[player]
		if save == nil or base == nil or player.Parent ~= Players or save.stars <= 0 then
			continue -- not before the first serve: the tutorial's line is the player's own
		end
		if hasVisitor(player) then
			visitorDue[player] = nil
			continue
		end
		local now = played(player)
		local due = visitorDue[player]
		if due == nil then
			local scripted = save.asks[SpecialRules.FIRST_DONE] ~= true
				and not visitedThisSession[player]
			due = SpecialRules.dueAt(
				now,
				base.play,
				not scripted,
				nextNumber,
				BuildRules.hasVip(save.stations, LiveFlags.isOn)
			)
			visitorDue[player] = due
		end
		if now >= (due :: number) then
			visitorDue[player] = nil
			visitedThisSession[player] = true
			visitorPending[player] = SpecialRules.pickCat(nextNumber) -- walks in at the next free place
		end
	end
end

-- The waiting line as the player's workers see it (WorkerService, switch workers), front first: what each cat is, how
-- dirty, and how much of its heart bar is left. Empty before the spa's first serve (the tutorial's line is the
-- player's own) and before the save loads.
function SpaService.lineForWorkers(player: Player): { WorkerRules.Entry }
	local save = DataService.get(player)
	local line = queues[player]
	if save == nil or save.stars <= 0 or line == nil then
		return {}
	end
	queueFor(player, true) -- keeps the orders in step with the line
	local now = Workspace:GetServerTimeNow()
	local out: { WorkerRules.Entry } = {}
	for place, order in ordersFor(player) do
		local kind = line[place]
		if kind == nil then
			break
		end
		local left = if LiveFlags.isOn(HeartRules.FLAG)
			then HeartRules.left(order.since, order.lasts, now)
			else 1
		-- the player's pick for a while, and a special visitor always, are the player's own
		local reserved = order.special == true
			or (order.reservedUntil ~= nil and os.clock() < (order.reservedUntil :: number))
		table.insert(out, { kind = kind, dirt = order.dirt, left = left, reserved = reserved })
	end
	return out
end

-- A worker takes the customer at `place` of the line (as lineForWorkers gave it): they leave the line with their cat,
-- which goes to the worker's station, and the line refills. Returns the cat's kind and dirt level, or nil when there
-- is nobody at that place any more.
function SpaService.takeForWorker(player: Player, place: number, kind: string): (string?, number?)
	local line = queues[player]
	if line == nil or line[place] ~= kind then
		return nil, nil
	end
	local order = ordersFor(player)[place]
	local dirt = if order then order.dirt else 1
	local shownPlace = place + (if carrying[player] == CarryRules.DOOR then 1 else 0)
	table.remove(line, place)
	table.remove(ordersFor(player), place)
	FigureService.left(player, shownPlace)
	sendQueue(player)
	return kind, dirt
end

function SpaService.Init(_services: { [string]: any }) end

function SpaService.Start()
	MascotService.whileInTub(function(player: Player): boolean
		local cat = cats[player]
		return cat ~= nil and cat.mascot == true
	end)
	NetService.on("RequestCat", { perSecond = 1, burst = 2 }, onRequestCat)
	task.spawn(function()
		while true do
			task.wait(1)
			if
				LiveFlags.isOn(HeartRules.FLAG)
				and LiveFlags.isOn(FLAG)
				and LiveFlags.isOn(CUSTOMERS_FLAG)
			then
				local ok, err = pcall(function()
					tickHearts()
					return nil :: any
				end)
				if not ok then
					warn("SpaService: heart bars:", err)
				end
			end
			if
				(
					LiveFlags.isOn(SpaRules.BENCH_FLAG)
					or LiveFlags.isOn(SpaRules.TUTORIAL_BENCH_FLAG)
				)
				and LiveFlags.isOn(FLAG)
				and LiveFlags.isOn(CUSTOMERS_FLAG)
			then
				-- a short line takes its next customer when the refill time is up (switch benchGrow), and the
				-- tutorial's line grows to 2 at 2:00 (switch tutorialBench)
				local ok, err = pcall(function()
					for player, line in queues do
						if player.Parent ~= Players then
							continue
						end
						local before = #line
						local size = benchSize(player)
						if player:GetAttribute(SpaRules.BENCH_ATTRIBUTE) ~= size then
							player:SetAttribute(SpaRules.BENCH_ATTRIBUTE, size)
						end
						if before < waitingSize(player) and #queueFor(player) ~= before then
							sendQueue(player)
						end
					end
					return nil :: any
				end)
				if not ok then
					warn("SpaService: bench:", err)
				end
			end
			if
				LiveFlags.isOn(SpecialRules.FLAG)
				and LiveFlags.isOn(FLAG)
				and LiveFlags.isOn(CUSTOMERS_FLAG)
			then
				local ok, err = pcall(function()
					tickVisitors()
					return nil :: any
				end)
				if not ok then
					warn("SpaService: special visitors:", err)
				end
			end
		end
	end)
	-- When the server saw the join, so the client can print how long the opening took to start (OpeningController).
	local function stampJoin(player: Player)
		if player:GetAttribute(SudsRules.JOINED_ATTRIBUTE) == nil then
			player:SetAttribute(SudsRules.JOINED_ATTRIBUTE, Workspace:GetServerTimeNow())
		end
		task.spawn(checkOwner, player)
		-- what is in their arms, for everyone else (showHeld): Suds while the box is open, and on a new character
		player:GetAttributeChangedSignal(SudsRules.BOX_ATTRIBUTE):Connect(function()
			showHeld(player)
		end)
		player.CharacterAdded:Connect(function()
			showHeld(player)
		end)
	end
	Players.PlayerAdded:Connect(stampJoin)
	for _, player in Players:GetPlayers() do
		stampJoin(player)
	end
	-- The chance board lights up from the second customer: once a save has stars, a customer was served.
	DataService.onLoaded:Connect(function(player: Player, save)
		playBase[player] = { play = save.playSeconds, at = os.clock() }
		restoreBench(player, save)
		if save.stars > 0 then
			player:SetAttribute(BOARD_LIT, true)
		end
		-- The board shows the chances of the player's star tier, the same table their rolls use.
		player:SetAttribute(CatRules.TIER_ATTRIBUTE, CatRules.tierFor(save.stars))
		-- crates held, for the crates' HUD (issue 511); set here as special visitors are the first to give one
		player:SetAttribute(
			SpecialRules.CRATES_ATTRIBUTE,
			save.crates[SpecialRules.CRATE_KIND] or 0
		)
		-- Whether the opening plays is decided once, here, so it waits for the server's first read of the switches
		-- (a fraction of a second; at most LiveFlags.READ_WAIT_SECONDS).
		LiveFlags.waitForRead()
		if player.Parent ~= Players then
			return
		end
		-- The owner's opening replay (switch openingReplay): their kitten starts over. The owner check started as they
		-- joined and is usually done; wait a moment for it if not.
		if LiveFlags.isOn(SudsRules.REPLAY_FLAG) then
			local deadline = os.clock() + OWNER_WAIT_SECONDS
			while isOwner[player] == nil and os.clock() < deadline and player.Parent == Players do
				task.wait()
			end
			if replaying(player) then
				save.suds = SudsRules.NONE
			end
		end
		-- How far the opening's kitten got, for the client's opening and Suds (#285).
		player:SetAttribute(SudsRules.ATTRIBUTE, SudsRules.cleanStage(save.suds))
		-- A new save's box is marked the moment the save loads, not when the client first asks for a cat, so the
		-- truck can start as soon as the player's game shows the world, and the first spawn is already on the
		-- opening spot (Derek: hook them instantly). The save starts loading as the player joins, so it is usually
		-- ready before their game has finished loading.
		holdForBox(player)
		loadDone[player] = true
		if waiting[player] then
			waiting[player] = nil
			onRequestCat(player)
		end
	end)
	-- Asks that came before the first read of the switches (onRequestCat), for saves that are already loaded.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.READ_ATTRIBUTE):Connect(function()
		if not LiveFlags.read() then
			return
		end
		-- Only once the save-loaded step is done: before it, the owner replay is not applied yet, and answering the ask
		-- would hand the owner a normal cat (Review-QA on #322). That step answers its own parked ask at its end.
		for player in table.clone(waiting) do
			if loadDone[player] then
				waiting[player] = nil
				onRequestCat(player)
			end
		end
	end)
	NetService.on("ReportScrubbed", { perSecond = 2 }, onScrubbed)
	NetService.on("ReportBrushStroke", { perSecond = 8 }, onBrushStroke)
	NetService.on("RequestPickBow", { perSecond = 2 }, onPickBow)
	NetService.on("RequestPhoto", { perSecond = 2 }, onPhoto)
	NetService.on("RequestPickCustomer", { perSecond = 1, burst = 2 }, onPickCustomer)
	NetService.on("RequestOpenBox", { perSecond = 1 }, onOpenBox)
	NetService.on("RequestPlaceKitten", { perSecond = 1 }, onPlaceKitten)
	NetService.on("RequestTakeCat", { perSecond = 1, burst = 2 }, onTakeCat)
	NetService.on("RequestPlaceCat", { perSecond = 1, burst = 2 }, onPlaceCat)
	-- The opening or the kitten switched off while a kitten waits in a box: the box goes, and the tub gets him (or,
	-- with sudsWash off, the usual first cat).
	for _, flag in { SudsRules.BOX_FLAG, SudsRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				if LiveFlags.isOn(flag) then
					return
				end
				for _, player in Players:GetPlayers() do
					-- in the box, or opened and still being carried
					if player:GetAttribute(SudsRules.BOX_ATTRIBUTE) ~= nil then
						handOut(player)
					end
				end
			end)
	end

	-- Switch turned off: drop every cat, so turning it on again starts clean.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(function()
			if not LiveFlags.isOn(FLAG) then
				table.clear(cats)
				for player in table.clone(carrying) do
					carrying[player] = nil
					sayCarry(player, nil)
				end
			end
		end)
	-- Customers switched on or off: the next cat follows the switch; a queue left over is dropped.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CUSTOMERS_FLAG)
		:Connect(function()
			if not LiveFlags.isOn(CUSTOMERS_FLAG) then
				for player in table.clone(carrying) do
					dropCarry(player)
				end
				table.clear(queues)
				table.clear(queueOrders)
			end
		end)
	-- The carry switched off: a cat at the door or in someone's arms goes straight into their tub.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CarryRules.FLAG)
		:Connect(function()
			if LiveFlags.isOn(CarryRules.FLAG) then
				return
			end
			for player in table.clone(carrying) do
				dropCarry(player)
			end
		end)
	-- A later wash step switched on or off: the waiting cards show or drop its need at once (CatRules.liveNeeds).
	for _, need in CatRules.LATER_NEEDS do
		ReplicatedStorage
			:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. WashDraft.NEED_FLAG[need])
			:Connect(function()
				if not LiveFlags.isOn(CUSTOMERS_FLAG) then
					return
				end
				for player in queues do
					sendQueue(player)
				end
			end)
	end
	-- The dirt levels switched on or off: the waiting customers' needs follow at once (their levels stay as rolled).
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. DirtRules.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(CUSTOMERS_FLAG) then
				return
			end
			for player, line in queues do
				queueFor(player)
				local orders = ordersFor(player)
				for place, kind in line do
					orders[place].needs = rollNeeds(kind, orders[place].dirt)
				end
				sendQueue(player)
			end
		end)
	Players.PlayerRemoving:Connect(function(player: Player)
		cats[player] = nil
		nextId[player] = nil
		lastSeq[player] = nil
		queues[player] = nil
		refillAt[player] = nil
		queueOrders[player] = nil
		playBase[player] = nil
		noLeaveWas[player] = nil
		handedOut[player] = nil
		waiting[player] = nil
		loadDone[player] = nil
		isOwner[player] = nil
		carrying[player] = nil
		visitorDue[player] = nil
		visitorPending[player] = nil
		visitedThisSession[player] = nil
	end)
end

return SpaService
