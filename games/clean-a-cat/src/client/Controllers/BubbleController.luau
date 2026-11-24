--!strict
-- BubbleController: when Suds's help bubble (BubbleRules, UI/SudsBubble, switch sudsBubble, off by default) shows,
-- and what its "Show me" does. Once a second it looks at what the player's device already knows (the coins, the
-- owned tools, the builds, the cats handed out, the opening's stage) and shows the first bubble that is due and that
-- this save has not shown, one at a time. It waits while a window, the recap card or the dim step is up, while the
-- opening's box waits for its tap, and for a moment after the screen frees up, so a bubble never lands on the frame a
-- card closes.
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
local SETTLE_SECONDS = 1.5 -- the screen stays free this long before a bubble shows
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
	if
		UI.busy()
		or player:GetAttribute(SudsRules.BOX_ATTRIBUTE) == true
		or FloorTrail.isShown()
	then
		freeSince = now
		return
	end
	if now - freeSince < SETTLE_SECONDS then
		return
	end
	local seen = BubbleRules.unpack(player:GetAttribute(BubbleRules.ATTRIBUTE))
	if seen == nil then
		return -- the save has not loaded yet
	end
	for id in told do
		seen[id] = true
	end
	local bubble = BubbleRules.pick(facts(), seen)
	if bubble == nil then
		return
	end
	told[bubble.id] = true
	Remotes.event("ReportBubbleSeen"):FireServer(bubble.id)
	local spot = if bubble.showMe then target(bubble.id) else nil
	UI.showBubble(
		bubble,
		if spot
			then function()
				pointTo(spot)
			end
			else nil
	)
end

local function onCatReady(
	_catId: unknown,
	kind: unknown,
	_needs: unknown,
	locked: unknown,
	stray: unknown
)
	if type(kind) == "string" and kind ~= SudsRules.NAME and stray ~= true then
		happened.firstCustomer = true
	end
	if type(locked) == "table" and table.find(locked :: { unknown }, "wet") then
		happened.wetCat = true
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

function BubbleController.Init(_controllers: { [string]: any }) end

function BubbleController.Start()
	Remotes.event("CatReady").OnClientEvent:Connect(onCatReady)
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
