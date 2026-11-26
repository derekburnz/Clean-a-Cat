--!strict
-- AskController: the first session's ask queue on the client (AskRules, issue 522), behind the switch askQueue.
-- A feature that wants to ask something outside the wash calls
--
--   AskController.want(id, show, hide?)   puts the ask in the line; `show()` runs when its turn comes
--   AskController.done(id, answer)        the ask was answered ("yes", "no": final for the visit) or "closed"
--   AskController.drop(id)                takes a waiting ask out of the line (its reason went away)
--   AskController.on()                    true while askQueue is on; with it off, call your old path instead
--
-- The screen counts as free (the one test for every ask, lifted from CheckinController) when no window, recap card
-- or strip, dim step or Suds bubble is up, no cat is in the tub or in the player's arms, and the opening is not
-- running; it must stay free SETTLE_SECONDS before an ask shows. One ask at a time, a minute apart, never dropped
-- (AskRules). With the switch turned off, the ask up now is hidden (its `hide`) and the line is emptied, so every
-- feature goes back to its own path at once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AskRules = require(Shared:WaitForChild("AskRules"))
local CarryRules = require(Shared:WaitForChild("CarryRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local CHECK_SECONDS = 0.5
local SETTLE_SECONDS = 1.5 -- the screen stays free this long before an ask shows

local AskController = {}

type Entry = { show: () -> (), hide: (() -> ())? }

local player = Players.LocalPlayer
local scrub: any = nil
local queue = AskRules.new()
local entries: { [string]: Entry } = {}
local freeSince = -math.huge

function AskController.on(): boolean
	return LiveFlags.isOn(AskRules.FLAG)
end

-- True from a cat landing in the tub until it leaves after the photo (the same reading as BubbleController's).
local function catInTub(): boolean
	local stage = if scrub then scrub.stage() else nil
	if stage == "done" then
		return scrub ~= nil and scrub.leaving()
	end
	return stage ~= nil and stage ~= "waiting"
end

-- The one "screen free" test: no wash, no recap, no window, no dim step or bubble, no cat held, no opening.
function AskController.free(): boolean
	return not (
		UI.busy()
		or UI.bubbleShown()
		or catInTub()
		or player:GetAttribute(CarryRules.ATTRIBUTE) == CarryRules.ARMS
		or player:GetAttribute(SudsRules.BOX_ATTRIBUTE) == true
		or SudsRules.cleanStage(player:GetAttribute(SudsRules.ATTRIBUTE)) == SudsRules.BOX
	)
end

function AskController.want(id: string, show: () -> (), hide: (() -> ())?): boolean
	if not AskController.on() then
		return false
	end
	if not AskRules.want(queue, id, os.clock()) then
		return false
	end
	entries[id] = { show = show, hide = hide }
	return true
end

function AskController.done(id: string, answer: AskRules.Answer)
	AskRules.done(queue, id, answer, os.clock())
	if queue.shown ~= id and queue.waiting[id] == nil then
		entries[id] = nil
	end
end

function AskController.drop(id: string)
	AskRules.drop(queue, id)
	if queue.shown ~= id then
		entries[id] = nil
	end
end

-- The ask up now, or nil.
function AskController.shown(): string?
	return queue.shown
end

local function clear()
	local up = queue.shown
	local entry = if up then entries[up] else nil
	local refused = queue.refused
	queue = AskRules.new()
	queue.refused = refused -- a no stays a no for the visit
	entries = {}
	freeSince = -math.huge
	if entry and entry.hide then
		task.spawn(entry.hide)
	end
end

local function tick()
	if not AskController.on() then
		return
	end
	local now = os.clock()
	if AskRules.stale(queue, now) then
		local up = queue.shown :: string
		AskRules.done(queue, up, "closed", now)
		entries[up] = nil
	end
	if queue.shown ~= nil or next(queue.waiting) == nil then
		freeSince = -math.huge
		return
	end
	if not AskController.free() then
		freeSince = -math.huge
		return
	end
	if freeSince == -math.huge then
		freeSince = now
	end
	if now - freeSince < SETTLE_SECONDS then
		return
	end
	local id = AskRules.pick(queue, now, true)
	if id == nil then
		return
	end
	freeSince = -math.huge
	local entry = entries[id]
	if AskRules.QUIET[id] then
		entries[id] = nil
	end
	if entry then
		local show = entry.show
		local ok, err: any = pcall(function()
			show()
		end)
		if not ok then
			warn(`AskController: {id} failed to show: {err}`)
			AskController.done(id, "closed")
		end
	else
		AskController.done(id, "closed")
	end
end

function AskController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
end

function AskController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. AskRules.FLAG)
		:Connect(function()
			if not AskController.on() then
				clear()
			end
		end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			tick()
		end
	end)
end

return AskController
