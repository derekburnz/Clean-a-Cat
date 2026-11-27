--!strict
-- BubbleController: when Suds's help bubble (BubbleRules, UI/SudsBubble, switch sudsBubble, off by default) shows,
-- and what its "Show me" does. It looks at what the player's device already knows (the coins, the owned tools, the
-- builds, the customers at the door, the opening's stage) and shows the first bubble that is due and that this save
-- has not shown, one at a time.
--
-- Nothing talks over a wash (Design-Agent): a bubble only shows while the tub is empty, and one still up when a cat
-- lands in the tub goes. The natural moment is as a recap card closes: RecapController hands us the next cat request
-- (afterRecap), so the due bubbles show one after another with the tub still empty, and the next cat is asked for
-- once the last one goes (by its button, its X, a window opening or the switch going off). A bubble never holds the
-- game up (Design-Agent): at most CHAIN in a row, and one left up for WAIT_SECONDS goes and the next cat comes
-- anyway, so the player never has to clear bubbles to keep playing. That is where "Let's open the spa!" and "First customer!" land, after Suds's naming card, before the customer's cat comes.
-- Between washes it also checks once a second, waiting while a window, the recap card or the dim step is up, while
-- the opening runs, and for a moment after the screen frees up.
--
-- "Show me" only points the way: the floor trail (switch tutorialTrail) to the tub, the Tools board or the builder
-- board, and Moments.SudsPoint so Suds can trot there from his bed. It never opens a window, buys, builds or moves
-- the player; they still walk there and tap the thing themselves. The trail goes once they arrive, start a scrub, or
-- after TRAIL_SECONDS. With `menuOnly` on, a card whose thing is done in a window (hire Jo in Helpers, a build or a
-- tool in Build: MenuRules.windowFor) has no trail, and its "Show me" opens that window instead (issue 1028).
--
-- With askQueue on (issue 522), every bubble but the opening's own (BubbleRules.OPENING) is the ask "bubble"
-- (AskController): between washes it waits its turn in the line and goes by itself after ASK_UP_SECONDS; as a recap
-- card closes it shows only if the line lets it now (else the next cat comes and it waits for a later turn), so it
-- never comes within a minute of the check in card or another ask, and never holds one back for long.
--
-- It tells the server each bubble it shows (ReportBubbleSeen), so a rejoin never shows it again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local CatRules = require(Shared:WaitForChild("CatRules"))
local CounterRules = require(Shared:WaitForChild("CounterRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local MenuRules = require(Shared:WaitForChild("MenuRules"))
local Moments = require(Shared:WaitForChild("Moments"))
local Passes = require(Shared:WaitForChild("Passes"))
local QuestViewRules = require(Shared:WaitForChild("QuestViewRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpecialRules = require(Shared:WaitForChild("SpecialRules"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))
local Wallet = require(Shared:WaitForChild("Wallet"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local Client = script.Parent.Parent
local FloorTrail = require(Client:WaitForChild("Spa"):WaitForChild("FloorTrail"))
local UI = require(Client:WaitForChild("UI"))

local CHECK_SECONDS = 1
local SETTLE_SECONDS = 1.5 -- the screen stays free this long before a bubble shows between washes
local CHAIN = 2 -- at most this many bubbles one after another as a recap card closes
local WAIT_SECONDS = 6 -- a bubble left up this long as the next cat waits goes, and the next cat comes
local ARRIVE = 8 -- studs from the spot where the trail is done
local TRAIL_SECONDS = 30
local ASK = "bubble" -- AskRules.IDS
local ASK_UP_SECONDS = 20 -- with askQueue on, a bubble shown between washes goes by itself after this
local SOAP = "BubbleSoap"
local TOOLS_SPOT = "Tools"
local TOOLS_FLAG = "toolsBoard"
local BUILDS_FLAG = "builds"
local MASCOT_FOLDER = "Mascot" -- MascotService's folder in the plot
local QUESTS_FLAG = "quests"
local HUD_FLAG = "gameHud" -- the Quests button lives on the HUD

local BubbleController = {}

local player = Players.LocalPlayer
local happened = { firstCustomer = false, wetCat = false, stationReady = false, special = false } -- this session's sightings
local scrub: any = nil
local ask: any = nil -- AskController
local told: { [string]: boolean } = {} -- shown here, before the server's list catches up
local haveBuilds = false
local builds: { [string]: BuildRules.Build } = {}
local built: { [string]: boolean } = {}
local freeSince = -math.huge
local chaining = false -- a recap card closed and the next cat waits for the bubbles in a row (afterRecap)
local hurryRow: (() -> ())? = nil -- (switch tipTake) ends that row now, so the next cat is asked for (hurry)
local trailUntil: number? = nil -- os.clock() when our trail goes; nil while it is not ours
local trailTo: Vector3? = nil

local function coins(): number
	local raw = player:GetAttribute(Wallet.ATTRIBUTE)
	return if type(raw) == "number" then raw else 0
end

local function canBuild(id: string): boolean
	if not haveBuilds or not LiveFlags.isOn(BUILDS_FLAG) then
		return false
	end
	if not table.find(BuildRules.offered(LiveFlags.isOn), id) then
		return false
	end
	return (
		BuildRules.canStart(
			{ coins = coins(), stations = built, builds = builds },
			id,
			LiveFlags.isOn,
			if player:GetAttribute(Passes.ATTRIBUTE_PREFIX .. "SecondBuilder") == true then 2 else 1
		)
	)
end

local function facts(): { [string]: boolean }
	local soap = ToolRules.TOOLS[SOAP]
	return {
		openSpa = SudsRules.cleanStage(player:GetAttribute(SudsRules.ATTRIBUTE)) >= SudsRules.DONE,
		firstCustomer = happened.firstCustomer,
		stationReady = happened.stationReady,
		wetCat = happened.wetCat,
		newSoap = LiveFlags.isOn(TOOLS_FLAG) and player:GetAttribute(
			ToolRules.ATTRIBUTE_PREFIX .. SOAP
		) ~= true and coins() >= soap.price,
		-- with the tubs on (tubBuilds), the first build is the Second Tub
		build = canBuild(
			if BuildRules.shown("SecondTub", LiveFlags.isOn) then "SecondTub" else "BrushTable"
		),
		longBuild = not BuildRules.shown("ThirdTub", LiveFlags.isOn) and canBuild("VipRoom"),
		longBuildTub = BuildRules.shown("ThirdTub", LiveFlags.isOn) and canBuild("ThirdTub"),
		-- contextAsks (issue 877): a special visitor at the door, and a crate held (the first one only, once a save)
		special = happened.special,
		crate = (tonumber(player:GetAttribute(SpecialRules.CRATES_ATTRIBUTE)) or 0) > 0,
		-- issue 913: Jo is affordable and not hired, with the helpers on
		hireJo = LiveFlags.isOn(WorkerRules.FLAG)
			and player:GetAttribute("WorkerLevel_Jo") == nil
			and coins() >= (WorkerRules.priceOf("Jo", LiveFlags.isOn) or math.huge),
		quests = LiveFlags.isOn(QUESTS_FLAG) and LiveFlags.isOn(HUD_FLAG) and player:GetAttribute(
			QuestViewRules.OPEN_ATTRIBUTE
		) == true,
	}
end

-- Where "Show me" points for each bubble; nil for the OK ones.
local function target(id: string): Vector3?
	if id == "firstCustomer" then
		return SpaLayout.tubSpot().Position
	elseif id == "newSoap" then
		return SpaLayout.spot(TOOLS_SPOT).Position
	elseif id == "wetCat" or id == "build" or id == "longBuild" or id == "longBuildTub" then
		return SpaLayout.spot(SpaLayout.BUILDER_SPOT).Position
	elseif id == "special" then
		-- where the customers wait: the counter window's first place (counterLine), else the head of the line
		return SpaLayout.spot(
			if LiveFlags.isOn(CounterRules.FLAG)
				then CounterRules.SPOT_PREFIX .. "1"
				else "SpotQueue1"
		).Position
	elseif id == "crate" then
		return SpaLayout.spot("Crate").Position -- CrateController's crate
	elseif id == "hireJo" then
		return SpaLayout.spot(WorkerRules.WORKERS.Jo.spot).Position
	end
	return nil
end

local function stopTrail()
	if trailUntil ~= nil then
		trailUntil, trailTo = nil, nil
		FloorTrail.hide()
	end
end

-- Suds on his bed in the player's own plot (MascotService), if he is there.
local function sudsOnBed(): Model?
	local slot = SpaLayout.slotOf(player)
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	local folder = if plot then plot:FindFirstChild(MASCOT_FOLDER) else nil
	local suds = if folder then folder:FindFirstChild(SudsRules.NAME) else nil
	return if suds and suds:IsA("Model") then suds :: Model else nil
end

local function pointTo(spot: Vector3)
	stopTrail()
	FloorTrail.show(spot)
	if FloorTrail.isShown() then
		trailUntil, trailTo = os.clock() + TRAIL_SECONDS, spot
	end
	local suds = sudsOnBed()
	if suds then
		Moments.SudsPoint:Fire(suds, spot)
	end
end

local function checkTrail()
	local until_, spot = trailUntil, trailTo
	if until_ == nil or spot == nil then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local near = root ~= nil
		and root:IsA("BasePart")
		and ((root :: BasePart).Position - spot).Magnitude <= ARRIVE
	if near or os.clock() > until_ or not FloorTrail.isShown() then
		stopTrail()
	end
end

-- True while a cat is in the tub (from landing until it leaves after the photo): no bubble then. The photo sets the
-- stage to "done" a few seconds before the recap card comes; without the leaving check, "Let's open the spa!" showed
-- at Suds's photo, 1.4 s before and then under his "Meet Suds!" card (Sync-Agent's run on ff0803d).
local function catInTub(): boolean
	local stage = if scrub then scrub.stage() else nil
	if stage == "done" then
		return scrub ~= nil and scrub.leaving()
	end
	return stage ~= nil and stage ~= "waiting"
end

-- The bubble due now, or nil: the switch on, the save's list loaded, and nothing else on screen or in the tub.
local function due(): BubbleRules.Bubble?
	if
		not LiveFlags.isOn(BubbleRules.FLAG)
		or UI.bubbleBlocked()
		or catInTub()
		or player:GetAttribute(SudsRules.BOX_ATTRIBUTE) == true
		or SudsRules.cleanStage(player:GetAttribute(SudsRules.ATTRIBUTE)) == SudsRules.BOX -- the kitten hops to the tub
	then
		return nil
	end
	local seen = BubbleRules.unpack(player:GetAttribute(BubbleRules.ATTRIBUTE))
	if seen == nil then
		return nil -- the save has not loaded yet
	end
	for id in told do
		seen[id] = true
	end
	return BubbleRules.pick(facts(), seen, LiveFlags.isOn)
end

local function show(bubble: BubbleRules.Bubble, onGone: ((closed: boolean) -> ())?)
	told[bubble.id] = true
	Remotes.event("ReportBubbleSeen"):FireServer(bubble.id)
	local window = if bubble.showMe then MenuRules.windowFor(bubble.id, LiveFlags.isOn) else nil
	if window then
		UI.showBubble(bubble, function()
			UI.open(window)
		end, onGone)
		return
	end
	local spot = if bubble.showMe then target(bubble.id) else nil
	-- contextAsks (issue 877): a guide card shows its trail with it, not only after "Show me"
	if spot and BubbleRules.contextOn(LiveFlags.isOn) then
		pointTo(spot)
		if bubble.id == "hireJo" then
			-- Motion-FX's walk up (issue 913) on WorkerController's prompt anchor for Jo
			local prompts = Workspace:FindFirstChild("CleanACat_WorkerPrompts")
			local pad = if prompts then prompts:FindFirstChild("Jo") else nil
			if pad and pad:IsA("BasePart") then
				Moments.JoArrives:Fire(pad :: BasePart)
			end
		end
	end
	UI.showBubble(
		bubble,
		if spot
			then function()
				pointTo(spot)
			end
			else nil,
		onGone
	)
end

-- RecapController calls this as a recap card closes, with the request for the next cat. The tub is still empty, so
-- the due bubbles show one after another, and the next cat is asked for once the last goes. With nothing due (or the
-- switch off) it asks at once, so the tub is never left empty by us.
function BubbleController.afterRecap(nextCat: () -> ())
	local left = CHAIN
	local finished = false
	chaining = true
	local function finish()
		if not finished then
			finished = true
			hurryRow = nil
			chaining = false
			freeSince = os.clock() -- the once-a-second check waits again before a bubble of its own
			nextCat()
		end
	end
	hurryRow = function()
		left = 0 -- no more in this row; the one shown stays until it goes by itself
		finish()
	end
	local step: () -> ()
	-- Every step runs guarded: an error anywhere in the row still brings the next cat.
	local function guarded()
		local failure = ""
		local ok = xpcall(step, function(err: unknown)
			failure = tostring(err)
		end)
		if not ok then
			warn(`BubbleController: a bubble failed, next cat now: {failure}`)
			finish()
		end
	end
	step = function()
		local bubble = if left > 0 and not finished then due() else nil
		if bubble == nil then
			finish()
			return
		end
		local asked = ask ~= nil and ask.on() and not BubbleRules.OPENING[bubble.id]
		if asked and not ask.takeNow(ASK) then
			finish() -- the line says wait: the next cat comes, and the bubble waits its turn between washes
			return
		end
		left -= 1
		show(bubble, function(closed: boolean)
			if asked then
				ask.done(ASK, "closed")
			end
			if closed then
				left = 0 -- the player's X ends the row (Review-QA on #300)
			end
			guarded()
		end)
		task.delay(WAIT_SECONDS, function()
			if UI.shownBubble() == bubble then
				left = 0 -- no more in this row: the next cat comes as this one goes
				UI.hideBubble()
			end
		end)
	end
	guarded()
end

-- (switch tipTake, issue 1017) Whether the next cat waits on Suds's bubbles after a recap card closed.
function BubbleController.holdingNextCat(): boolean
	return hurryRow ~= nil
end

-- (switch tipTake) The player tapped a cat on the counter while the next cat waits on a bubble: it is asked for now,
-- and the bubble shown stays until it goes by itself (Sync on 0e6a8f5: for 6 s every cat sat there with no Take).
-- False when nothing waits.
function BubbleController.hurry(): boolean
	local row = hurryRow
	if row == nil then
		return false
	end
	row()
	return true
end

-- The ask's turn came (askQueue): the bubble due now, if one still is, up for at most ASK_UP_SECONDS.
local function showAsked()
	local bubble = if chaining or UI.bubbleShown() then nil else due()
	if bubble == nil or BubbleRules.OPENING[bubble.id] then
		ask.skip(ASK)
		return
	end
	show(bubble, function()
		ask.done(ASK, "closed")
	end)
	task.delay(ASK_UP_SECONDS, function()
		if UI.shownBubble() == bubble then
			UI.hideBubble()
		end
	end)
end

local function check()
	checkTrail()
	if not LiveFlags.isOn(BubbleRules.FLAG) then
		UI.hideBubble()
		return
	end
	local now = os.clock()
	if chaining or UI.bubbleShown() then
		freeSince = now -- a bubble just going is no free screen (Review-QA on #300)
		return
	end
	if UI.bubbleBlocked() or catInTub() or FloorTrail.isShown() then
		freeSince = now
		return
	end
	if now - freeSince < SETTLE_SECONDS then
		return
	end
	local bubble = due()
	if bubble == nil then
		return
	end
	if ask ~= nil and ask.on() and not BubbleRules.OPENING[bubble.id] then
		if ask.shown() ~= ASK then
			ask.want(ASK, showAsked, UI.hideBubble)
		end
		return
	end
	show(bubble, nil)
end

-- A cat landed in the tub: any bubble still up goes, and the first that needs a dryer not built makes "Wet cat!" due
-- for after its wash.
local function onCatReady(_catId: unknown, _kind: unknown, _needs: unknown, locked: unknown)
	UI.hideBubble()
	if type(locked) == "table" and table.find(locked :: { unknown }, "wet") then
		happened.wetCat = true
	end
end

-- The customers at the door: the first one makes "First customer!" due.
local function onQueue(kinds: unknown)
	if type(kinds) == "table" and #(kinds :: { unknown }) > 0 then
		happened.firstCustomer = true
		for _, kind in kinds :: { unknown } do
			if type(kind) == "string" and CatRules.rarityOf(kind) == CatRules.SPECIAL then
				happened.special = true -- contextAsks: "A special visitor!"
			end
		end
	end
end

local function onBuilds(rawBuilds: unknown, rawBuilt: unknown)
	builds = BuildRules.cleanBuilds(rawBuilds)
	table.clear(built)
	if type(rawBuilt) == "table" then
		for _, id in rawBuilt :: { unknown } do
			if type(id) == "string" and BuildRules.ITEMS[id] then
				built[id] = true
			end
		end
	end
	haveBuilds = true
end

function BubbleController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
	ask = controllers.AskController
end

function BubbleController.Start()
	Remotes.event("CatReady").OnClientEvent:Connect(onCatReady)
	Remotes.event("CustomerQueue").OnClientEvent:Connect(onQueue)
	Remotes.event("Builds").OnClientEvent:Connect(onBuilds)
	Remotes.event("BuildFinished").OnClientEvent:Connect(function(rawId: unknown)
		if type(rawId) == "string" and BuildRules.ITEMS[rawId] then
			happened.stationReady = true
		end
	end)
	Moments.ScrubStart:Connect(function()
		stopTrail()
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			check()
		end
	end)
end

return BubbleController
