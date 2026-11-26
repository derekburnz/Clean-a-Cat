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
-- (cat, dryer): a clean cat sits on the built Blow Dryer's stool and the air starts.
local dryStart: Signal<Model, Model> = Signal.new()
-- (cat): the dry is done; the cat goes back to the tub.
local dryStop: Signal<Model> = Signal.new()
-- (cat): the Bubble Bath step starts (#267, switch bubbleBath): suds puff up round the cat.
local bathStart: Signal<Model> = Signal.new()
-- (cat, sudsPosition, sudsLeft): one suds puff pops as the player swirls.
local sudsPopped: Signal<Model, Vector3, number> = Signal.new()
-- (cat, catPosition): (switch latherFoam) the last puff lathered on: he is covered ("so foamy"); the rinse follows.
local bathFoamy: Signal<Model, Vector3> = Signal.new()
-- (cat): the last suds puff is gone; the smell is washed out.
local bathDone: Signal<Model> = Signal.new()
-- (cat): the Pawdicure step starts (#267, switch pawdicure): the long claws wait to be clipped.
local clawsStart: Signal<Model> = Signal.new()
-- (cat, clawPosition): one claw is snipped; a paw's four come WashDraft.SNIP_GAP apart (a snip sound each).
local clawSnipped: Signal<Model, Vector3> = Signal.new()
-- (cat, pawPosition, pawsLeft): one front paw's claws are all clipped.
local pawClipped: Signal<Model, Vector3, number> = Signal.new()
-- (cat): both front paws are clipped.
local clawsDone: Signal<Model> = Signal.new()
-- (cat, bowId): the player picks a bow.
local bowChosen: Signal<Model, string> = Signal.new()
-- (cat): the before and after photo card shows.
local photoTaken: Signal<Model> = Signal.new()
-- (cat): the opening's kitten is named Suds and his collar pops on (#285, switch sudsWash): a jingle and a sparkle.
local sudsNamed: Signal<Model> = Signal.new()
-- (suds): the player taps Suds on his bed (#285, switch sudsMascot): a purr and a hop. Suds is the mascot model.
local sudsTapped: Signal<Model> = Signal.new()
-- (suds, target): "Show me" on Suds's help bubble (switch sudsBubble); his model on the bed and the world position
-- he points the way to. Only fired while he is on his bed (switch sudsMascot), for Motion-FX's trot there.
local sudsPoint: Signal<Model, Vector3> = Signal.new()
-- (cat): a stray hops onto a window cushion.
local catToWindow: Signal<Model> = Signal.new()
-- (cat): a customer's cat goes home.
local catReturned: Signal<Model> = Signal.new()
-- (cat, step): (switch washMeter) the bar of `step` ("scrub", "brush", "rinse" or "claws") is full and the cat shakes
-- off what is left; the next step starts WashMeter.SHAKE_SECONDS later.
local shakeOff: Signal<Model, string> = Signal.new()
-- (cat, point, normal): (switch washMeter) a spray of the shower on the fur while the foam is rinsed off, every move.
local rinseSpray: Signal<Model, Vector3, Vector3> = Signal.new()
-- (customer): (switch heartBar) a waiting customer's heart bar fell to HeartRules.GRUMPY_AT: the cat turns grumpy. The
-- model is the customer's figure in the player's own door line, with HeartFill on it.
local heartLow: Signal<Model> = Signal.new()
-- (customer): (switch heartBar) a waiting customer's bar ran out and they leave with their cat; fired just before the
-- server redraws the line, so the figure is still there for a moment.
local catLeft: Signal<Model> = Signal.new()
-- (cat): (switch workers) a worker finished a cat: the clean model has just sat down in their tub, WorkerProgress 1.
-- Fired on every device that sees it, for any spa on the street.
local workerFinished: Signal<Model> = Signal.new()
-- (visitor, again): (switch specialVisitors) a special visitor's figure is in the player's own door line. `again` is
-- false the first time in a visit, and true when the line was redrawn and this is a new figure for the same visitor
-- (so the star can go back over their head without the arrival playing twice).
local visitorArrived: Signal<Model, boolean> = Signal.new()
-- (crate): (switch pets) a crate the player holds has landed by their tub (CleanACat_Prop_PetCrate, where it stays).
local crateDropped: Signal<Model> = Signal.new()
-- (crate): (switch pets) the player tapped Open and the server rolled the pet: the lid opens, the same every time.
local crateOpened: Signal<Model> = Signal.new()
-- (pet): (switch pets) the pet from the crate, just placed on the crate's PetSeat.
local petRevealed: Signal<Model> = Signal.new()
-- (pet): (switch pets) three pets fused: the pet beside the player or worker, now a star higher.
local petStarUp: Signal<Model> = Signal.new()
-- (build): (switch builds) a build the player started just finished, or finished while they were away: the built
-- station or room in their plot once it is drawn (its plot if it is not there within a few seconds).
local buildFinished: Signal<Model> = Signal.new()
-- (): (switch quests) one or more quests in the player's book just finished (they pay at once, with a notice).
local questDone: Signal<()> = Signal.new()
-- (): (switch checkinCard) the player claimed today's check in gift.
local checkInClaimed: Signal<()> = Signal.new()

local Moments = {
	ScrubStart = scrubStart,
	ScrubMove = scrubMove,
	ScrubStop = scrubStop,
	MudPatchCleared = mudPatchCleared,
	CatClean = catClean,
	BrushSwipe = brushSwipe,
	CatFluffed = catFluffed,
	DryStart = dryStart,
	DryStop = dryStop,
	BathStart = bathStart,
	SudsPopped = sudsPopped,
	BathFoamy = bathFoamy,
	BathDone = bathDone,
	ClawsStart = clawsStart,
	ClawSnipped = clawSnipped,
	PawClipped = pawClipped,
	ClawsDone = clawsDone,
	BowChosen = bowChosen,
	PhotoTaken = photoTaken,
	SudsNamed = sudsNamed,
	SudsTapped = sudsTapped,
	SudsPoint = sudsPoint,
	CatToWindow = catToWindow,
	CatReturned = catReturned,
	ShakeOff = shakeOff,
	RinseSpray = rinseSpray,
	HeartLow = heartLow,
	CatLeft = catLeft,
	WorkerFinished = workerFinished,
	VisitorArrived = visitorArrived,
	CrateDropped = crateDropped,
	CrateOpened = crateOpened,
	PetRevealed = petRevealed,
	PetStarUp = petStarUp,
	BuildFinished = buildFinished,
	QuestDone = questDone,
	CheckInClaimed = checkInClaimed,

	-- Every moment name, in the order they happen in a first session. Tests and tools read this list.
	NAMES = table.freeze({
		"ScrubStart",
		"ScrubMove",
		"ScrubStop",
		"MudPatchCleared",
		"CatClean",
		"BrushSwipe",
		"CatFluffed",
		"DryStart",
		"DryStop",
		"BathStart",
		"SudsPopped",
		"BathFoamy",
		"RinseSpray",
		"BathDone",
		"ShakeOff",
		"ClawsStart",
		"ClawSnipped",
		"PawClipped",
		"ClawsDone",
		"BowChosen",
		"PhotoTaken",
		"SudsNamed",
		"SudsTapped",
		"SudsPoint",
		"CatToWindow",
		"CatReturned",
		"HeartLow",
		"CatLeft",
		"WorkerFinished",
		"VisitorArrived",
		"CrateDropped",
		"CrateOpened",
		"PetRevealed",
		"PetStarUp",
		"BuildFinished",
		"QuestDone",
		"CheckInClaimed",
	}),
}

return table.freeze(Moments)
