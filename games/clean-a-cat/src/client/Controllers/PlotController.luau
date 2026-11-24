--!strict
-- PlotController: the street is look only (#88). Other players' spas get an invisible wall around them on this
-- client only, so this player can walk the street and look in through the open fronts and windows but not walk
-- in. It is a comfort rule, not security: the server already checks every action against the acting player's
-- own plot (SpaLayout.spot(name, player)). Behind the LiveFlags switch `spaVisitors`, off by default: off, the
-- walls stand; on, visitors may walk in. Has no effect while the street (`spaPlot`) is off.
-- Each wall is a hollow ring of four thin sides on the edge of the plot's box, never a solid block: a character
-- that is inside another plot when the walls go up (the shared spawn sits in plot 1, and a slot change leaves the
-- old walls up for a moment) stands on the floor until the server moves it, instead of being pushed out of a
-- solid part and through the floor (#169).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "spaVisitors"
local WALL_EXTRA_HEIGHT = 40 -- well above a jump, so nobody stands on top
local WALL_THICKNESS = 1
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
			local height = size.Y + WALL_EXTRA_HEIGHT
			local y = WALL_EXTRA_HEIGHT / 2
			local inX = size.X / 2 - WALL_THICKNESS / 2
			local inZ = size.Z / 2 - WALL_THICKNESS / 2
			-- Front and back span the full width; the two sides fit between them. All sit inside the box, so a
			-- neighbour's ring never reaches into this player's own plot.
			local sides: { { name: string, size: Vector3, offset: Vector3 } } = {
				{
					name = "Front",
					size = Vector3.new(size.X, height, WALL_THICKNESS),
					offset = Vector3.new(0, y, -inZ),
				},
				{
					name = "Back",
					size = Vector3.new(size.X, height, WALL_THICKNESS),
					offset = Vector3.new(0, y, inZ),
				},
				{
					name = "Left",
					size = Vector3.new(WALL_THICKNESS, height, size.Z - 2 * WALL_THICKNESS),
					offset = Vector3.new(-inX, y, 0),
				},
				{
					name = "Right",
					size = Vector3.new(WALL_THICKNESS, height, size.Z - 2 * WALL_THICKNESS),
					offset = Vector3.new(inX, y, 0),
				},
			}
			for _, side in sides do
				local wall = Instance.new("Part")
				wall.Name = `Wall{slot}{side.name}`
				wall.Anchored = true
				wall.CanCollide = true
				wall.CanQuery = false
				wall.CanTouch = false
				wall.CastShadow = false
				wall.Transparency = 1
				wall.Size = side.size
				wall.CFrame = cframe * CFrame.new(side.offset)
				wall.Parent = folder
			end
		end
	end
	folder.Parent = Workspace
	walls = folder
end

function PlotController.Init(_controllers: { [string]: any }) end

function PlotController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	SpaLayout.changed(function()
		-- The old walls may stand around this player's new plot: take them down now. The plots replicate after
		-- the attribute, so wait for them before drawing again.
		clear()
		task.delay(1, refresh)
	end)
	task.delay(1, refresh)
end

return PlotController
