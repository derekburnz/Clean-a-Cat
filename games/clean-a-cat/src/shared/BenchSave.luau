--!strict
-- BenchSave: the waiting line kept in the save (issue 523, switch benchSave). Each time the line is sent, SpaService
-- writes who waits (save.bench: each customer's cat, its dirt level and its needs, front first); on the next join a
-- spa that has served before gets the same customers back, with full heart bars, so a rejoin never swaps the line the
-- player was looking at. A special visitor is never kept (they come by their own timer), nor a new spa's tutorial
-- line. A saved line is read back through `restore`, which keeps only well-formed entries, so a damaged save can only
-- lose a customer, never break the line.
-- Pure, so tests/specs/BenchSave.spec.luau covers it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))
local DirtRules = require(script.Parent:WaitForChild("DirtRules"))
local SpaRules = require(script.Parent:WaitForChild("SpaRules"))

local BenchSave = {}

BenchSave.FLAG = "benchSave"

export type Entry = { kind: string, dirt: number, needs: { string } }

-- What one waiting customer needs to be kept: their order's dirt, needs and whether they are a special visitor.
export type Waiting = { dirt: number, needs: { string }, special: boolean? }

-- The line to save, from the queue's kinds and their orders, front first; special visitors are left out.
function BenchSave.snapshot(kinds: { string }, orders: { Waiting }): { Entry }
	local out: { Entry } = {}
	for place, kind in kinds do
		local order = orders[place]
		if order and not order.special and #out < SpaRules.MAX_QUEUE then
			table.insert(out, { kind = kind, dirt = order.dirt, needs = table.clone(order.needs) })
		end
	end
	return out
end

-- The saved line made safe: every entry a known customer cat with a dirt level of 1 to 4 and known needs (at least
-- one), at most MAX_QUEUE of them. Anything else is dropped.
function BenchSave.restore(raw: unknown): { Entry }
	local out: { Entry } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, item in raw :: { any } do
		if #out >= SpaRules.MAX_QUEUE then
			break
		end
		if type(item) ~= "table" then
			continue
		end
		local kind: unknown = item.kind
		local dirt = DirtRules.clean(item.dirt)
		local rarity = if type(kind) == "string" then CatRules.rarityOf(kind) else nil
		if rarity == nil or rarity == "Special" or dirt == nil or type(item.needs) ~= "table" then
			continue
		end
		local needs: { string } = {}
		for _, need in item.needs :: { any } do
			if
				type(need) == "string"
				and CatRules.NEED_STATION[need]
				and not table.find(needs, need)
			then
				table.insert(needs, need)
			end
		end
		if #needs > 0 then
			table.insert(out, { kind = kind :: string, dirt = dirt, needs = needs })
		end
	end
	return out
end

return table.freeze(BenchSave)
