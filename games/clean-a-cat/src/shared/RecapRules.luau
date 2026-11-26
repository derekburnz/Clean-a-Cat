--!strict
-- RecapRules: what the recap card shows after a customer's cat goes home (#224, switch recapCard). Pure, so
-- tests/specs/RecapRules.spec.luau covers it. The server builds a Recap from what it really paid and sends it
-- with PhotoPaid; the client only cleans and shows it, so it never works out a payment itself.
--
-- The card has two sizes: the full card, and a slim strip so a session of many cats is not many windows to close.
-- The two values that choose between them are FULL_BELOW_STARS and FULL_FROM_RARITY, here and nowhere else.
-- XP, a 3-star wash grade and a quick-job bonus are not in the game yet, so the card has no rows for them.
local BowRules = require(script.Parent:WaitForChild("BowRules"))
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
	-- The pay formula's extra coins, one line each (HeartRules.pay, switches heartBar and dirtLevels); 0 or nil when
	-- off (nil in a recap made before these lines existed).
	speed: number?, -- for a quick wash (the wash grade)
	early: number?, -- for picking the cat early in its heart bar
	dirt: number?, -- for a dirtier cat
	grade: number?, -- the wash's stars, 1 to 3; 0 when there is no grade
	bow: number?, -- the bow tier's coins (switch bowTiers, BowRules); 0 or nil when off
	bowTier: string?, -- the tier that earned them, one of BowRules.TIERS, for the line's words
}

-- The pay formula's lines for make; each 0 when not given.
export type Extra = {
	speed: number?,
	early: number?,
	dirt: number?,
	grade: number?,
	bow: number?,
	bowTier: string?,
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
	isNew: boolean,
	extra: Extra?
): Recap
	local rarity = CatRules.rarityOf(cat) or "Common"
	local more: Extra = extra or {}
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
		speed = more.speed or 0,
		early = more.early or 0,
		dirt = more.dirt or 0,
		grade = more.grade or 0,
		bow = more.bow or 0,
		bowTier = more.bowTier,
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
		speed = 0,
		early = 0,
		dirt = 0,
		grade = 0,
		bow = 0,
	}
end

-- Every coin the customer paid.
function RecapRules.total(recap: Recap): number
	return recap.coins
		+ (recap.speed or 0)
		+ (recap.early or 0)
		+ (recap.dirt or 0)
		+ (recap.bow or 0)
		+ recap.tip
		+ recap.bonus
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
	local grade = recap.grade or 0
	add("speed", `Quick wash, {grade} {if grade == 1 then "star" else "stars"}`, recap.speed or 0)
	add("early", "Picked early", recap.early or 0)
	add("dirt", "Extra dirty", recap.dirt or 0)
	add("bow", `{BowRules.TIER[recap.bowTier or BowRules.FIRST].name} bow`, recap.bow or 0)
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
	-- the formula's lines are optional (an older server sends none); a bad one is refused like any amount
	local function optional(raw: unknown, max: number): number?
		if raw == nil then
			return 0
		end
		return amount(raw, max)
	end
	local speed, early, dirt =
		optional(t.speed, MAX_AMOUNT), optional(t.early, MAX_AMOUNT), optional(t.dirt, MAX_AMOUNT)
	local grade = optional(t.grade, 3)
	local bow = optional(t.bow, MAX_AMOUNT)
	if speed == nil or early == nil or dirt == nil or grade == nil or bow == nil then
		return nil
	end
	local bowTier: unknown = t.bowTier
	if bowTier ~= nil and BowRules.clean(bowTier) == nil then
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
		speed = speed,
		early = early,
		dirt = dirt,
		grade = grade,
		bow = bow,
		bowTier = BowRules.clean(bowTier),
	}
end

return RecapRules
