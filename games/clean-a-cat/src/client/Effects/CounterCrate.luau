--!strict
-- CounterCrate: a customer brings their cat to the counter in its crate (Derek, 2026-11-26: "make the customers walk
-- up with the cats in their cat crate place them on the table and have the cats walk out and sit then the crate
-- disappear slowly"; issue #757, with Gameplay's counter line #746 behind counterCrate and counterLine).
--
-- Gameplay draws each customer at the counter with their cat on the counter (the figure's child Model CounterCat) and,
-- for a newcomer, the cat in the carrier on their arm too. On the CounterCat it sets two server times: CounterSetAt
-- (the customer reaches the counter) and CounterReadyAt (the cat may be taken). On this device:
--
--   before    the counter cat is hidden: the customer walks up with the cat in the crate on their arm
--   set       at CounterSetAt the carrying arm reaches forward and the crate (a local copy; the real one is hidden)
--             arcs from the hand onto the counter (Model-Agent's SpotCounterCrate by the cat's spot), with a soft puff
--   door      the crate's door (_Door_Swing) swings open by the crate's DoorOpenDegrees
--   walk      the cat steps out of the crate to its spot with a little bob in each step, grows to its counter size and
--             the real counter cat takes over where it stops
--   fade      the gate swings shut and the crate fades away slowly, gone by CounterReadyAt
--   after     the customer has no crate (the real one stays hidden) until Gameplay packs the cat back into it for a
--             leave (a PackedCat in the carrier), when it shows again so they walk off with their cat in it
--   comfort   Reduced Motion: no arc, swing or walk; the crate and the cat are simply on the counter and the crate fades
--
-- Client only and cosmetic; every player sees the same, since all go by server time. A late joiner or a figure drawn
-- already at its place joins at the right step (past CounterReadyAt: no crate at all). Hiding is by each part's own
-- Transparency, put back exactly: the walk-in writes LocalTransparencyModifier at the moment the crate is set down.
--
-- API
--   CounterCrate.start()                         watches the counter cats in Workspace
--   CounterCrate.at(t, total) -> (set, door, walk, fade)   pure: each step's share (0 to 1) at `t` seconds after
--                                                 CounterSetAt, for a sequence of `total` seconds
--   CounterCrate.arcAt(share) -> number          pure: the crate's lift (studs) along its arc
--   CounterCrate.reachAt(t) -> number            pure: the carrying arm's forward turn (radians) at `t` seconds
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

-- Issue 828 (switch counterSounds): a soft thud as the crate is set down and a small meow as the cat steps out, on the
-- player's own plot only. Required lazily so the pure specs never load Audio.
local SOUND_FLAG = "counterSounds"
local THUD_PITCH = 1.25 -- a small carrier, not a box off a truck
local soundParts: { LiveFlags: any, SpaLayout: any, Audio: any }? = nil
local function sounds(): { LiveFlags: any, SpaLayout: any, Audio: any }
	local loaded = soundParts
	if loaded == nil then
		local Shared = ReplicatedStorage:WaitForChild("Shared")
		loaded = {
			LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any,
			SpaLayout = require(Shared:WaitForChild("SpaLayout")) :: any,
			Audio = require(script.Parent.Parent:WaitForChild("Audio")) :: any,
		}
		soundParts = loaded
	end
	return loaded :: { LiveFlags: any, SpaLayout: any, Audio: any }
end

-- True when the counter sounds are on and `figure` stands in the local player's own plot.
local function ownSounds(figure: Model): boolean
	local s = sounds()
	if not s.LiveFlags.isOn(SOUND_FLAG) then
		return false
	end
	local ok, slot = pcall(s.SpaLayout.slotOf, Players.LocalPlayer)
	if not ok or type(slot) ~= "number" then
		return false
	end
	local plots = Workspace:FindFirstChild("SpaPlots")
	local plot = plots and plots:FindFirstChild("Plot" .. slot)
	return plot ~= nil and figure:IsDescendantOf(plot)
end

local CounterCrate = {}

-- CounterRules.CAT_NAME and Gameplay's two times (copied, so the specs load this without the shared rules)
CounterCrate.CAT_NAME = "CounterCat"
CounterCrate.SET_AT = "CounterSetAt"
CounterCrate.READY_AT = "CounterReadyAt"
CounterCrate.PACKED_NAME = "PackedCat"
CounterCrate.SPOT_ATTRIBUTE = "CounterCrateSpot" -- Gameplay's set-down spot for the crate's pivot
CounterCrate.REACH_ATTRIBUTE = "CounterReachAt" -- local, on the figure: CustomerMotion reaches the carrying arm
-- local, on the figure: true while the carrier on their arm is hidden (set down, or none until a leave), so
-- CustomerMotion lets the empty hand hang straight (Gameplay's CarryArmOut, issues 871 and 874)
CounterCrate.EMPTY_HAND_ATTRIBUTE = "CarrierHidden"
-- WalkRules.TO_ATTRIBUTE (copied): the mat the customer's walk ends on. Issue 871: a newcomer's CounterCat rode along
-- at counter height while they were still walking in (Sync, main 792d2dd: 5 to 6.5 studs off the carrier, over the
-- street), so the counter cat stays hidden until the customer stands on their mat, and a set-down that came due on the
-- way plays from the moment they arrive.
CounterCrate.WALK_TO = "WalkTo"
CounterCrate.ARRIVED = 0.25 -- studs, flat: the customer counts as on their mat

-- The steps as Gameplay's 2.4 s (CounterRules.SETTLE_SECONDS) splits them; a longer or shorter total scales them.
CounterCrate.TOTAL = 2.4
CounterCrate.SET = { 0, 0.5 }
CounterCrate.DOOR = { 0.5, 0.8 }
CounterCrate.WALK = { 0.8, 1.6 }
CounterCrate.FADE = { 1.6, 2.4 }
CounterCrate.LIFT = 0.6 -- studs over the straight line, mid arc
CounterCrate.BACK = 1.3 -- studs from the cat's spot back towards the customer, where the crate's seat lands
CounterCrate.BOB = 0.08 -- studs, each step of the walk out
CounterCrate.STEPS = 4
CounterCrate.REACH = math.rad(50)
CounterCrate.REACH_SECONDS = 0.7
CounterCrate.DOOR_DEGREES = 110 -- when the crate has no DoorOpenDegrees

local function share(t: number, span: { number }, scale: number): number
	local from, to = span[1] * scale, span[2] * scale
	if to <= from then
		return if t >= to then 1 else 0
	end
	return math.clamp((t - from) / (to - from), 0, 1)
end

function CounterCrate.at(t: number, total: number): (number, number, number, number)
	local scale = if total > 0 then total / CounterCrate.TOTAL else 1
	return share(t, CounterCrate.SET, scale),
		share(t, CounterCrate.DOOR, scale),
		share(t, CounterCrate.WALK, scale),
		share(t, CounterCrate.FADE, scale)
end

-- Whether a customer at `position` still has to walk to `mat` (where their WalkTo mat is), on the flat.
function CounterCrate.walking(position: Vector3, mat: Vector3?): boolean
	if mat == nil then
		return false
	end
	return Vector3.new(position.X - mat.X, 0, position.Z - mat.Z).Magnitude > CounterCrate.ARRIVED
end

-- The set-down's two times on this device: as the server gave them, or, for a customer seen walking in who arrived
-- after `setAt`, moved later so the crate goes down from the moment they arrived (`arrivedAt`).
function CounterCrate.shifted(setAt: number, readyAt: number, arrivedAt: number?): (number, number)
	if arrivedAt == nil or arrivedAt <= setAt then
		return setAt, readyAt
	end
	return arrivedAt, readyAt + (arrivedAt - setAt)
end

function CounterCrate.arcAt(u: number): number
	local s = math.clamp(u, 0, 1)
	return CounterCrate.LIFT * 4 * s * (1 - s)
end

function CounterCrate.reachAt(t: number): number
	if t <= 0 or t >= CounterCrate.REACH_SECONDS then
		return 0
	end
	return CounterCrate.REACH * math.sin(math.pi * t / CounterCrate.REACH_SECONDS)
end

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- Hiding by each part's own Transparency, remembered so it goes back exactly.
local saved: { [Instance]: number } = {}

local function hide(root: Instance)
	local function one(d: Instance)
		if d:IsA("BasePart") or d:IsA("Decal") then
			local item = d :: any
			if saved[d] == nil then
				saved[d] = item.Transparency
			end
			item.Transparency = 1
		end
	end
	one(root)
	for _, d in root:GetDescendants() do
		one(d)
	end
end

local function show(root: Instance)
	local function one(d: Instance)
		local was = saved[d]
		if was ~= nil then
			saved[d] = nil
			if d.Parent then
				(d :: any).Transparency = was
			end
		end
	end
	one(root)
	for _, d in root:GetDescendants() do
		one(d)
	end
end

-- drop what was hidden and is now gone (a served customer's figure is destroyed with its carrier still hidden)
local function forget()
	for d in saved do
		if not d:IsDescendantOf(game) then
			saved[d] = nil
		end
	end
end

-- The parts and decals a fade writes, collected once when the copy is made (issue 821: no per frame model walks).
local function fadeParts(root: Instance): { Instance }
	local list: { Instance } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(list, d)
		end
	end
	return list
end

local function fade(list: { Instance }, seen: number)
	for _, d in list do
		(d :: any).LocalTransparencyModifier = seen
	end
end

local FOLDER_NAME = "CleanACat_Fx_CounterCrate"
local function folder(): Folder
	local found = Workspace:FindFirstChild(FOLDER_NAME)
	if found and found:IsA("Folder") then
		return found :: Folder
	end
	local made = Instance.new("Folder")
	made.Name = FOLDER_NAME
	made.Parent = Workspace
	return made
end

type Entry = {
	cat: Model,
	figure: Model,
	phase: "before" | "playing" | "after",
	crate: Model?,
	walker: Model?,
	walkFrom: CFrame?,
	walkScale: number,
	crateFrom: CFrame?,
	crateTo: CFrame?,
	door: PVInstance?,
	doorClosed: CFrame?,
	doorAngle: number,
	landed: boolean,
	handedOver: boolean,
	crateParts: { Instance }?, -- the copy's parts for its fade, collected once (issue 821)
	crateSeen: number?, -- the fade last written, so an unchanged frame writes nothing
	waitHidden: boolean?, -- the waiting cat is hidden once before CounterSetAt, not every frame
	ownSounds: boolean?, -- issue 828: this crate plays its thud and meow (own plot, counterSounds on)
	meowed: boolean?,
	sawWalk: boolean?, -- issue 871: this customer was seen walking in, so their set-down waits for them
	arrivedAt: number?, -- server time they stood on their mat, after a walk this device saw
}

local entries: { [Model]: Entry } = {}
local stepping: RBXScriptConnection? = nil

local function carrierOf(figure: Model): Model?
	local found = figure:FindFirstChild("Carrier", true)
	return if found and found:IsA("Model") then found :: Model else nil
end

local function catIn(crate: Model): Model?
	for _, child in crate:GetChildren() do
		if
			child:IsA("Model")
			and string.sub(child.Name, 1, #"CleanACat_Cat_") == "CleanACat_Cat_"
		then
			return child :: Model
		end
	end
	return nil
end

local function doorOf(crate: Model): PVInstance?
	for _, child in crate:GetChildren() do
		if child:IsA("PVInstance") and string.sub(child.Name, -#"_Door_Swing") == "_Door_Swing" then
			return child :: PVInstance
		end
	end
	return nil
end

local function clean(entry: Entry)
	if entry.walker then
		entry.walker:Destroy()
		entry.walker = nil
	end
	if entry.crate then
		entry.crate:Destroy()
		entry.crate = nil
	end
end

local function settle(entry: Entry)
	-- the end state: the real cat on the counter, no crate on the arm (until it is packed for a leave)
	clean(entry)
	entry.phase = "after"
	show(entry.cat)
	local carrier = carrierOf(entry.figure)
	if carrier and carrier:FindFirstChild(CounterCrate.PACKED_NAME) == nil then
		hide(carrier)
		entry.figure:SetAttribute(CounterCrate.EMPTY_HAND_ATTRIBUTE, true)
	end
end

-- Where the crate lands: its seat BACK studs behind the cat's spot towards the customer, base on the counter top,
-- facing the way the customer faces (the door at its front, towards the cat's spot).
-- Model-Agent's crate spots on the big spa's counter (SpotCounterCrate1 to 6, beside each SpotCounterCat): the
-- crate's pivot goes on the nearest one, gate towards the cat. Without one, the crate lands behind the cat's spot.
CounterCrate.CRATE_SPOT_PREFIX = "SpotCounterCrate"
CounterCrate.CRATE_SPOT_RANGE = 4 -- studs from the cat's spot

-- the crate spots seen so far, collected by watch() as they stream in, so a crate never searches the whole world
local crateSpots: { [Attachment]: boolean } = {}

local function crateSpot(near: Vector3): CFrame?
	local best: CFrame? = nil
	local bestDistance = CounterCrate.CRATE_SPOT_RANGE
	for spot in crateSpots do
		if spot.Parent == nil then
			crateSpots[spot] = nil
			continue
		end
		local at = spot.WorldCFrame
		local distance = (at.Position - near).Magnitude
		if distance < bestDistance then
			best, bestDistance = at, distance
		end
	end
	return best
end

local function landing(entry: Entry, crate: Model, seat: Attachment?): CFrame
	local spot = entry.cat:GetPivot()
	-- Gameplay's spot for this place (the plot's SpotCounterCrate, or halfway on the counter top), then the plot's own
	local given = entry.cat:GetAttribute(CounterCrate.SPOT_ATTRIBUTE)
	if typeof(given) == "CFrame" then
		return given :: CFrame
	end
	local placed = crateSpot(spot.Position)
	if placed then
		return placed
	end
	local facing = entry.figure:GetPivot().Rotation
	local back = -facing.LookVector
	local pivot = crate:GetPivot()
	local box, size = crate:GetBoundingBox()
	local bottom = pivot.Position.Y - (box.Position.Y - size.Y / 2)
	local seatLocal = if seat then pivot:PointToObjectSpace(seat.WorldPosition) else Vector3.zero
	local seatAt = spot.Position + back * CounterCrate.BACK
	local base = CFrame.new(seatAt.X, spot.Position.Y + bottom, seatAt.Z) * facing
	-- move it so its seat, not its pivot, is over seatAt
	local offset = facing:VectorToWorldSpace(Vector3.new(seatLocal.X, 0, seatLocal.Z))
	return base - offset
end

local function begin(entry: Entry, carrier: Model)
	local still = Effects.reducedMotion()
	hide(entry.cat) -- a customer drawn already at the counter: the cat comes out of the crate all the same
	local copy = carrier:Clone() :: Model -- before hiding, so the copy keeps each part's own look
	copy.Name = "CleanACat_Fx_CounterCrate"
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		elseif d:IsA("ProximityPrompt") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local parts = fadeParts(copy)
	fade(parts, 0)
	entry.crateParts = parts
	entry.crateSeen = 0
	local seatFound = copy:FindFirstChild("CatSeat", true)
	local seat = if seatFound and seatFound:IsA("Attachment") then seatFound :: Attachment else nil
	entry.crateFrom = carrier:GetPivot()
	entry.crateTo = landing(entry, copy, seat)
	copy:PivotTo(if still then entry.crateTo :: CFrame else entry.crateFrom :: CFrame)
	copy.Parent = folder()
	hide(carrier)
	entry.figure:SetAttribute(CounterCrate.EMPTY_HAND_ATTRIBUTE, true)
	entry.crate = copy
	entry.door = doorOf(copy)
	if entry.door then
		entry.doorClosed = copy:GetPivot():ToObjectSpace((entry.door :: PVInstance):GetPivot())
	end
	local degrees = copy:GetAttribute("DoorOpenDegrees")
	entry.doorAngle =
		math.rad(if type(degrees) == "number" then degrees else CounterCrate.DOOR_DEGREES)
	if not still then
		entry.figure:SetAttribute(CounterCrate.REACH_ATTRIBUTE, os.clock())
	end
	entry.phase = "playing"
	if ownSounds(entry.figure) then
		entry.ownSounds = true
		sounds().Audio.play("boxThud", {
			at = copy.PrimaryPart or copy:FindFirstChildWhichIsA("BasePart", true),
			pitch = THUD_PITCH,
		})
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local still = Effects.reducedMotion()
	for cat, entry in entries do
		if cat.Parent == nil or entry.figure.Parent == nil then
			clean(entry)
			entries[cat] = nil
			forget()
			continue
		end
		local serverSet = cat:GetAttribute(CounterCrate.SET_AT)
		local serverReady = cat:GetAttribute(CounterCrate.READY_AT)
		if type(serverSet) ~= "number" or type(serverReady) ~= "number" then
			continue -- the crate switch is off: Gameplay's counter as it was
		end
		if entry.phase == "after" then
			continue
		end
		-- still walking in: the cat is in the crate on their arm, not on the counter beside them (issue 871)
		if entry.phase == "before" then
			local walkTo = entry.figure:GetAttribute(CounterCrate.WALK_TO)
			local mat = if typeof(walkTo) == "CFrame" then (walkTo :: CFrame).Position else nil
			if CounterCrate.walking(entry.figure:GetPivot().Position, mat) then
				entry.sawWalk = true
				entry.arrivedAt = nil
				if not entry.waitHidden then
					entry.waitHidden = true
					hide(cat)
				end
				continue
			end
			if entry.sawWalk and entry.arrivedAt == nil then
				entry.arrivedAt = now
			end
		end
		local setAt, readyAt = CounterCrate.shifted(serverSet, serverReady, entry.arrivedAt)
		if now < setAt then
			if not entry.waitHidden then
				entry.waitHidden = true
				hide(cat)
			end
			continue
		end
		if now >= readyAt then
			settle(entry)
			continue
		end
		if entry.phase == "before" then
			local carrier = carrierOf(entry.figure)
			if carrier == nil then
				settle(entry)
				continue
			end
			begin(entry, carrier :: Model)
		end
		local crate = entry.crate
		if crate == nil then
			settle(entry)
			continue
		end
		local total = readyAt - setAt
		local t = now - setAt
		local set, door, walk, fadeShare = CounterCrate.at(t, total)
		if still then
			set, door, walk = 1, 1, 1
		end
		local from, to = entry.crateFrom :: CFrame, entry.crateTo :: CFrame
		local u = smooth(set)
		local cf = from:Lerp(to, u) + Vector3.new(0, CounterCrate.arcAt(set), 0)
		crate:PivotTo(cf)
		if set >= 1 and not entry.landed then
			entry.landed = true
			if not still then
				local box, size = crate:GetBoundingBox()
				Effects.burst("roadDust", box.Position - Vector3.new(0, size.Y / 2, 0))
			end
		end
		local hinge, closed = entry.door, entry.doorClosed
		if hinge and closed then
			-- the gate turns about its hinge's up axis, and swings shut again as the crate fades, since the open gate
			-- lies by the sitting cat's tail (Model-Agent)
			local open = smooth(door) * (1 - smooth(math.clamp(fadeShare * 2, 0, 1)))
			hinge:PivotTo(crate:GetPivot() * closed * CFrame.Angles(0, entry.doorAngle * open, 0))
		end
		if walk > 0 and entry.ownSounds and not entry.meowed then
			entry.meowed = true
			sounds().Audio.play(
				"meow",
				{ at = cat.PrimaryPart or cat:FindFirstChildWhichIsA("BasePart", true) }
			)
		end
		if walk > 0 and not entry.handedOver then
			local walker = entry.walker
			if walker == nil then
				local inside = catIn(crate)
				if inside then
					walker = inside
					entry.walker = inside
					entry.walkFrom = inside:GetPivot()
					entry.walkScale = inside:GetScale()
					inside.Parent = folder()
				end
			end
			local spot = cat:GetPivot()
			if walker and entry.walkFrom then
				local target = cat:GetScale()
				local w = smooth(walk)
				local bob = CounterCrate.BOB
					* math.abs(math.sin(math.pi * CounterCrate.STEPS * walk))
				walker:ScaleTo(entry.walkScale + (target - entry.walkScale) * w)
				walker:PivotTo(
					(entry.walkFrom :: CFrame):Lerp(spot, w) + Vector3.new(0, bob * (1 - walk), 0)
				)
			end
			if walk >= 1 then
				entry.handedOver = true
				if entry.walker then
					entry.walker:Destroy()
					entry.walker = nil
				end
				show(cat)
			end
		end
		local parts = entry.crateParts
		if fadeShare > 0 and parts and fadeShare ~= entry.crateSeen then
			entry.crateSeen = fadeShare
			fade(parts, fadeShare)
		end
	end
	if next(entries) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function watch(instance: Instance)
	if
		instance:IsA("Attachment")
		and string.sub(instance.Name, 1, #CounterCrate.CRATE_SPOT_PREFIX)
			== CounterCrate.CRATE_SPOT_PREFIX
	then
		crateSpots[instance :: Attachment] = true
		return
	end
	if not instance:IsA("Model") or instance.Name ~= CounterCrate.CAT_NAME then
		return
	end
	local cat = instance :: Model
	local figure = cat.Parent
	if entries[cat] or figure == nil or not figure:IsA("Model") then
		return
	end
	local entry: Entry = {
		cat = cat,
		figure = figure :: Model,
		phase = "before",
		crate = nil,
		walker = nil,
		walkFrom = nil,
		walkScale = 1,
		crateFrom = nil,
		crateTo = nil,
		door = nil,
		doorClosed = nil,
		doorAngle = 0,
		landed = false,
		handedOver = false,
	}
	entries[cat] = entry
	-- a leave: Gameplay packs the cat back into the carrier, so the crate shows again round it
	local carrier = carrierOf(figure :: Model)
	if carrier then
		carrier.ChildAdded:Connect(function(child)
			if child.Name == CounterCrate.PACKED_NAME then
				show(carrier :: Model)
				entry.figure:SetAttribute(CounterCrate.EMPTY_HAND_ATTRIBUTE, nil)
			end
		end)
	end
	cat.AncestryChanged:Connect(function()
		if cat.Parent ~= entry.figure then
			clean(entry)
			show(cat)
			entries[cat] = nil
			forget()
		end
	end)
	if stepping == nil then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

local started = false
function CounterCrate.start()
	if started then
		return
	end
	started = true
	for _, d in Workspace:GetDescendants() do
		watch(d)
	end
	Workspace.DescendantAdded:Connect(watch)
end

return CounterCrate
