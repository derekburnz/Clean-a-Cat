--!strict
-- IndexRules: the Cat Index. Each of the ten cats gets a Washed stamp the first time one is cleaned and a
-- Resident stamp the first time one lives in the display window. Washing all ten pays a bonus once. Pure, so
-- tests/specs/IndexRules.spec.luau covers it; IndexService stamps on the server. The bonus is draft tuning.

local IndexRules = {}

IndexRules.BONUS_COINS = 100 -- paid once, when every cat on the roster has its Washed stamp

export type Entry = { washed: boolean, resident: boolean }
export type Stamp = "washed" | "resident"

-- The save's index with only well formed entries for real cats (`isCat`), so code can trust it.
function IndexRules.clean(raw: unknown, isCat: (name: string) -> boolean): { [string]: Entry }
	local out: { [string]: Entry } = {}
	if type(raw) ~= "table" then
		return out
	end
	for name, entry in raw :: { [unknown]: unknown } do
		if type(name) == "string" and isCat(name) and type(entry) == "table" then
			local e = entry :: { [string]: unknown }
			out[name] = { washed = e.washed == true, resident = e.resident == true }
		end
	end
	return out
end

-- Stamps `cat` in `index`. True only when the stamp is new.
function IndexRules.stamp(index: { [string]: Entry }, cat: string, stamp: Stamp): boolean
	local entry = index[cat]
	if entry == nil then
		entry = { washed = false, resident = false }
		index[cat] = entry
	end
	local e = entry :: Entry
	if stamp == "washed" then
		if e.washed then
			return false
		end
		e.washed = true
	else
		if e.resident then
			return false
		end
		e.resident = true
	end
	return true
end

-- How many of `cats` have the Washed stamp.
function IndexRules.washedCount(index: { [string]: Entry }, cats: { string }): number
	local count = 0
	for _, cat in cats do
		local entry = index[cat]
		if entry and entry.washed then
			count += 1
		end
	end
	return count
end

-- True when every cat in `cats` has the Washed stamp.
function IndexRules.complete(index: { [string]: Entry }, cats: { string }): boolean
	return #cats > 0 and IndexRules.washedCount(index, cats) == #cats
end

return table.freeze(IndexRules)
