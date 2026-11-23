--!strict
-- PlotService: places Model-Agent's spa plot (ReplicatedStorage.Assets.CleanACat_Area_SpaPlot) in Workspace and
-- moves the spawn to the plot's SpotSpawn, facing the tub. Behind the LiveFlags switch `spaPlot`: off, the plot
-- is taken away and the spawn goes back to the placeholder room, so the world is exactly as before.
-- Clients and other services read the spots through Shared.SpaLayout; the ReplicatedStorage attribute
-- SpaLayout.PLACED_ATTRIBUTE says whether the plot is placed, so they redraw when it changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local SPAWN_NAME = "PH_Spawn" -- the spawn in default.project.json
local ASSET_WAIT_SECONDS = 10

local PlotService = {}

local placed: Model? = nil
local roomSpawn: CFrame? = nil -- where PH_Spawn stood before the plot, to put it back

local function spawnLocation(): BasePart?
	local spawn = Workspace:FindFirstChild(SPAWN_NAME)
	return if spawn and spawn:IsA("SpawnLocation") then spawn :: BasePart else nil
end

local function place()
	if placed then
		return
	end
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	local asset = if assets then assets:FindFirstChild(SpaLayout.ASSET) else nil
	if asset == nil or not asset:IsA("Model") or placed or not LiveFlags.isOn(SpaLayout.FLAG) then
		if asset == nil then
			warn(
				`[PlotService] {SpaLayout.ASSET} is missing from ReplicatedStorage.Assets; staying in the room`
			)
		end
		return
	end
	local plot = (asset :: Model):Clone() :: Model
	plot.Name = SpaLayout.ASSET
	-- With streaming on, the whole plot stays on every client, so the spots are always there to read.
	plot.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	plot:PivotTo(CFrame.new(SpaLayout.PIVOT_POSITION))
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).Anchored = true
		end
	end
	plot.Parent = Workspace
	placed = plot
	ReplicatedStorage:SetAttribute(SpaLayout.PLACED_ATTRIBUTE, true)
	local spawn = spawnLocation()
	if spawn then
		roomSpawn = roomSpawn or spawn.CFrame
		-- The spawn's top sits on the floor at SpotSpawn; a new character faces the way the spawn faces.
		spawn.CFrame = SpaLayout.spot("SpotSpawn") * CFrame.new(0, -spawn.Size.Y / 2, 0)
	end
end

local function remove()
	ReplicatedStorage:SetAttribute(SpaLayout.PLACED_ATTRIBUTE, false)
	local plot = placed
	placed = nil
	if plot then
		plot:Destroy()
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

function PlotService.Init(_services: { [string]: any })
	ReplicatedStorage:SetAttribute(SpaLayout.PLACED_ATTRIBUTE, false)
end

function PlotService.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. SpaLayout.FLAG)
		:Connect(refresh)
	refresh()
end

return PlotService
