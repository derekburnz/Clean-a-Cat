--!strict
-- StationService: the stations a player has built stand in that player's own plot (SpaLayout.STATIONS), where
-- everyone on the street can see them through the open front. Before a station is built its spot holds the
-- build pad (SpaLayout.PAD_ASSET) with the station's name and price. The VIP Room's door shows locked, then a
-- building site while its build runs, and goes once it is built. The builder kitten (hard hat, hammer, toolbox)
-- stands by the builder board; while a station builds it has the attribute Building and the toolbox EndsAt, for
-- Motion-FX and the countdown. Redrawn when the save loads, when a build starts or finishes (BuildService calls
-- StationService.refresh), when the street is placed again and when the switch changes. Cleared when the owner
-- leaves, so the next player in that slot starts empty.
-- With tubBuilds on (issue 515, tuning build.VipRoom.effect), the built VIP Room itself (VipRules.AREA_ASSET) stands at
-- the door's spot, and the special cats the player has washed sit on its seats as residents (VipRules.residents);
-- SpaService calls StationService.refresh when a special cat is washed for the first time. The Garden (GardenRules)
-- stands behind the back door the same way: its locked gate, its building site, then the garden itself, where the
-- pets in the player's pen play while the switch pets is on too; PetService calls StationService.refreshGarden after
-- every change to the pets.
-- Behind the LiveFlags switch `stations`, off by default. Stations change nothing on the server: the pay bonus
-- is BuildRules', and the client's dry step (ScrubController) only reads the Blow Dryer model placed here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local VipRules = require(Shared:WaitForChild("VipRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local FLAG = "stations"
local LABEL_COLOR = Color3.fromRGB(90, 70, 110)

local StationService = {}

local warned: { [string]: boolean } = {}

local function anchorAll(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).Anchored = true
		end
	end
end

-- Moves `model` so its attachment `name` lands on `target`. False when it has no such attachment.
local function alignTo(model: Model, name: string, target: CFrame): boolean
	local attachment = model:FindFirstChild(name, true)
	if attachment == nil or not attachment:IsA("Attachment") then
		return false
	end
	local offset = (attachment :: Attachment).WorldCFrame:Inverse() * model:GetPivot()
	model:PivotTo(target * offset)
	return true
end

local function attachmentIn(model: Model, name: string): Attachment?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("Attachment") then found :: Attachment else nil
end

-- The builder kitten by the board, with its hat, hammer and toolbox, all in `folder`. With humanBuilder (issue 891)
-- the human builder stands there instead, his hard hat on his head already, with the same hammer and toolbox; the
-- kitten while his model is not in the game.
local function drawKitten(
	folder: Folder,
	assets: Instance,
	slot: number,
	running: BuildRules.Build?
)
	local humanAsset = if LiveFlags.isOn(SpaLayout.BUILDER_FLAG)
		then assets:FindFirstChild(SpaLayout.BUILDER_ASSET)
		else nil
	local human = humanAsset ~= nil and humanAsset:IsA("Model")
	local kittenAsset = if human
		then humanAsset
		else assets:FindFirstChild("CleanACat_NPC_BuilderKitten")
	if kittenAsset == nil or not kittenAsset:IsA("Model") then
		return
	end
	local spot = SpaLayout.slotSpot(SpaLayout.BUILDER_SPOT, slot)
	local kitten = (kittenAsset :: Model):Clone() :: Model
	kitten.Name = if human then "Builder" else "BuilderKitten"
	kitten:PivotTo(
		spot * CFrame.new(if human then SpaLayout.BUILDER_OFFSET else SpaLayout.KITTEN_OFFSET)
	)
	kitten:SetAttribute("Building", running ~= nil)
	anchorAll(kitten)
	local hatSlot = if human then nil else attachmentIn(kitten, "HatSlot")
	local hatAsset = assets:FindFirstChild("CleanACat_Prop_HardHat")
	if hatSlot and hatAsset and hatAsset:IsA("Model") then
		local hat = (hatAsset :: Model):Clone() :: Model
		hat.Name = "HardHat"
		if alignTo(hat, "HatSlot", hatSlot.WorldCFrame) then
			anchorAll(hat)
			hat.Parent = kitten
		else
			hat:Destroy()
		end
	end
	local grip = attachmentIn(kitten, "HammerGrip")
	local hammerAsset = assets:FindFirstChild("CleanACat_Prop_Hammer")
	if grip and hammerAsset and hammerAsset:IsA("Model") then
		local hammer = (hammerAsset :: Model):Clone() :: Model
		hammer.Name = "Hammer"
		if alignTo(hammer, "Grip", grip.WorldCFrame) then
			anchorAll(hammer)
			hammer.Parent = kitten
		else
			hammer:Destroy()
		end
	end
	kitten.Parent = folder
	local toolboxAsset = assets:FindFirstChild("CleanACat_Prop_Toolbox")
	if toolboxAsset and toolboxAsset:IsA("Model") then
		local toolbox = (toolboxAsset :: Model):Clone() :: Model
		toolbox.Name = "Toolbox"
		toolbox:PivotTo(spot * CFrame.new(SpaLayout.TOOLBOX_OFFSET))
		if running then
			toolbox:SetAttribute("EndsAt", running.endsAt)
		end
		anchorAll(toolbox)
		toolbox.Parent = folder
	end
end

-- The signs of running room builds (the VIP Room's and the Garden's sites), whose second line counts down
-- (issue 679): each label with its title and the build's end (os.time). A strong table: a weak one on Instances can
-- lose a label that still exists (Review-QA, #679), so a sign drops out only when it is destroyed.
local countdowns: { [TextLabel]: { title: string, endsAt: number } } = {}

-- A name and a second line on the model's Screen part's front.
local function label(pad: Model, title: string, line: string): TextLabel?
	local screen = pad:FindFirstChild("Screen", true)
	if screen == nil or not screen:IsA("BasePart") then
		return nil
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = LABEL_COLOR
	text.Text = `{title}\n{line}`
	text.Parent = gui
	gui.Parent = screen
	return text
end

-- A running room build's sign: the title over the time left, kept up to date by the countdown loop.
local function buildingLabel(model: Model, title: string, endsAt: number)
	local text = label(model, title, BuildRules.leftText(endsAt - os.time()))
	if text then
		countdowns[text] = { title = title, endsAt = endsAt }
		text.Destroying:Once(function()
			countdowns[text] = nil
		end)
	end
end

local function clear(plot: Model)
	local old = plot:FindFirstChild(SpaLayout.STATIONS_FOLDER)
	if old then
		old:Destroy()
	end
end

-- Draws stations, pads, the kitten and the VIP door in plot `slot` from a save's `stations` and `builds`.
-- A resident: the special cat's light sitting twin, else its sitting model, else its plain one (VipRules.residentModel),
-- with no scripts, anchored and not in the way, on seat `seat` at `scale`.
local function seatResident(
	area: Model,
	assets: Instance,
	kind: string,
	seat: number,
	scale: number
)
	local spot = attachmentIn(area, `{VipRules.SEAT_PREFIX}{seat}`)
	local name = VipRules.residentModel(kind, function(asset: string): boolean
		local found = assets:FindFirstChild(asset)
		return found ~= nil and found:IsA("Model")
	end)
	local base = if name then assets:FindFirstChild(name) else nil
	if spot == nil or base == nil or not base:IsA("Model") then
		return
	end
	local cat = (base :: Model):Clone() :: Model
	cat.Name = `Resident_{kind}`
	for _, piece in cat:GetDescendants() do
		if piece:IsA("Script") or piece:IsA("LocalScript") then
			piece:Destroy()
		elseif piece:IsA("BasePart") then
			local part = piece :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	cat:SetAttribute(VipRules.RESIDENT_ATTRIBUTE, seat)
	cat:SetAttribute("Cat", kind)
	cat:ScaleTo(scale)
	cat:PivotTo((spot :: Attachment).WorldCFrame)
	cat.Parent = area
end

-- The built VIP Room at the door's spot, with the player's washed special cats on its seats.
local function drawVipRoom(folder: Folder, assets: Instance, slot: number, index: any?)
	local asset = assets:FindFirstChild(VipRules.AREA_ASSET)
	if asset == nil or not asset:IsA("Model") then
		if not warned[VipRules.AREA_ASSET] then
			warned[VipRules.AREA_ASSET] = true
			warn(`[StationService] {VipRules.AREA_ASSET} is missing from ReplicatedStorage.Assets`)
		end
		return
	end
	local area = (asset :: Model):Clone() :: Model
	area.Name = VipRules.AREA_NAME
	area:SetAttribute("Built", true)
	area:PivotTo(SpaLayout.slotSpot(SpaLayout.VIP_SPOT, slot))
	anchorAll(area)
	if type(index) == "table" then
		local seats = VipRules.seatCount(area:GetAttribute(VipRules.SEATS_ATTRIBUTE))
		local scale = VipRules.scale(area:GetAttribute(VipRules.SCALE_ATTRIBUTE))
		for seat, kind in VipRules.residents(index, seats) do
			seatResident(area, assets, kind, seat, scale)
		end
	end
	area.Parent = folder
end

-- A pet in the garden: its model at its star, with no scripts, anchored and not in the way, on spot `spot`.
local function seatGardenPet(garden: Model, assets: Instance, pet: GardenRules.Seated, spot: number)
	local at = attachmentIn(garden, GardenRules.spotName(spot))
	local base = assets:FindFirstChild(`CleanACat_Pet_{pet.kind}`)
	if at == nil or base == nil or not base:IsA("Model") then
		return
	end
	local model = (base :: Model):Clone() :: Model
	model.Name = `GardenPet{spot}`
	for _, piece in model:GetDescendants() do
		local level = piece:GetAttribute("StarLevel")
		local aboveStar = piece:IsA("Model") and type(level) == "number" and level > pet.star
		if aboveStar or piece:IsA("Script") or piece:IsA("LocalScript") then
			piece:Destroy()
		elseif piece:IsA("BasePart") then
			local part = piece :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model:SetAttribute(GardenRules.PET_ATTRIBUTE, spot)
	model:SetAttribute("Pet", pet.kind)
	model:ScaleTo(GardenRules.PET_SCALE)
	model:PivotTo((at :: Attachment).WorldCFrame)
	model.Parent = garden
end

-- The pets in the finished garden, drawn again from `pets` (the save's).
local function drawGardenPets(garden: Model, assets: Instance, pets: any)
	for _, child in garden:GetChildren() do
		if child:GetAttribute(GardenRules.PET_ATTRIBUTE) ~= nil then
			child:Destroy()
		end
	end
	if type(pets) ~= "table" then
		return
	end
	local spots = GardenRules.spotCount(garden:GetAttribute(GardenRules.SPOTS_ATTRIBUTE))
	for spot, pet in GardenRules.pets(pets, spots) do
		seatGardenPet(garden, assets, pet, spot)
	end
end

-- (tubBuilds) The Garden at the back door: the locked gate, the building site while its build runs, then the garden.
local function drawGarden(
	folder: Folder,
	assets: Instance,
	slot: number,
	save: { stations: any, pets: any? },
	running: { [string]: BuildRules.Build },
	isOn: (flag: string) -> boolean
)
	local item = BuildRules.item(GardenRules.ID, isOn)
	if item == nil then
		return
	end
	local build = running[item.slot]
	local building = build ~= nil and build.item == GardenRules.ID
	local built = save.stations[GardenRules.ID] == true
	local assetName = if built
		then GardenRules.AREA_ASSET
		elseif building then GardenRules.BUILDING_ASSET
		else GardenRules.LOCKED_ASSET
	local asset = assets:FindFirstChild(assetName)
	if asset == nil or not asset:IsA("Model") then
		if not warned[assetName] then
			warned[assetName] = true
			warn(`[StationService] {assetName} is missing from ReplicatedStorage.Assets`)
		end
		return
	end
	local model = (asset :: Model):Clone() :: Model
	model.Name = if built then GardenRules.AREA_NAME else GardenRules.ID
	model:SetAttribute("Built", built)
	if building and build then
		model:SetAttribute("EndsAt", build.endsAt)
	end
	model:PivotTo(SpaLayout.slotSpot(GardenRules.SPOT, slot))
	anchorAll(model)
	if not built then
		if building and build then
			buildingLabel(model, item.name, build.endsAt)
		else
			label(model, item.name, `{item.price} coins`)
		end
	elseif isOn(CrateRules.FLAG) then
		drawGardenPets(model, assets, save.pets)
	end
	model.Parent = folder
end

local function drawInto(
	plot: Model,
	slot: number,
	assets: Instance,
	save: { stations: any, builds: any, index: any?, pets: any? },
	isOn: (flag: string) -> boolean
)
	local folder = Instance.new("Folder")
	folder.Name = SpaLayout.STATIONS_FOLDER
	for _, entry in SpaLayout.STATIONS do
		-- a station with its own switch (the Bubble Bath, the Pawdicure; #267) stands, or waits as a pad, only
		-- while that switch is on
		-- (tubBuilds) the tubs, and the old stations that leave for them, by BuildRules.shown
		if not BuildRules.shown(entry.id, isOn) then
			continue
		end
		local built = save.stations[entry.id] == true
		local assetName = if built then entry.asset else SpaLayout.PAD_ASSET
		local asset = (assets :: Instance):FindFirstChild(assetName)
		if asset == nil or not asset:IsA("Model") then
			if not warned[assetName] then
				warned[assetName] = true
				warn(`[StationService] {assetName} is missing from ReplicatedStorage.Assets`)
			end
			continue
		end
		local model = (asset :: Model):Clone() :: Model
		model.Name = entry.id
		model:SetAttribute("Built", built)
		model:PivotTo(SpaLayout.slotSpot(entry.spot, slot))
		anchorAll(model)
		if not built then
			local item = BuildRules.item(entry.id, isOn) :: BuildRules.Item
			label(model, item.name, `{item.price} coins`)
		end
		model.Parent = folder
	end
	-- the kitten builds stations; under tubBuilds it is the one builder, so it builds whatever is running
	local running = BuildRules.cleanBuilds(save.builds)
	local kittenBuild = running[BuildRules.ITEMS.BrushTable.slot]
	if kittenBuild == nil and isOn(BuildRules.TUBS_FLAG) then
		kittenBuild = running.room
	end
	drawKitten(folder, assets :: Instance, slot, kittenBuild)
	-- The VIP Room door: locked, a building site while it builds, gone once built.
	local vip = BuildRules.item(SpaLayout.VIP_ID, isOn) :: BuildRules.Item
	local vipBuild = running[vip.slot]
	local building = vipBuild ~= nil and vipBuild.item == SpaLayout.VIP_ID
	if not save.stations[SpaLayout.VIP_ID] then
		local doorName = if building
			then SpaLayout.VIP_BUILDING_ASSET
			else SpaLayout.VIP_LOCKED_ASSET
		local door = (assets :: Instance):FindFirstChild(doorName)
		if door and door:IsA("Model") then
			local model = (door :: Model):Clone() :: Model
			model.Name = SpaLayout.VIP_ID
			model:SetAttribute("Built", false)
			if building and vipBuild then
				model:SetAttribute("EndsAt", vipBuild.endsAt)
			end
			model:PivotTo(SpaLayout.slotSpot(SpaLayout.VIP_SPOT, slot))
			anchorAll(model)
			if building and vipBuild then
				buildingLabel(model, vip.name, vipBuild.endsAt)
			else
				label(model, vip.name, `{vip.price} coins`)
			end
			model.Parent = folder
		elseif not warned[doorName] then
			warned[doorName] = true
			warn(`[StationService] {doorName} is missing from ReplicatedStorage.Assets`)
		end
	elseif isOn(BuildRules.TUBS_FLAG) then
		drawVipRoom(folder, assets :: Instance, slot, save.index)
	end
	if BuildRules.shown(GardenRules.ID, isOn) then
		drawGarden(folder, assets :: Instance, slot, save, running, isOn)
	end
	folder.Parent = plot
end

-- Draws the player's stations and pads in their plot.
function StationService.refresh(player: Player)
	local slot = SpaLayout.slotOf(player)
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	if slot == nil or plot == nil then
		return
	end
	clear(plot)
	local save = DataService.get(player)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not LiveFlags.isOn(FLAG) or save == nil or assets == nil then
		return
	end
	drawInto(plot, slot, assets :: Instance, save, LiveFlags.isOn)
end

-- Draws the pets in the player's finished garden again (PetService, after every change to the pets), leaving the
-- rest of the plot as it is.
function StationService.refreshGarden(player: Player)
	local slot = SpaLayout.slotOf(player)
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	local folder = if plot then plot:FindFirstChild(SpaLayout.STATIONS_FOLDER) else nil
	local garden = if folder then folder:FindFirstChild(GardenRules.AREA_NAME) else nil
	local save = DataService.get(player)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if garden == nil or not garden:IsA("Model") or save == nil or assets == nil then
		return
	end
	drawGardenPets(
		garden :: Model,
		assets :: Instance,
		if LiveFlags.isOn(CrateRules.FLAG) then save.pets else nil
	)
end

-- Draws plot `slot` as if its owner had these stations and builds, whatever the switches say, replacing what is
-- there. Only for StreetLoadService's frame check on a full street.
function StationService.drawSlot(
	slot: number,
	stations: { [string]: boolean },
	builds: { [string]: any }
)
	local plot = SpaLayout.plotModel(slot)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if plot == nil or assets == nil then
		return
	end
	clear(plot)
	drawInto(plot, slot, assets :: Instance, { stations = stations, builds = builds }, function()
		return true
	end)
end

function StationService.clearSlot(slot: number)
	local plot = SpaLayout.plotModel(slot)
	if plot then
		clear(plot)
	end
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		StationService.refresh(player)
	end
end

function StationService.Init(_services: { [string]: any }) end

function StationService.Start()
	DataService.onLoaded:Connect(function(player: Player)
		StationService.refresh(player)
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(function()
			StationService.refresh(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local slot = SpaLayout.slotOf(player)
		local plot = if slot then SpaLayout.plotModel(slot) else nil
		if plot then
			clear(plot)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(refreshAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(refreshAll)
	ReplicatedStorage
		:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. SpaLayout.BUILDER_FLAG)
		:Connect(refreshAll)
	-- a station's own switches (#267, tubBuilds) show or hide it and its pad
	for _, flag in BuildRules.itemFlags() do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(refreshAll)
	end
	refreshAll()
	-- the room build signs count down; a finished build redraws the plot (BuildService), which drops its sign
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for text, entry in countdowns do
				if text.Parent == nil then
					countdowns[text] = nil
				else
					local line = `{entry.title}\n{BuildRules.leftText(entry.endsAt - now)}`
					if text.Text ~= line then
						text.Text = line
					end
				end
			end
		end
	end)
end

return StationService
