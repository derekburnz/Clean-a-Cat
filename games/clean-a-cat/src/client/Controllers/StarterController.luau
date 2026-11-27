--!strict
-- StarterController: the Spa Starter Pack (UI/StarterWindow, issue 519), behind the switch starterPack with passes on
-- too. StarterService keeps the offer on the Player: StarterEndsAt (os.time the offer ends, set only while it is
-- offered), StarterOpened (true once the window was opened) and Visits. The prices come from ReplicatedStorage:
-- ProductPrice_StarterPack for the pack and PassPrice_<key> for each of the three passes in it.
--
-- The HUD's Starter button shows only while StarterEndsAt is set (SideButtons), with a calm chip under its caption
-- ("1d 20h", "5h 12m", never seconds), read with the window's line. The button bobs as it appears, three times on the first
-- visit and once on the next two, never after the window has been opened (Effects/Attention). The window never opens
-- by itself. The first time it is opened, RequestStarterOpened tells the server; Get pack sends RequestStarter, and the
-- server opens Roblox's own purchase prompt, which is the player's real confirm. When the offer ends, the window
-- closes and the button goes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local Products = require(Shared:WaitForChild("Products"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StarterRules = require(Shared:WaitForChild("StarterRules"))
local StarterViewRules = require(Shared:WaitForChild("StarterViewRules"))

local Client = script.Parent.Parent
local Attention = require(Client:WaitForChild("Effects"):WaitForChild("Attention"))
local UI = require(Client:WaitForChild("UI"))

local StarterController = {}

local WINDOW = StarterViewRules.WINDOW
local CARD_FLAG = "starterCard" -- HUD/StarterAd.CARD_FLAG
local NOTE_SECONDS = 1 -- read each second so the chip turns with the window's line (issue 636); the words only
-- change once a minute, so nothing visibly ticks
local CHECK_SECONDS = 1

local player = Players.LocalPlayer
local sentOpened = false
local bobbed = false -- the button bobs once per visit at most
local noteAt = -math.huge
local lastNote: string? = nil
local ASK_ID = "starterButton"
local asks: any = nil -- AskController, when loaded

local function on(): boolean
	return LiveFlags.isOn(StarterRules.FLAG) and LiveFlags.isOn(Passes.FLAG)
end

local function endsAt(): number?
	local raw = player:GetAttribute(StarterRules.ENDS_ATTRIBUTE)
	if type(raw) ~= "number" or raw <= os.time() then
		return nil
	end
	return raw
end

local function opened(): boolean
	return sentOpened or player:GetAttribute(StarterRules.OPENED_ATTRIBUTE) == true
end

local function passPrice(key: string): unknown
	return ReplicatedStorage:GetAttribute(Passes.PRICE_PREFIX .. key)
end

local function refresh()
	local pack = StarterViewRules.packPrice(
		ReplicatedStorage:GetAttribute(Products.PRICE_PREFIX .. StarterRules.PRODUCT)
	)
	UI.setStarter(StarterViewRules.items(passPrice), pack, endsAt())
end

local function setNote(force: boolean)
	local now = os.clock()
	if not force and now - noteAt < NOTE_SECONDS then
		return
	end
	noteAt = now
	local ends = endsAt()
	local text: string? = if on() and ends
		then StarterViewRules.hudNote(
			StarterViewRules.left(ends, os.time()),
			LiveFlags.isOn(StarterViewRules.NO_CLOCK_FLAG)
		)
		else nil
	if text ~= lastNote then
		UI.setSideNote(WINDOW, text)
		lastNote = text
	end
end

local function bob()
	local button = UI.sideButton(WINDOW)
	if button == nil or not button.Visible or not on() or endsAt() == nil then
		return
	end
	if LiveFlags.isOn(CARD_FLAG) then
		return -- switch starterCard (issue 1080, Derek: "no bobbing"): the dark card stands out without moving
	end
	local bobs = StarterViewRules.bobs(player:GetAttribute(StarterRules.VISITS_ATTRIBUTE), opened())
	if bobs > 0 then
		Attention.start(button, bobs)
	end
end

-- The bob waits its turn in the ask line (AskController, switch askQueue: the quiet "starterButton" ask, which ends
-- the moment it shows), else it plays as soon as the button shows.
local function tryBob()
	if bobbed or not on() or endsAt() == nil then
		return
	end
	local button = UI.sideButton(WINDOW)
	if button == nil or not button.Visible then
		return
	end
	bobbed = true
	if asks and asks.on() and asks.want(ASK_ID, bob) then
		return
	end
	bob()
end

local function tick()
	local live = on() and endsAt() ~= nil
	if not live then
		if UI.isOpen(WINDOW) then
			UI.close(WINDOW)
		end
		if lastNote ~= nil then
			setNote(true)
		end
		return
	end
	setNote(false)
	tryBob()
end

function StarterController.Init(controllers: { [string]: any })
	asks = controllers.AskController
end

function StarterController.Start()
	UI.onOpened(function(name: string)
		if name ~= WINDOW then
			return
		end
		refresh()
		if on() and not opened() then
			sentOpened = true
			Remotes.event("RequestStarterOpened"):FireServer()
		end
	end)
	UI.onStarterBuy(function()
		if on() and endsAt() ~= nil then
			Remotes.event("RequestStarter"):FireServer()
		end
	end)
	player:GetAttributeChangedSignal(StarterRules.ENDS_ATTRIBUTE):Connect(function()
		refresh()
		setNote(true)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(Products.PRICE_PREFIX .. StarterRules.PRODUCT)
		:Connect(refresh)
	-- both packs' passes (starterBuilder): a card's price follows whichever pack is offered
	for _, list in { StarterRules.CONTENTS, StarterRules.BUILDER_CONTENTS } do
		for _, key in list do
			ReplicatedStorage:GetAttributeChangedSignal(Passes.PRICE_PREFIX .. key):Connect(refresh)
		end
	end
	for _, flag in
		{
			StarterRules.FLAG,
			Passes.FLAG,
			StarterViewRules.NO_CLOCK_FLAG,
			StarterRules.BUILDER_FLAG,
		}
	do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				refresh()
				setNote(true)
			end)
	end
	refresh()
	setNote(true)
	task.spawn(function()
		while true do
			tick()
			task.wait(CHECK_SECONDS)
		end
	end)
end

return StarterController
