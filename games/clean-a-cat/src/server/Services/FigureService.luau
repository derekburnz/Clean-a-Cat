--!strict
-- FigureService: the customers waiting at a player's door, drawn by the server in that player's own plot so the
-- whole street sees them. Each customer is a Roblox R15 figure (Players:CreateHumanoidModelFromDescription, which
-- only the server may call) in one of the style guide's four looks (section 15: body colours and one accessory),
-- holding Model-Agent's carrier by its Grip with the customer's dirty cat inside at the carrier's CatScale.
-- SpaService calls showQueue whenever it sends the queue. The figures only show the queue; they change nothing.
-- Behind the LiveFlags switch `customerFigures` (and `customers`), off by default. While it is off, or before the
-- plot is placed, each client draws its own placeholder line (DoorController).
--
-- With the switch `townsfolk` on (#446), each customer is instead one of Model-Agent's eight townsfolk
-- (CleanACat_NPC_Customer_<Name>, a plain anchored Model with jointed limbs, keeping its asset name so Motion-FX's
-- CustomerMotion finds it), the carrier on the Grip in its right hand. A customer who was not in the line as last
-- drawn is placed on the pavement and one who moved up is placed on their old mat, each marked with their mat and the
-- time they set off (WalkRules); every client walks them there (CustomerWalkController).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryRules = require(Shared:WaitForChild("CarryRules"))
local CatRules = require(Shared:WaitForChild("CatRules"))
local CounterRules = require(Shared:WaitForChild("CounterRules"))
local HeartRules = require(Shared:WaitForChild("HeartRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local SpecialRules = require(Shared:WaitForChild("SpecialRules"))
local WalkRules = require(Shared:WaitForChild("WalkRules"))

local LineLooks = require(script.Parent.Parent.Util.LineLooks)

local FLAG = "customerFigures"
local TOWNSFOLK_FLAG = "townsfolk"
local SWAP_FLAG = "lineSwap" -- issue 571
local REUSE_FLAG = "lineReuse" -- issues 571 and 570: the line is redrawn in place, each customer kept
local LOOK_ATTRIBUTE = "LineLook" -- the customer's look number on their townsfolk figure, so a redraw finds them
local LEAVING_ATTRIBUTE = "LineLeaving" -- a leaver's figure waiting for the redraw to take it away
local STEP_UP_DELAY = 1.2 -- seconds a customer waits before stepping up into a leaver's place (issue 570; 0.8 s still
-- overlapped the leaver's fading copy by half a stud in bug hunt B4)
-- Seconds a leaver's figure stays (server side) after the redraw that took them out of the line, so the device that
-- hears CustomerLeft after that redraw still finds it for the walk off copy; that device hides it at once.
local LEAVE_LINGER = 0.5
-- Model-Agent's townsfolk (#446), CleanACat_NPC_Customer_<name>. A look number n is TOWNSFOLK[n % #TOWNSFOLK + 1].
local TOWNSFOLK = { "Sunny", "Mo", "Pip", "Rae", "Juno", "Bea", "Theo", "Kit" }
local CUSTOMERS_FLAG = "customers"
local FOLDER_NAME = "Customers"
-- Each drawn customer's place in the line as shown, 1 at the front, for SetHearts and the client's CustomerLeft.
local PLACE_ATTRIBUTE = "LinePlace"
local CARRIER_ASSET = "CleanACat_Prop_Carrier"
-- Model-Agent's carrier looks (#458), the same Attachments and attributes as the first: each customer keeps one by
-- their look number, so a line is not three of one thing. A look not in the game yet falls back to the first.
local CARRIER_LOOKS = { CARRIER_ASSET, "CleanACat_Prop_CarrierSky", "CleanACat_Prop_CarrierButter" }
local MAX_SHOWN = 3 -- one on each queue mat

-- How many customers are drawn: one on each mat, or with benchGrow every bench place (SpotBench4 to 6).
local function maxShown(): number
	return if LiveFlags.isOn(SpaRules.BENCH_FLAG) then SpaRules.MAX_QUEUE else MAX_SHOWN
end

local FigureService = {}

-- (switch counterLine, issue 746) Waiting customers stand at the counter window with their cat on the counter in front
-- of them, their carrier empty in their hand.
local function counterOn(): boolean
	return LiveFlags.isOn(CounterRules.FLAG) and LiveFlags.isOn(CarryRules.FLAG)
end

-- (switch counterCrate) A new customer brings their cat to the counter in its crate (CounterRules).
local function crateOn(): boolean
	return counterOn() and LiveFlags.isOn(CounterRules.CRATE_FLAG)
end

type Look = {
	name: string,
	skin: Color3,
	torso: Color3,
	legs: Color3,
	accessory: string,
}

-- Style guide section 15.
local LOOKS: { Look } = {
	{
		name = "Sunny",
		skin = Color3.fromHex("F3C9A2"),
		torso = Color3.fromHex("A8E6CF"),
		legs = Color3.fromHex("2F3E5C"),
		accessory = "CleanACat_NPC_SunHat",
	},
	{
		name = "Mo",
		skin = Color3.fromHex("7A4B32"),
		torso = Color3.fromHex("F6DFA0"),
		legs = Color3.fromHex("3C7DD9"),
		accessory = "CleanACat_NPC_Scarf",
	},
	{
		name = "Pip",
		skin = Color3.fromHex("C98E6A"),
		torso = Color3.fromHex("8FD3FE"),
		legs = Color3.fromHex("E3C49C"),
		accessory = "CleanACat_NPC_ToteBag",
	},
	{
		name = "Rae",
		skin = Color3.fromHex("C98E6A"),
		torso = Color3.fromHex("FFB3C7"),
		legs = Color3.fromHex("2F3E5C"),
		accessory = "CleanACat_NPC_SunHat",
	},
}

local templates: { [string]: Model } = {}
local building: { [string]: boolean } = {}
-- Each player's door line as last drawn, with every customer's look, so a look moves up the line with its owner and
-- goes to the front with them when picked (#206). A look number n is LOOKS[n % #LOOKS + 1].
local lines: { [Player]: LineLooks.Line } = {}
-- The look numbers of the townsfolk last put in each player's plot, front first, so the next draw knows who moved.
local shown: { [Player]: { number } } = {}
-- Each player's newest in-place redraw (lineReuse): a redraw whose figure loading yielded stops if a newer one began,
-- so two quick redraws never both walk in the same newcomer (Review-QA's note on #596).
local redraws: { [Player]: number } = {}
-- Leavers' figures that wait LEAVE_LINGER before going (a customer who left; not one a worker took). A strong table
-- (a weak one on Instances can lose an entry while the figure still exists); an entry goes when its figure does.
local lingering: { [Instance]: boolean } = {}
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, text: string)
	if not warned[key] then
		warned[key] = true
		warn(`[FigureService] {text}`)
	end
end

local function asset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = if assets then assets:FindFirstChild(name) else nil
	if found and found:IsA("Model") then
		return found :: Model
	end
	warnOnce(name, `{name} is missing from ReplicatedStorage.Assets`)
	return nil
end

local function setAll(model: Instance, anchored: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = anchored
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

-- Model-Agent's accessory model as a Roblox Accessory: its parts welded to Handle.
local function accessoryFrom(model: Model): Accessory?
	local handle = model:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return nil
	end
	local accessory = Instance.new("Accessory")
	accessory.Name = model.Name
	local copy = model:Clone()
	for _, part in copy:GetChildren() do
		part.Parent = accessory
	end
	copy:Destroy()
	local newHandle = accessory:FindFirstChild("Handle") :: BasePart
	for _, part in accessory:GetDescendants() do
		if part:IsA("BasePart") and (part :: Instance) ~= (newHandle :: Instance) then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = newHandle
			weld.Part1 = part :: BasePart
			weld.Parent = newHandle
		end
	end
	setAll(accessory, false)
	return accessory
end

-- One figure per look, made once (the call yields), then cloned for every customer.
local function template(look: Look): Model?
	while building[look.name] do
		task.wait() -- another draw is making this look; use its result
	end
	local made = templates[look.name]
	if made then
		return made
	end
	building[look.name] = true
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.TorsoColor = look.torso
	description.LeftLegColor = look.legs
	description.RightLegColor = look.legs
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	building[look.name] = nil
	if not ok then
		warnOnce("rig", `could not make a customer figure: {result}`)
		return nil
	end
	local figure = result :: Model
	figure.Name = `Customer_{look.name}`
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	if humanoid then
		(humanoid :: Humanoid).DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local hat = asset(look.accessory)
		local accessory = if hat then accessoryFrom(hat) else nil
		if accessory then
			(humanoid :: Humanoid):AddAccessory(accessory)
		end
	end
	setAll(figure, false)
	templates[look.name] = figure
	return figure
end

-- The carrier hanging from `hand` (the figure's right hand) by its Grip, door to the front, the cat inside. `looks`
-- is how many figure looks there are.
local function carrierFor(
	figure: Model,
	hand: Instance?,
	kind: string,
	lookNumber: number,
	looks: number,
	empty: boolean?
): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	-- stepped past the figure looks, so one figure look does not always carry the same carrier
	local wanted = if CatRules.isSpecial(kind)
		then SpecialRules.CARRIER -- a special visitor's royal carrier (Model-Agent #476)
		else CARRIER_LOOKS[(lookNumber + lookNumber // looks) % #CARRIER_LOOKS + 1]
	local variant = if assets then assets:FindFirstChild(wanted) else nil
	local carrierAsset = if variant and variant:IsA("Model")
		then variant :: Model
		else asset(CARRIER_ASSET)
	if carrierAsset == nil or hand == nil or not hand:IsA("Attachment") then
		return nil
	end
	local carrier = carrierAsset:Clone() :: Model
	carrier.Name = "Carrier"
	local grip = carrier:FindFirstChild("Grip", true)
	local seat = carrier:FindFirstChild("CatSeat", true)
	if grip == nil or not grip:IsA("Attachment") then
		carrier:Destroy()
		return nil
	end
	local pivot = carrier:GetPivot()
	local gripLocal = pivot:PointToObjectSpace((grip :: Attachment).WorldPosition)
	local facing = figure:GetPivot().Rotation
	carrier:PivotTo(
		CFrame.new((hand :: Attachment).WorldPosition) * facing * CFrame.new(-gripLocal)
	)
	setAll(carrier, true)
	local cat = if empty then nil else asset(`CleanACat_Cat_{kind}_Dirty`)
	if cat and seat and seat:IsA("Attachment") then
		local copy = cat:Clone() :: Model
		local scale = carrier:GetAttribute("CatScale")
		copy:ScaleTo(if type(scale) == "number" and scale > 0 then scale else 0.8)
		copy:PivotTo((seat :: Attachment).WorldCFrame)
		setAll(copy, true)
		copy.Parent = carrier
	end
	return carrier
end

local function folderOf(player: Player): (Model?, Instance?)
	local slot = SpaLayout.slotOf(player)
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	return plot, if plot then plot:FindFirstChild(FOLDER_NAME) else nil
end

local function clear(player: Player)
	local _, old = folderOf(player)
	if old then
		old:Destroy()
	end
end

-- The `index`th spot of the line of mats in plot `slot` (SpaLayout.lineSpot for a slot instead of a player); past
-- the last mat the line goes on down the pavement.
local function lineSpotOf(index: number, slot: number): CFrame
	local name, past, before = SpaLayout.lineName("SpotQueue", index, true)
	local cframe = SpaLayout.slotSpot(name, slot)
	if past <= 0 then
		return cframe
	end
	return cframe + (cframe.Position - SpaLayout.slotSpot(before, slot).Position) * past
end

-- Where the customer at place `index` of plot `slot` stands: on the mats, or with benchGrow places 4 to 6 on
-- SpotBench<index> (SpaLayout.benchSpot for a slot).
local function queueSpot(index: number, slot: number): CFrame
	local counter = if counterOn()
		then SpaLayout.counterSpot(CounterRules.SPOT_PREFIX, index, slot)
		else nil
	if counter then
		return counter -- (switch counterLine) at the counter window
	end
	local bench = `SpotBench{index}`
	if LiveFlags.isOn(SpaRules.BENCH_FLAG) and SpaLayout.plotSpot(bench) then
		return SpaLayout.slotSpot(bench, slot)
	end
	return lineSpotOf(index, slot)
end

-- (switch counterLine) Where the cat of the customer at place `index` of plot `slot` sits on the counter: the plot's
-- SpotCounterCat<index>, else CounterRules.CAT_UP and CAT_FORWARD from where they stand.
local function catSpot(index: number, slot: number): CFrame
	return SpaLayout.counterSpot(CounterRules.CAT_SPOT_PREFIX, index, slot)
		or queueSpot(index, slot)
			* CFrame.new(0, CounterRules.CAT_UP, -CounterRules.CAT_FORWARD)
end

-- (switch counterLine) The dirty cat of `kind` on the counter for the customer of `lookNumber` at `place`, pivoted at
-- `at`: anchored, never colliding, with its place and its customer's look for Design's card and the take prompt.
local function counterCat(kind: string, lookNumber: number, place: number, at: CFrame): Model?
	local base = asset(`CleanACat_Cat_{kind}_Dirty`)
	if base == nil then
		return nil
	end
	local cat = base:Clone() :: Model
	cat.Name = CounterRules.CAT_NAME
	cat:ScaleTo(CounterRules.CAT_SCALE)
	cat:PivotTo(at)
	setAll(cat, true)
	for _, part in cat:GetDescendants() do
		if part:IsA("BasePart") then
			(part :: BasePart).CanCollide = false
			(part :: BasePart).CanTouch = false
		end
	end
	cat:SetAttribute(CounterRules.PLACE_ATTRIBUTE, place)
	cat:SetAttribute(CounterRules.LOOK_ATTRIBUTE, lookNumber)
	cat:SetAttribute(CounterRules.KIND_ATTRIBUTE, kind)
	return cat
end

-- A figure's place in the line as shown, on it and on its cat on the counter.
local function setPlace(figure: Model, index: number)
	figure:SetAttribute(PLACE_ATTRIBUTE, index)
	local cat = figure:FindFirstChild(CounterRules.CAT_NAME)
	if cat then
		cat:SetAttribute(CounterRules.PLACE_ATTRIBUTE, index)
	end
end

-- A leaving customer picks their cat up off the counter: it goes back in their carrier, so it walks off with them.
local function packCat(figure: Model)
	local cat = figure:FindFirstChild(CounterRules.CAT_NAME)
	if cat == nil or not cat:IsA("Model") then
		return
	end
	local carrier = figure:FindFirstChild("Carrier", true)
	local seat = if carrier then carrier:FindFirstChild("CatSeat", true) else nil
	if carrier == nil or seat == nil or not seat:IsA("Attachment") then
		cat:Destroy()
		return
	end
	local scale = carrier:GetAttribute("CatScale")
	local model = cat :: Model
	model:ScaleTo(if type(scale) == "number" and scale > 0 then scale else 0.8)
	model:PivotTo((seat :: Attachment).WorldCFrame)
	model:SetAttribute(CounterRules.PLACE_ATTRIBUTE, nil)
	model.Name = "PackedCat"
	model.Parent = carrier
end

-- Look numbers first, first + 1, ... for `count` customers.
local function lookRun(first: number, count: number): { number }
	local run = {}
	for index = 1, count do
		run[index] = first + index - 1
	end
	return run
end

-- One of Model-Agent's townsfolk for look number `lookNumber`, holding the carrier with a cat of `kind`, standing on
-- `spot` (its pivot is on the floor between its feet, front -Z, as a spot's).
local function townsfolkFor(
	lookNumber: number,
	kind: string,
	spot: CFrame,
	place: number?,
	slot: number?
): Model?
	local special = CatRules.isSpecial(kind)
	-- a special visitor is one of Model-Agent's three special customers (#476), each always with the same cat
	local look = if special
		then SpecialRules.lookFor(kind)
		else TOWNSFOLK[lookNumber % #TOWNSFOLK + 1]
	local base = asset(`CleanACat_NPC_Customer_{look}`)
	if base == nil then
		return nil
	end
	local figure = base:Clone() :: Model
	figure:PivotTo(spot)
	setAll(figure, true)
	local grip = figure:FindFirstChild("Grip", true)
	local onCounter = counterOn() and place ~= nil and slot ~= nil
	-- (switch counterCrate) the cat rides in the carrier up to the counter; Motion-FX hides one of the two
	local carrier =
		carrierFor(figure, grip, kind, lookNumber, #TOWNSFOLK, onCounter and not crateOn())
	if carrier then
		-- under the arm's joint Model, so the carrier sways with the arm Motion-FX turns
		local arm = if grip then grip:FindFirstAncestorWhichIsA("Model") else nil
		carrier.Parent = if arm and arm ~= (figure :: Instance) then arm else figure
	end
	if onCounter then
		-- the cat on the counter, placed from where the figure stands now as it will be from their place, so it lands
		-- on the counter as the figure arrives there (CustomerWalkController moves the whole figure)
		local mat = queueSpot(place :: number, slot :: number)
		local relative = mat:ToObjectSpace(catSpot(place :: number, slot :: number))
		local cat = counterCat(kind, lookNumber, place :: number, spot * relative)
		if cat then
			cat.Parent = figure
		end
	end
	figure:SetAttribute("CatKind", kind)
	if special then
		figure:SetAttribute(SpecialRules.FIGURE_ATTRIBUTE, true)
	end
	CollectionService:AddTag(figure, WalkRules.TAG)
	return figure
end

-- (switch counterCrate) Where the carrier of the customer at `place` is set down: the plot's SpotCounterCrate<place>,
-- else halfway from the customer to their cat at the counter top.
local function crateSpot(place: number, slot: number): CFrame
	local sits = catSpot(place, slot)
	local stands = queueSpot(place, slot)
	local halfway = stands.Position:Lerp(sits.Position, 0.5)
	return SpaLayout.counterSpot(CounterRules.CRATE_SPOT_PREFIX, place, slot)
		or CFrame.new(halfway.X, sits.Y, halfway.Z) * sits.Rotation
end

-- (switch counterCrate) Times the crate of `figure`'s cat on the counter (CounterRules.settleTimes): it goes down when
-- the figure, setting off from where it stands now at `walkAt`, reaches `mat` (the walk CustomerWalkController plays);
-- with no `walkAt` the cat already sits there.
-- Where each customer's current walk starts, once a step-up has given it a walk from part way (the drawn pivot stays
-- where the figure was first put; CustomerWalkController starts each new walk from where the figure stands).
-- A strong table, cleared when the figure is destroyed (Instance keys in weak tables are not reliably kept, #679).
local walkFrom: { [Model]: Vector3 } = {}

-- Where `figure` stands at server time `now`, along the walk its WalkTo and WalkAt describe.
local function standsAt(figure: Model, now: number): Vector3
	local from = walkFrom[figure] or figure:GetPivot().Position
	local to = figure:GetAttribute(WalkRules.TO_ATTRIBUTE)
	local at = figure:GetAttribute(WalkRules.AT_ATTRIBUTE)
	if typeof(to) ~= "CFrame" or type(at) ~= "number" then
		return from
	end
	local mat = to :: CFrame
	local speed = figure:GetAttribute("WalkSpeed")
	local distance = Vector3.new(mat.X - from.X, 0, mat.Z - from.Z).Magnitude
	local duration = WalkRules.duration(distance, if type(speed) == "number" then speed else nil)
	local progress = WalkRules.progress(now - at, duration) or 0
	return from:Lerp(mat.Position, progress)
end

local function settleCat(figure: Model, mat: CFrame, walkAt: number?, slot: number, start: Vector3?)
	local cat = figure:FindFirstChild(CounterRules.CAT_NAME)
	local place = if cat then cat:GetAttribute(CounterRules.PLACE_ATTRIBUTE) else nil
	if cat == nil or type(place) ~= "number" or not crateOn() then
		return
	end
	cat:SetAttribute(CounterRules.CRATE_SPOT_ATTRIBUTE, crateSpot(place, slot))
	local arriveAt: number? = nil
	if walkAt then
		local from = start or figure:GetPivot().Position
		local speed = figure:GetAttribute("WalkSpeed")
		local distance = Vector3.new(mat.X - from.X, 0, mat.Z - from.Z).Magnitude
		arriveAt = walkAt
			+ WalkRules.duration(distance, if type(speed) == "number" then speed else nil)
	end
	local setAt, readyAt = CounterRules.settleTimes(arriveAt, Workspace:GetServerTimeNow())
	cat:SetAttribute(CounterRules.SET_ATTRIBUTE, setAt)
	cat:SetAttribute(CounterRules.READY_ATTRIBUTE, readyAt)
end

-- The townsfolk for `kinds` in plot `slot`, front first. `from[index]` is where that customer stood as last drawn
-- (LineLooks.cameFrom: 0 for a new one); nil `from` puts everyone straight on their mat. Not parented yet.
local function buildTownsfolk(
	slot: number,
	kinds: { string },
	lookNumbers: { number },
	from: { number }?
): Folder
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local now = Workspace:GetServerTimeNow()
	local arrivals = 0
	for index = 1, math.min(#kinds, maxShown()) do
		local mat = queueSpot(index, slot)
		local was = if from then from[index] else index
		local start = mat
		local newcomer = false
		local setOff = now
		if was == 0 then
			start = lineSpotOf(WalkRules.STREET_PLACE, slot) -- on the pavement, whatever the bench
			setOff = now + arrivals * WalkRules.FILE_GAP -- new customers come in single file
			arrivals += 1
			newcomer = true
		elseif was ~= nil and was ~= index then
			start = queueSpot(was, slot)
		end
		local figure = townsfolkFor(lookNumbers[index] or index, kinds[index], start, index, slot)
		if figure then
			setPlace(figure, index)
			figure:SetAttribute(LOOK_ATTRIBUTE, lookNumbers[index] or index)
			if start ~= mat then
				figure:SetAttribute(WalkRules.TO_ATTRIBUTE, mat)
				figure:SetAttribute(WalkRules.AT_ATTRIBUTE, setOff)
				if newcomer then
					figure:SetAttribute(WalkRules.FILE_ATTRIBUTE, true)
				end
			end
			settleCat(figure, mat, if newcomer then setOff else nil, slot)
			figure.Parent = folder
		end
	end
	return folder
end

-- Builds the customers for `kinds` in plot `slot`, front first, customer `index` in look number `lookNumbers[index]`.
-- Not parented yet. May yield while a look's template is made. With `townsfolk` on, see buildTownsfolk.
local function buildFolder(
	slot: number,
	kinds: { string },
	lookNumbers: { number },
	from: { number }?
): Folder
	if LiveFlags.isOn(TOWNSFOLK_FLAG) then
		return buildTownsfolk(slot, kinds, lookNumbers, from)
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for index = 1, math.min(#kinds, maxShown()) do
		local look = LOOKS[(lookNumbers[index] or index) % #LOOKS + 1]
		local base = template(look)
		if base then
			local figure = base:Clone() :: Model
			figure.Name = `Customer{index}`
			local humanoid = figure:FindFirstChildOfClass("Humanoid")
			local root = figure:FindFirstChild("HumanoidRootPart")
			local height = if humanoid
					and root
					and root:IsA("BasePart")
				then (humanoid :: Humanoid).HipHeight + (root :: BasePart).Size.Y / 2
				else 3
			figure:PivotTo(queueSpot(index, slot) * CFrame.new(0, height, 0))
			if root and root:IsA("BasePart") then
				(root :: BasePart).Anchored = true
			end
			local carrier = carrierFor(
				figure,
				figure:FindFirstChild("RightGripAttachment", true),
				kinds[index],
				lookNumbers[index] or index,
				#LOOKS,
				counterOn()
			)
			if carrier then
				carrier.Parent = figure
			end
			if counterOn() then
				local cat = counterCat(
					kinds[index],
					lookNumbers[index] or index,
					index,
					catSpot(index, slot)
				)
				if cat then
					cat.Parent = figure
				end
			end
			figure:SetAttribute("CatKind", kinds[index])
			setPlace(figure, index)
			figure.Parent = folder
		end
	end
	return folder
end

-- (switch lineReuse) Redraws a drawn townsfolk line in place (issues 571 and 570): a customer still in the line keeps
-- their figure and, when their place changed, walks there from where they stand after STEP_UP_DELAY, so they never
-- step into a leaver's spot while the leaver walks off; a new customer is added on the pavement and walks in; one
-- who left is taken away. Nothing else is rebuilt, so no other figure blinks or arrives late on any screen.
local function redrawInPlace(player: Player, slot: number, line: LineLooks.Line, folder: Instance)
	local mine = (redraws[player] or 0) + 1
	redraws[player] = mine
	local drawn = table.move(line.looks, 1, math.min(#line.looks, maxShown()), 1, {})
	local byLook: { [number]: Model } = {}
	for _, child in folder:GetChildren() do
		local look = child:GetAttribute(LOOK_ATTRIBUTE)
		if
			child:IsA("Model")
			and type(look) == "number"
			and child:GetAttribute(LEAVING_ATTRIBUTE) ~= true
		then
			byLook[look] = child :: Model
		end
	end
	local now = Workspace:GetServerTimeNow()
	-- a newcomer waits on the pavement while anyone steps up, so they never reach a place before its customer has
	-- moved on from it (issue 628)
	local stepping = false
	for index, look in drawn do
		local figure = byLook[look]
		if
			figure
			and figure:GetAttribute("CatKind") == line.kinds[index]
			and figure:GetAttribute(PLACE_ATTRIBUTE) ~= index
		then
			stepping = true
		end
	end
	local walkIn = now + (if stepping then STEP_UP_DELAY else 0)
	local arrivals = 0
	local kept: { [Instance]: boolean } = {}
	local stepUps: { { figure: Model, index: number, mat: CFrame } } = {}
	local newcomers: { Model } = {}
	for index, look in drawn do
		local mat = queueSpot(index, slot)
		local kind = line.kinds[index]
		local figure = byLook[look]
		if figure and figure:GetAttribute("CatKind") == kind then
			kept[figure] = true
			if figure:GetAttribute(PLACE_ATTRIBUTE) ~= index then
				table.insert(stepUps, { figure = figure, index = index, mat = mat })
			end
			continue
		end
		local made = townsfolkFor(look, kind, lineSpotOf(WalkRules.STREET_PLACE, slot), index, slot)
		if redraws[player] ~= mine then
			if made then
				made:Destroy()
			end
			for _, other in newcomers do
				other:Destroy()
			end
			return -- a newer redraw took over while this one loaded a figure
		end
		if made then
			setPlace(made, index)
			made:SetAttribute(LOOK_ATTRIBUTE, look)
			made:SetAttribute(WalkRules.TO_ATTRIBUTE, mat)
			made:SetAttribute(WalkRules.AT_ATTRIBUTE, walkIn + arrivals * WalkRules.FILE_GAP)
			made:SetAttribute(WalkRules.FILE_ATTRIBUTE, true)
			settleCat(made, mat, walkIn + arrivals * WalkRules.FILE_GAP, slot)
			arrivals += 1
			kept[made] = true
			table.insert(newcomers, made)
		end
	end
	-- One pass with no yield (issue 571): the newcomers come, who went is taken away and the rest step up, so every
	-- device gets the whole change in the same frame and the line never counts one short or one over. The newcomers are
	-- parented first: a device applies the changes in the order they were made, and a new figure is many parts, so a
	-- removal sent ahead of it showed the line one short for a frame on a worker take (Review-QA's recheck on 2a34a8e).
	for _, made in newcomers do
		made.Parent = folder
	end
	for _, child in folder:GetChildren() do
		if kept[child] then
			continue
		end
		if lingering[child] then
			lingering[child] = nil
			task.delay(LEAVE_LINGER, function()
				if child.Parent then
					child:Destroy()
				end
			end)
		else
			child:Destroy()
		end
	end
	for _, step in stepUps do
		-- read before WalkTo and WalkAt change: where the new walk starts
		local here = standsAt(step.figure, now)
		local known: Vector3? = walkFrom[step.figure]
		if known == nil then
			local figure = step.figure
			figure.Destroying:Once(function()
				walkFrom[figure] = nil
			end)
		end
		walkFrom[step.figure] = here
		setPlace(step.figure, step.index)
		-- (switch counterCrate) the crate follows the customer to their new place (Sync's QA of PR 762: it stayed at
		-- the place they came in at). Still walking in with it: it goes down when they reach the new mat instead.
		local cat = step.figure:FindFirstChild(CounterRules.CAT_NAME)
		if cat and crateOn() then
			local setAt = cat:GetAttribute(CounterRules.SET_ATTRIBUTE)
			if type(setAt) == "number" and now < setAt then
				settleCat(step.figure, step.mat, now + STEP_UP_DELAY, slot, here)
			else
				cat:SetAttribute(CounterRules.CRATE_SPOT_ATTRIBUTE, crateSpot(step.index, slot))
			end
		end
		step.figure:SetAttribute(WalkRules.FILE_ATTRIBUTE, nil)
		step.figure:SetAttribute(WalkRules.TO_ATTRIBUTE, step.mat)
		-- set last: a client starts the walk when the start time changes
		step.figure:SetAttribute(WalkRules.AT_ATTRIBUTE, now + STEP_UP_DELAY)
	end
	shown[player] = drawn
end

local function draw(player: Player)
	-- (switch lineSwap) the old line stays until the new one is built, so it never blinks empty (issue 571)
	local swap = LiveFlags.isOn(SWAP_FLAG)
	if not swap then
		clear(player)
	end
	local line = lines[player]
	local plot = folderOf(player)
	local slot = SpaLayout.slotOf(player)
	if
		line == nil
		or plot == nil
		or slot == nil
		or not LiveFlags.isOn(FLAG)
		or not LiveFlags.isOn(CUSTOMERS_FLAG)
	then
		clear(player)
		shown[player] = nil
		return
	end
	local _, current = folderOf(player)
	if current and LiveFlags.isOn(REUSE_FLAG) and LiveFlags.isOn(TOWNSFOLK_FLAG) then
		redrawInPlace(player, slot, line, current)
		return
	end
	local drawn = table.move(line.looks, 1, math.min(#line.looks, maxShown()), 1, {})
	local folder =
		buildFolder(slot, line.kinds, line.looks, LineLooks.cameFrom(shown[player], drawn))
	-- template() may have yielded: draw only if this is still the newest queue.
	if lines[player] ~= line or folderOf(player) ~= plot then
		folder:Destroy()
		return
	end
	if swap then
		clear(player) -- the old line goes in the same frame the new one comes
	end
	folder.Parent = plot
	shown[player] = drawn
end

-- Called by SpaService with the player's queue, front first. Customers already known keep their looks
-- (LineLooks.show); the line before a serve or a pick was already moved by `served` or `picked`.
function FigureService.showQueue(player: Player, kinds: { string })
	local clean: { string } = {}
	for _, kind in kinds do
		if CatRules.rarityOf(kind) then
			table.insert(clean, kind)
		end
	end
	local line = LineLooks.show(lines[player], clean)
	lines[player] = line
	-- A resend of the same townsfolk leaves them be, so one walking in is not set back on their mat.
	local before = shown[player]
	local _, folder = folderOf(player)
	if LiveFlags.isOn(TOWNSFOLK_FLAG) and before and folder then
		local same = #before == math.min(#line.looks, maxShown())
		for index, look in before do
			same = same and line.looks[index] == look
		end
		if same then
			return
		end
	end
	task.spawn(draw, player)
end

-- Called by SpaService when the front customer hands over their cat (`kind`), before the line is refilled and
-- resent: that customer and their look leave, and everyone behind keeps theirs as they move up.
function FigureService.served(player: Player, kind: string)
	local line = LineLooks.served(lines[player], kind)
	if line then
		lines[player] = line -- a new table, so a draw still building the old line sees it is stale
	end
end

-- Called by SpaService when the player picked the customer at `index` to go next (switch queuePick), before it
-- resends the line: that customer's look goes to the front with their cat, so the figures don't swap cats.
function FigureService.picked(player: Player, index: number)
	local line = LineLooks.picked(lines[player], index)
	if line then
		lines[player] = line
	end
end

-- True while the line is redrawn in place (lineReuse with townsfolk): SpaService then tells the device of a leave
-- (CustomerLeft) after the redraw, and the leaver's figure lingers for it (`left` with `linger`).
function FigureService.inPlace(): boolean
	return LiveFlags.isOn(REUSE_FLAG) and LiveFlags.isOn(TOWNSFOLK_FLAG)
end

-- Called by SpaService when the customer at `index` of the line as shown leaves without being served (switch
-- heartBar) or is taken by a worker, before it resends the line: they and their look go, and everyone behind moves
-- up. `linger` (a customer who left, in place): the figure stays LEAVE_LINGER after the redraw for the walk off copy.
function FigureService.left(player: Player, index: number, linger: boolean?)
	local _, folder = folderOf(player)
	-- With lineReuse the leaver's figure stays until the redraw, which takes it away in the same frame the newcomer comes,
	-- so the line never counts one short for a frame (bug hunt B4); the device hides it beside its walk off copy itself
	-- (Effects/CustomerLeave, #612).
	if folder and FigureService.inPlace() then
		for _, figure in folder:GetChildren() do
			if
				figure:GetAttribute(PLACE_ATTRIBUTE) == index
				and figure:GetAttribute(LEAVING_ATTRIBUTE) ~= true
			then
				-- never taken for a newcomer with the same look; its place stays, for CustomerLeft's copy on the device
				figure:SetAttribute(LEAVING_ATTRIBUTE, true)
				if figure:IsA("Model") then
					packCat(figure :: Model) -- (switch counterLine) they take their cat off the counter with them
				end
				if linger and not lingering[figure] then
					lingering[figure] = true
					figure.Destroying:Once(function()
						lingering[figure] = nil
					end)
				end
			end
		end
	elseif folder and LiveFlags.isOn(SWAP_FLAG) then
		-- (switch lineSwap) the leaver's figure goes now: CustomerLeft went first, so their device already made the
		-- walk off copy, and the real figure is not shown beside it until the line is redrawn (issue 571)
		for _, figure in folder:GetChildren() do
			if figure:GetAttribute(PLACE_ATTRIBUTE) == index then
				figure:Destroy()
			end
		end
	end
	local line = LineLooks.left(lines[player], index)
	if line then
		lines[player] = line
	end
end

-- Puts each waiting customer's heart bar, 0 to 1, on their figure as HeartFill (switch heartBar), in the order of the
-- line as shown, for Motion-FX's mood poses and the client's grumpy moment. A figure not drawn yet gets it next time.
function FigureService.setHearts(player: Player, fills: { number })
	local _, folder = folderOf(player)
	if folder == nil then
		return
	end
	for _, figure in folder:GetChildren() do
		local place = figure:GetAttribute(PLACE_ATTRIBUTE)
		local fill = if type(place) == "number" then fills[place] else nil
		if figure:GetAttribute(HeartRules.FILL_ATTRIBUTE) ~= fill then
			figure:SetAttribute(HeartRules.FILL_ATTRIBUTE, fill)
		end
	end
end

-- Draws a full door line of `kinds` in plot `slot` whatever the switches say, replacing what is there. Only for
-- StreetLoadService's frame check on a full street; a player's own line goes through showQueue.
function FigureService.drawSlot(slot: number, kinds: { string })
	FigureService.clearSlot(slot)
	local folder = buildFolder(slot, kinds, lookRun(slot, #kinds))
	-- buildFolder may have yielded: skip if a player took the slot meanwhile, so no stand-in lands in their plot.
	local taken = false
	for _, player in Players:GetPlayers() do
		if SpaLayout.slotOf(player) == slot then
			taken = true
		end
	end
	local plot = SpaLayout.plotModel(slot)
	if taken or plot == nil or plot:FindFirstChild(FOLDER_NAME) then
		folder:Destroy()
		return
	end
	folder.Parent = plot
end

function FigureService.clearSlot(slot: number)
	local plot = SpaLayout.plotModel(slot)
	local old = if plot then plot:FindFirstChild(FOLDER_NAME) else nil
	if old then
		old:Destroy()
	end
end

local function drawAll()
	for _, player in Players:GetPlayers() do
		task.spawn(draw, player)
	end
end

-- (switch counterLine) Where the cat at shown place `index` sits on the counter in plot `slot`, for SpaService's reach
-- check on a take.
function FigureService.counterCatSpot(index: number, slot: number): CFrame
	return catSpot(index, slot)
end

-- (switch counterCrate) Whether the cat at shown counter place `place` of `player`'s line sits on the counter yet, so
-- it can be taken. True with no such cat drawn (counterCrate off, or the figures not drawn): SpaService's own checks
-- decide then.
function FigureService.counterSettled(player: Player, place: number): boolean
	local _, folder = folderOf(player)
	if folder == nil then
		return true
	end
	for _, item in folder:GetDescendants() do
		if
			item.Name == CounterRules.CAT_NAME
			and item:GetAttribute(CounterRules.PLACE_ATTRIBUTE) == place
		then
			return CounterRules.settled(
				item:GetAttribute(CounterRules.READY_ATTRIBUTE),
				Workspace:GetServerTimeNow()
			)
		end
	end
	return true
end

function FigureService.Init(_services: { [string]: any }) end

function FigureService.Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		clear(player)
		lines[player] = nil
		shown[player] = nil
		redraws[player] = nil
	end)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(drawAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(drawAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CUSTOMERS_FLAG)
		:Connect(drawAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. TOWNSFOLK_FLAG)
		:Connect(drawAll)
	-- the counter on or off changes how every figure is dressed: those lines are built again, not redrawn in place
	for _, flag in { CounterRules.FLAG, CarryRules.FLAG, CounterRules.CRATE_FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(function()
				for _, player in Players:GetPlayers() do
					clear(player)
					shown[player] = nil
				end
				drawAll()
			end)
	end
end

return FigureService
