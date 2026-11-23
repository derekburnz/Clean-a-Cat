--!strict
-- ToolRules: the tools on the Tools board, bought once with coins and kept forever (save.tools). Pure, so
-- tests/specs/ToolRules.spec.luau covers it; ToolService checks a purchase with it on the server and the scrub
-- reads the owned tools on the client. Prices are draft tuning from the first session plan.

local ToolRules = {}

export type Tool = {
	name: string, -- what the board and notices say
	price: number, -- coins
	spongeRadius: number?, -- studs; a wider scrub than ScrubRules.SPONGE_RADIUS
}

ToolRules.TOOLS = table.freeze({
	BubbleSoap = table.freeze({ name = "Bubble Soap", price = 30, spongeRadius = 1.4 }) :: Tool,
}) :: { [string]: Tool }

ToolRules.IDS = table.freeze({ "BubbleSoap" }) -- board order; every id is a key of TOOLS
ToolRules.ATTRIBUTE_PREFIX = "Tool_" -- the server sets Player attribute Tool_<id> = true for each owned tool
ToolRules.BOARD_POSITION = Vector3.new(-6, 0, -12) -- on the floor beside the tub (placeholder room)
ToolRules.PROMPT_REACH = 10 -- studs; the board's prompt shows within this distance
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
