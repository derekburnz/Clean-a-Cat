--!strict
-- LineLooks: which look (hat, scarf, tote) each customer waiting at the door wears, so a look stays with its
-- customer as the line moves (#206). Pure, so tests/specs/LineLooks.spec.luau covers it; FigureService keeps one Line
-- per player. A look number n is drawn as FigureService's LOOKS[n % #LOOKS + 1].
--
-- The serve and the pick are told explicitly (SpaService calls FigureService.served and .picked), never guessed from
-- the kinds: when every waiting cat is the same kind, a pick and a serve both look like "nothing changed".
local LineLooks = {}

export type Line = {
	kinds: { string }, -- the waiting cats, front first, as last seen
	looks: { number }, -- each customer's look number, parallel to kinds
	nextLook: number, -- the look number the next new customer gets
}

-- The line for the newly sent `kinds`: customers already known keep their looks, matched from the front. Everyone
-- past the first difference is new and takes the next look numbers. Always returns new tables.
function LineLooks.show(line: Line?, kinds: { string }): Line
	local looks: { number } = {}
	local nextLook = if line then line.nextLook else 0
	if line then
		for index, kind in kinds do
			local look = line.looks[index]
			if line.kinds[index] ~= kind or look == nil then
				break
			end
			looks[index] = look
		end
	end
	for index = #looks + 1, #kinds do
		looks[index] = nextLook
		nextLook += 1
	end
	return { kinds = table.clone(kinds), looks = looks, nextLook = nextLook }
end

-- The front customer handed over their cat of `kind`: they and their look leave. Nil when the line as last seen
-- does not start with that cat (then the next `show` treats the line as new from the first difference).
function LineLooks.served(line: Line?, kind: string): Line?
	if line == nil or line.kinds[1] ~= kind then
		return nil
	end
	return {
		kinds = table.move(line.kinds, 2, #line.kinds, 1, {}),
		looks = table.move(line.looks, 2, #line.looks, 1, {}),
		nextLook = line.nextLook,
	}
end

-- The customer at `index` was picked to go next: they move to the front with their look, the rest keep their order.
-- Nil when the index is not a place behind the front.
function LineLooks.picked(line: Line?, index: number): Line?
	if line == nil or index < 2 or index > #line.kinds or index ~= math.floor(index) then
		return nil
	end
	local kinds, looks = table.clone(line.kinds), table.clone(line.looks)
	local kind = table.remove(kinds, index) :: string
	table.insert(kinds, 1, kind)
	local look = table.remove(looks, index)
	if look ~= nil then
		table.insert(looks, 1, look)
	end
	return { kinds = kinds, looks = looks, nextLook = line.nextLook }
end

return LineLooks
