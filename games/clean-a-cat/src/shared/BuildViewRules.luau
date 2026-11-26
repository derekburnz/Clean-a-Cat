--!strict
-- BuildViewRules: what the Build window (UI/BuildWindow, issue 751, Derek 2026-11-26: the tidy HUD "looks like its
-- missing build/upgrades") shows, from BuildRules, ToolRules and BowRules. Two lists: the builds the Builds board
-- offers, in its order, and the upgrades the Tools board sells (each tool, then the next bow). Each row says what it
-- is, what it costs or how long is left, and whether it can be started now as far as the client knows (the server
-- checks again). Nothing here sells Robux: Finish now stays on the board. Pure, so
-- tests/specs/BuildViewRules.spec.luau covers it.
local BowRules = require(script.Parent:WaitForChild("BowRules"))
local BuildRules = require(script.Parent:WaitForChild("BuildRules"))
local ToolRules = require(script.Parent:WaitForChild("ToolRules"))

local BuildViewRules = {}

BuildViewRules.WINDOW = "Build"
BuildViewRules.FLAG = "buildWindow"
BuildViewRules.TITLE = "Build and upgrades"
BuildViewRules.BUILDS_FLAG = "builds" -- the Builds board's switch: no builds without it
BuildViewRules.TOOLS_FLAG = "toolsBoard" -- the Tools board's: no tools or bows without it

-- "buy": the button shows; "running": counting down; "locked": waits for something else; "done": built or owned
export type Row = {
	kind: string, -- "build", "tool" or "bow"
	id: string, -- a BuildRules id, a ToolRules id or a BowRules tier
	name: string,
	say: string,
	state: string,
	action: string?, -- the button's words while state is "buy"
	icon: string, -- an Icons name
}

type IsOn = (flag: string) -> boolean

-- "45s", "5m", "1h 30m", "8h", "1d 2h": the largest two parts, never more.
function BuildViewRules.time(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local days = s // 86400
	local hours = (s % 86400) // 3600
	local minutes = (s % 3600) // 60
	if days > 0 then
		return if hours > 0 then `{days}d {hours}h` else `{days}d`
	elseif hours > 0 then
		return if minutes > 0 then `{hours}h {minutes}m` else `{hours}h`
	elseif minutes > 0 then
		return `{minutes}m`
	end
	return `{s % 60}s`
end

-- The build rows. `builds` is BuildRules.cleanBuilds output, `built[id]` true once built, `now` the server's time,
-- `builders` 2 with the Second Builder pass.
function BuildViewRules.builds(
	builds: { [string]: BuildRules.Build },
	built: { [string]: boolean },
	now: number,
	isOn: IsOn,
	builders: number?
): { Row }
	local out: { Row } = {}
	if not isOn(BuildViewRules.BUILDS_FLAG) then
		return out
	end
	local oneBuilder = isOn(BuildRules.TUBS_FLAG) and (builders or 1) < 2
	local anyRunning: BuildRules.Build? = nil
	for _, slot in BuildRules.SLOTS do
		anyRunning = anyRunning or builds[slot]
	end
	for _, id in BuildRules.offered(isOn) do
		local item = BuildRules.item(id, isOn)
		if item then
			local running: BuildRules.Build? = builds[item.slot]
			if oneBuilder and running == nil then
				running = anyRunning
			end
			local row: Row = {
				kind = "build",
				id = id,
				name = item.name,
				say = "",
				state = "buy",
				action = nil,
				icon = "Build",
			}
			local before = item.requires
			if built[id] then
				row.state, row.say = "done", "Built"
			elseif running and running.item == id then
				row.state, row.say =
					"running", `Ready in {BuildViewRules.time(running.endsAt - now)}`
			elseif before and not built[before] then
				local first = BuildRules.ITEMS[before]
				row.state, row.say =
					"locked", `Build the {if first then first.name else before} first`
			elseif running then
				local busy = BuildRules.ITEMS[running.item]
				row.state, row.say =
					"locked", `Wait for the {if busy then busy.name else "build"} to finish`
			else
				row.say = `{item.price} coins · {BuildViewRules.time(item.seconds)}`
				row.action = "Build"
			end
			table.insert(out, row)
		end
	end
	return out
end

-- The upgrade rows: each tool on sale (owned ones say so), then the next bow tier after `bowTier` (or the best bow).
function BuildViewRules.upgrades(
	isOn: IsOn,
	owns: (id: string) -> boolean,
	bowTier: string?
): { Row }
	local out: { Row } = {}
	if not isOn(BuildViewRules.TOOLS_FLAG) then
		return out
	end
	for _, id in ToolRules.offered(isOn) do
		local tool = ToolRules.TOOLS[id]
		local mine = owns(id)
		table.insert(out, {
			kind = "tool",
			id = id,
			name = tool.name,
			say = if mine then "Yours" else `{tool.price} coins`,
			state = if mine then "done" else "buy",
			action = if mine then nil else "Buy",
			icon = "Tools",
		})
	end
	if isOn(BowRules.FLAG) then
		local tier = BowRules.clean(bowTier) or BowRules.FIRST
		local bows: { [string]: boolean } = {}
		for _, each in BowRules.TIERS do
			bows[each] = true
			if each == tier then
				break
			end
		end
		local nextTier = BowRules.nextTier(bows)
		if nextTier then
			local info = BowRules.TIER[nextTier]
			table.insert(out, {
				kind = "bow",
				id = nextTier,
				name = `{info.name} bow`,
				say = `{info.price} coins · +{info.bonus} a cat`,
				state = "buy",
				action = "Buy",
				icon = "Bow",
			})
		else
			local best = BowRules.TIER[tier]
			table.insert(out, {
				kind = "bow",
				id = tier,
				name = `{best.name} bow`,
				say = "The best bow, yours",
				state = "done",
				action = nil,
				icon = "Bow",
			})
		end
	end
	return out
end

return BuildViewRules
