--!strict
-- CounterCardRules: how a cat waiting on the counter shows whose it is and how long it will wait (issue 745 part 2,
-- with the counter of issue 746; switch counterCards, which needs counterLine and heartBar). Derek, 2026-11-26: the
-- cats sit on the counter "so grabbing them is easy and can see patience bar but its still obvious who they belong
-- to".
--
-- Each cat on the counter gets one small card over it: a round chip in its owner's shirt colour, then its heart bar.
-- The owner stands right behind their cat, and the mat under the cat (CounterMat<place>) takes a pale wash of that
-- same shirt colour, so the cat, its mat, its card and its owner read as one. The bar is drawn from the HeartFill the
-- server already puts on the owner's figure (HeartRules), so it shows nothing new and costs nothing on the server.
-- The card is not a button: the Take prompt on the cat stays the one tap. It is quiet further than FAR studs off.
-- Pure, so tests/specs/CounterCardRules.spec.luau covers it; CounterCardController and UI/CounterCard use it.
local HeartRules = require(script.Parent:WaitForChild("HeartRules"))

local CounterCardRules = {}

CounterCardRules.FLAG = "counterCards"
CounterCardRules.NEEDS = table.freeze({ "counterLine", "heartBar" })
CounterCardRules.MAT_PREFIX = "CleanACat_Area_SpaPlotBig_CounterMat" -- Model-Agent's tintable mats, one per place
CounterCardRules.FAR = 40 -- studs: the cards are not drawn further off
CounterCardRules.UP = 2.3 -- studs over the cat's pivot
CounterCardRules.WIDTH = 2.7 -- studs: the places are 3.2 apart, so two cards never touch
CounterCardRules.HEIGHT = 0.8 -- studs
CounterCardRules.MAT_WASH = 0.45 -- the mat is the shirt colour this far towards cream, so the cat stays the hero
CounterCardRules.LOW_AT = HeartRules.GRUMPY_AT -- the bar turns coral here, as the cat turns grumpy
CounterCardRules.MID_AT = 0.6

local CREAM = Color3.fromHex("FFF6EC")
CounterCardRules.FULL = Color3.fromHex("7BD88F") -- mint green
CounterCardRules.MID = Color3.fromHex("FFC94D") -- the HUD's gold
CounterCardRules.LOW = Color3.fromHex("FF7A7A") -- coral, never a harsh red

-- Is the card on, for `isOn` (LiveFlags.isOn)?
function CounterCardRules.on(isOn: (string) -> boolean): boolean
	if not isOn(CounterCardRules.FLAG) then
		return false
	end
	for _, flag in CounterCardRules.NEEDS do
		if not isOn(flag) then
			return false
		end
	end
	return true
end

-- The bar's share, 0 to 1, from the figure's raw HeartFill; nil (no bar) when it is not a number.
function CounterCardRules.fill(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw then
		return nil
	end
	return math.clamp(raw, 0, 1)
end

-- The bar's colour for `fill`.
function CounterCardRules.barColor(fill: number): Color3
	if fill <= CounterCardRules.LOW_AT then
		return CounterCardRules.LOW
	elseif fill <= CounterCardRules.MID_AT then
		return CounterCardRules.MID
	end
	return CounterCardRules.FULL
end

-- The mat's tint under the cat of an owner in `shirt`.
function CounterCardRules.matColor(shirt: Color3): Color3
	return shirt:Lerp(CREAM, CounterCardRules.MAT_WASH)
end

-- The mat's part name for counter `place`, or nil for a place that is not a whole number from 1.
function CounterCardRules.matName(place: unknown): string?
	if type(place) ~= "number" or place < 1 or place % 1 ~= 0 then
		return nil
	end
	return `{CounterCardRules.MAT_PREFIX}{place}`
end

return table.freeze(CounterCardRules)
