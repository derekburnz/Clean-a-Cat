--!strict
-- StationService: the stations a player has built stand in that player's own plot (SpaLayout.STATIONS), where
-- everyone on the street can see them through the open front. Before a station is built its spot holds the
-- build pad (SpaLayout.PAD_ASSET) with the station's name and price. The VIP Room's door shows locked, then a
-- building site while its build runs, and goes once it is built. Redrawn when the save loads, when a build
-- starts or finishes (BuildService calls StationService.refresh), when the street is placed again, and when the switch
-- changes; cleared when the owner leaves, so the next player in that slot starts empty.
-- Behind the LiveFlags switch `stations`, off by default. Stations change nothing on the server: the pay bonus
-- is BuildRules', and the client's dry step (ScrubController) only reads the Blow Dryer model placed here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

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

-- A name and a second line on the model's Screen part's front.
local function label(pad: Model, title: string, line: string)
	local screen = pad:FindFirstChild("Screen", true)
	if screen == nil or not screen:IsA("BasePart") then
		return
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
end

local function clear(plot: Model)
	local old = plot:FindFirstChild(SpaLayout.STATIONS_FOLDER)
	if old then
		old:Destroy()
	end
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
	local folder = Instance.new("Folder")
	folder.Name = SpaLayout.STATIONS_FOLDER
	for _, entry in SpaLayout.STATIONS do
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
			local item = BuildRules.ITEMS[entry.id]
			label(model, item.name, `{item.price} coins`)
		end
		model.Parent = folder
	end
	-- The VIP Room door: locked, a building site while it builds, gone once built.
	local vip = BuildRules.ITEMS[SpaLayout.VIP_ID]
	local running = BuildRules.cleanBuilds(save.builds)[vip.slot]
	local building = running ~= nil and running.item == SpaLayout.VIP_ID
	if not save.stations[SpaLayout.VIP_ID] then
		local doorName = if building
			then SpaLayout.VIP_BUILDING_ASSET
			else SpaLayout.VIP_LOCKED_ASSET
		local door = (assets :: Instance):FindFirstChild(doorName)
		if door and door:IsA("Model") then
			local model = (door :: Model):Clone() :: Model
			model.Name = SpaLayout.VIP_ID
			model:SetAttribute("Built", false)
			if building and running then
				model:SetAttribute("EndsAt", running.endsAt)
			end
			model:PivotTo(SpaLayout.slotSpot(SpaLayout.VIP_SPOT, slot))
			anchorAll(model)
			label(model, vip.name, if building then "Building" else `{vip.price} coins`)
			model.Parent = folder
		elseif not warned[doorName] then
			warned[doorName] = true
			warn(`[StationService] {doorName} is missing from ReplicatedStorage.Assets`)
		end
	end
	folder.Parent = plot
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
	refreshAll()
end

return StationService
