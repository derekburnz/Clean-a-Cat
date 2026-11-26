--!strict
-- ToolRules: the tools on the Tools board, bought once with coins and kept forever (save.tools). Pure, so
-- tests/specs/ToolRules.spec.luau covers it; ToolService checks a purchase with it on the server and the scrub
-- reads the owned tools on the client. Prices are draft tuning from the first session plan.

local WashDraft = require(script.Parent:WaitForChild("WashDraft"))
local WashPace = require(script.Parent:WaitForChild("WashPace"))

local ToolRules = {}

export type Tool = {
	name: string, -- what the board and notices say
	price: number, -- coins
	spongeRadius: number?, -- studs; a wider scrub than ScrubRules.SPONGE_RADIUS
	brushStrokes: number?, -- strokes that brush the tangles out, fewer than SpaRules.BRUSH_STROKES
	flag: string?, -- a LiveFlags switch: while it is off the tool is not offered (offered)
}

ToolRules.TOOLS = table.freeze({
	BubbleSoap = table.freeze({ name = "Bubble Soap", price = 30, spongeRadius = 1.4 }) :: Tool,
	ProBrush = table.freeze({ -- WashDraft (#267)
		name = WashDraft.PRO_BRUSH.name,
		price = WashDraft.PRO_BRUSH.price,
		brushStrokes = WashDraft.PRO_BRUSH.brushStrokes,
		flag = WashDraft.PRO_BRUSH.flag,
	}) :: Tool,
}) :: { [string]: Tool }

ToolRules.IDS = table.freeze({ "BubbleSoap", "ProBrush" }) -- board order; every id is a key of TOOLS
ToolRules.ATTRIBUTE_PREFIX = "Tool_" -- the server sets Player attribute Tool_<id> = true for each owned tool
ToolRules.PROMPT_REACH = 10 -- studs; the board's prompt shows within this distance
-- A buy on the board is a short hold, never a tap (issue 908: in the big spa one E press at the counter took the cat
-- and bought Bubble Soap off the board 9.6 studs away). A quick E for another prompt starts and ends the hold before it
-- buys anything; a pill tap holds the full time (PromptController), so phones still buy with one tap.
ToolRules.BUY_HOLD = 0.4
ToolRules.SERVER_REACH = 16 -- studs; the server's distance check, with room for lag

export type Wallet = {
	coins: number,
	tools: { [string]: boolean },
}

-- Can `wallet` buy tool `id`? Returns false plus a short reason the player can read.
function ToolRules.canBuy(wallet: Wallet, id: string): (boolean, string?)
	local tool = ToolRules.TOOLS[id]
	if tool == nil then
		return false, "Unknown tool"
	end
	if wallet.tools[id] then
		return false, "Already yours"
	end
	if not (wallet.coins >= tool.price) then
		return false, `Needs {tool.price} coins`
	end
	return true, nil
end

-- Takes the price and adds the tool when canBuy allows it. Returns the coins spent (0 when refused).
function ToolRules.buy(wallet: Wallet, id: string): number
	if not ToolRules.canBuy(wallet, id) then
		return 0
	end
	local price = ToolRules.TOOLS[id].price
	wallet.coins -= price
	wallet.tools[id] = true
	return price
end

-- The ids the board shows and the server takes: IDS less those whose switch `isOn` says is off.
function ToolRules.offered(isOn: (flag: string) -> boolean): { string }
	local out: { string } = {}
	for _, id in ToolRules.IDS do
		local flag = ToolRules.TOOLS[id].flag
		if flag == nil or isOn(flag) then
			table.insert(out, id)
		end
	end
	return out
end

-- The brush strokes for a player who owns the tools for which `owns(id)` is true: the fewest, `base` without one.
-- A tool whose switch is off (`isOn`) does not count, so turning it off puts the hand brush back. A tool's strokes
-- are of the old hand brush's 3; with a longer brushing (`base` more, switch washPace) they keep the same share.

function ToolRules.brushStrokes(
	base: number,
	owns: (id: string) -> boolean,
	isOn: (flag: string) -> boolean
): number
	local strokes = base
	for id, tool in ToolRules.TOOLS do
		local fewer = if tool.brushStrokes
			then WashPace.toolStrokes(tool.brushStrokes, base)
			else nil
		local flag = tool.flag
		if fewer and fewer < strokes and owns(id) and (flag == nil or isOn(flag)) then
			strokes = fewer
		end
	end
	return strokes
end

-- The sponge radius for a player who owns the tools for which `owns(id)` is true: the widest one.
function ToolRules.spongeRadius(base: number, owns: (id: string) -> boolean): number
	local radius = base
	for id, tool in ToolRules.TOOLS do
		local wider = tool.spongeRadius
		if wider and wider > radius and owns(id) then
			radius = wider
		end
	end
	return radius
end

return table.freeze(ToolRules)
