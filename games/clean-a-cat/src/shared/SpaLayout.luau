--!strict
-- SpaLayout: where each gameplay spot is (the tub, the spawn, the customer line, the window, the boards), on the
-- server and the client. While the spa plot is placed (PlotService, behind the LiveFlags switch `spaPlot`), a spot
-- is Model-Agent's Attachment of the same name in the plot, read as its WorldCFrame. Otherwise it is the old
-- placeholder room's spot, so turning the switch off gives back exactly the world before the plot.
--
-- Every spot faces the way the thing there faces: a model's front (-Z, its LookVector) points along the spot's
-- LookVector. Each spot is where the base of the thing there sits.
--
--   SpaLayout.spot(name): CFrame        the spot in the world right now
--   SpaLayout.lineSpot(prefix, index)   SpotQueue<index> or SpotWindow<index>; past the last one, the line goes on
--   SpaLayout.onPlot(): boolean         is the plot placed?
--   SpaLayout.changed(fn)               fn() when the plot is placed or taken away (redraw what stands on spots)
--   SpaLayout.place(name, onPlot)       the pure part: (position, yaw) from the tables below; specs cover it
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpaLayout = {}

SpaLayout.FLAG = "spaPlot"
SpaLayout.ASSET = "CleanACat_Area_SpaPlot" -- ReplicatedStorage.Assets.<ASSET>, placed in Workspace under this name
SpaLayout.PLACED_ATTRIBUTE = "SpaPlotPlaced" -- ReplicatedStorage attribute: true while the plot is in Workspace
-- Where the plot's pivot (the plot centre on the ground, street side -Z) goes. This keeps the tub where the
-- placeholder room had it, (0, 0, -12) on the ground.
SpaLayout.PIVOT_POSITION = Vector3.new(-5, 0, -10)

export type Spot = { position: Vector3, yaw: number }

local function at(x: number, y: number, z: number, yaw: number): Spot
	local spot: Spot = { position = Vector3.new(x, y, z), yaw = yaw }
	return spot
end

local TURNED = math.pi -- a half turn: faces +Z

-- The plot's spots relative to its pivot, matching the Attachments in CleanACat_Area_SpaPlot (y is the height
-- above the pivot: the floor top is 0.5). Used when an Attachment is missing, and before the plot replicates.
-- Keep these in step with the model.
SpaLayout.PLOT_SPOTS = table.freeze({
	SpotTub = at(5, 0.5, -2, 0),
	SpotSpawn = at(5, 0.5, -8.5, TURNED),
	SpotQueue1 = at(-5, 0.5, -13, TURNED),
	SpotQueue2 = at(-5, 0.5, -17.5, TURNED),
	SpotQueue3 = at(-5, 0.5, -21.5, TURNED),
	SpotStray = at(12, 0.5, 7, 0),
	SpotWindow1 = at(13.5, 3.35, -14.2, 0),
	SpotWindow2 = at(10, 3.35, -14.2, 0),
	SpotWindow3 = at(6.5, 3.35, -14.2, 0),
	SpotWindow4 = at(3, 3.35, -14.2, 0),
	SpotBuilder = at(-13, 0.5, 6, 0),
	SpotStation2 = at(-7, 0.5, -1, 0),
	SpotStation3 = at(-13.5, 0.5, -1, 0),
	SpotVipDoor = at(-7, 0.5, 10.5, 0),
	SpotBoard = at(-13.5, 4.5, -14.95, TURNED),
	-- Not in the model: the Tools board stands on the floor left of the tub, facing the spawn.
	Tools = at(-1, 0.5, -2, 0),
}) :: { [string]: Spot }

-- The placeholder room before the plot, in world space: the spawn at the origin and everything facing it (+Z).
SpaLayout.ROOM_SPOTS = table.freeze({
	SpotTub = at(0, 0, -12, TURNED),
	SpotSpawn = at(0, 0.5, 0, 0),
	SpotQueue1 = at(8, 0, -8, TURNED),
	SpotQueue2 = at(11, 0, -8, TURNED),
	SpotQueue3 = at(14, 0, -8, TURNED),
	SpotWindow1 = at(-9, 0, -3, TURNED),
	SpotWindow2 = at(-6.6, 0, -3, TURNED),
	SpotWindow3 = at(-4.2, 0, -3, TURNED),
	SpotWindow4 = at(-1.8, 0, -3, TURNED),
	SpotBuilder = at(-11, 0, -12, TURNED),
	SpotBoard = at(5, 1, -6, TURNED),
	Tools = at(-6, 0, -12, TURNED),
}) :: { [string]: Spot }

-- A spot's world position and yaw from the tables: the plot's (moved to PIVOT_POSITION) while it is placed,
-- else the room's. A spot the room never had uses the plot's. Nil for an unknown name.
function SpaLayout.place(name: string, onPlot: boolean): (Vector3?, number)
	local room = SpaLayout.ROOM_SPOTS[name]
	if not onPlot and room then
		return room.position, room.yaw
	end
	local plot = SpaLayout.PLOT_SPOTS[name]
	if plot then
		return SpaLayout.PIVOT_POSITION + plot.position, plot.yaw
	end
	return nil, 0
end

-- The name of the `index`th spot of a line ("SpotQueue", "SpotWindow"). Past the last listed spot it is the last
-- one, with how many steps further on (0 when listed) and the spot before it, whose gap is one step.
function SpaLayout.lineName(
	prefix: string,
	index: number,
	onPlot: boolean
): (string, number, string)
	local tables = if onPlot then SpaLayout.PLOT_SPOTS else SpaLayout.ROOM_SPOTS
	local last = 0
	while tables[prefix .. (last + 1)] do
		last += 1
	end
	if index <= last or last < 2 then
		local name = prefix .. math.max(1, math.min(index, last))
		return name, 0, name
	end
	return prefix .. last, index - last, prefix .. (last - 1)
end

function SpaLayout.onPlot(): boolean
	return ReplicatedStorage:GetAttribute(SpaLayout.PLACED_ATTRIBUTE) == true
end

local function placedAttachment(name: string): Attachment?
	local plot = game:GetService("Workspace"):FindFirstChild(SpaLayout.ASSET)
	local found = if plot then plot:FindFirstChild(name, true) else nil
	return if found and found:IsA("Attachment") then found :: Attachment else nil
end

function SpaLayout.spot(name: string): CFrame
	local onPlot = SpaLayout.onPlot()
	if onPlot then
		local attachment = placedAttachment(name)
		if attachment then
			return attachment.WorldCFrame
		end
	end
	local position, yaw = SpaLayout.place(name, onPlot)
	return CFrame.new(position or Vector3.zero) * CFrame.Angles(0, yaw, 0)
end

-- The `index`th spot of a line. Past the last listed spot the line goes on, one step (the gap between the last
-- two spots) at a time.
function SpaLayout.lineSpot(prefix: string, index: number): CFrame
	local name, past, before = SpaLayout.lineName(prefix, index, SpaLayout.onPlot())
	local cframe = SpaLayout.spot(name)
	if past <= 0 then
		return cframe
	end
	return cframe + (cframe.Position - SpaLayout.spot(before).Position) * past
end

function SpaLayout.changed(fn: () -> ()): RBXScriptConnection
	return ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(fn)
end

return SpaLayout
