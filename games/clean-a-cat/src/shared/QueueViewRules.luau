--!strict
-- QueueViewRules: what the "Who's next?" window (#246, UI/QueueWindow) and the HUD's waiting faces show for the
-- customers at the door. Pure functions over what the client already has: the line the server sends
-- (CustomerQueue, front first), the player's Cat Index stamps and which stations are built. The server owns the
-- line and the picks (SpaService, SpaRules.pickNext); nothing here decides anything.
local CatRules = require(script.Parent:WaitForChild("CatRules"))
local DirtRules = require(script.Parent:WaitForChild("DirtRules"))
local HeartRules = require(script.Parent:WaitForChild("HeartRules"))
local IndexRules = require(script.Parent:WaitForChild("IndexRules"))
local SpaRules = require(script.Parent:WaitForChild("SpaRules"))

local QueueViewRules = {}

-- From this rarity up a waiting customer is a VIP: a glow and a crown on the card, and the window says how often
-- that rarity visits. Every row stays the same as on the other cards.
QueueViewRules.VIP_FROM = "Rare"

export type Card = {
	place: number, -- 1 is the front of the line (next out); the server's RequestPickCustomer takes 2..QUEUE_SIZE
	cat: string,
	rarity: string,
	needs: { CatRules.Need },
	locked: { [string]: boolean }, -- needs whose station is not built yet
	pays: number, -- the coins for the wash (the tip comes on top, for a clean job), times the dirt level's pay
	isNew: boolean, -- never washed: not in the Cat Index yet
	vip: boolean,
	dirt: number?, -- 1 to 4 while the dirt levels are on (DirtRules); nil while they are off
	steps: number, -- the steps this cat's wash shows (DirtRules.steps), the bow included
	heart: HeartRules.Heart?, -- the heart bar while heartBar is on (HeartRules.fill draws it); nil while it is off
}

-- The line as the server sent it, kept only if it is a list of real cats no longer than the line can be.
function QueueViewRules.clean(raw: unknown): { string }
	local out: { string } = {}
	if type(raw) ~= "table" then
		return out
	end
	for index = 1, SpaRules.QUEUE_SIZE do
		local kind = (raw :: { [number]: unknown })[index]
		if type(kind) ~= "string" or CatRules.rarityOf(kind) == nil then
			break
		end
		table.insert(out, kind)
	end
	return out
end

-- What each waiting cat needs, as the server sent it beside the line (#267), place by place. A place whose list is
-- not a list of known needs (each a key of CatRules.NEED_STATION, at most once) is left out, and its card falls back
-- to the cat's rarity's needs.
function QueueViewRules.cleanNeeds(raw: unknown): { [number]: { CatRules.Need } }
	local out: { [number]: { CatRules.Need } } = {}
	if type(raw) ~= "table" then
		return out
	end
	for place = 1, SpaRules.QUEUE_SIZE do
		local list = (raw :: { [number]: unknown })[place]
		if type(list) ~= "table" then
			continue
		end
		local needs: { CatRules.Need } = {}
		local ok = true
		for index = 1, #(list :: { unknown }) do
			local need = (list :: { [number]: unknown })[index]
			if
				type(need) ~= "string"
				or CatRules.NEED_STATION[need] == nil
				or table.find(needs, need) ~= nil
			then
				ok = false
				break
			end
			table.insert(needs, need)
		end
		if ok and #needs > 0 then
			out[place] = needs
		end
	end
	return out
end

-- Each waiting cat's dirt level, as the server sent it beside the line (switch dirtLevels), place by place; a place
-- without a level 1 to 4 is left out.
function QueueViewRules.cleanDirt(raw: unknown): { [number]: number }
	local out: { [number]: number } = {}
	if type(raw) ~= "table" then
		return out
	end
	for place = 1, SpaRules.QUEUE_SIZE do
		local level = DirtRules.clean((raw :: { [number]: unknown })[place])
		if level then
			out[place] = level
		end
	end
	return out
end

-- Each waiting cat's heart bar, as the server sent it beside the line (switch heartBar), place by place.
function QueueViewRules.cleanHearts(raw: unknown): { [number]: HeartRules.Heart }
	local out: { [number]: HeartRules.Heart } = {}
	if type(raw) ~= "table" then
		return out
	end
	for place = 1, SpaRules.QUEUE_SIZE + 1 do -- the line plus a customer still at the door
		local heart = HeartRules.cleanHeart((raw :: { [number]: unknown })[place])
		if heart then
			out[place] = heart
		end
	end
	return out
end

function QueueViewRules.isVip(rarity: string): boolean
	local from = table.find(CatRules.RARITIES, QueueViewRules.VIP_FROM) :: number
	local at = table.find(CatRules.RARITIES, rarity)
	return at ~= nil and at >= from
end

-- One card per customer in `line` (front first). `rolled` is each place's needs as the server rolled them
-- (cleanNeeds); a place without one shows its rarity's needs. `dirt` is each place's dirt level (cleanDirt) while the
-- dirt levels are on: the card then pays the level's pay and no need is locked.
function QueueViewRules.cards(
	line: { string },
	entries: { [string]: IndexRules.Entry },
	built: { [string]: boolean },
	rolled: { [number]: { CatRules.Need } }?,
	dirt: { [number]: number }?,
	hearts: { [number]: HeartRules.Heart }?
): { Card }
	local out: { Card } = {}
	for place, cat in line do
		local rarity = CatRules.rarityOf(cat) or "Common"
		local given: { CatRules.Need }? = if rolled then rolled[place] else nil
		local needs = if given then table.clone(given) else CatRules.needs(cat)
		local level: number? = if dirt then dirt[place] else nil
		local locked: { [string]: boolean } = {}
		if level == nil then
			for _, need in CatRules.lockedNeeds(needs, built) do
				locked[need] = true
			end
		end
		local entry: IndexRules.Entry? = entries[cat]
		table.insert(out, {
			place = place,
			cat = cat,
			rarity = rarity,
			needs = needs,
			locked = locked,
			pays = DirtRules.pay(CatRules.pay(cat), level).coins,
			isNew = not (entry ~= nil and entry.washed),
			vip = QueueViewRules.isVip(rarity),
			dirt = level,
			steps = DirtRules.steps(needs),
			heart = if hearts then hearts[place] else nil,
		})
	end
	return out
end

-- The window's line under the title: how often the rarest VIP in the line visits, with the chance board's own
-- numbers at the player's star tier (CatRules.boardLines, the same source as the board), or the plain ask.
function QueueViewRules.headline(cards: { Card }, tier: number?): string
	local rarest: string? = nil
	for _, card in cards do
		if
			card.vip
			and (
				rarest == nil
				or table.find(CatRules.RARITIES, card.rarity) :: number
					> (table.find(CatRules.RARITIES, rarest) :: number)
			)
		then
			rarest = card.rarity
		end
	end
	if rarest ~= nil then
		for _, line in CatRules.boardLines(tier) do
			if line.rarity == rarest then
				local article = if string.find(rarest, "^[AEIOU]") then "An" else "A"
				return `{article} {rarest} cat is here · {CatRules.percentText(line.percent)} of customers`
			end
		end
	end
	return "Pick a cat to wash"
end

-- Whether the card at `place` gets a Wash next button: never the front (it is already next), and only while the
-- server would take the pick (the queuePick switch on and a customer already served).
function QueueViewRules.canPick(place: number, pickOn: boolean, served: boolean): boolean
	return pickOn and served and place >= 2 and place <= SpaRules.QUEUE_SIZE
end

return table.freeze(QueueViewRules)
