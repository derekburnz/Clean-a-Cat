--!strict
-- PlotController: the street is look only (#88). Other players' spas get an invisible wall around them on this
-- client only, so this player can walk the street and look in through the open fronts and windows but not walk
-- in. It is a comfort rule, not security: the server already checks every action against the acting player's
-- own plot (SpaLayout.spot(name, player)). Behind the LiveFlags switch `spaVisitors`, off by default: off, the
-- walls stand; on, visitors may walk in. Has no effect while the street (`spaPlot`) is off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "spaVisitors"
local WALL_EXTRA_HEIGHT = 40 -- well above a jump, so nobody stands on top
local FOLDER_NAME = "VisitorWalls"

local PlotController = {}

local walls: Folder? = nil

local function clear()
	local folder = walls
	walls = nil
	if folder then
		folder:Destroy()
	end
end

local function refresh()
	clear()
	if LiveFlags.isOn(FLAG) or not SpaLayout.onPlot() then
		return
	end
	local mine = SpaLayout.slotOf()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for slot = 1, SpaLayout.PLOT_COUNT do
		local plot = SpaLayout.plotModel(slot)
		if slot ~= mine and plot then
			local cframe, size = (plot :: Model):GetBoundingBox()
			local wall = Instance.new("Part")
			wall.Name = `Wall{slot}`
			wall.Anchored = true
			wall.CanCollide = true
			wall.CanQuery = false
			wall.CanTouch = false
			wall.CastShadow = false
			wall.Transparency = 1
			wall.Size = size + Vector3.new(0, WALL_EXTRA_HEIGHT, 0)
			wall.CFrame = cframe * CFrame.new(0, WALL_EXTRA_HEIGHT / 2, 0)
			wall.Parent = folder
		end
	end
	folder.Parent = Workspace
	walls = folder
end

function PlotController.Init(_controllers: { [string]: any }) end

function PlotController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	SpaLayout.changed(function()
		-- The plots replicate after the attribute; wait for this player's plot before drawing.
		task.delay(1, refresh)
	end)
	task.delay(1, refresh)
end

return PlotController
