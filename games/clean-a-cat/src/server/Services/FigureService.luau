--!strict
-- FigureService: the customers waiting at a player's door, drawn by the server in that player's own plot so the
-- whole street sees them. Each customer is a Roblox R15 figure (Players:CreateHumanoidModelFromDescription, which
-- only the server may call) in one of the style guide's four looks (section 15: body colours and one accessory),
-- holding Model-Agent's carrier by its Grip with the customer's dirty cat inside at the carrier's CatScale.
-- SpaService calls showQueue whenever it sends the queue. The figures only show the queue; they change nothing.
-- Behind the LiveFlags switch `customerFigures` (and `customers`), off by default. While it is off, or before the
-- plot is placed, each client draws its own placeholder line (DoorController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "customerFigures"
local CUSTOMERS_FLAG = "customers"
local FOLDER_NAME = "Customers"
local CARRIER_ASSET = "CleanACat_Prop_Carrier"
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
local lastKinds: { [Player]: { string } } = {}
local served: { [Player]: number } = {} -- customers served this session, so each look moves up the line with its owner
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

-- The carrier hanging from the figure's right hand by its Grip, door to the front, the cat inside.
local function carrierFor(figure: Model, kind: string): Model?
	local carrierAsset = asset(CARRIER_ASSET)
	local hand = figure:FindFirstChild("RightGripAttachment", true)
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

local function draw(player: Player)
	clear(player)
	local kinds = lastKinds[player]
	local plot = folderOf(player)
	if
		kinds == nil
		or plot == nil
		or not LiveFlags.isOn(FLAG)
		or not LiveFlags.isOn(CUSTOMERS_FLAG)
	then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for index = 1, math.min(#kinds, MAX_SHOWN) do
		local look = LOOKS[((served[player] or 0) + index - 1) % #LOOKS + 1]
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
			figure:PivotTo(
				SpaLayout.lineSpot("SpotQueue", index, player) * CFrame.new(0, height, 0)
			)
			if root and root:IsA("BasePart") then
				(root :: BasePart).Anchored = true
			end
			local carrier = carrierFor(figure, kinds[index])
			if carrier then
				carrier.Parent = figure
			end
			figure:SetAttribute("CatKind", kinds[index])
			figure.Parent = folder
		end
	end
	-- template() may have yielded: draw only if this is still the newest queue.
	if lastKinds[player] ~= kinds or folderOf(player) ~= plot then
		folder:Destroy()
		return
	end
	folder.Parent = plot
end

-- The front customer was served when the new line is the old one moved up by one.
local function movedUp(old: { string }?, new: { string }): boolean
	if old == nil or #old == 0 then
		return false
	end
	for index = 1, #old - 1 do
		if new[index] ~= old[index + 1] then
			return false
		end
	end
	return true
end

-- Called by SpaService with the player's queue, front first.
function FigureService.showQueue(player: Player, kinds: { string })
	local clean: { string } = {}
	for _, kind in kinds do
		if CatRules.rarityOf(kind) then
			table.insert(clean, kind)
		end
	end
	if movedUp(lastKinds[player], clean) then
		served[player] = (served[player] or 0) + 1
	end
	lastKinds[player] = clean
	task.spawn(draw, player)
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
		lastKinds[player] = nil
		served[player] = nil
	end)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(drawAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(drawAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CUSTOMERS_FLAG)
		:Connect(drawAll)
end

return FigureService
