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
local CatRules = require(Shared:WaitForChild("CatRules"))
local HeartRules = require(Shared:WaitForChild("HeartRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpecialRules = require(Shared:WaitForChild("SpecialRules"))
local WalkRules = require(Shared:WaitForChild("WalkRules"))

local LineLooks = require(script.Parent.Parent.Util.LineLooks)

local FLAG = "customerFigures"
local TOWNSFOLK_FLAG = "townsfolk"
local SWAP_FLAG = "lineSwap" -- issue 571
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

local FigureService = {}

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
	looks: number
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
	local cat = asset(`CleanACat_Cat_{kind}_Dirty`)
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

-- The `index`th queue spot of plot `slot` (SpaLayout.lineSpot for a slot instead of a player).
local function queueSpot(index: number, slot: number): CFrame
	local name, past, before = SpaLayout.lineName("SpotQueue", index, true)
	local cframe = SpaLayout.slotSpot(name, slot)
	if past <= 0 then
		return cframe
	end
	return cframe + (cframe.Position - SpaLayout.slotSpot(before, slot).Position) * past
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
local function townsfolkFor(lookNumber: number, kind: string, spot: CFrame): Model?
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
	local carrier = carrierFor(figure, grip, kind, lookNumber, #TOWNSFOLK)
	if carrier then
		-- under the arm's joint Model, so the carrier sways with the arm Motion-FX turns
		local arm = if grip then grip:FindFirstAncestorWhichIsA("Model") else nil
		carrier.Parent = if arm and arm ~= (figure :: Instance) then arm else figure
	end
	figure:SetAttribute("CatKind", kind)
	if special then
		figure:SetAttribute(SpecialRules.FIGURE_ATTRIBUTE, true)
	end
	CollectionService:AddTag(figure, WalkRules.TAG)
	return figure
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
	for index = 1, math.min(#kinds, MAX_SHOWN) do
		local mat = queueSpot(index, slot)
		local was = if from then from[index] else index
		local start = mat
		local setOff = now
		if was == 0 then
			start = queueSpot(WalkRules.STREET_PLACE, slot)
			setOff = now + arrivals * WalkRules.FILE_GAP -- new customers come in single file
			arrivals += 1
		elseif was ~= nil and was ~= index then
			start = queueSpot(was, slot)
		end
		local figure = townsfolkFor(lookNumbers[index] or index, kinds[index], start)
		if figure then
			figure:SetAttribute(PLACE_ATTRIBUTE, index)
			if start ~= mat then
				figure:SetAttribute(WalkRules.TO_ATTRIBUTE, mat)
				figure:SetAttribute(WalkRules.AT_ATTRIBUTE, setOff)
			end
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
	for index = 1, math.min(#kinds, MAX_SHOWN) do
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
				#LOOKS
			)
			if carrier then
				carrier.Parent = figure
			end
			figure:SetAttribute("CatKind", kinds[index])
			figure:SetAttribute(PLACE_ATTRIBUTE, index)
			figure.Parent = folder
		end
	end
	return folder
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
	local drawn = table.move(line.looks, 1, math.min(#line.looks, MAX_SHOWN), 1, {})
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
		local same = #before == math.min(#line.looks, MAX_SHOWN)
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

-- Called by SpaService when the customer at `index` of the line as shown leaves without being served (switch
-- heartBar), before it resends the line: they and their look go, and everyone behind moves up.
function FigureService.left(player: Player, index: number)
	local _, folder = folderOf(player)
	if folder and LiveFlags.isOn(SWAP_FLAG) then
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

function FigureService.Init(_services: { [string]: any }) end

function FigureService.Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		clear(player)
		lines[player] = nil
		shown[player] = nil
	end)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(drawAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(drawAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CUSTOMERS_FLAG)
		:Connect(drawAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. TOWNSFOLK_FLAG)
		:Connect(drawAll)
end

return FigureService
