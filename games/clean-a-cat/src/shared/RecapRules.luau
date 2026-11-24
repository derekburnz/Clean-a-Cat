--!strict
-- RecapRules: what the recap card shows after a customer's cat goes home (#224, switch recapCard). Pure, so
-- tests/specs/RecapRules.spec.luau covers it. The server builds a Recap from what it really paid and sends it
-- with PhotoPaid; the client only cleans and shows it, so it never works out a payment itself.
--
-- The card has two sizes: the full card, and a slim strip so a session of many cats is not many windows to close.
-- The two values that choose between them are FULL_BELOW_STARS and FULL_FROM_RARITY, here and nowhere else.
-- XP, a 3-star wash grade and a quick-job bonus are not in the game yet, so the card has no rows for them.
local CatRules = require(script.Parent:WaitForChild("CatRules"))

local RecapRules = {}

-- The full card shows while the spa has fewer than this many stars: a player's first customers, since a Common or
-- Uncommon cat earns 1 star each (a Rare one earlier on makes it fewer, and gets the full card anyway).
RecapRules.FULL_BELOW_STARS = 3
-- The full card always shows for a cat of this rarity or rarer.
RecapRules.FULL_FROM_RARITY = "Rare"

-- Above any real payment; a bigger number from the network is refused rather than shown.
local MAX_AMOUNT = 1_000_000
local MAX_STARS = 99
local MAX_NAME = 24

export type Recap = {
	cat: string, -- the cat's name (a CatRules.ROSTER entry)
	rarity: string, -- one of CatRules.RARITIES
	coins: number, -- the customer's pay for the wash
	tip: number, -- the customer's tip
	bonus: number, -- extra pay from built stations, 0 when there is none
	stars: number, -- the spa stars this customer gave
	isNew: boolean, -- the cat's first Washed stamp in the Cat Index
	full: boolean, -- the full card, or the slim strip
	mascot: boolean, -- the opening's kitten (SudsRules, #285): his name and score only, no rarity and no coins
}

export type Row = { key: string, say: string, value: number }

local function rank(rarity: string): number?
	return table.find(CatRules.RARITIES, rarity)
end

-- Whether a customer gets the full card: the spa's stars before this customer paid, and the cat's rarity.
function RecapRules.isFull(starsBefore: number, rarity: string): boolean
	if starsBefore < RecapRules.FULL_BELOW_STARS then
		return true
	end
	local own, from = rank(rarity), rank(RecapRules.FULL_FROM_RARITY)
	return own ~= nil and from ~= nil and own >= from
end

-- The server's recap for one customer, from what it paid.
function RecapRules.make(
	cat: string,
	pay: CatRules.Pay,
	bonus: number,
	starsBefore: number,
	isNew: boolean
): Recap
	local rarity = CatRules.rarityOf(cat) or "Common"
	return {
		cat = cat,
		rarity = rarity,
		coins = pay.coins,
		tip = pay.tip,
		bonus = bonus,
		stars = pay.stars,
		isNew = isNew,
		full = RecapRules.isFull(starsBefore, rarity),
		mascot = false,
	}
end

-- The card for the opening's kitten at his naming: the full card with his name and his score (always the same
-- stars), nothing paid and no Cat Index stamp.
function RecapRules.mascot(name: string, stars: number): Recap
	return {
		cat = name,
		rarity = "Common",
		coins = 0,
		tip = 0,
		bonus = 0,
		stars = stars,
		isNew = false,
		full = true,
		mascot = true,
	}
end

-- Every coin the customer paid.
function RecapRules.total(recap: Recap): number
	return recap.coins + recap.tip + recap.bonus
end

-- The card's coin rows, in order; a row worth 0 is left out.
function RecapRules.rows(recap: Recap): { Row }
	local rows: { Row } = {}
	local function add(key: string, say: string, value: number)
		if value > 0 then
			table.insert(rows, { key = key, say = say, value = value })
		end
	end
	add("wash", "Washed and dried", recap.coins)
	add("tip", "Happy owner tip", recap.tip)
	add("bonus", "Spa stations bonus", recap.bonus)
	return rows
end

local function amount(raw: unknown, max: number): number?
	if type(raw) ~= "number" or raw ~= raw or raw < 0 or raw > max then
		return nil
	end
	return math.floor(raw)
end

-- The client's check of a recap from the network: a well-formed Recap, or nil to show nothing.
function RecapRules.clean(raw: unknown): Recap?
	if type(raw) ~= "table" then
		return nil
	end
	local t = raw :: { [any]: any }
	local cat: unknown = t.cat
	local rarity: unknown = t.rarity
	if type(cat) ~= "string" or #cat == 0 or #cat > MAX_NAME then
		return nil
	end
	if type(rarity) ~= "string" or rank(rarity) == nil then
		return nil
	end
	local coins, tip, bonus =
		amount(t.coins, MAX_AMOUNT), amount(t.tip, MAX_AMOUNT), amount(t.bonus, MAX_AMOUNT)
	local stars = amount(t.stars, MAX_STARS)
	if coins == nil or tip == nil or bonus == nil or stars == nil then
		return nil
	end
	return {
		cat = cat,
		rarity = rarity,
		coins = coins,
		tip = tip,
		bonus = bonus,
		stars = stars,
		isNew = t.isNew == true,
		full = t.full == true,
		mascot = t.mascot == true,
	}
end

return RecapRules
