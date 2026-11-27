--!strict
-- CarryRules: carrying a customer's cat from the door to the tub (switch customerCarry, claim #406). The owner's dev
-- note of 2026-11-25: "take it from customer and walk it over to the bathtub and when you put it in tub thats when it
-- puts you into the minigame scene". With the switch on, the next customer's cat stays in its carrier with the front
-- customer until the player takes it (RequestTakeCat), and is in the tub only once the player puts it there
-- (RequestPlaceCat); then the wash starts as before (CatReady). Suds and strays still go straight to the tub.
--
-- The server owns where the cat is and says it with a Player attribute, so a client that missed a message, or joined
-- the carry late, still draws the right thing: ATTRIBUTE is "door" (with the customer) or "arms" (being carried), and
-- nil once the cat is in the tub. KIND_ATTRIBUTE names the cat (a CatRules kind) while ATTRIBUTE is set. Pure, so
-- tests/specs/CarryRules.spec.luau covers it.

local CarryRules = {}

CarryRules.FLAG = "customerCarry"
CarryRules.CUSTOMERS_FLAG = "customers"
CarryRules.ATTRIBUTE = "CarryCat"
CarryRules.KIND_ATTRIBUTE = "CarryKind"
CarryRules.DOOR = "door"
CarryRules.ARMS = "arms"
-- On the carrier's character, for every other player's game (switch carryShared, Motion-FX draws it): CHARACTER_CAT is
-- the ReplicatedStorage.Assets model of the cat in their arms and CHARACTER_HELD how it is held ("sit" or "loaf"); both
-- nil when the arms are empty. The carrier's own game draws theirs itself (CarryController, OpeningController).
CarryRules.CHARACTER_CAT = "CarryCat"
CarryRules.CHARACTER_HELD = "CarryHeld"
CarryRules.SHARED_FLAG = "carryShared"
CarryRules.TAKE_REACH = 14 -- studs, flat, from the front customer's spot; the client's prompt reaches 10
CarryRules.PLACE_REACH = 16 -- studs, flat, from the tub's spot; the client's prompt reaches 10
-- (switch loafCarry, issue 1138) Derek 2026-11-27: every carried cat lies in the arms as a loaf, like Suds, for the
-- player and for the helpers. A kind's held loaf is CleanACat_Cat_<Kind>_Dirty_Loaf (dirty, the take and the fetch)
-- and CleanACat_Cat_<Kind>_Loaf (clean, a helper's walk back); a kind with none still goes as its sitting body.
CarryRules.LOAF_FLAG = "loafCarry"
CarryRules.LOAF = "loaf"
CarryRules.SIT = "sit"

export type Where = "door" | "arms"
export type Held = "sit" | "loaf"

-- Whether a cat of `kind` is carried in from the door: a customer's cat (it has a kind, and is no stray and not the
-- opening's kitten) while both switches are on.
function CarryRules.carried(
	kind: string?,
	stray: boolean?,
	mascot: boolean?,
	isOn: (string) -> boolean
): boolean
	return isOn(CarryRules.FLAG)
		and isOn(CarryRules.CUSTOMERS_FLAG)
		and kind ~= nil
		and stray ~= true
		and mascot ~= true
end

-- Whether `at` is within `reach` studs of `spot`, along the ground (height is ignored: a jump never puts a player out
-- of reach).
function CarryRules.within(at: Vector3, spot: Vector3, reach: number): boolean
	local offset = at - spot
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach
end

-- The Assets model a customer's cat of `kind` is carried as, and how it is held: with `loaf` (switch loafCarry) its
-- held loaf when Assets has one ("loaf"); else its sitting body, or its dirty body when it has none ("sit").
function CarryRules.modelName(
	kind: string,
	has: (string) -> boolean,
	loaf: boolean?
): (string, Held)
	local held = `CleanACat_Cat_{kind}_Dirty_Loaf`
	if loaf == true and has(held) then
		return held, "loaf"
	end
	local sit = `CleanACat_Cat_{kind}_Dirty_Sit`
	return if has(sit) then sit else `CleanACat_Cat_{kind}_Dirty`, "sit"
end

-- The Assets model a helper carries a cat of `kind` as (switch helperFetch): dirty on the fetch from the counter,
-- clean on the walk back. With `loaf` (switch loafCarry) its held loaf when Assets has one, else its sitting body.
function CarryRules.helperModelName(
	kind: string,
	clean: boolean,
	has: (string) -> boolean,
	loaf: boolean?
): (string, Held)
	local base = if clean then `CleanACat_Cat_{kind}` else `CleanACat_Cat_{kind}_Dirty`
	if loaf == true and has(`{base}_Loaf`) then
		return `{base}_Loaf`, "loaf"
	end
	return `{base}_Sit`, "sit"
end

-- Whether an Assets model name is a held loaf (a helper's client reads the carried name off the staff model).
function CarryRules.isLoaf(name: string): boolean
	return string.sub(name, -5) == "_Loaf"
end

-- The door line as the player sees it: while the cat is still with its customer at the door, that customer is at the
-- front, ahead of the line the server rolls the next cats from. Returns new tables.
function CarryRules.shownLine<T, N>(
	line: { T },
	needs: { N },
	where: Where?,
	kind: T?,
	kindNeeds: N?
): ({ T }, { N })
	local kinds, lists = table.clone(line), table.clone(needs)
	if where == CarryRules.DOOR and kind ~= nil then
		table.insert(kinds, 1, kind)
		table.insert(lists, 1, kindNeeds :: N)
	end
	return kinds, lists
end

return table.freeze(CarryRules)
