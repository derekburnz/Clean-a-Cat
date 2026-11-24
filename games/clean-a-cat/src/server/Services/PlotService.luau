--!strict
-- PlotService: places the street of spa plots (Model-Agent's ReplicatedStorage.Assets.CleanACat_Area_SpaPlot,
-- SpaLayout.PLOT_COUNT copies side by side) in Workspace.SpaPlots and gives every player their own (#88): the
-- lowest free slot, in the Player attribute SpaLayout.SLOT_ATTRIBUTE, freed when they leave. Each plot has its own
-- SpawnLocation on its spawn spot (SpaLayout.spawnSpot: SpotSpawn facing the tub, or with `spawnView` on beside the
-- turned tub facing the street), and each player's Player.RespawnLocation is their plot's, so a character appears
-- in its own plot and is never carried over from plot 1 (#188). Behind the LiveFlags switch `spaPlot`: off, the street is
-- taken away and the spawn goes back to the placeholder room, so the world is exactly as before.
-- Clients and other services read the spots through Shared.SpaLayout; the ReplicatedStorage attribute
-- SpaLayout.PLACED_ATTRIBUTE says whether the street is placed, so they redraw when it changes.
-- With each plot come Model-Agent's fixed props on their spots (SpaLayout.PROPS, in the plot's Props folder):
-- queue mats, the stray box, the window cushions, the tip jar and the spa sign. What changes per player (cats,
-- the jar's fill, the chance board) is drawn by the owner's client on top.
-- Under the plots goes Model-Agent's street (SpaLayout.STREET_ASSET, pivot at slot 1's pivot, unrotated). While it
-- is placed the placeholder floor PH_Floor is put away in ServerStorage, so the two grounds never fight; it comes
-- back with the room.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local SPAWN_NAME = "PH_Spawn" -- the spawn in default.project.json
local FLOOR_NAME = "PH_Floor" -- the placeholder floor in default.project.json
local ASSET_WAIT_SECONDS = 10
local VIEW_FLAG = SpaLayout.VIEW_FLAG -- moves the spawn beside the turned tub (SpaLayout.spawnSpot, #169)

local PlotService = {}

local street: Folder? = nil
local roomSpawn: CFrame? = nil -- where PH_Spawn stood before the plot, to put it back
local plotSpawns: { [number]: SpawnLocation } = {} -- copies of PH_Spawn for slot 2 and up, in the street folder
local storedFloor: Instance? = nil -- PH_Floor while the street is placed
local owners: { [number]: Player? } = {}

local function spawnLocation(): BasePart?
	local spawn = Workspace:FindFirstChild(SPAWN_NAME)
	return if spawn and spawn:IsA("SpawnLocation") then spawn :: BasePart else nil
end

local function anchorAll(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).Anchored = true
		end
	end
end

-- A spot on a plot not yet in Workspace: its Attachment, or the table's spot for that slot.
local function spotOn(plot: Model, name: string, slot: number): CFrame
	local attachment = plot:FindFirstChild(name, true)
	if attachment and attachment:IsA("Attachment") then
		return (attachment :: Attachment).WorldCFrame
	end
	local position, yaw = SpaLayout.place(name, true, slot)
	return CFrame.new(position or Vector3.zero) * CFrame.Angles(0, yaw, 0)
end

-- One plot in slot `slot`, with its props, parented to `folder`.
local function placePlot(asset: Model, assets: Instance, slot: number, folder: Folder)
	local plot = asset:Clone() :: Model
	plot.Name = `Plot{slot}`
	plot:SetAttribute("Slot", slot)
	-- With streaming on, every plot stays on every client, so the spots are always there to read.
	plot.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	plot:PivotTo(CFrame.new(SpaLayout.slotPivot(slot)))
	anchorAll(plot)
	plot.Parent = folder
	-- The props, each on its spot. A missing prop asset is skipped; the spot stays empty.
	local props = Instance.new("Folder")
	props.Name = SpaLayout.PROPS_FOLDER
	for _, entry in SpaLayout.PROPS do
		local propAsset = assets:FindFirstChild(entry.asset)
		if propAsset and propAsset:IsA("Model") then
			local prop = (propAsset :: Model):Clone() :: Model
			prop.Name = entry.name
			prop:PivotTo(spotOn(plot, entry.spot, slot))
			anchorAll(prop)
			prop.Parent = props
		elseif slot == 1 then
			warn(`[PlotService] {entry.asset} is missing from ReplicatedStorage.Assets`)
		end
	end
	props.Parent = plot
end

local spawnSpot = SpaLayout.spawnSpot

-- Sets where the player respawns; nil goes back to Roblox's pick. The engine's type has no nil, though it takes one.
local function setRespawn(player: Player, spawn: SpawnLocation?)
	(player :: any).RespawnLocation = spawn
end

-- Slot `slot`'s spawn: PH_Spawn itself for slot 1, its copy for the others.
local function spawnFor(slot: number): SpawnLocation?
	if slot == 1 then
		local spawn = spawnLocation()
		return if spawn then spawn :: any else nil
	end
	return plotSpawns[slot]
end

-- Every plot gets a spawn whose top sits on the floor at its spawn spot, facing the same way, so the character and
-- the camera start there already turned right. Before #188 there was one spawn, in plot 1, and players in slot 2
-- and up were moved about 44 studs after spawning: the camera swung along the move and started sideways.
-- Then every player's RespawnLocation is set to their own plot's spawn (a Neutral spawn in Workspace).
local function placeSpawnLocation()
	local spawn = spawnLocation()
	local folder = street
	if spawn == nil or folder == nil then
		return
	end
	roomSpawn = roomSpawn or spawn.CFrame
	for slot = 1, SpaLayout.PLOT_COUNT do
		local target: BasePart? = spawnFor(slot)
		if target == nil then
			local copy = spawn:Clone() :: SpawnLocation
			copy.Name = `{SPAWN_NAME}{slot}`
			copy.Parent = folder
			plotSpawns[slot] = copy
			target = copy
		end
		local part = target :: BasePart
		part.CFrame = spawnSpot(slot) * CFrame.new(0, -spawn.Size.Y / 2, 0)
	end
	for _, player in Players:GetPlayers() do
		local slot = SpaLayout.slotOf(player)
		setRespawn(player, if slot then spawnFor(slot) else nil)
	end
end

-- Puts a character on its owner's spawn spot, standing, facing the way the spot faces.
local function moveToPlot(player: Player, character: Model)
	local slot = SpaLayout.slotOf(player)
	if slot == nil or street == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local rootPart = root :: BasePart
	local height = (humanoid :: Humanoid).HipHeight + rootPart.Size.Y / 2
	local target = spawnSpot(slot) * CFrame.new(0, height, 0)
	local offset = rootPart.Position - target.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 1 then
		return -- it spawned on its own plot's spawn: leave it, and the camera, alone
	end
	-- A fallback, for a character that spawned before its plot's spawn existed.
	character:PivotTo(target)
	-- Drop any speed from the first spawn, so the move never carries a fall into the new plot.
	rootPart.AssemblyLinearVelocity = Vector3.zero
end

local function place()
	if street then
		return
	end
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	local asset = if assets then assets:FindFirstChild(SpaLayout.ASSET) else nil
	if asset == nil or not asset:IsA("Model") or street or not LiveFlags.isOn(SpaLayout.FLAG) then
		if asset == nil then
			warn(
				`[PlotService] {SpaLayout.ASSET} is missing from ReplicatedStorage.Assets; staying in the room`
			)
		end
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = SpaLayout.PLOTS_FOLDER
	local streetAsset = (assets :: Instance):FindFirstChild(SpaLayout.STREET_ASSET)
	if streetAsset and streetAsset:IsA("Model") then
		local streetModel = (streetAsset :: Model):Clone() :: Model
		streetModel.Name = "Street"
		streetModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		streetModel:PivotTo(CFrame.new(SpaLayout.slotPivot(1)))
		anchorAll(streetModel)
		streetModel.Parent = folder
		local floor = Workspace:FindFirstChild(FLOOR_NAME)
		if floor then
			storedFloor = floor
			floor.Parent = ServerStorage
		end
	else
		warn(`[PlotService] {SpaLayout.STREET_ASSET} is missing from ReplicatedStorage.Assets`)
	end
	for slot = 1, SpaLayout.PLOT_COUNT do
		placePlot(asset :: Model, assets :: Instance, slot, folder)
	end
	folder.Parent = Workspace
	street = folder
	ReplicatedStorage:SetAttribute(SpaLayout.PLACED_ATTRIBUTE, true)
	placeSpawnLocation()
end

local function remove()
	ReplicatedStorage:SetAttribute(SpaLayout.PLACED_ATTRIBUTE, false)
	local folder = street
	street = nil
	if folder then
		folder:Destroy()
	end
	local floor = storedFloor
	storedFloor = nil
	if floor then
		floor.Parent = Workspace
	end
	table.clear(plotSpawns) -- destroyed with the street folder
	for _, player in Players:GetPlayers() do
		setRespawn(player, nil)
	end
	local spawn = spawnLocation()
	if spawn and roomSpawn then
		spawn.CFrame = roomSpawn :: CFrame
	end
end

local function refresh()
	if LiveFlags.isOn(SpaLayout.FLAG) then
		place()
	else
		remove()
	end
end

-- Gives the player the lowest free slot. A full street (more players than plots) leaves them without one: they
-- see the room's spots, and the server size should match PLOT_COUNT so this never happens.
local function assign(player: Player)
	if SpaLayout.slotOf(player) ~= nil then
		return
	end
	for slot = 1, SpaLayout.PLOT_COUNT do
		if owners[slot] == nil then
			owners[slot] = player
			player:SetAttribute(SpaLayout.SLOT_ATTRIBUTE, slot)
			if street then
				setRespawn(player, spawnFor(slot))
			end
			return
		end
	end
	warn(`[PlotService] all {SpaLayout.PLOT_COUNT} plots are taken; set the server size to match`)
end

local function release(player: Player)
	for slot, owner in owners do
		if owner == player then
			owners[slot] = nil
		end
	end
end

local function onPlayer(player: Player)
	assign(player)
	-- Whatever sets the slot (assign, or a test that changes it by hand), the next spawn is in that plot.
	player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(function()
		local slot = SpaLayout.slotOf(player)
		if street then
			setRespawn(player, if slot then spawnFor(slot) else nil)
		end
	end)
	player.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("HumanoidRootPart", 5)
		task.defer(moveToPlot, player, character)
	end)
	local character = player.Character
	if character then
		task.defer(moveToPlot, player, character)
	end
end

function PlotService.Init(_services: { [string]: any })
	ReplicatedStorage:SetAttribute(SpaLayout.PLACED_ATTRIBUTE, false)
end

function PlotService.Start()
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. SpaLayout.FLAG)
		:Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. VIEW_FLAG)
		:Connect(placeSpawnLocation)
	refresh()
end

return PlotService
