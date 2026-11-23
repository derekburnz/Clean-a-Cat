--!strict
-- Moments: the named gameplay moments that effects and sound listen to (scrub, reveal, fluff, bow, photo, send-off).
-- Client only. Gameplay code on the player's device fires them; src/client/Effects and src/client/Audio connect.
-- A moment only reports what already happened: listeners must never change gameplay state, and the server never
-- reads them. Signal runs each listener in its own thread, so a broken effect cannot stop gameplay.
--
-- Payloads are positional and always start with the cat model, so one listener shape fits every moment.
-- Rename or add a moment here only, and tell Motion-FX-Agent on the hook issue (#3).
local Signal = require(script.Parent:WaitForChild("Signal"))

type Signal<T...> = Signal.Signal<T...>

-- (cat, hitPoint): finger or mouse down on the cat with the sponge.
local scrubStart: Signal<Model, Vector3> = Signal.new()
-- (cat, hitPoint, normal, dragSpeed in studs per second): each frame the sponge drags on the cat.
local scrubMove: Signal<Model, Vector3, Vector3, number> = Signal.new()
-- (cat, lastHitPoint): finger or mouse up, or the sponge leaves the cat.
local scrubStop: Signal<Model, Vector3> = Signal.new()
-- (cat, patchPosition, patchesLeft): one mud patch vanishes.
local mudPatchCleared: Signal<Model, Vector3, number> = Signal.new()
-- (cat): the last mud patch is gone. The reveal moment.
local catClean: Signal<Model> = Signal.new()
-- (cat, strokeIndex from 1): one brush stroke lands.
local brushSwipe: Signal<Model, number> = Signal.new()
-- (cat): the last brush stroke is done.
local catFluffed: Signal<Model> = Signal.new()
-- (cat, bowId): the player picks a bow.
local bowChosen: Signal<Model, string> = Signal.new()
-- (cat): the before and after photo card shows.
local photoTaken: Signal<Model> = Signal.new()
-- (cat): a stray hops onto a window cushion.
local catToWindow: Signal<Model> = Signal.new()
-- (cat): a customer's cat goes home.
local catReturned: Signal<Model> = Signal.new()

local Moments = {
	ScrubStart = scrubStart,
	ScrubMove = scrubMove,
	ScrubStop = scrubStop,
	MudPatchCleared = mudPatchCleared,
	CatClean = catClean,
	BrushSwipe = brushSwipe,
	CatFluffed = catFluffed,
	BowChosen = bowChosen,
	PhotoTaken = photoTaken,
	CatToWindow = catToWindow,
	CatReturned = catReturned,

	-- Every moment name, in the order they happen in a first session. Tests and tools read this list.
	NAMES = table.freeze({
		"ScrubStart",
		"ScrubMove",
		"ScrubStop",
		"MudPatchCleared",
		"CatClean",
		"BrushSwipe",
		"CatFluffed",
		"BowChosen",
		"PhotoTaken",
		"CatToWindow",
		"CatReturned",
	}),
}

return table.freeze(Moments)
