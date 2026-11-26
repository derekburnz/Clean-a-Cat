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
local StandRules = require(Shared:WaitForChild("StandRules"))

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
		if SpaLayout.big() and SpaLayout.BIG_SKIPS_PROPS[entry.name] then
			continue
		end
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

-- Stands a character on `spot` (the base of its feet), facing the way the spot faces, R6 or R15 (StandRules).
-- Nothing when it already stands there, so the camera is left alone; one that sank or fell below the spot is moved.
-- False for a character with no humanoid or root yet.
local function standAt(character: Model, spot: CFrame): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	local rootPart = root :: BasePart
	local body = humanoid :: Humanoid
	local height = StandRules.rootHeight(
		body.RigType == Enum.HumanoidRigType.R15,
		body.HipHeight,
		rootPart.Size.Y
	)
	local target = spot * CFrame.new(0, height, 0)
	local offset = rootPart.Position - target.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 1 and math.abs(offset.Y) < 1 then
		return true
	end
	character:PivotTo(target)
	-- Drop any speed from the first spawn, so the move never carries a fall into the new spot.
	rootPart.AssemblyLinearVelocity = Vector3.zero
	return true
end

-- A plot spot a player stands on instead of the spawn until released (the opening's SpotOpening, #285).
local standSpot: { [Player]: string } = {}

-- Puts a character on its owner's spawn spot (or the spot it was told to stand on), standing, facing the way the
-- spot faces. A fallback, for a character that spawned before its plot's spawn existed; one already there is left
-- alone.
local function moveToPlot(player: Player, character: Model)
	local slot = SpaLayout.slotOf(player)
	if slot == nil or street == nil then
		return
	end
	local name = standSpot[player]
	standAt(character, if name then SpaLayout.slotSpot(name, slot) else spawnSpot(slot))
end

-- Stands the player on plot spot `name` of their own plot (the opening's SpotOpening, #285), now if the character
-- is there and on every spawn until release(). False when the street, the plot or the spot is missing.
function PlotService.standOn(player: Player, name: string): boolean
	if SpaLayout.plotSpot(name) == nil then
		return false
	end
	standSpot[player] = name
	local slot = SpaLayout.slotOf(player)
	local character = player.Character
	if slot == nil or street == nil or character == nil then
		return false
	end
	return standAt(character, SpaLayout.slotSpot(name, slot))
end

-- The player spawns on their plot's spawn again (the box was opened).
function PlotService.release(player: Player)
	standSpot[player] = nil
end

local function place()
	if street then
		return
	end
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	-- (switch bigSpa) the big spa when it is on and both its plot and street are in the game, else the small one
	local bigPlot = if assets then assets:FindFirstChild(SpaLayout.BIG_ASSET) else nil
	local bigStreet = if assets then assets:FindFirstChild(SpaLayout.BIG_STREET_ASSET) else nil
	local useBig = LiveFlags.isOn(SpaLayout.BIG_FLAG)
		and bigPlot ~= nil
		and bigPlot:IsA("Model")
		and bigStreet ~= nil
		and bigStreet:IsA("Model")
	if LiveFlags.isOn(SpaLayout.BIG_FLAG) and not useBig then
		warn(
			`[PlotService] bigSpa is on but {SpaLayout.BIG_ASSET} or {SpaLayout.BIG_STREET_ASSET} is missing; placing the small spa`
		)
	end
	local asset = if assets
		then assets:FindFirstChild(if useBig then SpaLayout.BIG_ASSET else SpaLayout.ASSET)
		else nil
	if asset == nil or not asset:IsA("Model") or street or not LiveFlags.isOn(SpaLayout.FLAG) then
		if asset == nil then
			warn(
				`[PlotService] {SpaLayout.ASSET} is missing from ReplicatedStorage.Assets; staying in the room`
			)
		end
		return
	end
	-- said before anything is placed, so every spot and pivot below (and on every client) follows the same street
	ReplicatedStorage:SetAttribute(SpaLayout.BIG_ATTRIBUTE, useBig)
	local folder = Instance.new("Folder")
	folder.Name = SpaLayout.PLOTS_FOLDER
	local streetAsset = (assets :: Instance):FindFirstChild(
		if useBig then SpaLayout.BIG_STREET_ASSET else SpaLayout.STREET_ASSET
	)
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
	ReplicatedStorage:SetAttribute(SpaLayout.BIG_ATTRIBUTE, false)
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
	-- the first read sets each switch's attribute one by one: placing on the spa switch's own change could read
	-- bigSpa before it is set and place the small spa for good (#871); Start places once the read is done
	if not LiveFlags.read() then
		return
	end
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
	standSpot[player] = nil
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
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. SpaLayout.SIDE_FLAG)
		:Connect(placeSpawnLocation)
	-- the street's size (bigSpa) is chosen once, when it is placed: wait for the switches' first read, or a server
	-- that placed before it would keep the small spa all its life while the counter line is on (#871)
	task.spawn(function()
		LiveFlags.waitForRead()
		refresh()
	end)
	-- a first read that ends after that wait places it then (place does nothing a second time; Review-QA on #898)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.READ_ATTRIBUTE):Connect(refresh)
end

return PlotService
