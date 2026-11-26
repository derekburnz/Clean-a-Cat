--!strict
-- WorkerRules: the spa's helpers (issue 509, switch workers). The owner's picks on the plan page, 2026-11-25: "the
-- helpers just periodically take whichever is next in line any rarity", they "also get bonuses ... but make it much
-- less and make them take longer the dirtier the cat is", with a "mode" the player sets ("prioritize cats about to
-- leave, rarest cats, dirtiest cats first, cats that are first in line"), and "the worker comes with the station".
-- One purchase hires a worker with their own station beside the player's tub. A worker takes a waiting customer's
-- cat from the line by their mode, washes it at their station for a while (longer the dirtier) and pays a share of
-- the wash's coins: no wash stars, no early pick, no bow and no tip (tuning worker.share), and no spa stars.
-- Lou is the third worker and comes with a game pass (issue 518), never for coins.
-- The numbers are Design-Agent's in docs/design/clean-a-cat/tuning.md, section 7; change them there and here
-- together, and re-run its guard rail sum. Pure, so tests/specs/WorkerRules.spec.luau covers it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))
local DirtRules = require(script.Parent:WaitForChild("DirtRules"))

local WorkerRules = {}

WorkerRules.FLAG = "workers"
WorkerRules.POPUP_FLAG = "helperPopups" -- a helper's pay goes to the HelperPaid remote (a popup over their stand), no toast
WorkerRules.HUD_TIDY_FLAG = "hudTidy" -- the stand's Level up prompt leaves the world: levels are bought in the Helpers window
WorkerRules.PROGRESS_ATTRIBUTE = "WorkerProgress" -- 0 to 1 on the cat a worker washes (Motion-FX's WorkerBar)
WorkerRules.WORKER_ATTRIBUTE = "Worker" -- the worker's id on that cat and on their station
WorkerRules.WASHING_ATTRIBUTE = "Washing" -- true on the staff model while they wash a cat (Motion-FX's staff motion)
WorkerRules.FOLDER = "Workers" -- each plot's folder of worker stations and pads
WorkerRules.PROMPT_REACH = 10 -- studs; the station's prompts show within this distance
WorkerRules.SERVER_REACH = 16 -- studs; the server's distance check, with room for lag

-- In the order they are offered.
WorkerRules.IDS = table.freeze({ "Jo", "Sam", "Lou" }) :: { string }

export type Info = {
	name: string,
	price: number?, -- coins, nil for a pass worker
	pass: boolean, -- comes with a game pass, never sold for coins
	spot: string, -- their station's spot in the plot (the plot's Attachment, else SpaLayout.PLOT_SPOTS)
	stand: string, -- their wash stand, Model-Agent's model (Attachments CatSeat and WorkerSpot, attribute CatScale)
}

local JO: Info = {
	name = "Jo",
	price = 150,
	pass = false,
	spot = "SpotWorkerJo",
	stand = "CleanACat_Station_WashStandJo",
}
local SAM: Info = {
	name = "Sam",
	price = 1200,
	pass = false,
	spot = "SpotWorkerSam",
	stand = "CleanACat_Station_WashStandSam",
}
local LOU: Info = {
	name = "Lou",
	price = nil,
	pass = true,
	spot = "SpotWorkerLou",
	stand = "CleanACat_Station_WashStandLou",
}
WorkerRules.WORKERS = table.freeze({
	Jo = table.freeze(JO),
	Sam = table.freeze(SAM),
	Lou = table.freeze(LOU),
}) :: { [string]: Info }

-- Jo's price with the switch joPrice on (issue 841): today's early gifts (the check in's 50 at 3:45, the like
-- reward's 150 from the first special visitor, quests from 6:00) put a 150 coin Jo at about cat 6; at 300 he lands
-- at about cat 10 to 15, near the tenth minute (tuning worker.Jo.price).
WorkerRules.PRICE_FLAG = "joPrice"
WorkerRules.JO_PRICE = 300

-- The coins worker `id` costs as the switches `isOn` make it; nil for a pass worker or an unknown id.
function WorkerRules.priceOf(id: string, isOn: ((flag: string) -> boolean)?): number?
	local info = WorkerRules.WORKERS[id]
	if info == nil or info.price == nil then
		return nil
	end
	if id == "Jo" and isOn ~= nil and isOn(WorkerRules.PRICE_FLAG) then
		return WorkerRules.JO_PRICE
	end
	return info.price
end

-- The modes, the default first, with the words the station shows.
WorkerRules.MODES = table.freeze({ "first", "leaving", "rarest", "dirtiest" }) :: { string }
WorkerRules.MODE_NAMES = table.freeze({
	first = "First in line",
	leaving = "About to leave",
	rarest = "Rarest first",
	dirtiest = "Dirtiest first",
}) :: { [string]: string }
WorkerRules.DEFAULT_MODE = "first"

-- Seconds a level 1 worker takes for a cat at each dirt level (tuning worker.washSeconds).
WorkerRules.WASH_SECONDS = table.freeze({ 50, 75, 110, 150 }) :: { number }
WorkerRules.LEVEL_SPEED = 0.05 -- each level above 1 takes this much off the wash time
WorkerRules.MAX_LEVEL = 5
-- Coins to reach each level (tuning worker.levelCost).
WorkerRules.LEVEL_COST =
	table.freeze({ [2] = 200, [3] = 500, [4] = 1200, [5] = 3000 }) :: { [number]: number }
WorkerRules.SHARE = 0.25 -- of base x dirt at level 1
WorkerRules.SHARE_STEP = 0.03 -- more for each level above 1
-- Seconds the clean cat stays at the station after the bar fills, before it goes home and the worker pays.
WorkerRules.SHOW_DONE_SECONDS = 1.5
-- Seconds a customer the player picked to go next is kept from the workers (tuning worker.reserve); it is theirs
-- for good once it reaches the tub, as it leaves the line then.
WorkerRules.RESERVE_SECONDS = 15

-- A waiting customer as a worker sees the line.
export type Entry = {
	kind: string,
	dirt: number,
	left: number, -- the heart bar left, 0 to 1 (1 while bars are off)
	reserved: boolean?, -- the player picked it to go next (RESERVE_SECONDS): never taken
}

function WorkerRules.cleanMode(raw: unknown): string?
	if type(raw) ~= "string" or WorkerRules.MODE_NAMES[raw] == nil then
		return nil
	end
	return raw
end

function WorkerRules.cleanLevel(raw: unknown): number
	if type(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 then
		return 1
	end
	return math.clamp(raw, 1, WorkerRules.MAX_LEVEL)
end

-- The mode after `mode`, for the station's tap to change it.
function WorkerRules.nextMode(mode: string?): string
	local at = table.find(
		WorkerRules.MODES,
		WorkerRules.cleanMode(mode) or WorkerRules.DEFAULT_MODE
	) :: number
	return WorkerRules.MODES[at % #WorkerRules.MODES + 1]
end

-- Seconds a worker at `level` takes for a cat at dirt level `dirt`.
function WorkerRules.washSeconds(dirt: number, level: number): number
	local base = WorkerRules.WASH_SECONDS[DirtRules.clean(dirt) or 1]
	return base * (1 - WorkerRules.LEVEL_SPEED * (WorkerRules.cleanLevel(level) - 1))
end

-- What a worker at `level` earns for a cat of `kind` at dirt level `dirt`: their share of the wash's coins times the
-- dirt's pay, rounded, at least 1.
function WorkerRules.pay(kind: string, dirt: number, level: number): number
	local base = CatRules.pay(kind).coins * DirtRules.PAY[DirtRules.clean(dirt) or 1]
	local share = WorkerRules.SHARE + WorkerRules.SHARE_STEP * (WorkerRules.cleanLevel(level) - 1)
	return math.max(1, math.floor(base * share + 0.5))
end

local function rank(kind: string): number
	return table.find(CatRules.RARITIES, CatRules.rarityOf(kind) or "Common") or 1
end

-- Which waiting customer (their place in `line`) a worker in `mode` takes next, or nil when nobody can be taken. A
-- reserved customer is skipped. Ties go to the one nearer the front.
function WorkerRules.pick(mode: string?, line: { Entry }): number?
	local chosen = WorkerRules.cleanMode(mode) or WorkerRules.DEFAULT_MODE
	local best: number? = nil
	local bestScore = -math.huge
	for place, entry in line do
		if entry.reserved then
			continue
		end
		local score = if chosen == "leaving"
			then -entry.left
			elseif chosen == "rarest" then rank(entry.kind)
			elseif chosen == "dirtiest" then entry.dirt
			else -place
		if score > bestScore then
			best, bestScore = place, score
		end
	end
	return best
end

type Save = { coins: number, workers: { [string]: any } }

-- Whether `save` may hire worker `id` for coins now, and the words to show when not.
function WorkerRules.canHire(
	save: Save,
	id: string,
	isOn: ((flag: string) -> boolean)?
): (boolean, string?)
	local info = WorkerRules.WORKERS[id]
	local price = WorkerRules.priceOf(id, isOn)
	if info == nil or info.pass or price == nil then
		return false, "That helper can't be hired with coins"
	end
	if save.workers[id] ~= nil then
		return false, `{info.name} already works here`
	end
	if save.coins < price then
		return false, `{price - save.coins} more coins to hire {info.name}`
	end
	return true, nil
end

-- A new worker's save record.
function WorkerRules.newWorker(now: number): { mode: string, level: number, hiredAt: number }
	return { mode = WorkerRules.DEFAULT_MODE, level = 1, hiredAt = now }
end

-- Hires worker `id` for `save`. Returns the coins spent, 0 when they could not be hired.
function WorkerRules.hire(
	save: Save,
	id: string,
	now: number,
	isOn: ((flag: string) -> boolean)?
): number
	if not WorkerRules.canHire(save, id, isOn) then
		return 0
	end
	local price = WorkerRules.priceOf(id, isOn) :: number
	save.coins -= price
	save.workers[id] = WorkerRules.newWorker(now)
	return price
end

-- Hires pass worker `id` (Lou) for `save` once his pass is owned (PassService, issue 518): no coins, the same record
-- as any hire, and never twice. True when he was hired now.
function WorkerRules.hirePass(save: Save, id: string, now: number): boolean
	local info = WorkerRules.WORKERS[id]
	if info == nil or not info.pass or save.workers[id] ~= nil then
		return false
	end
	save.workers[id] = WorkerRules.newWorker(now)
	return true
end

-- The coins to take worker record `worker` up a level, or nil at the top.
function WorkerRules.levelCost(worker: { level: number }): number?
	return WorkerRules.LEVEL_COST[WorkerRules.cleanLevel(worker.level) + 1]
end

-- Takes worker `id` of `save` up a level. Returns the coins spent (0 when it could not), and the words when not.
function WorkerRules.levelUp(save: Save, id: string): (number, string?)
	local worker = save.workers[id]
	if worker == nil then
		return 0, "Hire them first"
	end
	local cost = WorkerRules.levelCost(worker)
	if cost == nil then
		return 0, `{WorkerRules.WORKERS[id].name} is at the top level`
	end
	if save.coins < cost then
		return 0, `{cost - save.coins} more coins`
	end
	save.coins -= cost
	worker.level = WorkerRules.cleanLevel(worker.level) + 1
	return cost, nil
end

export type Shown = { name: string, value: any }

-- The Player attributes that show `save`'s workers to the client (the stand's Takes and Level prompts, the Helpers
-- button and window): WorkerMode_<id> and WorkerLevel_<id> for every worker id, nil for one not hired. Set after a
-- join, a pass hire and a pad hire (issue 696: a pad hire set none, so nothing showed until a rejoin).
function WorkerRules.shown(save: Save): { Shown }
	local out: { Shown } = {}
	for _, id in WorkerRules.IDS do
		local worker: any = save.workers[id]
		table.insert(out, {
			name = `WorkerMode_{id}`,
			value = if worker then WorkerRules.cleanMode(worker.mode) else nil,
		})
		table.insert(out, {
			name = `WorkerLevel_{id}`,
			value = if worker then WorkerRules.cleanLevel(worker.level) else nil,
		})
	end
	return out
end

return table.freeze(WorkerRules)
