--!strict
-- IndexViewRules: what the Cat Index window shows (#238, from Design-Agent's catindex.html, switch
-- catIndexWindow). Pure, so tests/specs/IndexViewRules.spec.luau covers it. It reads the stamps IndexService sends
-- (IndexRules entries) and the same chances the chance board prints (CatRules.boardLines), so a chance shown here is
-- always the real one. It never decides a stamp.
local CatRules = require(script.Parent:WaitForChild("CatRules"))
local IndexRules = require(script.Parent:WaitForChild("IndexRules"))

local IndexViewRules = {}

export type Card = {
	cat: string,
	rarity: string,
	seen: boolean, -- washed at least once: shows the cat; otherwise a silhouette with the rarity word, never a name
	washed: boolean,
	resident: boolean,
	isNew: boolean,
}

-- Every cat on the roster, rarest last and in roster order within a rarity; `filter` is "All" or one rarity.
function IndexViewRules.cards(
	entries: { [string]: IndexRules.Entry },
	filter: string,
	newCats: { [string]: boolean }?
): { Card }
	local cards: { Card } = {}
	-- The special visitors' cats have their own page (the Special tab); "All" stays the customers' set.
	if filter == CatRules.SPECIAL then
		for _, cat in CatRules.SPECIAL_CATS do
			local entry = entries[cat]
			local washed = entry ~= nil and entry.washed
			table.insert(cards, {
				cat = cat,
				rarity = CatRules.SPECIAL,
				seen = washed,
				washed = washed,
				resident = entry ~= nil and entry.resident,
				isNew = washed and newCats ~= nil and newCats[cat] == true,
			})
		end
		return cards
	end
	for _, rarity in CatRules.RARITIES do
		if filter == "All" or filter == rarity then
			for _, cat in CatRules.ROSTER[rarity] do
				local entry = entries[cat]
				local washed = entry ~= nil and entry.washed
				table.insert(cards, {
					cat = cat,
					rarity = rarity,
					seen = washed,
					washed = washed,
					resident = entry ~= nil and entry.resident,
					isNew = washed and newCats ~= nil and newCats[cat] == true,
				})
			end
		end
	end
	return cards
end

-- Every cat on the roster, in the order cards() lists them.
function IndexViewRules.allCats(): { string }
	local cats = {}
	for _, rarity in CatRules.RARITIES do
		for _, cat in CatRules.ROSTER[rarity] do
			table.insert(cats, cat)
		end
	end
	return cats
end

-- (washed, total) of the special visitors' cats, for the Special page.
function IndexViewRules.specialProgress(entries: { [string]: IndexRules.Entry }): (number, number)
	return IndexRules.washedCount(entries, CatRules.SPECIAL_CATS), #CatRules.SPECIAL_CATS
end

-- (washed, total) for the "Wash all 10" bar.
function IndexViewRules.progress(entries: { [string]: IndexRules.Entry }): (number, number)
	local cats = IndexViewRules.allCats()
	return IndexRules.washedCount(entries, cats), #cats
end

-- The detail's Chance line at the player's star tier, from the chance board's own numbers.
function IndexViewRules.chanceLine(rarity: string, tier: number?): string
	if rarity == CatRules.SPECIAL then
		return "Only special visitors bring these cats"
	end
	for _, line in CatRules.boardLines(tier) do
		if line.rarity == rarity then
			return `{rarity} cats: {CatRules.percentText(line.percent)} of customers`
		end
	end
	return `{rarity} cats`
end

-- The cats washed for the first time in `now` that were not in `before` (the window's New! marks).
function IndexViewRules.newlyWashed(
	before: { [string]: IndexRules.Entry },
	now: { [string]: IndexRules.Entry }
): { string }
	local fresh = {}
	for cat, entry in now do
		local old = before[cat]
		if entry.washed and not (old ~= nil and old.washed) then
			table.insert(fresh, cat)
		end
	end
	table.sort(fresh)
	return fresh
end

return IndexViewRules
