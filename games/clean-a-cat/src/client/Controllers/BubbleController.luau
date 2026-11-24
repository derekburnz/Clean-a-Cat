--!strict
-- BubbleController: when Suds's help bubble (BubbleRules, UI/SudsBubble, switch sudsBubble, off by default) shows,
-- and what its "Show me" does. It looks at what the player's device already knows (the coins, the owned tools, the
-- builds, the customers at the door, the opening's stage) and shows the first bubble that is due and that this save
-- has not shown, one at a time.
--
-- Nothing talks over a wash (Design-Agent): a bubble only shows while the tub is empty, and one still up when a cat
-- lands in the tub goes. The natural moment is as a recap card closes: RecapController hands us the next cat request
-- (afterRecap), so the due bubbles show one after another with the tub still empty, and the next cat is asked for
-- once the last one goes (by its button, its X, a window opening or the switch going off), never before. That is
-- where "Let's open the spa!" and "First customer!" land, after Suds's naming card, before the customer's cat comes.
-- Between washes it also checks once a second, waiting while a window, the recap card or the dim step is up, while
-- the opening runs, and for a moment after the screen frees up.
--
-- "Show me" only points the way: the floor trail (switch tutorialTrail) to the tub, the Tools board or the builder
-- board, and Moments.SudsPoint so Suds can trot there from his bed. It never opens a window, buys, builds or moves
-- the player; they still walk there and tap the thing themselves. The trail goes once they arrive, start a scrub, or
-- after TRAIL_SECONDS.
--
-- It tells the server each bubble it shows (ReportBubbleSeen), so a rejoin never shows it again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))
local Wallet = require(Shared:WaitForChild("Wallet"))

local Client = script.Parent.Parent
local FloorTrail = require(Client:WaitForChild("Spa"):WaitForChild("FloorTrail"))
local UI = require(Client:WaitForChild("UI"))

local CHECK_SECONDS = 1
local SETTLE_SECONDS = 1.5 -- the screen stays free this long before a bubble shows between washes
local CHAIN = 3 -- at most this many bubbles one after another as a recap card closes
local ARRIVE = 8 -- studs from the spot where the trail is done
local TRAIL_SECONDS = 30
local SOAP = "BubbleSoap"
local TOOLS_SPOT = "Tools"
local TOOLS_FLAG = "toolsBoard"
local BUILDS_FLAG = "builds"
local MASCOT_FOLDER = "Mascot" -- MascotService's folder in the plot

local BubbleController = {}

local player = Players.LocalPlayer
local happened = { firstCustomer = false, wetCat = false, stationReady = false } -- this session's sightings
local scrub: any = nil
local told: { [string]: boolean } = {} -- shown here, before the server's list catches up
local haveBuilds = false
local builds: { [string]: BuildRules.Build } = {}
local built: { [string]: boolean } = {}
local freeSince = -math.huge
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
	return (BuildRules.canStart({ coins = coins(), stations = built, builds = builds }, id))
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
		build = canBuild("BrushTable"),
		longBuild = canBuild("VipRoom"),
	}
end

-- Where "Show me" points for each bubble; nil for the OK ones.
local function target(id: string): Vector3?
	if id == "firstCustomer" then
		return SpaLayout.tubSpot().Position
	elseif id == "newSoap" then
		return SpaLayout.spot(TOOLS_SPOT).Position
	elseif id == "wetCat" or id == "build" or id == "longBuild" then
		return SpaLayout.spot(SpaLayout.BUILDER_SPOT).Position
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

-- True while a cat is in the tub (from landing to the photo): no bubble then.
local function catInTub(): boolean
	local stage = if scrub then scrub.stage() else nil
	return stage ~= nil and stage ~= "waiting" and stage ~= "done"
end

-- The bubble due now, or nil: the switch on, the save's list loaded, and nothing else on screen or in the tub.
local function due(): BubbleRules.Bubble?
	if
		not LiveFlags.isOn(BubbleRules.FLAG)
		or UI.busy()
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
	return BubbleRules.pick(facts(), seen)
end

local function show(bubble: BubbleRules.Bubble, onGone: (() -> ())?)
	told[bubble.id] = true
	Remotes.event("ReportBubbleSeen"):FireServer(bubble.id)
	local spot = if bubble.showMe then target(bubble.id) else nil
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
	local function step()
		local bubble = if left > 0 then due() else nil
		if bubble == nil then
			nextCat()
			return
		end
		left -= 1
		show(bubble, step)
	end
	local failure = ""
	local ok = xpcall(step, function(err: unknown)
		failure = tostring(err)
	end)
	if not ok then
		warn(`BubbleController: a bubble failed, next cat now: {failure}`)
		nextCat()
	end
end

local function check()
	checkTrail()
	if not LiveFlags.isOn(BubbleRules.FLAG) then
		UI.hideBubble()
		return
	end
	if UI.bubbleShown() then
		return
	end
	local now = os.clock()
	if UI.busy() or catInTub() or FloorTrail.isShown() then
		freeSince = now
		return
	end
	if now - freeSince < SETTLE_SECONDS then
		return
	end
	local bubble = due()
	if bubble then
		show(bubble, nil)
	end
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
