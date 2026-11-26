--!strict
-- CounterRules: the waiting cats on the counter (issue 746, switch counterLine, with customers and customerCarry).
-- Derek, 2026-11-26: an open window at the desk where waiting customers put their cats on the table, so grabbing one
-- is easy, its patience bar shows, it stays obvious whose cat it is, and nobody walks to the back of the line.
--
-- Each customer as shown stands at their counter place (SpotCounter<place> on the plot, else their place in the line
-- as before) with their cat on the counter in front of them (SpotCounterCat<place>, else CAT_UP and CAT_FORWARD from
-- where they stand). The player takes any cat from its place (RequestTakeCat(place)); place 1 is the front, as
-- before. Another place takes that customer's cat at once, with what queuePick does: the customer and their order go
-- first. When a customer at the door already holds the next cat (customerCarry), that cat goes back on the counter at
-- the front of the line with a full heart bar, and the one taken is handed over instead. The line itself is not changed otherwise,
-- so heart bars, picks, the saved bench, the tutorial bench and the workers work as before.
-- Pure, so tests/specs/CounterRules.spec.luau covers it; SpaService, FigureService and CarryController use it.

local CounterRules = {}

CounterRules.FLAG = "counterLine"
CounterRules.SPOT_PREFIX = "SpotCounter" -- where customer <place> stands, outside the window facing in
CounterRules.CAT_SPOT_PREFIX = "SpotCounterCat" -- their cat on the counter top, in front of them
-- Their cat on the counter in the frame of where they stand (front -Z, y up from the floor), when the plot has no
-- SpotCounterCat<place>: about a counter's height, a little in front of them.
CounterRules.CAT_UP = 3.2 -- studs up from the floor
CounterRules.CAT_FORWARD = 2.4 -- studs in front of them
CounterRules.CAT_SCALE = 0.8 -- the cat on the counter, as in a carrier
CounterRules.CAT_NAME = "CounterCat" -- the cat's model under its customer's figure
-- On that model, for Design's card over it and the take prompt.
CounterRules.PLACE_ATTRIBUTE = "CounterPlace" -- its place at the counter, the same index as the CustomerQueue card
-- Where the cat sits on the counter, in the world (issue 923): each device seats it there once its customer stands
-- on their mat (CustomerWalkController), whatever the walk or the figure's pivot did to it on the way.
CounterRules.SPOT_AT_ATTRIBUTE = "CounterSpotAt"
CounterRules.LOOK_ATTRIBUTE = "LineLook" -- its customer's look number (the figure carries the same one)
CounterRules.KIND_ATTRIBUTE = "CatKind"

-- (switch counterCrate, with counterLine) Derek, 2026-11-26: a customer walks up with their cat in its crate, sets the
-- crate on the counter, the cat walks out and sits, and the crate fades. The server only times it: on the CounterCat,
-- SET_ATTRIBUTE is when its customer reaches their counter place (the crate goes down) and READY_ATTRIBUTE that plus
-- SETTLE_SECONDS (the cat sits, the crate is gone), both Workspace:GetServerTimeNow(). Before READY_ATTRIBUTE the cat
-- cannot be taken. Motion-FX's Effects play the crate and the cat from these times; the carrier holds the cat again.
CounterRules.CRATE_FLAG = "counterCrate"
CounterRules.SET_ATTRIBUTE = "CounterSetAt"
CounterRules.READY_ATTRIBUTE = "CounterReadyAt"
CounterRules.CRATE_SPOT_PREFIX = "SpotCounterCrate" -- the plot's spot for the set-down carrier's pivot at <place>
CounterRules.CRATE_SPOT_ATTRIBUTE = "CounterCrateSpot" -- CFrame on the CounterCat: where its carrier is set down
CounterRules.SETTLE_SECONDS = 2.4 -- about 0.5 s the crate down, 1.1 s the cat out and sitting, the crate fading 0.8 s

-- Which entry of the server's line the shown `place` is: with a cat at the door (`door`), place 1 is that cat (0)
-- and place p is entry p - 1; else place p is entry p. Nil past the line or for a place under 1.
function CounterRules.entryFor(place: number, door: boolean, length: number): number?
	local entry = if door then place - 1 else place
	if place < 1 or entry > length then
		return nil
	end
	return entry
end

-- Takes entry `index` (2 or more as an entry, or 1 without a cat at the door) out of `line` and `orders`, which move
-- together. With `back` (the kind and order of the cat at the door) that cat goes back to the front first, so the
-- customer is not lost and keeps their place. Returns the taken kind and order, or nil when `index` is not in the
-- line. Changes the tables in place.
function CounterRules.swapIn<K, O>(
	line: { K },
	orders: { O },
	index: number,
	back: { kind: K, order: O }?
): (K?, O?)
	if index < 1 or index > #line or #orders ~= #line then
		return nil, nil
	end
	local kind = table.remove(line, index)
	local order = table.remove(orders, index)
	if back then
		table.insert(line, 1, back.kind)
		table.insert(orders, 1, back.order)
	end
	return kind, order
end

-- When a cat's crate goes down and when it can be taken: `arriveAt` is when its customer reaches their counter place,
-- nil when they stand there already (then both are `now`, so the cat already sits there and no crate shows).
function CounterRules.settleTimes(arriveAt: number?, now: number): (number, number)
	if arriveAt == nil or arriveAt <= now then
		return now, now
	end
	return arriveAt, arriveAt + CounterRules.SETTLE_SECONDS
end

-- Whether a cat whose READY_ATTRIBUTE is `readyAt` can be taken at `now`. A cat with none (counterCrate off, or drawn
-- before it) can.
function CounterRules.settled(readyAt: unknown, now: number): boolean
	return type(readyAt) ~= "number" or now >= readyAt
end

return table.freeze(CounterRules)
