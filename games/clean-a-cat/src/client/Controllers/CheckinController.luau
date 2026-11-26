--!strict
-- CheckinController: the check in card (UI/CheckinCard, issue 517), behind the switch checkinCard. It draws the card
-- from the Player attributes CheckinService keeps (CheckinReady, the day waiting or nil; CheckinDays, the days taken)
-- and sends RequestCheckin when Claim is pressed; the server checks the day and gives the gift once.
--
-- The card opens by itself once for each day that comes ready (the first at about 3:45 of play, then the first join
-- of each new day played), and only between washes (Design-Agent): never while a cat is in the tub or in the
-- player's arms, while the opening runs, or while a window, the recap card, the dim step or a Suds bubble is up, and
-- only after the screen has been free for SETTLE_SECONDS. Closed with its X, it waits on the HUD's Gifts button.
-- The good crate's chance button opens the crate window, and the card comes back when that closes (not after Open
-- crate there, so the reveal plays clear).
-- With askQueue on (issue 522), the card's own opening goes through AskController instead: it waits its turn in the
-- one ask queue (a minute from any other ask) and the queue's screen free test, and with the switch off the old
-- path above runs as before.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryRules = require(Shared:WaitForChild("CarryRules"))
local CheckinRules = require(Shared:WaitForChild("CheckinRules"))
local CheckinViewRules = require(Shared:WaitForChild("CheckinViewRules"))
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local CrateViewRules = require(Shared:WaitForChild("CrateViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local CHECK_SECONDS = 1
local SETTLE_SECONDS = 1.5 -- the screen stays free this long before the card opens by itself
local WINDOW = "Checkin"
local ASK = "checkin" -- AskRules id

local CheckinController = {}

local player = Players.LocalPlayer
local scrub: any = nil
local crates: any = nil
local ask: any = nil
local openedFor: number? = nil -- the day the card already opened by itself for, this session
local freeSince = -math.huge

local function on(): boolean
	return LiveFlags.isOn(CheckinRules.FLAG)
end

local function state(): (number?, number)
	return CheckinViewRules.read(
		player:GetAttribute(CheckinRules.READY_ATTRIBUTE),
		player:GetAttribute(CheckinRules.DAYS_ATTRIBUTE)
	)
end

local function chancesOn(): boolean
	return crates ~= nil and LiveFlags.isOn(CrateViewRules.FLAG) and LiveFlags.isOn(CrateRules.FLAG)
end

local function refresh()
	local ready, days = state()
	UI.setCheckin(ready, days, chancesOn())
end

-- True from a cat landing in the tub until it leaves after the photo (the same reading as BubbleController's).
local function catInTub(): boolean
	local stage = if scrub then scrub.stage() else nil
	if stage == "done" then
		return scrub ~= nil and scrub.leaving()
	end
	return stage ~= nil and stage ~= "waiting"
end

local function free(): boolean
	return not (
		UI.busy()
		or UI.bubbleShown()
		or catInTub()
		or player:GetAttribute(CarryRules.ATTRIBUTE) == CarryRules.ARMS
		or player:GetAttribute(SudsRules.BOX_ATTRIBUTE) == true
		or SudsRules.cleanStage(player:GetAttribute(SudsRules.ATTRIBUTE)) == SudsRules.BOX
	)
end

-- The card's turn in the ask queue (askQueue on).
local function showAsked()
	local ready = state()
	if not on() or ready == nil then
		ask.done(ASK, "closed")
		return
	end
	openedFor = ready
	refresh()
	UI.open(WINDOW)
	UI.onceClosed(WINDOW, function()
		ask.done(ASK, "closed")
	end)
end

local function tick()
	if not on() then
		freeSince = -math.huge
		if ask and ask.on() then
			ask.drop(ASK)
		end
		return
	end
	local ready = state()
	if ask and ask.on() then
		freeSince = -math.huge
		if ready == nil or ready == openedFor then
			ask.drop(ASK)
		else
			ask.want(ASK, showAsked)
		end
		return
	end
	if ready == nil or ready == openedFor then
		return
	end
	if not free() then
		freeSince = -math.huge
		return
	end
	local now = os.clock()
	if freeSince == -math.huge then
		freeSince = now
	end
	if now - freeSince >= SETTLE_SECONDS then
		openedFor = ready
		refresh()
		UI.open(WINDOW)
	end
end

function CheckinController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
	crates = controllers.CrateWindowController
	ask = controllers.AskController
end

function CheckinController.Start()
	UI.onCheckinClaim(function()
		if on() and state() ~= nil then
			Remotes.event("RequestCheckin"):FireServer()
		end
	end)
	UI.onCheckinChances(function(kind: string)
		local held = player:GetAttribute(CrateRules.CRATE_ATTRIBUTE_PREFIX .. kind)
		if crates and chancesOn() and crates.show(kind) then
			UI.onceClosed("Crate", function()
				-- back to the card after a look at the chances; not after Open crate, so the reveal plays clear
				local opened = player:GetAttribute(CrateRules.CRATE_ATTRIBUTE_PREFIX .. kind)
					~= held
				if on() and not opened and not UI.busy() then
					refresh()
					UI.open(WINDOW)
				end
			end)
		end
	end)
	player:GetAttributeChangedSignal(CheckinRules.READY_ATTRIBUTE):Connect(refresh)
	player:GetAttributeChangedSignal(CheckinRules.DAYS_ATTRIBUTE):Connect(refresh)
	for _, name in { CheckinRules.FLAG, CrateViewRules.FLAG, CrateRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. name)
			:Connect(refresh)
	end
	refresh()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			tick()
		end
	end)
end

return CheckinController
