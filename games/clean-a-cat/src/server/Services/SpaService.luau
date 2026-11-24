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
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local CatRules = require(Shared:WaitForChild("CatRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local RecapRules = require(Shared:WaitForChild("RecapRules"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))
local WashDraft = require(Shared:WaitForChild("WashDraft"))
local WindowRules = require(Shared:WaitForChild("WindowRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local FigureService = require(script.Parent:WaitForChild("FigureService"))
local IndexService = require(script.Parent:WaitForChild("IndexService"))
local MascotService = require(script.Parent:WaitForChild("MascotService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))
local WindowService = require(script.Parent:WaitForChild("WindowService"))

local FLAG = "scrubPrototype"
local CUSTOMERS_FLAG = "customers"
local STRAYS_FLAG = "strays"
local PICK_FLAG = "queuePick"
local RECAP_FLAG = "recapCard"
local QUEUE_SIZE = SpaRules.QUEUE_SIZE
local BOARD_LIT = "ChanceBoardLit" -- Player attribute: true once a customer has been served, so the board shows
local MAX_CAT_ID = 2 ^ 31
local OWNER_WAIT_SECONDS = 3 -- the opening replay's owner check, at most this long after the save loads

local SpaService = {}

local cats: { [Player]: SpaRules.Cat } = {}
local nextId: { [Player]: number } = {}
local lastSeq: { [Player]: number } = {} -- the newest report number each client sent
local queues: { [Player]: { string } } = {} -- customers waiting at the door, front first
-- What each waiting customer's cat needs, in the same order as queues (#267): rolled when the customer joins the
-- line, so the card shows a smell or long claws before the pick, and moved with the customer on a pick.
local queueNeeds: { [Player]: { { CatRules.Need } } } = {}
local handedOut: { [Player]: number } = {} -- cats handed out this session, for the stray turns
-- Asked for a cat before the save loaded while sudsWash is on: answered once it loads, so a slow load can never hand
-- a brand new player a customer's cat in place of the kitten.
local waiting: { [Player]: boolean } = {}
-- The save-loaded step below has finished for this player (the owner replay is applied), so a parked ask may run.
local loadDone: { [Player]: boolean } = {}
local random = Random.new()

local function rollCustomer(player: Player): string
	local save = DataService.get(player)
	local queue = queues[player]
	-- The first customer of a save is common: no stars yet and nobody queued ahead of them.
	local first = (save == nil or save.stars <= 0) and (queue == nil or #queue == 0)
	return CatRules.roll(function()
		return random:NextNumber()
	end, first, if save then CatRules.tierFor(save.stars) else 1)
end

-- A cat's needs: its rarity's, plus the later needs whose switches are on, by chance (WashDraft, #267).
local function rollNeeds(kind: string): { CatRules.Need }
	return CatRules.rollNeeds(kind, function()
		return random:NextNumber()
	end, LiveFlags.isOn)
end

-- The needs list beside the player's door queue, kept as long as the queue.
local function needsFor(player: Player): { { CatRules.Need } }
	local list = queueNeeds[player]
	if list == nil then
		list = {}
		queueNeeds[player] = list
	end
	return list :: { { CatRules.Need } }
end

-- The player's door queue, filled to QUEUE_SIZE, so there is always a customer waiting.
local function queueFor(player: Player): { string }
	local queue = queues[player]
	if queue == nil then
		queue = {}
		queues[player] = queue
	end
	local q = queue :: { string }
	local n = needsFor(player)
	-- a line left from before this list existed, or out of step: roll what is missing, drop what is extra
	while #n < #q do
		table.insert(n, rollNeeds(q[#n + 1]))
	end
	while #n > #q do
		table.remove(n)
	end
	while #q < QUEUE_SIZE do
		local kind = rollCustomer(player)
		table.insert(q, kind)
		table.insert(n, rollNeeds(kind))
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

local function newCat(player: Player): SpaRules.Cat
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
			cat.needs = rollNeeds(cat.kind :: string)
			cats[player] = cat
			return cat
		end
	end
	if LiveFlags.isOn(CUSTOMERS_FLAG) then
		-- The front customer hands over their cat; queueFor refills the line when it is next read.
		local line = queueFor(player)
		cat.kind = table.remove(line, 1)
		cat.needs = table.remove(needsFor(player), 1)
		FigureService.served(player, cat.kind :: string) -- that customer's figure leaves the line
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
	local save = DataService.get(player)
	local needs = CatRules.liveNeeds(cat.needs or CatRules.needs(kind), LiveFlags.isOn)
	local locked = CatRules.lockedNeeds(needs, if save then save.stations else {})
	NetService.fire(player, "CatReady", cat.id, kind, needs, locked, cat.stray, cat.brushStrokes)
end

-- Sends the door line to the client and the figures (switch customers).
local function sendQueue(player: Player)
	local line = queueFor(player)
	local needs: { { CatRules.Need } } = {}
	for place, list in needsFor(player) do
		needs[place] = CatRules.liveNeeds(list, LiveFlags.isOn)
	end
	NetService.fire(player, "CustomerQueue", table.clone(line), needs)
	FigureService.showQueue(player, table.clone(queueFor(player)))
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
	sendCat(player, cat :: SpaRules.Cat)
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

-- The player picks a waiting customer to be washed next: it moves to the front of the line (#201).
local function onPickCustomer(player: Player, rawIndex: unknown)
	if
		not (LiveFlags.isOn(FLAG) and LiveFlags.isOn(CUSTOMERS_FLAG) and LiveFlags.isOn(PICK_FLAG))
	then
		return
	end
	local index = Guard.int(rawIndex, 2, QUEUE_SIZE)
	if index == nil or queues[player] == nil then
		return
	end
	-- A new save's first customer is the guaranteed common cat; picking past it would skip that. Picks open once a
	-- customer has been served (stars > 0), the same moment the chance board lights.
	local save = DataService.get(player)
	if save == nil or save.stars <= 0 then
		return
	end
	local line = queueFor(player)
	if SpaRules.pickNext(line, index) then
		SpaRules.pickNext(needsFor(player), index) -- the cat's needs move with it
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
	end
	if kind ~= nil and cat.stray then
		-- A stray has nobody to pay: the photo coins, and it moves into the window when there is room.
		save.coins += coins
		WalletService.show(player)
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
		WalletService.show(player)
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
		NetService.notice(player, `+{coins} coins`)
		return
	end
	-- A customer's cat goes home: the customer pays coins plus a tip, and the spa earns stars.
	local pay = CatRules.pay(kind)
	-- Built stations (a Brush Table, a dryer) make every customer pay a little more; only while builds are on.
	local bonus = if LiveFlags.isOn("builds")
		then BuildRules.payBonus(save.stations, LiveFlags.isOn)
		else 0
	coins = pay.coins + pay.tip + bonus
	save.coins += coins
	WalletService.show(player)
	local starsBefore = save.stars
	save.stars += pay.stars
	player:SetAttribute(BOARD_LIT, true)
	player:SetAttribute(CatRules.TIER_ATTRIBUTE, CatRules.tierFor(save.stars))
	if LiveFlags.isOn(RECAP_FLAG) then
		-- The recap card shows the payment line by line (#224), so it replaces the toast.
		local recap = RecapRules.make(kind, pay, bonus, starsBefore, isNew)
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins, recap)
	else
		NetService.fire(player, "PhotoPaid", cat.id, coins, save.coins)
		NetService.notice(
			player,
			`+{coins} coins, +{pay.stars} {if pay.stars == 1 then "star" else "stars"}`
		)
	end
	Telemetry.onboarding(player, "first_return")
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
	MascotService.whileInTub(function(player: Player): boolean
		local cat = cats[player]
		return cat ~= nil and cat.mascot == true
	end)
	NetService.on("RequestCat", { perSecond = 1, burst = 2 }, onRequestCat)
	-- When the server saw the join, so the client can print how long the opening took to start (OpeningController).
	local function stampJoin(player: Player)
		if player:GetAttribute(SudsRules.JOINED_ATTRIBUTE) == nil then
			player:SetAttribute(SudsRules.JOINED_ATTRIBUTE, Workspace:GetServerTimeNow())
		end
		task.spawn(checkOwner, player)
	end
	Players.PlayerAdded:Connect(stampJoin)
	for _, player in Players:GetPlayers() do
		stampJoin(player)
	end
	-- The chance board lights up from the second customer: once a save has stars, a customer was served.
	DataService.onLoaded:Connect(function(player: Player, save)
		if save.stars > 0 then
			player:SetAttribute(BOARD_LIT, true)
		end
		-- The board shows the chances of the player's star tier, the same table their rolls use.
		player:SetAttribute(CatRules.TIER_ATTRIBUTE, CatRules.tierFor(save.stars))
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
			end
		end)
	-- Customers switched on or off: the next cat follows the switch; a queue left over is dropped.
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CUSTOMERS_FLAG)
		:Connect(function()
			if not LiveFlags.isOn(CUSTOMERS_FLAG) then
				table.clear(queues)
				table.clear(queueNeeds)
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
	Players.PlayerRemoving:Connect(function(player: Player)
		cats[player] = nil
		nextId[player] = nil
		lastSeq[player] = nil
		queues[player] = nil
		queueNeeds[player] = nil
		handedOut[player] = nil
		waiting[player] = nil
		loadDone[player] = nil
		isOwner[player] = nil
	end)
end

return SpaService
